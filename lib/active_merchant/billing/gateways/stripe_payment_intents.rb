require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This gateway uses the current Stripe {Payment Intents API}[https://stripe.com/docs/api/payment_intents].
    # For the legacy API, see the Stripe gateway
    class StripePaymentIntentsGateway < StripeGateway
      self.supported_countries = %w(AT AU BE BG BR CA CH CY CZ DE DK EE ES FI FR GB GR HK IE IT JP LT LU LV MT MX NL NO NZ PL PT RO SE SG SI SK US)

      ALLOWED_METHOD_STATES = %w[automatic manual].freeze
      ALLOWED_CANCELLATION_REASONS = %w[duplicate fraudulent requested_by_customer abandoned].freeze
      CREATE_INTENT_ATTRIBUTES = %i[description statement_descriptor_suffix statement_descriptor receipt_email save_payment_method]
      CONFIRM_INTENT_ATTRIBUTES = %i[receipt_email return_url save_payment_method setup_future_usage off_session]
      UPDATE_INTENT_ATTRIBUTES = %i[description statement_descriptor_suffix statement_descriptor receipt_email setup_future_usage]
      DEFAULT_API_VERSION = '2019-05-16'

      def create_intent(money, payment_method, options = {})
        post = {}
        add_amount(post, money, options, true)
        add_capture_method(post, options)
        add_confirmation_method(post, options)
        add_customer(post, options)
        payment_method = add_payment_method_token(post, payment_method, options)
        return payment_method if payment_method.is_a?(ActiveMerchant::Billing::Response)

        add_metadata(post, options)
        add_return_url(post, options)
        add_connected_account(post, options)
        add_shipping_address(post, options)
        setup_future_usage(post, options)
        add_exemption(post, options)

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
        payment_method = add_payment_method_token(post, payment_method, options)
        return payment_method if payment_method.is_a?(ActiveMerchant::Billing::Response)

        CONFIRM_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end
        commit(:post, "payment_intents/#{intent_id}/confirm", post, options)
      end

      def create_payment_method(payment_method, options = {})
        post = {}
        post[:type] = 'card'
        post[:card] = {}
        post[:card][:number] = payment_method.number
        post[:card][:exp_month] = payment_method.month
        post[:card][:exp_year] = payment_method.year
        post[:card][:cvc] = payment_method.verification_value if payment_method.verification_value
        add_billing_address(post, options)
        options = format_idempotency_key(options, 'pm')
        commit(:post, 'payment_methods', post, options)
      end

      def update_intent(money, intent_id, payment_method, options = {})
        post = {}
        add_amount(post, money, options)

        payment_method = add_payment_method_token(post, payment_method, options)
        return payment_method if payment_method.is_a?(ActiveMerchant::Billing::Response)

        add_payment_method_types(post, options)
        add_customer(post, options)
        add_metadata(post, options)
        add_shipping_address(post, options)
        add_connected_account(post, options)

        UPDATE_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end
        commit(:post, "payment_intents/#{intent_id}", post, options)
      end

      def create_setup_intent(payment_method, options = {})
        post = {}
        add_customer(post, options)
        payment_method = add_payment_method_token(post, payment_method, options)
        return payment_method if payment_method.is_a?(ActiveMerchant::Billing::Response)

        add_metadata(post, options)
        add_return_url(post, options)
        post[:on_behalf_of] = options[:on_behalf_of] if options[:on_behalf_of]
        post[:usage] = options[:usage] if %w(on_session off_session).include?(options[:usage])
        post[:description] = options[:description] if options[:description]

        commit(:post, 'setup_intents', post, options)
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
        if payment_method.is_a?(StripePaymentToken) || payment_method.is_a?(ActiveMerchant::Billing::CreditCard)
          payment_method = add_payment_method_token(params, payment_method, options)
          return payment_method if payment_method.is_a?(ActiveMerchant::Billing::Response)

          if options[:customer]
            customer_id = options[:customer]
          else
            post[:validate] = options[:validate] unless options[:validate].nil?
            post[:description] = options[:description] if options[:description]
            post[:email] = options[:email] if options[:email]
            options = format_idempotency_key(options, 'customer')
            customer = commit(:post, 'customers', post, options)
            customer_id = customer.params['id']
          end
          options = format_idempotency_key(options, 'attach')
          commit(:post, "payment_methods/#{params[:payment_method]}/attach", { customer: customer_id }, options)
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

      private

      def add_connected_account(post, options = {})
        super(post, options)
        post[:application_fee_amount] = options[:application_fee] if options[:application_fee]
      end

      def add_whitelisted_attribute(post, options, attribute)
        post[attribute] = options[attribute] if options[attribute]
        post
      end

      def add_capture_method(post, options)
        capture_method = options[:capture_method].to_s
        post[:capture_method] = capture_method if ALLOWED_METHOD_STATES.include?(capture_method)
        post
      end

      def add_confirmation_method(post, options)
        confirmation_method = options[:confirmation_method].to_s
        post[:confirmation_method] = confirmation_method if ALLOWED_METHOD_STATES.include?(confirmation_method)
        post
      end

      def add_customer(post, options)
        customer = options[:customer].to_s
        post[:customer] = customer if customer.start_with?('cus_')
        post
      end

      def add_return_url(post, options)
        return unless options[:confirm]

        post[:confirm] = options[:confirm]
        post[:return_url] = options[:return_url] if options[:return_url]
        post
      end

      def add_payment_method_token(post, payment_method, options)
        return if payment_method.nil?

        if payment_method.is_a?(ActiveMerchant::Billing::CreditCard)
          p = create_payment_method(payment_method, options)
          return p unless p.success?

          payment_method = p.params['id']
        end

        if payment_method.is_a?(StripePaymentToken)
          post[:payment_method] = payment_method.payment_data['id']
        elsif payment_method.is_a?(String)
          if payment_method.include?('|')
            customer_id, payment_method_id = payment_method.split('|')
            token = payment_method_id
            post[:customer] = customer_id
          else
            token = payment_method
          end
          post[:payment_method] = token
        end
      end

      def add_payment_method_types(post, options)
        payment_method_types = options[:payment_method_types] if options[:payment_method_types]
        return if payment_method_types.nil?

        post[:payment_method_types] = Array(payment_method_types)
        post
      end

      def add_exemption(post, options = {})
        return unless options[:confirm]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:moto] = true if options[:moto]
      end

      def setup_future_usage(post, options = {})
        post[:setup_future_usage] = options[:setup_future_usage] if %w(on_session off_session).include?(options[:setup_future_usage])
        post[:off_session] = options[:off_session] if options[:off_session] && options[:confirm] == true
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
        post
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
        post
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
    end
  end
end
