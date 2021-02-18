module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VacaypayGateway < Gateway
      class_attribute :stripe_live_url

      self.stripe_live_url = 'https://api.stripe.com/v1/'
      self.live_url = 'https://www.procuro.io/api/v1/vacay-pay/'

      # The homepage URL of the gateway
      self.homepage_url = 'https://www.procuro.io/vacay-pay'

      # The name of the gateway
      self.display_name = 'VacayPay'

      # Money is referenced in dollars
      self.money_format = :dollars
      self.default_currency = 'USD'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = %w(AU CA GB US BE DK FI FR DE NL NO ES IT IE)

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club, :maestro]

      STANDARD_ERROR_CODE_MAPPING = {
        'incorrect_number' => STANDARD_ERROR_CODE[:incorrect_number],
        'invalid_number' => STANDARD_ERROR_CODE[:invalid_number],
        'invalid_expiry_month' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_expiry_year' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_cvc' => STANDARD_ERROR_CODE[:invalid_cvc],
        'expired_card' => STANDARD_ERROR_CODE[:expired_card],
        'incorrect_cvc' => STANDARD_ERROR_CODE[:incorrect_cvc],
        'incorrect_zip' => STANDARD_ERROR_CODE[:incorrect_zip],
        'card_declined' => STANDARD_ERROR_CODE[:card_declined],
        'call_issuer' => STANDARD_ERROR_CODE[:call_issuer],
        'processing_error' => STANDARD_ERROR_CODE[:processing_error],
        'incorrect_pin' => STANDARD_ERROR_CODE[:incorrect_pin],
        'test_mode_live_card' => STANDARD_ERROR_CODE[:test_mode_live_card]
      }

      RESPONSE_API_UNAUTHORIZED = 4

      def initialize(options={})
        requires!(options, :api_key, :account_uuid)

        @api_key = options[:api_key]
        @account_uuid = options[:account_uuid]
        @publishable_key = options[:publishable_key]

        super
      end

      def purchase(money, payment_method, options={})
        post = {}

        store_response = store(payment_method, options)
        return store_response unless store_response.success?

        add_payment_method(post, store_response)
        add_invoice(post, money, options)
        add_address(post, payment_method, options)
        add_customer_data(post, options)
        add_settings(post, options)

        commit('charge', post)
      end

      def authorize(money, payment_method, options={})
        post = { :authorize => true }

        store_response = store(payment_method, options)
        return store_response unless store_response.success?

        add_payment_method(post, store_response)
        add_invoice(post, money, options)
        add_address(post, payment_method, options)
        add_customer_data(post, options)
        add_settings(post, options)

        commit('authorize', post)
      end

      def capture(money, authorization, options={})
        options[:payment_uuid] = authorization
        options[:amount] = amount(money)

        commit('capture', options)
      end

      def refund(money, authorization, options={})
        options[:payment_uuid] = authorization
        options[:amount] = amount(money)

        commit('refund', options)
      end

      def void(authorization, options={})
        options[:payment_uuid] = authorization

        commit('void', options)
      end

      def store(payment_method, options={})
        card = {
          :number => payment_method.number,
          :cvc => payment_method.verification_value,
          :exp_month => format(payment_method.month, :two_digits),
          :exp_year => format(payment_method.year, :two_digits)
        }

        stripe_commit('tokens', { :card => card })
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r(((?:\r\n)?X-Auth-Token: )[^\\]*), '\1[FILTERED]').
          gsub(%r("number\\?":\\?"[0-9]*\\?"), '\1[FILTERED]').
          gsub(%r("cvv\\?":\\?"[0-9]*\\?"), '\1[FILTERED]').
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((Authorization: Bearer )\w+), '\1[FILTERED]').
          gsub(%r((card\[number\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[cvc\]=)\d+), '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:email] = options[:email].to_s
        post[:firstName] = options[:first_name].to_s
        post[:lastName] = options[:last_name].to_s
        post[:description] = options[:description].to_s
        post[:externalPaymentReference] = options[:order_id].to_s
        post[:externalBookingReference] = options[:external_booking_reference].to_s
        post[:accessingIp] = options[:ip]
        post[:notes] = options[:notes].to_s
        post[:metadata] = options[:metadata].to_h
      end

      def add_address(post, creditcard, options)
        address = options[:billing_address] || options[:address]
        if address
          post[:billingLine1] = address[:address1] if address[:address1]
          post[:billingLine2] = address[:address2] if address[:address2]
          post[:billingPostcode] = address[:zip] if address[:zip]
          post[:billingRegion] = address[:state] if address[:state]
          post[:billingTown] = address[:city] if address[:city]
          post[:billingCountry] = address[:country] if address[:country]
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment_method(post, token_response)
        post[:cardToken] = token_response.authorization
      end

      def add_settings(post, options)
        post[:sendEmailConfirmation] = options[:send_email_confirmation] # Defaults to false
      end

      def parse(body)
        if body.nil?
          {}
        else
          JSON.parse(body)
        end
      end

      def stripe_commit(endpoint, parameters)
        url = "#{self.stripe_live_url}#{endpoint}"

        begin
          response = parse(ssl_post(url, stripe_post_data(parameters), stripe_headers))
        rescue ActiveMerchant::ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          stripe_success_from(response),
          stripe_message_from(response),
          response,
          authorization: stripe_authorization_from(response),
          test: test?,
          error_code: stripe_error_code_from(response)
        )
      end

      def stripe_post_data(params = {})
        return nil unless params

        params.map do |key, value|
          next if value != false && value.blank?
          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            stripe_post_data(h)
          elsif value.is_a?(Array)
            value.map { |v| "#{key}[]=#{CGI.escape(v.to_s)}" }.join("&")
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join("&")
      end

      def stripe_headers
        {
          'Authorization' => 'Bearer ' + publishable_key,
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      def stripe_success_from(response)
        !response.key?('error')
      end

      def stripe_message_from(response)
        stripe_success_from(response) ? 'Succeeded' : response['error']['message']
      end

      def stripe_authorization_from(response)
        response['id']
      end

      def stripe_error_code_from(response)
        return nil if stripe_success_from(response)

        code = response['error']['code']
        decline_code = response['error']['decline_code'] if code == 'card_declined'

        error_code = STANDARD_ERROR_CODE_MAPPING[decline_code]
        error_code ||= STANDARD_ERROR_CODE_MAPPING[code]
        error_code
      end

      def commit(endpoint, parameters)
        url = get_url(endpoint, parameters)

        begin
          response = parse(ssl_post(url, post_data(parameters), headers))
        rescue ActiveMerchant::ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def get_url(action, parameters={})
        # Set uuid to 0 as we get a route not found (404) when account_uuid empty - this will return the expected 401
        account_uuid = @account_uuid.to_s.empty? ? '0' : @account_uuid.to_s

        if action == 'charge' || action == 'authorize'
          return "#{self.live_url}accounts/#{account_uuid}/payments"
        elsif action == 'capture'
          return "#{self.live_url}accounts/#{account_uuid}/payments/#{parameters[:payment_uuid]}/capture"
        elsif action == 'refund' || action == 'void'
          return "#{self.live_url}accounts/#{account_uuid}/payments/#{parameters[:payment_uuid]}/refund"
        elsif action =='account_details'
          return "#{self.live_url}accounts/#{account_uuid}"
        else
          raise ActiveMerchantError.new('Cannot commit without a valid endpoint')
        end
      end

      def post_data(params = {})
        params.to_json
      end

      def headers
        {
          'X-Auth-Token' => @api_key.to_s,
          'Content-Type' => 'application/json'
        }
      end

      def success_from(response)
        response['appCode'] == 0
      end

      def message_from(response)
        if success_from(response)
          return 'Succeeded'
        else
          if response.key?('data') && response['data'].key?('message')
            return response['data']['message'].to_s
          elsif response['appCode'] == RESPONSE_API_UNAUTHORIZED
            return response['appMessage']
          elsif response.key?('meta') && response['meta'].key?('errors') && response['meta']['errors'].kind_of?(Array)
            return response['meta']['errors'].compact.join(', ')
          end
        end
      end

      def authorization_from(response)
        response['data']['paymentUuid']
      end

      def error_code_from(response)
        return nil if success_from(response)

        if response['data'].key?('code')
          return STANDARD_ERROR_CODE_MAPPING[response['data']['code']] || 'unknown'
        else
          return response['appCode'].to_s
        end
      end

      def publishable_key
        return @publishable_key if @publishable_key.present? && @publishable_key != 'nil'

        begin
          response = parse(ssl_get(get_url('account_details'), headers))
          @publishable_key = response['data']['publishableKey'].to_s
        rescue ResponseError
          # Not authentication part just fetching extra details - wait till we get the 401 if credentials invalid
          ''
        end
      end
    end
  end
end
