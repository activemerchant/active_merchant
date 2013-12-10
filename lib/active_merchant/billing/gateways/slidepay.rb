require 'slidepay'

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
        #requires!(options, :email, :password)
        @email      = options[:email] unless options[:email] == nil
        @password   = options[:password] unless options[:password] == nil
        @token      = options[:token] unless options[:token] == nil
        @api_key    = options[:api_key] unless options[:api_key] == nil
        # @endpoint   = options[:endpoint]

        # Need to somehow include endpoint discovery in this one.
        if options[:is_test]
          @endpoint           = self.test_url
          SlidePay.endpoint   = self.test_url
        elsif options[:endpoint]
          @endpoint   = options[:endpoint]
        else
          @endpoint   = self.live_url
        end

        if @api_key and @endpoint
          SlidePay.api_key = @api_key
          SlidePay.endpoint = @endpoint
        elsif @token and @endpoint
          SlidePay.api_key = @api_key
          SlidePay.endpoint = @endpoint
        elsif @email and @password

          if SlidePay.authenticate(@email, @password) == true
            @token = SlidePay.token
          else
            raise SlidePayAuthenticationError.new("Could not retrieve a SlidePay token for that email and password.")
          end
        else
          raise ArgumentError.new("To initialize SlidePay, you must supply one of the following three value pairs: an api_key and endpoint, a token and endpoint, or an email and password.")
        end

        super
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_creditcard(post, creditcard, options)

        commit(:post, 'payment/simple', post, options)
      end

      # Currently do not support partial refunds, so the money parameter will be ignored.
      def credit(money, identification, options)
        commit(:post, "payment/refund/#{identification}", {}, options)
      end

      # TO IMPLEMENT:
      # def authorize(money, creditcard, options = {}) end
      # def capture(money, identification, options = {}) end
      # def void(identification, options = {}) end

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

      def parse(body)
        JSON.parse(body)
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

          response = SlidePay::Response.new(raw_response)
          success = response.was_successful?


        rescue ResponseError => e

          raw_response = e.response.body
          response = SlidePay::Response.new(raw_response)

        rescue JSON::ParserError

          response = "SlidePay returned an invalid response. Contact support@slidepay.com and "
          response += "please provide the raw response that follows: #{raw_response}"

        rescue Exception => e

          response_json = {
            success: false,
            data: {error_text: "Something went wrong."}
          }.to_json

          response = SlidePay::Response.new(response_json)
        end
        if response.is_a? SlidePay::Response
          message = success ? "Successful" : response.data
        elsif response.is_a? String
          message = success ? "Success: #{response}" : "Failure: #{response}"
        else
          message = "Response - #{response}"
        end


        Response.new(success,message)
      end

      def url(path)
        "#{@endpoint}#{path}"
      end

      def request_data(data)

        data.to_json
      end

      class SlidePayAuthenticationError < StandardError
      end
    end
  end
end

