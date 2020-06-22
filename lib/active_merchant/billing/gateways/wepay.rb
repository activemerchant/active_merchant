module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WepayGateway < Gateway
      self.test_url = 'https://stage.wepayapi.com/v2'
      self.live_url = 'https://wepayapi.com/v2'

      self.supported_countries = %w[US CA]
      self.supported_cardtypes = %i[visa master american_express discover]
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
          MultiResponse.run do |r|
            r.process { authorize_with_token(post, money, payment_method, options) }
            r.process { capture(money, r.authorization, options) }
          end
        else
          MultiResponse.run do |r|
            r.process { store(payment_method, options) }
            r.process { authorize_with_token(post, money, r.authorization, options) }
            r.process { capture(money, r.authorization, options) }
          end
        end
      end

      def authorize(money, payment_method, options = {})
        post = {}
        if payment_method.is_a?(String)
          authorize_with_token(post, money, payment_method, options)
        else
          MultiResponse.run do |r|
            r.process { store(payment_method, options) }
            r.process { authorize_with_token(post, money, r.authorization, options) }
          end
        end
      end

      def capture(money, identifier, options = {})
        checkout_id, original_amount = split_authorization(identifier)

        post = {}
        post[:checkout_id] = checkout_id
        post[:amount] = amount(money) if money && (original_amount != amount(money))
        commit('/checkout/capture', post, options)
      end

      def void(identifier, options = {})
        post = {}
        post[:checkout_id] = split_authorization(identifier).first
        post[:cancel_reason] = (options[:description] || 'Void')
        commit('/checkout/cancel', post, options)
      end

      def refund(money, identifier, options = {})
        checkout_id, original_amount = split_authorization(identifier)

        post = {}
        post[:checkout_id] = checkout_id
        post[:amount] = amount(money) if money && (original_amount != amount(money))
        post[:refund_reason] = (options[:description] || 'Refund')
        post[:payer_email_message] = options[:payer_email_message] if options[:payer_email_message]
        post[:payee_email_message] = options[:payee_email_message] if options[:payee_email_message]
        commit('/checkout/refund', post, options)
      end

      def store(creditcard, options = {})
        post = {}
        post[:client_id] = @options[:client_id]
        post[:user_name] = "#{creditcard.first_name} #{creditcard.last_name}"
        post[:email] = options[:email] || 'unspecified@example.com'
        post[:cc_number] = creditcard.number
        post[:cvv] = creditcard.verification_value unless options[:recurring]
        post[:expiration_month] = creditcard.month
        post[:expiration_year] = creditcard.year

        if (billing_address = (options[:billing_address] || options[:address]))
          post[:address] = {}
          post[:address]['address1'] = billing_address[:address1] if billing_address[:address1]
          post[:address]['city']     = billing_address[:city] if billing_address[:city]
          post[:address]['country']  = billing_address[:country]  if billing_address[:country]
          post[:address]['region']   = billing_address[:state] if billing_address[:state]
          post[:address]['postal_code'] = billing_address[:zip]
        end

        if options[:recurring] == true
          post[:client_secret] = @options[:client_secret]
          commit('/credit_card/transfer', post, options)
        else
          post[:original_device] = options[:device_fingerprint] if options[:device_fingerprint]
          post[:original_ip] = options[:ip] if options[:ip]
          commit('/credit_card/create', post, options)
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((\\?"cc_number\\?":\\?")[^\\"]+(\\?"))i, '\1[FILTERED]\2').
          gsub(%r((\\?"cvv\\?":\\?")[^\\"]+(\\?"))i, '\1[FILTERED]\2').
          gsub(%r((Authorization: Bearer )\w+)i, '\1[FILTERED]\2')
      end

      private

      def authorize_with_token(post, money, token, options)
        add_token(post, token)
        add_product_data(post, money, options)
        commit('/checkout/create', post, options)
      end

      def add_product_data(post, money, options)
        post[:account_id] = @options[:account_id]
        post[:amount] = amount(money)
        post[:short_description] = (options[:description] || 'Purchase')
        post[:type] = (options[:type] || 'goods')
        post[:currency] = (options[:currency] || currency(money))
        post[:long_description] = options[:long_description] if options[:long_description]
        post[:payer_email_message] = options[:payer_email_message] if options[:payer_email_message]
        post[:payee_email_message] = options[:payee_email_message] if options[:payee_email_message]
        post[:reference_id] = options[:order_id] if options[:order_id]
        post[:unique_id] = options[:unique_id] if options[:unique_id]
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
        post[:payer_rbits] = options[:payer_rbits] if options[:payer_rbits]
        post[:transaction_rbits] = options[:transaction_rbits] if options[:transaction_rbits]
        add_fee(post, options)
      end

      def add_token(post, token)
        payment_method = {}
        payment_method[:type] = 'credit_card'
        payment_method[:credit_card] = {
          id: token,
          auto_capture: false
        }

        post[:payment_method] = payment_method
      end

      def add_fee(post, options)
        if options[:application_fee] || options[:fee_payer]
          post[:fee] = {}
          post[:fee][:app_fee] = options[:application_fee] if options[:application_fee]
          post[:fee][:fee_payer] = options[:fee_payer] if options[:fee_payer]
        end
      end

      def parse(response)
        JSON.parse(response)
      end

      def commit(action, params, options={})
        begin
          response = parse(
            ssl_post(
              ((test? ? test_url : live_url) + action),
              params.to_json,
              headers(options)
            ))
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        return Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response, params),
          test: test?
        )
      rescue JSON::ParserError
        return unparsable_response(response)
      end

      def success_from(response)
        (!response['error'])
      end

      def message_from(response)
        (response['error'] ? response['error_description'] : 'Success')
      end

      def authorization_from(response, params)
        return response['credit_card_id'].to_s if response['credit_card_id']

        original_amount = response['amount'].nil? ? nil : sprintf('%0.02f', response['amount'])
        [response['checkout_id'], original_amount].join('|')
      end

      def split_authorization(authorization)
        auth, original_amount = authorization.to_s.split('|')
        [auth, original_amount]
      end

      def unparsable_response(raw_response)
        message = 'Invalid JSON response received from WePay. Please contact WePay support if you continue to receive this message.'
        message += " (The raw response returned by the API was #{raw_response.inspect})"
        return Response.new(false, message)
      end

      def headers(options)
        headers = {
          'Content-Type'      => 'application/json',
          'User-Agent'        => "ActiveMerchantBindings/#{ActiveMerchant::VERSION}",
          'Authorization'     => "Bearer #{@options[:access_token]}"
        }
        headers['Api-Version'] = options[:version] if options[:version]
        headers['Client-IP'] = options[:ip] if options[:ip]
        headers['WePay-Risk-Token'] = options[:risk_token] if options[:risk_token]

        headers
      end
    end
  end
end
