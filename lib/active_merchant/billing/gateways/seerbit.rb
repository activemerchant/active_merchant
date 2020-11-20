module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SeerbitGateway < Gateway
      self.test_url = 'https://seerbitapi.com/api/v2'
      self.live_url = 'https://seerbitapi.com/api/v2'

      self.homepage_url = 'https://seerbit.com/'
      self.display_name = 'Seerbit'

      self.supported_countries = ['GH', 'KE', 'NG', 'TZ', 'US', 'CM']
      self.default_currency = 'GHS'

      self.supported_cardtypes = [:visa, :mastercard, :maestro]
      self.money_format = :dollars

      #
      #  00 - success - Purchase without 3DS
      # S20 - successful initial call - 3DS
      #
      SUCCESS_CODES = %w( 00 S20 )

      # Some endpoints require Bearer token auth,
      # the rest of them use basic auth
      REQUIRE_BEARER_TOKEN = %w( /payments/initiates /recurring/subscribes )

      PLAN_INTERVALS = %w( DAILY WEEKLY MONTHLY ANNUALLY )

      def initialize(options = {})
        requires!(options, :public_key, :private_key)

        @public_key = options[:public_key]
        @private_key = options[:private_key]
        super
      end

      # Initiates a 3DS transaction
      # https://doc.seerbit.com/overview-1/cards#scenario-2-master-card-and-visa-card
      #
      def initiate_3ds(money, payment, options = {})
        post = {}

        add_public_key(post)
        add_order(post, money, options)
        add_retry_data(post, options)
        add_customer_data(post, options)
        add_payment(post, payment)
        add_card_data(post, payment)
        add_3ds_data(post, options)

        commit("/payments/initiates", post)
      end

      def purchase(money, payment, options = {})
        post = {}

        add_public_key(post)
        add_order(post, money, options)
        add_retry_data(post, options)
        add_customer_data(post, options)
        add_payment(post, payment)
        add_card_data(post, payment)

        commit("/payments/charge", post)
      end



      def recurring(money, payment, options = {})
        post = {}

        add_public_key(post)
        add_payment(post, payment)
        add_product_data(post, options)
        add_order(post, money, options)
        add_customer_data(post, options)
        add_recurring_data(post, options)

        commit("/recurring/subscribes", post)
      end

      def supports_scrubbing?
        true
      end

      def add_3ds_data(post, options)
        add_product_data(post, options)
        post[:fee] = options[:fee] if options[:fee].present?
        post[:invoiceNumber] = options[:invoice_number] if options[:invoice_number].present?
        post[:deviceType] = options[:device_type] if options[:device_type].present?
        post[:sourceIP] = options[:source_ip] if options[:source_ip]
        post[:clientAppCode] = options[:app_code] if options[:app_code].present?

        post[:redirectUrl] = options[:redirect_url] || '127.0.0.1'

        post
      end

      def add_product_data(post, options)
        post[:productId] = options[:product_id] if options[:product_id].present?
        post[:productDescription] = options[:product_desc] if options[:product_desc].present?
      end

      def add_customer_data(post, options)
        customer = options[:customer] || {}

        post[:email] = customer[:email]
        post[:fullName] = customer[:full_name]
        post[:mobileNumber] = customer[:mob_phone]
        post[:cardName] = customer[:full_name]
      end

      def add_recurring_data(post, options)
        post[:planId] = options[:plan_id] if options[:plan_id].present?
        post[:startDate] = options[:start_date] if options[:start_date].present?
        post[:callbackUrl] = options[:callback_url]
        post[:billingCycle] = (PLAN_INTERVALS & [ options[:billing_cycle]&.upcase ]).first
        post[:billingPeriod] = options[:billing_period]
        post[:subscriptionAmount] = options[:subscription_amount] || false
      end

      def add_order(post, money, options)
        address = options[:address] || {}

        post[:amount] = amount(money)
        post[:currency] = options[:currency] || currency(money)
        post[:country] = address[:country] || 'NG'
        post[:paymentReference] = options[:reference]
      end

      def add_retry_data(post, options)
        post[:retry] = options[:retry] || false  
      end

      def add_payment(post, payment)
        post[:cardNumber] = payment.number
        post[:cvv] = payment.verification_value if payment.verification_value?
        post[:expiryMonth] = payment.month.to_s.rjust(2, '0')
        post[:expiryYear] = payment.year.to_s[-2, 2]
      end

      def add_card_data(post, payment)
        post[:paymentType] = 'CARD'
        post[:channelType] = card_brand(payment)
      end

      def add_public_key(post)
        post[:publicKey] = @options[:public_key]
      end

      def card_brand(card)
        brand = super
        ({"master" => 'Mastercard'}[brand] || brand)
      end

      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Basic )([A-Za-z0-9\-\._~\+\/]+=*)/, '\1[FILTERED]').
          gsub(/(\\?\\?\\?"cardNumber\\?\\?\\?":\\?\\?\\?")\d+/, '\1[FILTERED]').
          gsub(/(\\?\\?\\?"cvv\\?\\?\\?":\\?\\?\\?"?)\d+/, '\1[FILTERED]')
      end

      private

      def commit(action, parameters)
        begin
          url = (test? ? test_url : live_url) + action

          raw_response = ssl_post(url, parameters.to_json, headers(action))

          parsed_response = parse(raw_response)

          succeeded = success_from(parsed_response)

          response(succeeded, parsed_response)
        rescue ResponseError => e
          response(false, parse(e.response.body))
        end
      end

      def response(succeeded, response)
        Response.new(
          succeeded,
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(succeeded, response))
      end

      def headers(action)
        token_type = REQUIRE_BEARER_TOKEN.include?(action) ? 'Bearer' : 'Basic'

        {
          'Content-Type' => 'application/json',
          'Authorization' => "#{token_type} #{authorization_token(token_type)}"
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def response_error(raw_response)
        begin
          parse(raw_response)
        rescue JSON::ParserError
          json_error(raw_response)
        end
      end

      def success_from(response)
        response.fetch('status') == 'SUCCESS' &&
          SUCCESS_CODES.include?(response.dig('data', 'code'))
      end

      def message_from(response)
        response.dig('data', 'message').presence || response.dig('message')
      end

      def authorization_from(response)
        response.dig('data', 'payments', 'linkingReference').presence
      end

      def error_code_from(succeeded, response)
        response.dig('data', 'code').presence || response.dig('message')
      end

      def authorization_token(token_type)
        token_type == 'Bearer' ? bearer_token : basic_token
      end

      def basic_token
        credentials = "#{@options[:public_key]}:#{@options[:private_key]}"
        Base64.strict_encode64(credentials)
      end

      def bearer_token
        url = (test? ? test_url : live_url) + '/encrypt/keys'
        headers = { 'Content-Type' => 'application/json' }
        params = { key: "#{@options[:private_key]}.#{@options[:public_key]}"}

        raw_response = ssl_post(url, params.to_json, headers)

        get_token(raw_response)
      end

      def get_token(raw_response)
        response = parse(raw_response)
        if success_from(response)
          response.dig('data', 'EncryptedSecKey', 'encryptedKey')
        else
          raise "Failed authorization: #{raw_response}"
        end
      end
    end
  end
end
