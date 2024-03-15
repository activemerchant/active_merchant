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

      def create_intent(money, payment_method, options = {})
        MultiResponse.run do |r|
          r.process do
            post = {}
            add_amount(post, money, options, true)
            add_capture_method(post, options)
            add_confirmation_method(post, options)
            add_customer(post, options)

            result = add_payment_method(post, payment_method, options)
            return result if result.is_a?(ActiveMerchant::Billing::Response)

            add_external_three_d_secure_auth_data(post, options)
            add_metadata(post, options)
            add_return_url(post, options)
            add_connected_account(post, options)
            add_radar_data(post, options)
            add_shipping_address(post, options)
            add_stored_credentials(post, options)
            setup_future_usage(post, options)
            add_exemption(post, options)
            add_ntid(post, options)
            add_claim_without_transaction_id(post, options)
            add_error_on_requires_action(post, options)
            add_fulfillment_date(post, options)
            request_three_d_secure(post, options)
            add_level_three(post, options)
            add_card_brand(post, options)
            post[:expand] = ['charges.data.balance_transaction']

            CREATE_INTENT_ATTRIBUTES.each do |attribute|
              add_whitelisted_attribute(post, options, attribute)
            end
            commit(:post, 'payment_intents', post, options)
          end
        end
      end

      def show_intent(intent_id, options)
        commit(:get, "payment_intents/#{intent_id}", nil, options)
      end

      def create_test_customer
        response = api_request(:post, 'customers')
        response['id']
      end

      def confirm_intent(intent_id, payment_method, options = {})
        post = {}
        result = add_payment_method(post, payment_method, options)
        return result if result.is_a?(ActiveMerchant::Billing::Response)

        add_payment_method_types(post, options)
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
        post = {
          type: 'card',
          card: {
            exp_month: payment_method.month,
            exp_year: payment_method.year,
            number: payment_method.number,
            cvc: payment_method.verification_value
          }
        }

        add_billing_address(post, payment_method, options)
        post
      end

      def update_intent(money, intent_id, payment_method, options = {})
        post = {}
        add_amount(post, money, options)

        result = add_payment_method(post, payment_method, options)
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
        MultiResponse.run do |r|
          r.process do
            post = {}
            add_customer(post, options)
            result = add_payment_method(post, payment_method, options, r)
            return result if result.is_a?(ActiveMerchant::Billing::Response)

            add_metadata(post, options)
            add_return_url(post, options)
            add_fulfillment_date(post, options)
            request_three_d_secure(post, options)
            add_card_brand(post, options)
            post[:on_behalf_of] = options[:on_behalf_of] if options[:on_behalf_of]
            post[:usage] = options[:usage] if %w(on_session off_session).include?(options[:usage])
            post[:description] = options[:description] if options[:description]
            post[:expand] = ['latest_attempt']

            commit(:post, 'setup_intents', post, options)
          end
        end
      end

      def retrieve_setup_intent(setup_intent_id, options = {})
        # Retrieving a setup_intent passing 'expand[]=latest_attempt' allows the caller to
        # check for a network_transaction_id and ds_transaction_id
        # eg (latest_attempt -> payment_method_details -> card -> network_transaction_id)
        #
        # Being able to retrieve these fields enables payment flows that rely on MIT exemptions, e.g: off_session
        commit(:post, "setup_intents/#{setup_intent_id}", {
          'expand[]': 'latest_attempt'
        }, options)
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
        if payment_method.is_a?(StripePaymentToken) || payment_method.is_a?(CreditCard)
          result = add_payment_method(params, payment_method, options)
          return result if result.is_a?(ActiveMerchant::Billing::Response)

          customer_id = options[:customer] || customer(post, payment_method, options).params['id']
          options = format_idempotency_key(options, 'attach')
          attach_parameters = { customer: customer_id }
          attach_parameters[:validate] = options[:validate] unless options[:validate].nil?
          commit(:post, "payment_methods/#{params[:payment_method]}/attach", attach_parameters, options)
        else
          super(payment_method, options)
        end
      end

      def customer(post, payment, options)
        post[:description] = options[:description] if options[:description]
        post[:expand] = [:sources]
        post[:email] = options[:email]

        if billing = options[:billing_address] || options[:address]
          post.merge!(add_address(billing, options))
        end

        if shipping = options[:shipping_address]
          post[:shipping] = add_address(shipping, options).except(:email)
        end

        options = format_idempotency_key(options, 'customer')
        commit(:post, 'customers', post, options)
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
        create_setup_intent(payment_method, options.merge!({ confirm: true, verify: true }))
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

      def supports_network_tokenization?
        true
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

      def add_card_brand(post, options)
        return unless options[:card_brand]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:network] = options[:card_brand] if options[:card_brand]
      end

      def add_level_three(post, options = {})
        level_three = {}

        level_three[:merchant_reference] = options[:merchant_reference] if options[:merchant_reference]
        level_three[:customer_reference] = options[:customer_reference] if options[:customer_reference]
        level_three[:shipping_address_zip] = options[:shipping_address_zip] if options[:shipping_address_zip]
        level_three[:shipping_from_zip] = options[:shipping_from_zip] if options[:shipping_from_zip]
        level_three[:shipping_amount] = options[:shipping_amount] if options[:shipping_amount]
        level_three[:line_items] = options[:line_items] if options[:line_items]

        post[:level3] = level_three unless level_three.empty?
      end

      def add_return_url(post, options)
        return unless options[:confirm]

        post[:confirm] = options[:confirm]
        post[:return_url] = options[:return_url] if options[:return_url]
      end

      def add_payment_method(post, payment_method, options, responses = [])
        case payment_method
        when StripePaymentToken
          add_stripe_payment_token(post, payment_method)
        when String
          extract_token_from_string_and_maybe_add_customer_id(post, payment_method)
        when NetworkTokenizationCreditCard
          add_network_token(post, payment_method, options)
        when CreditCard
          add_credit_card(post, payment_method, options, responses)
        end
      end

      def add_stripe_payment_token(post, payment_method)
        payment_token = payment_method.payment_data['id'] || payment_method.payment_data
        post[:payment_method_data] = {
          type: 'card',
          card: {
            token: payment_token
          }
        }
        post[:payment_method] = payment_token
      end

      def add_network_token(post, payment_method, options)
        post[:card] = {
          last4: options[:last_4],
          network_token: {
            number: payment_method.number,
            exp_month: payment_method.month,
            exp_year: payment_method.year,
            tokenization_method: payment_method.source.to_s
          }
        }
        post[:card][:network_token][:payment_account_reference] = options[:payment_account_reference] if options[:payment_account_reference]

        post[:payment_method_options] = {
          card: {
            network_token: {
              cryptogram: payment_method.payment_cryptogram,
              electronic_commerce_indicator: payment_method.eci
            }
          }
        }

        add_billing_address(post, payment_method, options)
      end

      def add_credit_card(post, payment_method, options, responses)
        if options[:verify] || !off_session_request?(options)
          payment_method_response = create_payment_method(payment_method, options)
          return payment_method_response if payment_method_response.failure?

          responses << payment_method_response
          add_payment_method(post, payment_method_response.params['id'], options)
        else
          post[:payment_method_data] = add_payment_method_data(payment_method, options)
        end
      end

      def extract_token_from_string_and_maybe_add_customer_id(post, payment_method)
        if payment_method.include?('|')
          customer_id, payment_method = payment_method.split('|')
          post[:customer] = customer_id
        end

        if payment_method.include?('tok_')
          post_data.merge!({
            payment_method_types: ['card'],
            payment_method_data: { type: 'card', card: { token: payment_method } }
          })
        else
          post[:payment_method] = payment_method
        end
      end

      def add_payment_method_types(post, options)
        return unless payment_method_types = options[:payment_method_types]

        post[:payment_method_types] = Array(payment_method_types)
      end

      def add_exemption(post, options = {})
        return unless options[:confirm] && options[:moto]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:moto] = true
      end

      # Stripe Payment Intents now supports specifying on a transaction level basis stored credential information.
      # The feature is currently gated but is listed as `stored_credential_transaction_type` inside the
      # `post[:payment_method_options][:card]` hash. Since this is a beta field adding an extra check to use
      # the existing logic by default. To be able to utilize this field, you must reach out to Stripe.

      def add_stored_credentials(post, options = {})
        stored_credential = options[:stored_credential]
        return unless stored_credential && !stored_credential.values.all?(&:nil?)

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:mit_exemption] = {}

        # Stripe PI accepts network_transaction_id and ds_transaction_id via mit field under card.
        # The network_transaction_id can be sent in nested under stored credentials OR as its own field (add_ntid handles when it is sent in on its own)
        # If it is sent is as its own field AND under stored credentials, the value sent under its own field is what will send.
        mit_exemption =  post[:payment_method_options][:card][:mit_exemption]
        mit_exemption[:ds_transaction_id] = stored_credential[:ds_transaction_id] if stored_credential[:ds_transaction_id]
        unless options[:setup_future_usage] == 'off_session'
          mit_exemption[:network_transaction_id] = stored_credential[:network_transaction_id] if stored_credential[:network_transaction_id]
        end

        return unless options[:stored_credential_transaction_type]
        post[:payment_method_options][:card][:stored_credential_transaction_type] = add_stored_credential_type(post, options, stored_credential)
      end

      def add_stored_credential_type(post, options, stored_credential)
        # Not compatible with off_session parameter.
        options.delete(:off_session)

        if stored_credential[:initial_transaction]
          return unless stored_credential[:initiator] == 'cardholder'

          initial_transaction_stored_credential(post, stored_credential)
        else
          subsequent_transaction_stored_credential(post, stored_credential)
        end
      end

      def initial_transaction_stored_credential(post, stored_credential)
        case reason_type = stored_credential[:reason_type]
        when 'unscheduled', 'recurring'
          # Charge on-session and store card for future one-off or recurring payment use
          "setup_off_session_#{reason_type}"
        else
          post[:payment_method_options][:card][:mit_exemption].delete(:network_transaction_id)
          # Charge on-session and store card for future on-session payment use.
          'setup_on_session'
        end
      end

      def subsequent_transaction_stored_credential(post, stored_credential)
        if stored_credential[:initiator] == 'cardholder'
          # Charge on-session customer using previously stored card.
          'stored_on_session'
        elsif stored_credential[:reason_type] == 'recurring'
          # Charge off-session customer using previously stored card for recurring transaction
          'stored_off_session_recurring'
        else
          # Charge off-session customer using previously stored card for one-off transaction
          'stored_off_session_unscheduled'
        end
      end

      def add_ntid(post, options = {})
        return unless ntid = options[:network_transaction_id]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:mit_exemption] = {
          network_transaction_id: ntid
        }
      end

      def add_claim_without_transaction_id(post, options = {})
        return if options[:stored_credential] || options[:network_transaction_id] || options[:ds_transaction_id]
        return unless transaction_id = options[:claim_without_transaction_id]

        # Stripe PI accepts claim_without_transaction_id for transactions without transaction ids.
        # Gateway validation for this field occurs through a different service, before the transaction request is sent to the gateway.
        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:mit_exemption] = {
          claim_without_transaction_id: transaction_id
        }
      end

      def add_error_on_requires_action(post, options = {})
        return unless options[:confirm] && options[:error_on_requires_action]

        post[:error_on_requires_action] = true
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
        binding.pry
        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:three_d_secure] ||= {}
        post[:payment_method_options][:card][:three_d_secure] = {
          version: three_d_secure[:version] || (three_d_secure[:ds_transaction_id] ? '2.2.0' : '1.0.2'),
          electronic_commerce_indicator: three_d_secure[:eci],
          cryptogram: three_d_secure[:cavv],
          transaction_id: three_d_secure[:ds_transaction_id]
        }.compact
      end

      def setup_future_usage(post, options = {})
        post[:setup_future_usage] = options[:setup_future_usage] if %w(on_session off_session).include?(options[:setup_future_usage])
        post[:off_session] = options[:off_session] if off_session_request?(options)
      end

      def add_billing_address(post, payment_method, options = {})
        if billing = options[:billing_address] || options[:address]
          post[:billing_details] = add_address(billing, options)
        end

        if post[:billing_details].nil?
          post[:billing_details] = {} unless post[:billing_details]

          name = [payment_method.first_name, payment_method.last_name].compact.join(' ')
          post[:billing_details][:name] = name
        end
      end

      def add_shipping_address(post, options = {})
        return unless shipping = options[:shipping_address]

        post[:shipping] = add_address(shipping, options).except(:email)
        post[:shipping].merge!({
          carrier: shipping[:carrier] || options[:shipping_carrier],
          tracking_number: shipping[:tracking_number] || options[:shipping_tracking_number]
        }.compact)
      end

      def add_address(address, options)
        {
          address: {
            city: address[:city],
            country: address[:country],
            line1: address[:address1],
            line2: address[:address2],
            postal_code: address[:zip],
            state: address[:state]
          }.compact,
          email: address[:email] || options[:email],
          phone: address[:phone] || address[:phone_number],
          name: address[:name]
        }.compact
      end

      def format_idempotency_key(options, suffix)
        return options unless options[:idempotency_key]

        options.merge(idempotency_key: "#{options[:idempotency_key]}-#{suffix}")
      end

      def success_from(response, options)
        return super(response, options) unless response['status'] == 'requires_action' && !options[:execute_threed]
          
        response['error'] = {
          'message' =>  'Received unexpected 3DS authentication response, but a 3DS initiation flag was not included in the request.'
        }

        false
      end

      def add_currency(post, options, money)
        post[:currency] = options[:currency] || currency(money)
      end
    end
  end
end
