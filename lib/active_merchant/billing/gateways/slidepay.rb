require File.dirname(__FILE__) + '/slidepay/slidepay_response'
require File.dirname(__FILE__) + '/slidepay/slidepay_errors'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SlidepayGateway < Gateway
      self.money_format = :dollars
      self.default_currency = 'USD'

      self.test_url = 'https://dev.getcube.com:65532/rest.svc/api/'
      self.live_url = 'https://supervisor.getcube.com:65532/rest.svc/api/'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.slidepay.com/'

      # The name of the gateway
      self.display_name = 'SlidePay'

      def initialize(options = {})
        # requires!(options, :endpoint)
        @token      = options[:token] unless options[:token] == nil
        @api_key    = options[:api_key] unless options[:api_key] == nil
        @endpoint   = options[:endpoint]

        # Need to somehow include endpoint discovery in this one.
        if options[:is_test]
          @endpoint   = self.test_url
        elsif options[:endpoint]
          @endpoint   = options[:endpoint]
        else
          raise SlidePayEndpointMissingError.new("Either an endpoint url or the is_test parameter is required.")
        end

        super
      end

      # payments
      def purchase(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_creditcard(post, creditcard, options)

        commit(:post, 'payment/simple', post, options)
      end

      # Currently do not support partial refunds, so the money parameter will be ignored.
      def credit(identification, options = {})
        commit(:post, "payment/refund/#{identification}", {}, options)
      end

      # authorizations
      def authorize(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_creditcard(post, creditcard, options)

        commit(:post, 'authorization/simple', post, options)
      end

      def capture(identification, options = {})
        # for manual
        capture_type = "auto"
        if options[:capture_type] == "manual"
          capture_type = options[:capture_type]
        end

        post = {}
        if identification.is_a? Array
          post = identification
          path = "capture/#{capture_type}"
        else
          path = "capture/#{capture_type}/#{identification}"
        end

        commit(:post, path, post, options)
      end

      def void(identification, options = {})
        post = {}
        if identification.is_a? Array
          post = identification
          path = "authorization/void"
        else
          path = "authorization/void/#{identification}"
        end

        commit(:post, path, post, options)
      end

      private

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_billing_address(post, options)
        billing_address = options[:billing_address] || options[:address]
        if billing_address
          post[:cc_billing_zip] = billing_address[:zip]
        end
      end

      def add_creditcard(post, creditcard, options)
        # Only dealing with CNP for the moment
        if creditcard.respond_to?(:number)
          post[:method]           = "CreditCard"
          post[:cc_number]        = creditcard.number
          post[:cc_cvv2]          = creditcard.verification_value
          post[:cc_expiry_month]  = creditcard.month
          post[:cc_expiry_year]   = creditcard.year

          add_billing_address(post, options)
        end
      end

      def headers(options={})
        api_key = options[:api_key] || @api_key
        token = options[:token] || @token

        headers = { "Content-Type" => "application/json" }
        headers["x-cube-token"] = token unless token == nil
        headers["x-cube-api-key"] = api_key unless api_key == nil

        headers
      end

      def commit(method, path, data={}, options={})

        # Default values
        raw_response = response = nil
        success = false

        begin
          # Actually make the network request
          raw_response = ssl_request(method, url(path), request_data(data), headers(options))

          response = SlidePayResponse.new(raw_response)
          success = response.was_successful?

        rescue ResponseError => e

          raw_response = e.response.body
          response = SlidePayResponse.new(raw_response)

        rescue JSON::ParserError

          response = "SlidePay returned an invalid response. Contact support@slidepay.com and "
          response += "please provide the raw response that follows: #{raw_response}"

        rescue Exception => e
          response_json = {
            success: false,
            data: {error_text: "Something went wrong."}
          }.to_json

          response = SlidePayResponse.new(response_json)
        end

        response
      end

      def parse(body)
        JSON.parse(body)
      end

      def url(path)
        "#{@endpoint}#{path}"
      end

      def request_data(data)
        data.to_json
      end
    end
  end
end

