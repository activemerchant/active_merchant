require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FatZebraGateway < Gateway
      self.live_url = "https://gateway.fatzebra.com.au/v1.0"
      self.test_url = "https://gateway.sandbox.fatzebra.com.au/v1.0"

      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :jcb]

      self.homepage_url = 'https://www.fatzebra.com.au/'
      self.display_name = 'Fat Zebra'

      def initialize(options = {})
        requires!(options, :username, :token)
        super
      end

      def purchase(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        add_extra_options(post, options)
        add_order_id(post, options)
        add_ip(post, options)

        commit(:post, 'purchases', post)
      end

      def authorize(money, creditcard, options = {})
        post = {}

        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        add_extra_options(post, options)
        add_order_id(post, options)
        add_ip(post, options)

        post[:capture] = false

        commit(:post, 'purchases', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_amount(post, money, options)
        add_extra_options(post, options)

        commit(:post, "purchases/#{CGI.escape(authorization)}/capture", post)
      end

      def refund(money, txn_id, options={})
        post = {}

        add_extra_options(post, options)
        add_amount(post, money, options)
        post[:transaction_id] = txn_id
        add_order_id(post, options)

        commit(:post, "refunds", post)
      end

      def store(creditcard, options={})
        post = {}
        add_creditcard(post, creditcard)

        commit(:post, "credit_cards", post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("card_number\\":\\")[^"\\]*)i, '\1[FILTERED]').
          gsub(%r(("cvv\\":\\")\d+), '\1[FILTERED]')
      end

      private

      def add_amount(post, money, options)
        post[:currency] = (options[:currency] || currency(money))
        post[:currency] = post[:currency].upcase if post[:currency]
        post[:amount] = money
      end

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
          ActiveMerchant.deprecated "Passing the credit card as a Hash is deprecated. Use a String and put the (optional) CVV in the options hash instead."
          post[:card_token] = creditcard[:token]
          post[:cvv] = creditcard[:cvv]
        else
          raise ArgumentError.new("Unknown credit card format #{creditcard.inspect}")
        end
      end

      def add_extra_options(post, options)
        extra = {}
        extra[:ecm] = "32" if options[:recurring]
        extra[:cavv] = options[:cavv] if options[:cavv]
        extra[:xid] = options[:xid] if options[:xid]
        extra[:sli] = options[:sli] if options[:sli]
        extra[:name] = options[:merchant] if options[:merchant]
        extra[:location] = options[:merchant_location] if options[:merchant_location]
        post[:extra] = extra if extra.any?
      end

      def add_order_id(post, options)
        post[:reference] = options[:order_id] || SecureRandom.hex(15)
      end

      def add_ip(post, options)
        post[:customer_ip] = options[:ip] || "127.0.0.1"
      end

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

      def get_url(uri)
        base = test? ? self.test_url : self.live_url
        base + "/" + uri
      end

      def headers
        {
          "Authorization" => "Basic " + Base64.strict_encode64(@options[:username].to_s + ":" + @options[:token].to_s).strip,
          "User-Agent" => "Fat Zebra v1.0/ActiveMerchant #{ActiveMerchant::VERSION}"
        }
      end
    end
  end
end
