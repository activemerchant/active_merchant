module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SlidepayGateway < Gateway
      self.money_format = :dollars
      self.default_currency = 'USD'

      self.test_url = 'https://dev.getcube.com:65532/rest.svc/api/'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.slidepay.com/'
      self.display_name = 'SlidePay'

      def initialize(options = {})
        super

        options[:endpoint] ||= test_url if test?
        requires!(options, :endpoint)
      end

      def purchase(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_creditcard(post, creditcard, options)

        commit(:post, 'payment/simple', post)
      end

      def authorize(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_creditcard(post, creditcard, options)

        commit(:post, 'authorization/simple', post)
      end

      def capture(money, identification, options = {})
        raise ArgumentError.new("Partial captures are not supported.") if money

        commit(:post, "capture/auto/#{identification}")
      end

      def refund(money, identification, options = {})
        raise ArgumentError.new("Partial refunds are not supported.") if money

        commit(:post, "payment/refund/#{identification}")
      end

      def void(identification, options = {})
        commit(:post, "authorization/void/#{identification}")
      end

      private

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_billing_address(post, options)
        billing_address = (options[:billing_address] || options[:address])
        post[:cc_billing_zip] = billing_address[:zip] if billing_address
      end

      def add_creditcard(post, creditcard, options)
        post[:method]           = "CreditCard"
        post[:cc_number]        = creditcard.number
        post[:cc_cvv2]          = creditcard.verification_value
        post[:cc_expiry_month]  = creditcard.month
        post[:cc_expiry_year]   = creditcard.year
        add_billing_address(post, options)
      end

      def headers
        headers = { "Content-Type" => "application/json" }
        headers["x-cube-token"] = @options[:token] if @options[:token]
        headers["x-cube-api-key"] = @options[:api_key] if @options[:api_key]
        headers
      end

      def commit(method, path, post={})
        response = parse(ssl_request(method, url(path), post.to_json, headers))

        Response.new(
          response["success"],
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def message_from(response)
        return "Succeeded" if response["success"]
        (
          response["message"] ||
          (response["data"] && response["data"]["status_message"]) ||
          "Failed"
        )
      end

      def authorization_from(response)
        (response["data"] && response["data"]["payment_id"])
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        {
          "success" => false,
          "message" => %(SlidePay returned an invalid response. Contact support@slidepay.com and provide the raw response that follows: #{body})
        }
      end

      def url(path)
        "#{@endpoint}#{path}"
      end
    end
  end
end

