require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This gateway uses the current Stripe {Payment Intents API}[https://stripe.com/docs/api/payment_intents].
    # For the legacy API, see the Stripe gateway
    class StripePaymentIntentsGateway < StripeGateway
      ALLOWED_METHOD_STATES = %w[automatic manual].freeze
      ALLOWED_CANCELLATION_REASONS = %w[duplicate fraudulent requested_by_customer abandoned].freeze
      CREATE_INTENT_ATTRIBUTES = %i[description statement_descriptor_suffix statement_descriptor receipt_email save_payment_method]
      CONFIRM_INTENT_ATTRIBUTES = %i[receipt_email return_url save_payment_method setup_future_usage off_session]
      UPDATE_INTENT_ATTRIBUTES = %i[description statement_descriptor_suffix statement_descriptor receipt_email setup_future_usage]
      DEFAULT_API_VERSION = '2020-08-27'
      NO_WALLET_SUPPORT = %w(apple_pay google_pay android_pay)

      def create_intent(money, payment_method, options = {})
        card_source_pay = payment_method.source.to_s if defined?(payment_method.source)
        card_brand_pay = card_brand(payment_method) unless payment_method.is_a?(String) || payment_method.nil?
        if NO_WALLET_SUPPORT.include?(card_source_pay) || NO_WALLET_SUPPORT.include?(card_brand_pay)
          store_apple_or_google_pay_token = 'Direct Apple Pay and Google Pay transactions are not supported. Those payment methods must be stored before use.'
          return Response.new(false, store_apple_or_google_pay_token)
        end

        post = {}
        add_amount(post, money, options, true)
        add_capture_method(post, options)
        add_confirmation_method(post, options)
        add_customer(post, options)
        if payment_method.is_a?(String) && payment_method.include?('tok_')
          add_payment_method_card_data_tok(post, payment_method, options)
        else
          result = add_payment_method_token(post, payment_method, options)
          return result if result.is_a?(ActiveMerchant::Billing::Response)

        end

        add_external_three_d_secure_auth_data(post, options)
        add_metadata(post, options)
        add_return_url(post, options)
        add_connected_account(post, options)
        add_radar_data(post, options)
        add_shipping_address(post, options)
        setup_future_usage(post, options)
        add_exemption(post, options)
        add_stored_credentials(post, options)
        add_ntid(post, options)
        add_claim_without_transaction_id(post, options)
        add_error_on_requires_action(post, options)
        add_fulfillment_date(post, options)
        request_three_d_secure(post, options)

        CREATE_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end

        commit(:post, 'payment_intents', post, options)
      end

      def show_intent(intent_id, options)
        commit(:get, "payment_intents/#{intent_id}", nil, options)
      end

      def confirm_intent(intent_id, payment_method, options = {})
        post = {}
        result = add_payment_method_token(post, payment_method, options)
        return result if result.is_a?(ActiveMerchant::Billing::Response)

        CONFIRM_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end

        commit(:post, "payment_intents/#{intent_id}/confirm", post, options)
      end

      def create_payment_method(payment_method, options = {})
        post_data = add_payment_method_data(payment_method, options)

        options = format_idempotency_key(options, 'pm')
        commit(:post, 'payment_methods', post_data, options)
      end

      def add_payment_method_data(payment_method, options = {})
        post_data = {}
        post_data[:type] = 'card'
        post_data[:card] = {}
        post_data[:card][:number] = payment_method.number
        post_data[:card][:exp_month] = payment_method.month
        post_data[:card][:exp_year] = payment_method.year
        post_data[:card][:cvc] = payment_method.verification_value if payment_method.verification_value
        add_billing_address(post_data, options)
        add_name_only(post_data, payment_method) if post_data[:billing_details].nil?
        post_data
      end

      def add_payment_method_card_data_tok(post_data, payment_method, options = {})
        post_data[:payment_method_types] = {}
        post_data[:payment_method_types][''] = 'card'
        post_data[:payment_method_data] = {}
        post_data[:payment_method_data][:type] = 'card'
        post_data[:payment_method_data][:card] = {}
        post_data[:payment_method_data][:card][:token] = payment_method
        post_data
      end

      def update_intent(money, intent_id, payment_method, options = {})
        post = {}
        add_amount(post, money, options)

        result = add_payment_method_token(post, payment_method, options)
        return result if result.is_a?(ActiveMerchant::Billing::Response)

        add_payment_method_types(post, options)
        add_customer(post, options)
        add_metadata(post, options)
        add_shipping_address(post, options)
        add_connected_account(post, options)
        add_fulfillment_date(post, options)

        UPDATE_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end
        commit(:post, "payment_intents/#{intent_id}", post, options)
      end

      def create_setup_intent(payment_method, options = {})
        post = {}
        add_customer(post, options)
        result = add_payment_method_token(post, payment_method, options)
        return result if result.is_a?(ActiveMerchant::Billing::Response)

        add_metadata(post, options)
        add_return_url(post, options)
        add_fulfillment_date(post, options)
        post[:on_behalf_of] = options[:on_behalf_of] if options[:on_behalf_of]
        post[:usage] = options[:usage] if %w(on_session off_session).include?(options[:usage])
        post[:description] = options[:description] if options[:description]

        commit(:post, 'setup_intents', post, options)
      end

      def retrieve_setup_intent(setup_intent_id)
        # Retrieving a setup_intent passing 'expand[]=latest_attempt' allows the caller to
        # check for a network_transaction_id and ds_transaction_id
        # eg (latest_attempt -> payment_method_details -> card -> network_transaction_id)
        #
        # Being able to retrieve these fields enables payment flows that rely on MIT exemptions, e.g: off_session
        commit(:post, "setup_intents/#{setup_intent_id}", {
          'expand[]': 'latest_attempt'
        }, {})
      end

      def authorize(money, payment_method, options = {})
        create_intent(money, payment_method, options.merge!(confirm: true, capture_method: 'manual'))
      end

      def purchase(money, payment_method, options = {})
        create_intent(money, payment_method, options.merge!(confirm: true, capture_method: 'automatic'))
      end

      def capture(money, intent_id, options = {})
        post = {}
        currency = options[:currency] || currency(money)
        post[:amount_to_capture] = localized_amount(money, currency)
        if options[:transfer_amount]
          post[:transfer_data] = {}
          post[:transfer_data][:amount] = options[:transfer_amount]
        end
        post[:application_fee_amount] = options[:application_fee] if options[:application_fee]
        options = format_idempotency_key(options, 'capture')
        commit(:post, "payment_intents/#{intent_id}/capture", post, options)
      end

      def void(intent_id, options = {})
        post = {}
        post[:cancellation_reason] = options[:cancellation_reason] if ALLOWED_CANCELLATION_REASONS.include?(options[:cancellation_reason])
        commit(:post, "payment_intents/#{intent_id}/cancel", post, options)
      end

      def refund(money, intent_id, options = {})
        if intent_id.include?('pi_')
          intent = api_request(:get, "payment_intents/#{intent_id}", nil, options)

          return Response.new(false, intent['error']['message'], intent) if intent['error']

          charge_id = intent.try(:[], 'charges').try(:[], 'data').try(:[], 0).try(:[], 'id')

          if charge_id.nil?
            error_message = "No associated charge for #{intent['id']}"
            error_message << "; payment_intent has a status of #{intent['status']}" if intent.try(:[], 'status') && intent.try(:[], 'status') != 'succeeded'
            return Response.new(false, error_message, intent)
          end
        else
          charge_id = intent_id
        end

        super(money, charge_id, options)
      end

      # Note: Not all payment methods are currently supported by the {Payment Methods API}[https://stripe.com/docs/payments/payment-methods]
      # Current implementation will create a PaymentMethod object if the method is a token or credit card
      # All other types will default to legacy Stripe store
      def store(payment_method, options = {})
        params = {}
        post = {}

        # If customer option is provided, create a payment method and attach to customer id
        # Otherwise, create a customer, then attach
        if payment_method.is_a?(ActiveMerchant::Billing::NetworkTokenizationCreditCard)
          result = tokenize_apple_google_token(payment_method, options)
          return result
        elsif payment_method.is_a?(StripePaymentToken) || payment_method.is_a?(ActiveMerchant::Billing::CreditCard)
          result = add_payment_method_token(params, payment_method, options)
          return result if result.is_a?(ActiveMerchant::Billing::Response)

          if options[:customer]
            customer_id = options[:customer]
          else
            post[:description] = options[:description] if options[:description]
            post[:email] = options[:email] if options[:email]
            options = format_idempotency_key(options, 'customer')
            post[:expand] = [:sources]
            customer = commit(:post, 'customers', post, options)
            customer_id = customer.params['id']
          end
          options = format_idempotency_key(options, 'attach')
          attach_parameters = { customer: customer_id }
          attach_parameters[:validate] = options[:validate] unless options[:validate].nil?
          commit(:post, "payment_methods/#{params[:payment_method]}/attach", attach_parameters, options)
        else
          super(payment_method, options)
        end
      end

      def unstore(identification, options = {}, deprecated_options = {})
        if identification.include?('pm_')
          _, payment_method = identification.split('|')
          commit(:post, "payment_methods/#{payment_method}/detach", nil, options)
        else
          super(identification, options, deprecated_options)
        end
      end

      def verify(payment_method, options = {})
        create_setup_intent(payment_method, options.merge!(confirm: true))
      end

      def setup_purchase(money, options = {})
        requires!(options, :payment_method_types)
        post = {}
        add_currency(post, options, money)
        add_amount(post, money, options)
        add_payment_method_types(post, options)
        add_metadata(post, options)
        commit(:post, 'payment_intents', post, options)
      end

      private

      def off_session_request?(options = {})
        (options[:off_session] || options[:setup_future_usage]) && options[:confirm] == true
      end

      def add_connected_account(post, options = {})
        super(post, options)
        post[:application_fee_amount] = options[:application_fee] if options[:application_fee]
      end

      def add_whitelisted_attribute(post, options, attribute)
        post[attribute] = options[attribute] if options[attribute]
      end

      def add_capture_method(post, options)
        capture_method = options[:capture_method].to_s
        post[:capture_method] = capture_method if ALLOWED_METHOD_STATES.include?(capture_method)
      end

      def add_confirmation_method(post, options)
        confirmation_method = options[:confirmation_method].to_s
        post[:confirmation_method] = confirmation_method if ALLOWED_METHOD_STATES.include?(confirmation_method)
      end

      def add_customer(post, options)
        customer = options[:customer].to_s
        post[:customer] = customer if customer.start_with?('cus_')
      end

      def add_fulfillment_date(post, options)
        post[:fulfillment_date] = options[:fulfillment_date].to_i if options[:fulfillment_date]
      end

      def add_metadata(post, options = {})
        super

        post[:metadata][:event_type] = options[:event_type] if options[:event_type]
      end

      def add_return_url(post, options)
        return unless options[:confirm]

        post[:confirm] = options[:confirm]
        post[:return_url] = options[:return_url] if options[:return_url]
      end

      def add_payment_method_token(post, payment_method, options)
        case payment_method
        when StripePaymentToken
          post[:payment_method] = payment_method.payment_data['id']
        when String
          extract_token_from_string_and_maybe_add_customer_id(post, payment_method)
        when ActiveMerchant::Billing::CreditCard
          get_payment_method_data_from_card(post, payment_method, options)
        end
      end

      def extract_token_from_string_and_maybe_add_customer_id(post, payment_method)
        if payment_method.include?('|')
          customer_id, payment_method = payment_method.split('|')
          post[:customer] = customer_id
        end

        post[:payment_method] = payment_method
      end

      def get_payment_method_data_from_card(post, payment_method, options)
        return create_payment_method_and_extract_token(post, payment_method, options) unless off_session_request?(options)

        post[:payment_method_data] = add_payment_method_data(payment_method, options)
      end

      def create_payment_method_and_extract_token(post, payment_method, options)
        payment_method_response = create_payment_method(payment_method, options)
        return payment_method_response if payment_method_response.failure?

        add_payment_method_token(post, payment_method_response.params['id'], options)
      end

      def add_payment_method_types(post, options)
        payment_method_types = options[:payment_method_types] if options[:payment_method_types]
        return if payment_method_types.nil?

        post[:payment_method_types] = Array(payment_method_types)
      end

      def tokenize_apple_google_token(payment, options = {})
        if payment.inspect.include?('google_pay')
          tokenization_method = 'android_pay'
        elsif payment.inspect.include?('apple_pay')
          tokenization_method = 'apple_pay'
        end
        post = {
          card: {
            number: payment.number,
            exp_month: payment.month,
            exp_year: payment.year,
            tokenization_method: tokenization_method,
            eci: payment.eci,
            cryptogram: payment.payment_cryptogram
          }
        }
        token_response = api_request(:post, 'tokens', post, {})
        #p token_response
        success = token_response['error'].nil?
        if success && token_response['id']
          Response.new(success, nil, token: token_response)
        else
          Response.new(success, token_response['error']['message'])
        end
      end

      def add_exemption(post, options = {})
        return unless options[:confirm]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:moto] = true if options[:moto]
      end

      # Stripe Payment Intents does not pass any parameters for cardholder/merchant initiated
      # it also does not support installments for any country other than Mexico (reason for this is unknown)
      # The only thing that Stripe PI requires for stored credentials to work currently is the network_transaction_id
      # network_transaction_id is created when the card is authenticated using the field `setup_for_future_usage` with the value `off_session` see def setup_future_usage below

      def add_stored_credentials(post, options = {})
        return unless options[:stored_credential] && !options[:stored_credential].values.all?(&:nil?)

        stored_credential = options[:stored_credential]
        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:mit_exemption] = {}

        # Stripe PI accepts network_transaction_id and ds_transaction_id via mit field under card.
        # The network_transaction_id can be sent in nested under stored credentials OR as its own field (add_ntid handles when it is sent in on its own)
        # If it is sent is as its own field AND under stored credentials, the value sent under its own field is what will send.
        post[:payment_method_options][:card][:mit_exemption][:ds_transaction_id] = stored_credential[:ds_transaction_id] if stored_credential[:ds_transaction_id]
        post[:payment_method_options][:card][:mit_exemption][:network_transaction_id] = stored_credential[:network_transaction_id] if stored_credential[:network_transaction_id]
      end

      def add_ntid(post, options = {})
        return unless options[:network_transaction_id]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:mit_exemption] = {}

        post[:payment_method_options][:card][:mit_exemption][:network_transaction_id] = options[:network_transaction_id] if options[:network_transaction_id]
      end

      def add_claim_without_transaction_id(post, options = {})
        return if options[:stored_credential] || options[:network_transaction_id] || options[:ds_transaction_id]
        return unless options[:claim_without_transaction_id]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:mit_exemption] = {}

        # Stripe PI accepts claim_without_transaction_id for transactions without transaction ids.
        # Gateway validation for this field occurs through a different service, before the transaction request is sent to the gateway.
        post[:payment_method_options][:card][:mit_exemption][:claim_without_transaction_id] = options[:claim_without_transaction_id]
      end

      def add_error_on_requires_action(post, options = {})
        return unless options[:confirm]

        post[:error_on_requires_action] = true if options[:error_on_requires_action]
      end

      def request_three_d_secure(post, options = {})
        return unless options[:request_three_d_secure] && %w(any automatic).include?(options[:request_three_d_secure])

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:request_three_d_secure] = options[:request_three_d_secure]
      end

      def add_external_three_d_secure_auth_data(post, options = {})
        return unless options[:three_d_secure]&.is_a?(Hash)

        three_d_secure = options[:three_d_secure]
        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:three_d_secure] ||= {}
        post[:payment_method_options][:card][:three_d_secure][:version] = three_d_secure[:version] || (three_d_secure[:ds_transaction_id] ? '2.2.0' : '1.0.2')
        post[:payment_method_options][:card][:three_d_secure][:electronic_commerce_indicator] = three_d_secure[:eci] if three_d_secure[:eci]
        post[:payment_method_options][:card][:three_d_secure][:cryptogram] = three_d_secure[:cavv] if three_d_secure[:cavv]
        post[:payment_method_options][:card][:three_d_secure][:transaction_id] = three_d_secure[:ds_transaction_id] || three_d_secure[:xid]
      end

      def setup_future_usage(post, options = {})
        post[:setup_future_usage] = options[:setup_future_usage] if %w(on_session off_session).include?(options[:setup_future_usage])
        post[:off_session] = options[:off_session] if off_session_request?(options)
        post
      end

      def add_billing_address(post, options = {})
        return unless billing = options[:billing_address] || options[:address]

        post[:billing_details] = {}
        post[:billing_details][:address] = {}
        post[:billing_details][:address][:city] = billing[:city] if billing[:city]
        post[:billing_details][:address][:country] = billing[:country] if billing[:country]
        post[:billing_details][:address][:line1] = billing[:address1] if billing[:address1]
        post[:billing_details][:address][:line2] = billing[:address2] if billing[:address2]
        post[:billing_details][:address][:postal_code] = billing[:zip] if billing[:zip]
        post[:billing_details][:address][:state] = billing[:state] if billing[:state]
        post[:billing_details][:email] = billing[:email] if billing[:email]
        post[:billing_details][:name] = billing[:name] if billing[:name]
        post[:billing_details][:phone] = billing[:phone] if billing[:phone]
      end

      def add_name_only(post, payment_method)
        post[:billing_details] = {} unless post[:billing_details]

        name = [payment_method.first_name, payment_method.last_name].compact.join(' ')
        post[:billing_details][:name] = name
      end

      def add_shipping_address(post, options = {})
        return unless shipping = options[:shipping]

        post[:shipping] = {}
        post[:shipping][:address] = {}
        post[:shipping][:address][:line1] = shipping[:address][:line1]
        post[:shipping][:address][:city] = shipping[:address][:city] if shipping[:address][:city]
        post[:shipping][:address][:country] = shipping[:address][:country] if shipping[:address][:country]
        post[:shipping][:address][:line2] = shipping[:address][:line2] if shipping[:address][:line2]
        post[:shipping][:address][:postal_code] = shipping[:address][:postal_code] if shipping[:address][:postal_code]
        post[:shipping][:address][:state] = shipping[:address][:state] if shipping[:address][:state]

        post[:shipping][:name] = shipping[:name]
        post[:shipping][:carrier] = shipping[:carrier] if shipping[:carrier]
        post[:shipping][:phone] = shipping[:phone] if shipping[:phone]
        post[:shipping][:tracking_number] = shipping[:tracking_number] if shipping[:tracking_number]
      end

      def format_idempotency_key(options, suffix)
        return options unless options[:idempotency_key]

        options.merge(idempotency_key: "#{options[:idempotency_key]}-#{suffix}")
      end

      def success_from(response, options)
        if response['status'] == 'requires_action' && !options[:execute_threed]
          response['error'] = {}
          response['error']['message'] = 'Received unexpected 3DS authentication response. Use the execute_threed option to initiate a proper 3DS flow.'
          return false
        end

        super(response, options)
      end

      def add_currency(post, options, money)
        post[:currency] = options[:currency] || currency(money)
      end
    end
  end
end
