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
      self.money_format = :cents

      def initialize(options = {})
        requires!(options, :public_key, :private_key)

        @public_key = options[:public_key]
        @private_key = options[:private_key]
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
        post[:expiryYear] = payment.year.to_s[-2, 2]
        post[:channelType] = card_brand(payment)
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
          parameters[:publicKey] = @options[:public_key]

          raw_response = ssl_post(url, parameters.to_json, headers)
          response = parse(raw_response)
          succeeded = success_from(response)

          response(succeeded, response)
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

      def headers(options = {})
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{token}"
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
          response.dig('data', 'code') == '00'
      end

      def message_from(response)
        response.dig('data', 'message')
      end

      def authorization_from(response)
        response.dig('data', 'payments', 'linkingReference').presence
      end

      def error_code_from(succeeded, response)
        response.dig('data', 'code').presence
      end

      def token
        credentials = "#{@options[:public_key]}:#{@options[:private_key]}"
        Base64.strict_encode64(credentials)
      end
    end
  end
end
