module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SeerbitGateway < Gateway
      self.test_url = 'https://seerbitapi.com/api/v2'
      self.live_url = 'https://seerbitapi.com/api/v2'

      self.homepage_url = 'https://seerbit.com/'
      self.display_name = 'Seerbit'

      # GHS
      # Ghanaian Cedi
      # Ghana

      # KES
      # Kenya Shilling
      # Kenya

      # NGN
      # Nigerian Naira
      # Nigeria

      # TZS
      # Tanzanian Shilling
      # Tanzania

      # USD
      # Us Dollars
      # United States

      # XOF
      # CFA Franc BCEAO
      # Cameroon, Senegal, Dr Congo, Burkinfaso
      self.supported_countries = ['GH', 'KE', 'NG', 'TZ', 'US', 'CM']
      self.default_currency = 'GHS'

      self.supported_cardtypes = [:visa, :mastercard, :maestro]
      self.money_format = :cents

      def initialize(options = {})
        requires!(options, :public_key)

        @token = options[:token]
        @public_key = options[:public_key]
        @secret_key = options[:secret_key]
        super
      end

      def purchase(money, payment, options = {})
        post = {}

        add_order(post, money, options)
        add_customer_data(post, options)
        add_payment(post, payment)

        commit('/payments/charge', post)
      end

      def supports_scrubbing?
        true
      end

      def add_customer_data(post, options)
        customer = options[:customer] || {}

        post[:email] = customer[:email]
        post[:fullName] = customer[:full_name]
        post[:mobileNumber] = customer[:mob_phone]
      end

      def add_order(post, money, options)
        address = options[:address] || {}

        post[:amount] = amount(money)
        post[:currency] = options[:currency] || currency(money)
        post[:country] = address[:country] || 'NG'
        post[:paymentReference] = options[:reference]
        post[:retry] = false
      end

      def add_payment(post, payment)
        post[:payment] = {}
        post[:paymentType] = 'CARD'
        post[:cardNumber] = payment.number
        post[:cvv] = payment.verification_value if payment.verification_value?
        post[:expiryMonth] = payment.month.to_s
        post[:expiryYear] = payment.year.to_s

        post[:channelType] = card_brand(payment)
      end

      def card_brand(card)
        brand = super
        ({"master" => 'Mastercard'}[brand] || brand)
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Bearer )([A-Za-z0-9\-\._~\+\/]+=*)/, '\1[FILTERED]').
          gsub(/(\\?\\?\\?"pan\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?\\?\\?"cvv\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]')
      end

      private

      def commit(action, parameters)
        puts
        puts " # ========== commit ============== "

        url = (test? ? test_url : live_url) + action
        parameters[:publicKey] = @options[:public_key]

        puts " # url.inspect = #{url.inspect}"
        puts " # headers.inspect = #{headers.to_json.inspect}"
        puts " # parameters.inspect = #{parameters.to_json.inspect}"
        puts " # ===================== "
        puts

        raw_response = ssl_post(url, parameters.to_json, headers)
        response = parse(raw_response)
        succeeded = success_from(response)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers(options = {})
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{token}"
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response.fetch('status') == 'SUCCESS'
      end

      def message_from(succeeded, response)
        response.dig('data', 'message')
      end

      def authorization_from(response)
        response.dig('data', 'payments', 'linkingReference')
      end

      def error_code_from(response)
        response.dig('data', 'code')
      end

      def token
        @token || get_bearer_token
      end

      def get_bearer_token
        raise ArgumentError, 'You must include secret key' if @options[:secret_key].blank?

        auth_headers = { 'Content-Type' => 'application/json' }
        request_body = { key: "#{@options[:secret_key]}.#{@options[:public_key]}" }

        @token =  parse_bearer_token(
          ssl_post("#{live_url}/encrypt/keys", request_body.to_json, auth_headers)
        )
      end

      def parse_bearer_token(response)
        response.dig('data', 'EncryptedSecKey', 'encryptedKey')
      end
    end
  end
end
