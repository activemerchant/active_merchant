module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BamboraNaGateway < Gateway
      include Empty

      self.live_url = 'https://api.na.bambora.com'

      self.supported_countries = ['US', 'CA']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.bambora.com/'
      self.display_name = 'Bambora North America'

      STANDARD_ERROR_CODE_MAPPING = {}

      # TODO: add error code mapping and auth/capture/void/refund methods

      def initialize(options={})
        requires!(options, :merchant_id, :api_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, 'sale')
        add_address(post, payment, options)

        commit('sale', post)
      end

      def store(credit_card, options = {})
        post = {}
        if options[:create_profile]
          add_payment(post, credit_card, 'profile')
          add_address(post, credit_card, options, 'profile')

          commit('ProfileBody', post)
        else
          add_payment(post, credit_card, 'store')

          commit('TokenRequest', post)
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Passcode )\w+), '\1[FILTERED]').
          gsub(/("number\\?":\\?")(\d*)/, '\1[FILTERED]').
          gsub(/("cvd\\?":\\?")(\d*)/, '\1[FILTERED]')
      end

      private

      def add_address(post, creditcard, options, action = nil)
        post[:billing] = {}
        if address = options[:billing_address] || options[:address]
          post[:billing][:address_line1] = address[:address1] if address[:address1]
          post[:billing][:address_line2] = address[:address2] if address[:address2]
          post[:billing][:city] = address[:city] if address[:city]
          post[:billing][:province] = address[:state] if address[:state]
          post[:billing][:postal_code] = address[:zip] if address[:zip]
          post[:billing][:country] = address[:country] if address[:country]
          if action && action == 'profile'
            post[:billing][:name] = creditcard.name
            post[:billing][:email_address] = options[:email]
            post[:billing][:phone_number] = address[:phone] if address[:phone]
          end
        end
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:payment_method] = 'card'
        post[:order_number] = options[:order_id] unless empty?(options[:order_id])
      end

      def add_payment(post, payment, action = nil)
        card = {}
        card[:number] = payment.number
        card[:expiry_month] = format(payment.month, :two_digits)
        card[:expiry_year] = format(payment.year, :two_digits)

        unless action == 'store'
          card[:name] = payment.name
          card[:cvd] = payment.verification_value
          card[:complete] = (action != 'auth')
        end

        action == 'store' ? post.merge!(card) : post[:card] = card
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers
        {
          'Authorization' => "Passcode #{encoded_passcode}",
          'Content-Type' => 'application/json'
        }
      end

      def encoded_passcode
        Base64.strict_encode64 "#{@options[:merchant_id]}:#{@options[:api_key]}"
      end

      def url(action)
        endpoint = if action == 'TokenRequest'
          'scripts/tokenization/tokens'
        elsif action == 'ProfileBody'
          'v1/profiles'
        else
          'v1/payments'
        end
        
        "#{live_url}/#{endpoint}"
      end

      def commit(action, parameters)
        begin
          raw_response = ssl_post(url(action), parameters.to_json, headers)
          body = parse(raw_response)
          code = '200' # AM returns the response.body when http_status 200..300
                       # so it's not available
        rescue ResponseError => e
          body = parse(e.response.body)
          code = e.response.code
        end
        
        Response.new(
          success_from(code),
          message_from(body),
          body,
          authorization: authorization_from(action, code, body),
          test: test?,
          error_code: error_code_from(body)
        )

      rescue JSON::ParserError
        return unparsable_response(raw_response)
      end

      def success_from(http_status)
        http_status == '200'
      end

      def message_from(response)
        response['message']
      end

      def authorization_from(action, http_status, response)
        if success_from(http_status) && action == 'sale'
          [response['id'], response['auth_code']].join('|')
        elsif success_from(http_status) && action == 'TokenRequest'
          response['token']
        elsif success_from(http_status) && action == 'ProfileBody'
          response['customer_code']
        end
      end

      def unparsable_response(raw_response)
        message = "Invalid JSON response received from Bambora NA. Please contact support if you continue to receive this message."
        message += "Support is available at https://help.na.bambora.com/hc/en-us/requests/new"
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
