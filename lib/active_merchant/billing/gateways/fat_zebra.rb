require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FatZebraGateway < Gateway
      LIVE_URL    = "https://gateway.fatzebra.com.au/v1.0"
      SANDBOX_URL = "https://gateway.sandbox.fatzebra.com.au/v1.0"

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
        requires!(options, :username)
        requires!(options, :token)
        @username = options[:username]
        @token    = options[:token]
        super
      end

      # To create a charge on a card or a token, call
      #
      #   purchase(money, card_hash_or_token, { ... })
      #
      # To create a charge on a customer, call
      #
      #   purchase(money, nil, { :customer => id, ... })
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
      def store(creditcard)
        post = {}
        add_creditcard(post, creditcard)

        commit(:post, "credit_cards", post)
      end

      private
      def add_amount(post, money, options)
        post[:amount] = money
      end

      def add_creditcard(post, creditcard, options = {})
        if creditcard.respond_to?(:number)
          post[:card_number] = creditcard.number
          post[:card_expiry] = "#{creditcard.month}/#{creditcard.year}"
          post[:cvv] = creditcard.verification_value if creditcard.verification_value?
          post[:card_holder] = creditcard.name if creditcard.name
        else
            post[:card_token] = creditcard[:token]
            post[:cvv] = creditcard[:cvv]
        end
      end

      # Post the data to the gateway
      def commit(method, uri, parameters=nil)
        raw_response = response = nil
        success = false
        begin
          raw_response = ssl_request(method, get_url(uri), parameters.to_json, headers)
          response = parse(raw_response)
          success = response["successful"] && (response["response"]["successful"] || response["response"]["token"])
        rescue ResponseError => e
          if e.response.code == "401"
            return Response.new(false, "Invalid Login")
          end

          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        message = response["response"]["message"]
        unless response["successful"]
          # There is an error, so we will show that instead
          message = response["errors"].empty? ? "Unknown Error" : response["errors"].join(", ")
        end

        Response.new(success,
          message,
          response,
          :test => response.has_key?("test") ? response["test"] : false,
          :authorization => response["response"]["authorization"],
          :id => response["response"]["id"])
      end

      def response_error(data)
        puts data.inspect
        {}
      end

      # Parse the returned JSON
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
        base = test? ? SANDBOX_URL : LIVE_URL
        base + "/" + uri
      end

      # Builds the auth and U-A headers for the request
      def headers
        {
          "Authorization" => "Basic " + Base64.encode64(@username.to_s + ":" + @token.to_s).strip,
          "User-Agent" => "Fat Zebra v1.0/ActiveMerchant #{ActiveMerchant::VERSION}"
        }
      end 
    end
  end
end