module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WepayGateway < Gateway
      self.test_url = 'https://stage.wepayapi.com/v2'
      self.live_url = 'https://wepayapi.com/v2'

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'https://www.wepay.com/'
      self.default_currency = 'USD'
      self.display_name = 'WePay'

      def initialize(options = {})
        requires!(options, :client_id, :account_id, :access_token)
        super(options)
      end

      def purchase(money, payment_method, options = {})
        post = {}
        if payment_method.is_a?(String)
          purchase_with_token(post, money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { store(payment_method, options) }
            r.process { purchase_with_token(post, money, split_authorization(r.authorization).first, options) }
          end
        end
      end

      def authorize(money, payment_method, options = {})
        post = {auto_capture: 0}
        if payment_method.is_a?(String)
          purchase_with_token(post, money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { store(payment_method, options) }
            r.process { purchase_with_token(post, money, split_authorization(r.authorization).first, options) }
          end
        end
      end

      def capture(money, identifier, options = {})
        post = {}
        post[:checkout_id] = split_authorization(identifier).first
        commit('/checkout/capture', post)
      end

      def void(identifier, options = {})
        post = {}
        post[:checkout_id] = split_authorization(identifier).first
        post[:cancel_reason] = (options[:description] || "Void")
        commit('/checkout/cancel', post)
      end

      def refund(money, identifier, options = {})
        checkout_id, original_amount = split_authorization(identifier)

        post = {}
        post[:checkout_id] = checkout_id
        if(money && (original_amount != amount(money)))
          post[:amount] = amount(money)
        end
        post[:refund_reason] = (options[:description] || "Refund")
        post[:app_fee] = options[:application_fee] if options[:application_fee]
        post[:payer_email_message] = options[:payer_email_message] if options[:payer_email_message]
        post[:payee_email_message] = options[:payee_email_message] if options[:payee_email_message]
        commit("/checkout/refund", post)
      end

      def store(creditcard, options = {})
        requires!(options, :email)

        post = {}
        post[:client_id] = @options[:client_id]
        post[:user_name] = "#{creditcard.first_name} #{creditcard.last_name}"
        post[:email] = options[:email]
        post[:cc_number] = creditcard.number
        post[:cvv] = creditcard.verification_value
        post[:expiration_month] = creditcard.month
        post[:expiration_year] = creditcard.year
        post[:original_ip] = options[:ip] if options[:ip]
        post[:original_device] = options[:device_fingerprint] if options[:device_fingerprint]
        if(billing_address = (options[:billing_address] || options[:address]))
          post[:address] = {
            "address1" => billing_address[:address1],
            "city"     => billing_address[:city],
            "state"    => billing_address[:state],
            "country"  => billing_address[:country]
          }
          if(post[:country] == "US")
            post[:address]["zip"] = billing_address[:zip]
          else
            post[:address]["postcode"] = billing_address[:zip]
          end
        end
        commit('/credit_card/create', post)
      end

      private

      def purchase_with_token(post, money, token, options)
        add_token(post, token)
        add_product_data(post, money, options)
        commit('/checkout/create', post)
      end

      def add_product_data(post, money, options)
        post[:account_id] = @options[:account_id]
        post[:amount] = amount(money)
        post[:short_description] = (options[:description] || "Purchase")
        post[:type] = (options[:type] || "GOODS")
        post[:currency] = (options[:currency] || currency(money))
        post[:long_description] = options[:long_description] if options[:long_description]
        post[:payer_email_message] = options[:payer_email_message] if options[:payer_email_message]
        post[:payee_email_message] = options[:payee_email_message] if options[:payee_email_message]
        post[:reference_id] = options[:order_id] if options[:order_id]
        post[:app_fee] = options[:application_fee] if options[:application_fee]
        post[:fee_payer] = options[:fee_payer] if options[:fee_payer]
        post[:redirect_uri] = options[:redirect_uri] if options[:redirect_uri]
        post[:callback_uri] = options[:callback_uri] if options[:callback_uri]
        post[:fallback_uri] = options[:fallback_uri] if options[:fallback_uri]
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

      def commit(action, params, options={})
        begin
          response = parse(ssl_post(
            ((test? ? test_url : live_url) + action),
            params.to_json,
            headers
          ))
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, params),
          test: test?
        )
      end

      def success_from(response)
        (!response["error"])
      end

      def message_from(response)
        (response["error"] ? response["error_description"] : "Success")
      end

      def authorization_from(response, params)
        return response["credit_card_id"].to_s if response["credit_card_id"]

        [response["checkout_id"], params[:amount]].join('|')
      end

      def split_authorization(authorization)
        auth, original_amount = authorization.to_s.split("|")
        [auth, original_amount]
      end

      def headers
        {
          "Content-Type"  => "application/json",
          "User-Agent"    => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          "Authorization" => "Bearer #{@options[:access_token]}"
        }
      end
    end
  end
end

