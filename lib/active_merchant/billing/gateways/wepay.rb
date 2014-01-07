module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WepayGateway < Gateway
      self.test_url = 'https://stage.wepayapi.com/v2'
      self.live_url = 'https://wepayapi.com/v2'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'https://www.wepay.com/'

      # The default currency
      self.default_currency = 'USD'

      # The name of the gateway
      self.display_name = 'WePay'

      module Actions
        CHECKOUT_DETAILS = '/checkout'
        CHECKOUT_CREATE = '/checkout/create'
        CHECKOUT_FIND = '/checkout/find'
        CHECKOUT_CANCEL = '/checkout/cancel'
        CHECKOUT_REFUND = '/checkout/refund'
        CREDIT_CARD_CREATE = '/credit_card/create'
      end

      def initialize(options = {})
        requires!(options, :account_id, :access_token, :use_staging)
        if options[:use_staging]
          @api_endpoint = self.test_url
        else
          @api_endpoint = self.live_url
        end
        @use_ssl = true
        super
      end

      def authorize(money, creditcard, options = {})
        raise NotImplementedError
      end

      def purchase(money, creditcard, options = {})
        post = {:account_id => @options[:account_id]}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        add_product_data(post, money, options)

        service_call(Actions::CHECKOUT_CREATE, money, post)
      end

      def capture(money, authorization, options = {})
        raise NotImplementedError
      end

      private

      def add_customer_data(post, options)
      end

      def add_product_data(post, money, options)
        post[:amount] = amount(money)
        post[:short_description] = "A brand new soccer ball"
        post[:type] = "GOODS"
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
      end

      def add_creditcard(post, creditcard)
      end

      def parse(body)
      end

      def commit(action, money, parameters)
        result = service_call action, parameters
      end

      def message_from(response)
      end

      def post_data(action, parameters = {})
      end

      def service_call(action, money, post)
        url = URI.parse(@api_endpoint + action)

        headers = {
          "Content-Type"          => "application/json",
          "User-Agent"            => "WePay Ruby SDK",
          "Authorization"         => "Bearer #{options[:access_token]}"
        }

        response = ssl_post(url, post_data(post, money), headers)
        response = JSON.parse(response)
        success = false
        success = true unless response["error"]
        Response.new(success, "Success", response, :authorization => response["checkout_id"], :test => test?)
      end

    end
  end
end

