require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FatZebraGateway < Gateway
      self.live_url    = "https://gateway.fatzebra.com.au/v1.0"
      self.test_url = "https://gateway.sandbox.fatzebra.com.au/v1.0"

      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb]

      self.homepage_url = 'https://www.fatzebra.com.au/'
      self.display_name = 'Fat Zebra'

      # Setup a new instance of the gateway.
      #
      # The options hash should include :username and :token
      # You can find your username and token at https://dashboard.fatzebra.com.au
      # Under the Your Account section
      def initialize(options = {})
        requires!(options, :username, :token)
        @username = options[:username]
        @token    = options[:token]
        super
      end

      # To create a purchase on a credit card use:
      #
      #   purchase(money, creditcard)
      #
      # To charge a tokenized card
      #
      #   purchase(money, "abzy87u", :cvv => "123")
      def purchase(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        post[:reference] = options[:order_id]
        post[:customer_ip] = options[:ip]

        commit(:post, 'purchases', post)
      end

      # Refund a transaction
      #
      # amount - Integer - the amount to refund
      # txn_id - String - the original transaction to be refunded
      # reference - String - your transaction reference
      def refund(money, txn_id, reference)
        post = {}

        post[:amount] = money
        post[:transaction_id] = txn_id
        post[:reference] = reference

        commit(:post, "refunds", post)
      end

      # Tokenize a credit card
      #
      # The token is returned in the Response#authorization
      def store(creditcard)
        post = {}
        add_creditcard(post, creditcard)

        commit(:post, "credit_cards", post)
      end

      private

      # Add the money details to the request
      def add_amount(post, money, options)
        post[:amount] = money
      end

      # Add the credit card details to the request
      def add_creditcard(post, creditcard, options = {})
        if creditcard.respond_to?(:number)
          post[:card_number] = creditcard.number
          post[:card_expiry] = "#{creditcard.month}/#{creditcard.year}"
          post[:cvv] = creditcard.verification_value if creditcard.verification_value?
          post[:card_holder] = creditcard.name if creditcard.name
        elsif creditcard.is_a?(String)
          post[:card_token] = creditcard
          post[:cvv] = options[:cvv]
        elsif creditcard.is_a?(Hash)
          deprecated "Passing the credit card as a Hash is deprecated. Use a String and put the (optional) CVV in the options hash instead."
          post[:card_token] = creditcard[:token]
          post[:cvv] = creditcard[:cvv]
        else
          raise ArgumentError.new("Unknown credit card format #{creditcard.inspect}")
        end
      end

      # Post the data to the gateway
      def commit(method, uri, parameters=nil)
        response = begin
          parse(ssl_request(method, get_url(uri), parameters.to_json, headers))
        rescue ResponseError => e
          return Response.new(false, "Invalid Login") if(e.response.code == "401")
          parse(e.response.body)
        end

        success = success_from(response)
        Response.new(
          success,
          message_from(response),
          response,
          :test => response["test"],
          :authorization => authorization_from(response, success)
        )
      end

      def success_from(response)
        (
          response["successful"] &&
          response["response"] &&
          (response["response"]["successful"] || response["response"]["token"])
        )
      end

      def authorization_from(response, success)
        if success
          (response["response"]["id"] || response["response"]["token"])
        else
          nil
        end
      end

      def message_from(response)
        if !response["errors"].empty?
          response["errors"].join(", ")
        elsif response["response"]["message"]
          response["response"]["message"]
        else
          "Unknown Error"
        end
      end

      # Parse the returned JSON, if parse errors are raised then return a detailed error.
      def parse(response)
        begin
          JSON.parse(response)
        rescue JSON::ParserError
          msg = 'Invalid JSON response received from Fat Zebra. Please contact support@fatzebra.com.au if you continue to receive this message.'
          msg += "  (The raw response returned by the API was #{response.inspect})"
          {
            "successful" => false,
            "response" => {},
            "errors" => [msg]
          }
        end
      end

      # Build the URL based on the AM mode and the URI
      def get_url(uri)
        base = test? ? self.test_url : self.live_url
        base + "/" + uri
      end

      # Builds the auth and U-A headers for the request
      def headers
        {
          "Authorization" => "Basic " + Base64.strict_encode64(@username.to_s + ":" + @token.to_s).strip,
          "User-Agent" => "Fat Zebra v1.0/ActiveMerchant #{ActiveMerchant::VERSION}"
        }
      end
    end
  end
end
