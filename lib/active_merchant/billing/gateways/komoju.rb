require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class KomojuGateway < Gateway
      self.test_url = 'https://komoju.com/api/v1'
      self.live_url = 'https://komoju.com/api/v1'
      self.supported_countries = ['JP']
      self.default_currency = 'JPY'
      self.money_format = :cents
      self.homepage_url = 'https://www.komoju.com/'
      self.display_name = 'Komoju'
      self.supported_cardtypes = %i[visa master american_express jcb]

      STANDARD_ERROR_CODE_MAPPING = {
        'bad_verification_value' => 'incorrect_cvc',
        'card_expired' => 'expired_card',
        'card_declined' => 'card_declined',
        'invalid_number' => 'invalid_number'
      }

      def initialize(options = {})
        requires!(options, :login)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        post[:amount] = amount(money)
        post[:description] = options[:description]
        add_payment_details(post, payment, options)
        post[:currency] = options[:currency] || default_currency
        post[:external_order_num] = options[:order_id] if options[:order_id]
        post[:tax] = options[:tax] if options[:tax]
        add_fraud_details(post, options)

        commit('/payments', post)
      end

      def refund(money, identification, options = {})
        commit("/payments/#{identification}/refund", {})
      end

      private

      def add_payment_details(post, payment, options)
        details = {}

        details[:type] = 'credit_card'
        details[:number] = payment.number
        details[:month] = payment.month
        details[:year] = payment.year
        details[:verification_value] = payment.verification_value
        details[:given_name] = payment.first_name
        details[:family_name] = payment.last_name
        details[:email] = options[:email] if options[:email]

        post[:payment_details] = details
      end

      def add_fraud_details(post, options)
        details = {}

        details[:customer_ip] = options[:ip] if options[:ip]
        details[:customer_email] = options[:email] if options[:email]
        details[:browser_language] = options[:browser_language] if options[:browser_language]
        details[:browser_user_agent] = options[:browser_user_agent] if options[:browser_user_agent]

        post[:fraud_details] = details unless details.empty?
      end

      def api_request(path, data)
        raw_response = nil
        begin
          raw_response = ssl_post("#{url}#{path}", data, headers)
        rescue ResponseError => e
          raw_response = e.response.body
        end

        JSON.parse(raw_response)
      end

      def commit(path, params)
        response = api_request(path, params.to_json)
        success = !response.key?('error')
        message = (success ? 'Transaction succeeded' : response['error']['message'])
        Response.new(
          success,
          message,
          response,
          test: test?,
          error_code: (success ? nil : error_code(response['error']['code'])),
          authorization: (success ? response['id'] : nil)
        )
      end

      def error_code(code)
        STANDARD_ERROR_CODE_MAPPING[code] || code
      end

      def url
        test? ? self.test_url : self.live_url
      end

      def headers
        {
          'Authorization' => 'Basic ' + Base64.encode64(@options[:login].to_s + ':').strip,
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => "Komoju/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end
    end
  end
end
