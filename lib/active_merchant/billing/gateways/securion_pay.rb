module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SecurionPayGateway < Gateway
      self.test_url = 'https://api.securionpay.com/'
      self.live_url = 'https://api.securionpay.com/'

      self.supported_countries = %w(AD BE BG CH CY CZ DE DK EE ES FI FO FR GI GL GR GS GT HR HU IE IS IT LI LR LT
                                    LU LV MC MT MU MV MW NL NO PL RO SE SI)

      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express discover jcb diners_club]

      self.homepage_url = 'https://securionpay.com/'
      self.display_name = 'SecurionPay'

      STANDARD_ERROR_CODE_MAPPING = {
        'incorrect_number' => STANDARD_ERROR_CODE[:incorrect_number],
        'invalid_number' => STANDARD_ERROR_CODE[:invalid_number],
        'invalid_expiry_month' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_expiry_year' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'invalid_cvc' => STANDARD_ERROR_CODE[:invalid_cvc],
        'expired_card' => STANDARD_ERROR_CODE[:expired_card],
        'insufficient_funds' => STANDARD_ERROR_CODE[:card_declined],
        'incorrect_cvc' => STANDARD_ERROR_CODE[:incorrect_cvc],
        'incorrect_zip' => STANDARD_ERROR_CODE[:incorrect_zip],
        'card_declined' => STANDARD_ERROR_CODE[:card_declined],
        'processing_error' => STANDARD_ERROR_CODE[:processing_error],
        'lost_or_stolen' => STANDARD_ERROR_CODE[:card_declined],
        'suspected_fraud' => STANDARD_ERROR_CODE[:card_declined],
        'expired_token' => STANDARD_ERROR_CODE[:card_declined]
      }

      def initialize(options={})
        requires!(options, :secret_key)
        super
      end

      def purchase(money, payment, options={})
        post = create_post_for_auth_or_purchase(money, payment, options)
        commit('charges', post, options)
      end

      def authorize(money, payment, options={})
        post = create_post_for_auth_or_purchase(money, payment, options)
        post[:captured] = 'false'
        commit('charges', post, options)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_amount(post, money, options)
        commit("charges/#{CGI.escape(authorization)}/capture", post, options)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_amount(post, money, options)
        commit("charges/#{CGI.escape(authorization)}/refund", post, options)
      end

      def void(authorization, options = {})
        commit("charges/#{CGI.escape(authorization)}/refund", {}, options)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(credit_card, options = {})
        if options[:customer_id].blank?
          MultiResponse.run() do |r|
            # create charge object
            r.process { authorize(100, credit_card, options) }
            # create customer and save card
            r.process { create_customer_add_card(r.authorization, options) }
            # void the charge
            r.process(:ignore_result) { void(r.params['metadata']['chargeId'], options) }
          end
        else
          verify(credit_card, options)
        end
      end

      def customer(options = {})
        if options[:customer_id].blank?
          return nil
        else
          commit("customers/#{CGI.escape(options[:customer_id])}", nil, options, :get)
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((card\[number\]=)\d+), '\1[FILTERED]').
          gsub(%r((card\[cvc\]=)\d+), '\1[FILTERED]')
      end

      private

      def create_customer_add_card(authorization, options)
        post = {}
        post[:email] = options[:email]
        post[:description] = options[:description]
        post[:card] = authorization
        post[:metadata] = {}
        post[:metadata][:chargeId] = authorization
        commit('customers', post, options)
      end

      def add_customer(post, payment, options)
        post[:customerId] = options[:customer_id] if options[:customer_id]
      end

      def add_customer_data(post, options)
        post[:description] = options[:description]
        post[:ip] =          options[:ip]
        post[:user_agent] =  options[:user_agent]
        post[:referrer] =    options[:referrer]
      end

      def create_post_for_auth_or_purchase(money, payment, options)
        post = {}
        add_amount(post, money, options, true)
        add_creditcard(post, payment, options)
        add_customer(post, payment, options)
        add_customer_data(post, options)
        if options[:email]
          post[:metadata] = {}
          post[:metadata][:email] = options[:email]
        end
        post
      end

      def add_amount(post, money, options, include_currency = false)
        currency = (options[:currency] || default_currency)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency.downcase if include_currency
      end

      def add_creditcard(post, creditcard, options)
        card = {}
        if creditcard.respond_to?(:number)
          card[:number] = creditcard.number
          card[:expMonth] = creditcard.month
          card[:expYear] = creditcard.year
          card[:cvc] = creditcard.verification_value if creditcard.verification_value?
          card[:cardholderName] = creditcard.name if creditcard.name

          post[:card] = card
          add_address(post, options)
        elsif creditcard.kind_of?(String)
          post[:card] = creditcard
        else
          raise ArgumentError.new("Unhandled payment method #{creditcard.class}.")
        end
      end

      def add_address(post, options)
        return unless post[:card]&.kind_of?(Hash)

        if address = options[:billing_address]
          post[:card][:addressLine1] = address[:address1] if address[:address1]
          post[:card][:addressLine2] = address[:address2] if address[:address2]
          post[:card][:addressCountry] = address[:country] if address[:country]
          post[:card][:addressZip] = address[:zip] if address[:zip]
          post[:card][:addressState] = address[:state] if address[:state]
          post[:card][:addressCity] = address[:city] if address[:city]
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(url, parameters = nil, options = {}, method = nil)
        response = api_request(url, parameters, options, method)
        success = !response.key?('error')

        Response.new(success,
          (success ? 'Transaction approved' : response['error']['message']),
          response,
          test: test?,
          authorization: (success ? response['id'] : response['error']['charge']),
          error_code: (success ? nil : STANDARD_ERROR_CODE_MAPPING[response['error']['code']])
        )
      end

      def headers(options = {})
        secret_key = options[:secret_key] || @options[:secret_key]

        headers = {
          'Authorization' => 'Basic ' + Base64.encode64(secret_key.to_s + ':').strip,
          'User-Agent' => "SecurionPay/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
        headers
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def post_data(params)
        return nil unless params

        params.map do |key, value|
          next if value.blank?

          if value.is_a?(Hash)
            h = {}
            value.each do |k, v|
              h["#{key}[#{k}]"] = v unless v.blank?
            end
            post_data(h)
          elsif value.is_a?(Array)
            value.map { |v| "#{key}[]=#{CGI.escape(v.to_s)}" }.join('&')
          else
            "#{key}=#{CGI.escape(value.to_s)}"
          end
        end.compact.join('&')
      end

      def api_request(endpoint, parameters = nil, options = {}, method = nil)
        raw_response = response = nil
        begin
          if method.blank?
            raw_response = ssl_post(self.live_url + endpoint, post_data(parameters), headers(options))
          else
            raw_response = ssl_request(method, self.live_url + endpoint, post_data(parameters), headers(options))
          end
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the SecurionPay API.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'error' => {
            'message' => msg
          }
        }
      end

      def test?
        (@options[:secret_key]&.include?('_test_'))
      end
    end
  end
end
