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
        CHECKOUT_CAPTURE   = '/checkout/capture'
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

      def purchase(money, payment_method, options = {})
        post = WepayPostData.new
        if payment_method.is_a?(String)
          purchase_with_token(post, money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { add_card(payment_method, options) }
            r.process { purchase_with_token(post, money, r.authorization, options) }
          end
        end
      end

      def authorize(money, payment_method, options = {})
        post = WepayPostData.new
        post[:auto_capture] = 0
        if payment_method.is_a?(String)
          purchase_with_token(post, money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { add_card(payment_method, options) }
            r.process { purchase_with_token(post, money, r.authorization, options) }
          end
        end
      end

      def capture(checkout_id, options = {})
        post = WepayPostData.new
        post[:checkout_id] = checkout_id
        commit(Actions::CHECKOUT_CAPTURE, post)
      end

      def void(checkout_id, options = {})
        post = WepayPostData.new
        post[:checkout_id] = checkout_id
        post[:cancel_reason] = options[:cancel_reason]
        commit(Actions::CHECKOUT_CANCEL, post)
      end

      def refund(money, checkout_id, options = {})
        post = WepayPostData.new
        post[:checkout_id] = checkout_id
        post[:amount] = amount(money) unless options[:full_refund]
        post[:refund_reason] = options[:refund_reason]
        post[:app_fee] = options[:app_fee] if options[:app_fee]
        post[:payer_email_message] = options[:payer_email_message] if options[:payer_email_message]
        post[:payee_email_message] = options[:payee_email_message] if options[:payee_email_message]
        commit(Actions::CHECKOUT_REFUND, post)
      end

      # https://www.wepay.com/developer/reference/credit_card#create
      def add_card(creditcard, options = {})
        post = WepayPostData.new
        post[:client_id] = @options[:client_id]
        post[:user_name] = "#{creditcard.first_name} #{creditcard.last_name}"
        post[:email] = options[:email]
        post[:cc_number] = creditcard.number
        post[:cvv] = creditcard.verification_value
        post[:expiration_month] = creditcard.month
        post[:expiration_year] = creditcard.year
        post[:original_ip] = options[:ip] if options[:ip]
        post[:original_device] = options[:device_fingerprint] if options[:device_fingerprint]
        if billing_address = options[:billing_address] || options[:address]
          post[:address] = {
            "address1" => billing_address[:address1],
            "city"     => billing_address[:city],
            "state"    => billing_address[:state],
            "country"  => billing_address[:country],
            "zip"      => billing_address[:zip]
          }
        end
        commit(Actions::CREDIT_CARD_CREATE, post, "credit_card_id")
      end

      private

      def purchase_with_token(post, money, token, options)
        add_token(post, token)
        add_product_data(post, money, options)
        commit(Actions::CHECKOUT_CREATE, post)
      end

      def add_product_data(post, money, options)
        # https://www.wepay.com/developer/reference/checkout#create
        post[:account_id] = @options[:account_id]
        post[:amount] = amount(money)
        post[:short_description] = options[:description]
        post[:type] = options[:type]
        post[:currency] = options[:currency] if options[:currency]
        post[:long_description] = options[:long_description] if options[:long_description]
        post[:payer_email_message] = options[:payer_email_message] if options[:payer_email_message]
        post[:payee_email_message] = options[:payee_email_message] if options[:payee_email_message]
        post[:reference_id] = options[:reference_id] if options[:reference_id]
        post[:app_fee] = options[:app_fee] if options[:app_fee]
        post[:fee_payer] = options[:fee_payer] if options[:fee_payer]
        post[:redirect_uri] = options[:redirect_uri] if options[:redirect_uri]
        post[:callback_uri] = options[:callback_uri] if options[:callback_uri]
        post[:fallback_uri] = options[:fallback_uri] if options[:fallback_uri]
        post[:auto_capture] = options[:auto_capture] if options[:auto_capture]
        post[:require_shipping] = options[:require_shipping] if options[:require_shipping]
        post[:shipping_fee] = options[:shipping_fee] if options[:shipping_fee]
        post[:charge_tax] = options[:charge_tax] if options[:charge_tax]
        post[:mode] = options[:mode] if options[:mode]
        post[:preapproval_id] = options[:preapproval_id] if options[:preapproval_id]
        post[:prefill_info] = options[:prefill_info] if options[:prefill_info]
        post[:funding_sources] = options[:funding_sources] if options[:funding_sources]
      end

      def add_token(post, token)
        post[:payment_method_id]   = token
        post[:payment_method_type] = "credit_card"
      end

      def parse(response)
        JSON.parse(response)
      end

      def commit(action, params, authorization_field = "checkout_id")
        success = false
        begin
          response = service_call(action, params)
          success = true unless response["error"]
        rescue ResponseError => e
          response = parse(e.response.body)
        end
        Response.new(success, (success)? "Success" : "Failed", response,
                 :authorization => response[authorization_field], :test => test?)
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

