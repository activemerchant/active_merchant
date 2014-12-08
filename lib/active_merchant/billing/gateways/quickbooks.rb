require 'oauth'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickbooksGateway < Gateway
      self.test_url = 'https://sandbox.api.intuit.com'
      self.live_url = 'https://api.intuit.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://payments.intuit.com'
      self.display_name = 'QuickBooks Payments'
      ENDPOINT =  "/quickbooks/v4/payments/charges"
      OAUTH_ENDPOINTS = {
        site: 'https://oauth.intuit.com',
        request_token_path: '/oauth/v1/get_request_token',
        authorize_url: 'https://appcenter.intuit.com/Connect/Begin',
        access_token_path: '/oauth/v1/get_access_token'
      }

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :consumer_key, :consumer_secret, :access_token, :token_secret, :realm_id)
        @consumer_key = options[:consumer_key]
        @consumer_secret = options[:consumer_secret]
        @access_token = options[:access_token]
        @token_secret = options[:token_secret]
        @realm_id = options[:realm_id]
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        charge_data(post: post, options: options)
        post[:capture] = "true"

        commit(uri: ENDPOINT, body: post)
      end

      def authorize(money, payment, options={})
        post = {}
        charge_data(post: post, options: options)
        post[:capture] = "false"

        commit(uri: ENDPOINT, body: post)
      end

      def capture(money, authorization, options={})
        capture_uri = "#{ENDPOINT}/#{CGI.escape(authorization)}/capture"
        post = options[:id]
        commit(uri: capture_uri, body: post)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:amount] = money.to_s
        refund_uri = "#{ENDPOINT}/#{CGI.escape(authorization)}/refund"
        commit(uri: refund_uri, body: post)
      end

      def void(authorization, options={})
        MultiResponse.run do |r|
          amount = r.process { amount_to_void(authorization: authorization) }
          r.process { refund(amount, authorization, options = {}) }
        end.responses.last
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(1.00, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def charge_data(post:, payment:, options:)
        add_payment(post: post, payment: payment, options: options[:card_code])
        add_address(post: post, payment: payment, options: options)
        add_context(context: options[:context]) if options[:context]
      end

      def add_address(post:, options:)
        return unless post[:card] && post[:card].kind_of?(Hash)
        card_address = {}
        if address = options[:billing_address]
          card_address[:streetAddress] = address[:address1]
          card_address[:city] = address[:city]
          card_address[:region] = address[:state]
          card_address[:country] = address[:country]
          card_address[:postalCode] = address[:zip] if address[:zip]
        end
        post[:card][:address] = card_address
      end

      def add_amount(post:, money:, options:)
        currency = options[:currency] || currency(money)
        post[:amount] = localized_amount(money, currency)
        post[:currency] = currency.upcase
        post[:amount]
      end

      def add_payment(post:, payment:)
        add_creditcard(post: post, payment: payment)
      end

      def add_creditcard(post: ,creditcard:)
        card = {}
        card[:number] = creditcard.number
        card[:expMonth] = creditcard.month
        card[:expYear] = creditcard.year
        card[:cvc] = creditcard.verification_value if creditcard.verification_value?
        card[:name] = creditcard.name if creditcard.name
        card[:commercialCardCode] = creditcard.card_code if creditcard.card_code

        post[:card] = card
      end

      def add_context(post:, context:)
        payment_context = {}
        payment_context[:tax] = context[:tax] if context[:tax]
        payment_context[:recurring] = context[:recurring] if context[:recurring]

        post[:context] = payment_context
      end

      def amount_to_void(authorization:)
        response = parse(ssl_request(:get, "#{gateway_url}#{ENDPOINT}/#{authorization}", post_data, headers))
        response[:amount]
      end

      def authorization_object_from_endpoint(authorization:)

      end

      def parse(body:)
        JSON.parse(body)
      end

      def commit(uri:, body:)
        endpoint = gateway_url + uri
        request = ssl_post(endpoint, post_data(body: body), headers(method: :post, uri: endpoint))
        response = parse(request)

        Response.new(
          success_from(response: response),
          message_from(response: response),
          response,
          authorization: authorization_from(response: response),
          test: test?,
          error_code => 'error'
        )
      end

      def gateway_url
        test? ? test_url : live_url
      end

      def success_from(response:)

      end

      def message_from(response:)
      end

      def authorization_from(response:)
      end

      def post_data(data: {})
        data.to_json
      end

      def headers(method:, uri:)
        return unless method && uri
        request_uri = URI.parse(uri)

        request_class = case method
        when :post
          Net::HTTP::Post
        when :get
          Net::HTTP::Get
        end
        consumer = OAuth::Consumer.new(
          @consumer_key,
          @consumer_secret,
          OAUTH_ENDPOINTS)
        access_token = OAuth::AccessToken.new(
          consumer,
          @access_token,
          @token_secret)
        client_helper = OAuth::Client::Helper.new(
          request_class.new(request_uri),
          consumer: consumer,
          token: access_token,
          realm: @realm_id,
          request_uri: request_uri)
        oauth_header = client_helper.header

        {
          "Content-type" => "application/json",
          "Request-Id" => @request_id.to_s,
          "Authorization" => oauth_header
        }
      end
    end
  end
end
