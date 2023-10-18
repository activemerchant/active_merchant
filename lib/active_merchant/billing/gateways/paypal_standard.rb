module ActiveMerchant
  module Billing
    class PaypalStandardGateway < Gateway
      include Empty
      self.test_url = 'https://api-m.sandbox.paypal.com'
      self.live_url = 'https://api-m.paypal.com'

      ENDPOINTS = {
        generate_token: '/v1/oauth2/token',
        create_order: '/v2/checkout/orders',
        capture_order: '/v2/checkout/orders/%{id}/capture'
      }

      SUCCESS_CODE = 100
      SOFT_DECLINE_CODES = [201, 203, 204, 205, 221, 223, 225, 226, 240].freeze

      self.default_currency = 'USD'
      self.money_format = :dollars
      self.display_name = 'PayPal'

      def initialize(options = {})
        requires!(options, :client_id, :client_secret)
        @client_id = options[:client_id]
        @client_secret = options[:client_secret]
        super
        @access_token = setup_access_token
      end

      def purchase(amount, payment_method, options = {})
        post ||= {}

        add_payment_intent(post, intent_type = "CAPTURE")
        add_purchase_units(post, amount, options)
        add_payment_source(post, options)

        commit(:create_order, post)
      end

      def capture(amount, authorization, options = {})
        post = {}
        commit(:capture_order, post, options[:order_id])
      end

      def void(authorization, options = {})
      end

      def refund(amount, authorization, options = {})
        post = {}
        commit('refund', post)
      end

      private

      def commit(action, post, id = nil)
        url = build_request_url(action, id)

        response = parse(ssl_post(url, post_data(post), headers))
        success = success_from(response)
        Response.new(
          success_from(response),
          message_from(response),
          response,
          test: test?,
          authorization: authorization_from(response),
          avs_result: { code: response['avs'] },
          cvv_result: response['cvv2'],
          error_code: success ? nil : error_code_from(response)
        )
      end

      def base_url
        if test?
          test_url
        else
          live_url
        end
      end

      def setup_access_token
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{encoded_credentials}"
        }

        response = ssl_post(build_request_url(:generate_token), grant_type, headers)
        JSON.parse(response)['access_token']
      end

      def build_request_url(action, id = nil)
        base_url = (test? ? test_url : live_url)
        base_url + ENDPOINTS[action].to_s % { id: id }
      end

      def encoded_credentials
        Base64.strict_encode64("#{@client_id}:#{@client_secret}")
      end

      def headers
       { 'Authorization' => "Bearer #{@access_token}", 'Content-Type' => 'application/json' }
      end

      def post_data(post)
        post.to_json
      end

      def grant_type
        "grant_type=client_credentials"
      end

      def parse(body)
        JSON.parse(body)
      end

      def success_from(response)
        response["status"] == "CREATED"
      end

      def message_from(response)
        response.dig('latest_payment_attempt', 'status') || response['status'] || response['message']
      end

      def authorization_from(response)
        response.dig('latest_payment_attempt', 'payment_intent_id')
      end

      def error_code_from(response)
        response['provider_original_response_code'] || response['code'] unless success_from(response)
      end

      def add_purchase_units(post, amount, options)
        purchase_unit = {}
        purchase_unit[:amount] = {}
        purchase_unit[:amount][:value] = amount
        purchase_unit[:amount][:currency_code] = options[:currency_code]

        post[:purchase_units] ||= []

        post[:purchase_units] << purchase_unit
      end

      def add_payment_source(post, options)
        post[:payment_source] ||= {}
        post[:payment_source][:paypal] ||= {}

        payment_source = {}
        payment_source[:landing_page] = "LOGIN"
        payment_source[:user_action] = "PAY_NOW"
        payment_source[:return_url] = options[:return_url]
        payment_source[:cancel_url] = options[:cancel_url]
        post[:payment_source][:paypal][:experience_context] = payment_source
      end

      def add_payment_intent(post, intent_type = "CAPTURE")
        post[:intent] = intent_type
      end
    end
  end
end
