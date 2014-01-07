module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WepayGateway < Gateway

      class WepayPostData < PostData
        self.required_fields = [ :amount, :account_id ]
      end

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
        CHECKOUT_DETAILS   = '/checkout'
        CHECKOUT_CREATE    = '/checkout/create'
        CHECKOUT_FIND      = '/checkout/find'
        CHECKOUT_CANCEL    = '/checkout/cancel'
        CHECKOUT_REFUND    = '/checkout/refund'
        CREDIT_CARD_CREATE = '/credit_card/create'
      end

      def initialize(options = {})
        requires!(options, :client_id, :account_id, :access_token, :use_staging)
        if options[:use_staging]
          @api_endpoint = self.test_url
        else
          @api_endpoint = self.live_url
        end
        @use_ssl = true
        super(options)
      end

      def authorize(money, creditcard, options = {})
        raise NotImplementedError
      end

      def purchase(money, creditcard, options = {})
        post = WepayPostData.new
        post[:account_id] = @options[:account_id]
        add_invoice(post, options)
        add_creditcard(post, creditcard, options)
        add_product_data(post, money, options)
        commit(Actions::CHECKOUT_CREATE, money, post)
      end

      def capture(money, authorization, options = {})
        raise NotImplementedError
      end

      def refund(money, checkout_id, options = {})
        post = WepayPostData.new
        post[:checkout_id]   = checkout_id
        post[:refund_reason] = options[:refund_reason] || "Test"

        post[:app_fee] = options[:app_fee] if options[:app_fee]
        post[:payer_email_message] = options[:payer_email_message] if options[:payer_email_message]
        post[:payee_email_message] = options[:payee_email_message] if options[:payee_email_message]
        commit(Actions::CHECKOUT_REFUND, money, post)
      end

      private

      def add_product_data(post, money, options)
        post[:amount] = amount(money)
        post[:short_description] = options[:description]
        post[:type] = options[:type]
      end

      def add_invoice(post, options)
      end

      def add_creditcard(post, creditcard, options)
        cc_post = WepayPostData.new
        cc_post[:client_id] = @options[:client_id]
        cc_post[:user_name] = "#{creditcard.first_name} #{creditcard.last_name}"
        cc_post[:email] = options[:email] if options[:email]
        cc_post[:cc_number] = creditcard.number
        cc_post[:cvv] = creditcard.verification_value
        cc_post[:expiration_month] = creditcard.month
        cc_post[:expiration_year] = creditcard.year
        if billing_address = options[:billing_address] || options[:address]
          cc_post[:address] = {
            "address1" => billing_address[:address1],
            "city"     => billing_address[:city],
            "state"    => billing_address[:state],
            "country"  => billing_address[:country],
            "zip"      => billing_address[:zip]
          }
        end

        # Money is ignored
        response = commit(Actions::CREDIT_CARD_CREATE, 0, cc_post)
        post[:payment_method_id] = response.params["credit_card_id"]
        post[:payment_method_type] = "credit_card"
      end

      def parse(response)
        JSON.parse(response)
      end

      def commit(action, money, params)
        success = false
        begin
          response = service_call(action, params)

          success = true unless response["error"]
        rescue ResponseError => e
          response = parse(e.response.body)
        end
        Response.new(success, (success)? "Success" : "Failed", response,
                 :authorization => response["checkout_id"], :test => test?)

      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def headers
        {
          "Content-Type"          => "application/json",
          "User-Agent"            => "WePay Ruby SDK",
          "Authorization"         => "Bearer #{@options[:access_token]}"
        }
      end

      def service_call(action, params)
        url = URI.parse(@api_endpoint + action)
        response = parse( ssl_post(url, post_data(params), headers) )
      end

    end
  end
end

