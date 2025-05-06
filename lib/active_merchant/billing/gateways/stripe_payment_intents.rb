require 'active_support/core_ext/hash/slice'

module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    # This gateway uses the current Stripe {Payment Intents API}[https://stripe.com/docs/api/payment_intents].
    # For the legacy API, see the Stripe gateway
    class StripePaymentIntentsGateway < StripeGateway
      ALLOWED_METHOD_STATES = %w[automatic manual].freeze
      ALLOWED_CANCELLATION_REASONS = %w[duplicate fraudulent requested_by_customer abandoned].freeze
      CREATE_INTENT_ATTRIBUTES = %i[description statement_descriptor_suffix statement_descriptor receipt_email save_payment_method]
      CONFIRM_INTENT_ATTRIBUTES = %i[receipt_email return_url save_payment_method setup_future_usage off_session]
      UPDATE_INTENT_ATTRIBUTES = %i[description statement_descriptor_suffix statement_descriptor receipt_email setup_future_usage]
      DEFAULT_API_VERSION = '2020-08-27'
      DIGITAL_WALLETS = {
        apple_pay: 'apple_pay',
        google_pay: 'google_pay_dpan'
      }

      def create_intent(money, payment_method, options = {})
        MultiResponse.run do |r|
          if payment_method.is_a?(NetworkTokenizationCreditCard) && digital_wallet_payment_method?(payment_method) && options[:new_ap_gp_route] != true
            r.process { tokenize_apple_google(payment_method, options) }
            payment_method = (r.params['token']['id']) if r.success?
          end
          r.process do
            post = {}
            add_amount(post, money, options, true)
            add_capture_method(post, options)
            add_confirmation_method(post, options)
            add_customer(post, options)

            if new_apple_google_pay_flow(payment_method, options)
              add_digital_wallet(post, payment_method, options)
              add_billing_address(post, payment_method, options)
            else
              result = add_payment_method_token(post, payment_method, options)
              return result if result.is_a?(ActiveMerchant::Billing::Response)
            end

            add_network_token_info(post, payment_method, options)
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
            add_aft_recipient_details(post, options)
            add_aft_sender_details(post, options)
            add_request_extended_authorization(post, options)
            add_statement_descriptor_suffix_kanji_kana(post, options)
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
        if new_apple_google_pay_flow(payment_method, options)
          add_digital_wallet(post, payment_method, options)
        else
          result = add_payment_method_token(post, payment_method, options)
          return result if result.is_a?(ActiveMerchant::Billing::Response)
        end

        add_network_token_info(post, payment_method, options)
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

      def new_apple_google_pay_flow(payment_method, options)
        return false unless options[:new_ap_gp_route]

        payment_method.is_a?(NetworkTokenizationCreditCard) && digital_wallet_payment_method?(payment_method)
      end

      def add_payment_method_data(payment_method, options = {})
        post = {
          type: 'card',
          card: {
            exp_month: payment_method.month,
            exp_year: payment_method.year
          }
        }
        post[:card][:number] = payment_method.number unless adding_network_token_card_data?(payment_method)
        post[:card][:cvc] = payment_method.verification_value if payment_method.verification_value
        if billing = options[:billing_address] || options[:address]
          post[:billing_details] = add_address(billing, options)
        end

        # wallet_type is only passed for non-tokenized GooglePay which acts as a CreditCard
        if options[:wallet_type]
          post[:metadata] ||= {}
          post[:metadata][:input_method] = 'GooglePay'
        end
        add_name_only(post, payment_method) if post[:billing_details].nil?
        add_network_token_data(post, payment_method, options)
        post
      end

      def add_payment_method_card_data_token(post_data, payment_method)
        post_data.merge!({
          payment_method_types: ['card'],
          payment_method_data: { type: 'card', card: { token: payment_method } }
        })
      end

      def update_intent(money, intent_id, payment_method, options = {})
        post = {}
        add_amount(post, money, options)

        if new_apple_google_pay_flow(payment_method, options)
          add_digital_wallet(post, payment_method, options)
        else
          result = add_payment_method_token(post, payment_method, options)
          return result if result.is_a?(ActiveMerchant::Billing::Response)
        end

        add_network_token_info(post, payment_method, options)
        add_payment_method_types(post, options)
        add_customer(post, options)
        add_metadata(post, options)
        add_shipping_address(post, options)
        add_connected_account(post, options)
        add_fulfillment_date(post, options)
        add_statement_descriptor_suffix_kanji_kana(post, options)

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

            if new_apple_google_pay_flow(payment_method, options)
              add_digital_wallet(post, payment_method, options)
              add_billing_address(post, payment_method, options)
            else
              result = add_payment_method_token(post, payment_method, options, r)
              return result if result.is_a?(ActiveMerchant::Billing::Response)
            end

            add_network_token_info(post, payment_method, options)
            add_metadata(post, options)
            add_return_url(post, options)
            add_fulfillment_date(post, options)
            request_three_d_secure(post, options)
            add_card_brand(post, options)
            add_exemption(post, options)
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
        commit(:get, "setup_intents/#{setup_intent_id}?expand[]=latest_attempt", nil, options)
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
        # If customer option is provided, create a payment method and attach to customer id
        # Otherwise, create a customer, then attach
        if new_apple_google_pay_flow(payment_method, options)
          options[:customer] = customer(payment_method, options).params['id'] unless options[:customer]
          verify(payment_method, options.merge!(action: :store))
        elsif payment_method.is_a?(ActiveMerchant::Billing::CreditCard)
          result = add_payment_method_token(params, payment_method, options)
          return result if result.is_a?(ActiveMerchant::Billing::Response)

          customer_id = options[:customer] || customer(payment_method, options).params['id']
          options = format_idempotency_key(options, 'attach')
          attach_parameters = { customer: customer_id }
          attach_parameters[:validate] = options[:validate] unless options[:validate].nil?
          commit(:post, "payment_methods/#{params[:payment_method]}/attach", attach_parameters, options)
        else
          super(payment_method, options)
        end
      end

      def customer(payment, options)
        post = {}
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

      def error_id(response, url)
        if url.end_with?('payment_intents')
          response.dig('error', 'payment_intent', 'id') || super
        else
          super
        end
      end

      def digital_wallet_payment_method?(payment_method)
        payment_method.source == :google_pay || payment_method.source == :apple_pay
      end

      def adding_network_token_card_data?(payment_method)
        return true if payment_method.is_a?(ActiveMerchant::Billing::NetworkTokenizationCreditCard) && payment_method.source == :network_token

        false
      end

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

      def add_request_extended_authorization(post, options)
        return unless options[:request_extended_authorization]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:request_extended_authorization] = options[:request_extended_authorization] if options[:request_extended_authorization]
      end

      def add_statement_descriptor_suffix_kanji_kana(post, options)
        return unless options[:statement_descriptor_suffix_kanji] || options[:statement_descriptor_suffix_kana]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:statement_descriptor_suffix_kanji] = options[:statement_descriptor_suffix_kanji] if options[:statement_descriptor_suffix_kanji]
        post[:payment_method_options][:card][:statement_descriptor_suffix_kana] = options[:statement_descriptor_suffix_kana] if options[:statement_descriptor_suffix_kana]
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

      def add_aft_recipient_details(post, options)
        return unless options[:recipient_details]&.is_a?(Hash)

        recipient_details = options[:recipient_details]
        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:recipient_details] = {}
        post[:payment_method_options][:card][:recipient_details][:first_name] = recipient_details[:first_name] if recipient_details[:first_name]
        post[:payment_method_options][:card][:recipient_details][:last_name] = recipient_details[:last_name] if recipient_details[:last_name]
        post[:payment_method_options][:card][:recipient_details][:email] = recipient_details[:email] if recipient_details[:email]
        post[:payment_method_options][:card][:recipient_details][:phone] = recipient_details[:phone] if recipient_details[:phone]

        if recipient_details[:address].is_a?(Hash)
          address = recipient_details[:address]
          post[:payment_method_options][:card][:recipient_details][:address] = {}
          post[:payment_method_options][:card][:recipient_details][:address][:country] = address[:country] if address[:country]
          post[:payment_method_options][:card][:recipient_details][:address][:line1] = address[:line1] if address[:line1]
          post[:payment_method_options][:card][:recipient_details][:address][:line2] = address[:line2] if address[:line2]
          post[:payment_method_options][:card][:recipient_details][:address][:postal_code] = address[:postal_code] if address[:postal_code]
          post[:payment_method_options][:card][:recipient_details][:address][:state] = address[:state] if address[:state]
          post[:payment_method_options][:card][:recipient_details][:address][:city] = address[:city] if address[:city]
        end

        if recipient_details[:account_details].is_a?(Hash)
          account_details = recipient_details[:account_details]
          post[:payment_method_options][:card][:recipient_details][:account_details] = {}

          if account_details[:card].is_a?(Hash)
            card = account_details[:card]
            post[:payment_method_options][:card][:recipient_details][:account_details][:card] = {}
            post[:payment_method_options][:card][:recipient_details][:account_details][:card][:first6] = card[:first6] if card[:first6]
            post[:payment_method_options][:card][:recipient_details][:account_details][:card][:last4] = card[:last4] if card[:last4]
          end

          if account_details[:unique_identifier].is_a?(Hash)
            unique_identifier = account_details[:unique_identifier]
            post[:payment_method_options][:card][:recipient_details][:account_details][:unique_identifier] = {}
            post[:payment_method_options][:card][:recipient_details][:account_details][:unique_identifier][:identifier] = unique_identifier[:identifier] if unique_identifier[:identifier]
          end
        end
      end

      def add_aft_sender_details(post, options)
        return unless options[:sender_details]&.is_a?(Hash)

        sender_details = options[:sender_details]
        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:sender_details] = {}
        post[:payment_method_options][:card][:sender_details][:first_name] = sender_details[:first_name] if sender_details[:first_name]
        post[:payment_method_options][:card][:sender_details][:last_name] = sender_details[:last_name] if sender_details[:last_name]
        post[:payment_method_options][:card][:sender_details][:email] = sender_details[:email] if sender_details[:email]
        post[:payment_method_options][:card][:sender_details][:occupation] = sender_details[:occupation] if sender_details[:occupation]
        post[:payment_method_options][:card][:sender_details][:nationality] = sender_details[:nationality] if sender_details[:nationality]
        post[:payment_method_options][:card][:sender_details][:birth_country] = sender_details[:birth_country] if sender_details[:birth_country]

        if sender_details[:address].is_a?(Hash)
          address = sender_details[:address]
          post[:payment_method_options][:card][:sender_details][:address] = {}
          post[:payment_method_options][:card][:sender_details][:address][:country] = address[:country] if address[:country]
          post[:payment_method_options][:card][:sender_details][:address][:line1] = address[:line1] if address[:line1]
          post[:payment_method_options][:card][:sender_details][:address][:line2] = address[:line2] if address[:line2]
          post[:payment_method_options][:card][:sender_details][:address][:postal_code] = address[:postal_code] if address[:postal_code]
          post[:payment_method_options][:card][:sender_details][:address][:state] = address[:state] if address[:state]
          post[:payment_method_options][:card][:sender_details][:address][:city] = address[:city] if address[:city]
        end

        if sender_details[:dob].is_a?(Hash)
          dob = sender_details[:dob]
          post[:payment_method_options][:card][:sender_details][:dob] = {}
          post[:payment_method_options][:card][:sender_details][:dob][:day] = dob[:day] if dob[:day]
          post[:payment_method_options][:card][:sender_details][:dob][:month] = dob[:month] if dob[:month]
          post[:payment_method_options][:card][:sender_details][:dob][:year] = dob[:year] if dob[:year]
        end
      end

      def add_return_url(post, options)
        return unless options[:confirm]

        post[:confirm] = options[:confirm]
        post[:return_url] = options[:return_url] if options[:return_url]
      end

      def add_payment_method_token(post, payment_method, options, responses = [])
        case payment_method
        when String
          extract_token_from_string_and_maybe_add_customer_id(post, payment_method)
        when ActiveMerchant::Billing::CreditCard
          return create_payment_method_and_extract_token(post, payment_method, options, responses) if options[:verify]

          get_payment_method_data_from_card(post, payment_method, options, responses)
        when ActiveMerchant::Billing::NetworkTokenizationCreditCard
          get_payment_method_data_from_card(post, payment_method, options, responses)
        end
      end

      def add_network_token_data(post_data, payment_method, options)
        return unless adding_network_token_card_data?(payment_method)

        post_data[:card] ||= {}
        post_data[:card][:last4] = options[:last_4] || payment_method.number[-4..]
        post_data[:card][:network_token] = {}
        post_data[:card][:network_token][:number] = payment_method.number
        post_data[:card][:network_token][:exp_month] = payment_method.month
        post_data[:card][:network_token][:exp_year] = payment_method.year
        post_data[:card][:network_token][:payment_account_reference] = options[:payment_account_reference] if options[:payment_account_reference]

        post_data
      end

      def add_network_token_info(post, payment_method, options)
        # wallet_type is only passed for non-tokenized GooglePay which acts as a CreditCard
        if options[:wallet_type]
          post[:metadata] ||= {}
          post[:metadata][:input_method] = 'GooglePay'
        end

        return unless payment_method.is_a?(NetworkTokenizationCreditCard) && options.dig(:stored_credential, :initiator) != 'merchant'
        return if digital_wallet_payment_method?(payment_method) && options[:new_ap_gp_route] != true

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:network_token] ||= {}
        post[:payment_method_options][:card][:network_token].merge!({
          cryptogram: payment_method.respond_to?(:payment_cryptogram) ? payment_method.payment_cryptogram : options[:cryptogram],
          electronic_commerce_indicator: format_eci(payment_method, options)
        }.compact)
      end

      def add_digital_wallet(post, payment_method, options)
        post[:payment_method_data] = {
          type: 'card',
          card: {
            last4: options[:last_4] || payment_method.number[-4..],
            exp_month: payment_method.month,
            exp_year: payment_method.year,
            network_token: {
              number: payment_method.number,
              exp_month: payment_method.month,
              exp_year: payment_method.year,
              tokenization_method: DIGITAL_WALLETS[payment_method.source]
            }
          }
        }
      end

      def format_eci(payment_method, options)
        eci_value = payment_method.respond_to?(:eci) ? payment_method.eci : options[:eci]

        if eci_value&.length == 1
          "0#{eci_value}"
        else
          eci_value
        end
      end

      def extract_token_from_string_and_maybe_add_customer_id(post, payment_method)
        if payment_method.include?('|')
          customer_id, payment_method = payment_method.split('|')
          post[:customer] = customer_id
        end

        if payment_method.include?('tok_')
          add_payment_method_card_data_token(post, payment_method)
        else
          post[:payment_method] = payment_method
        end
      end

      def tokenize_apple_google(payment, options = {})
        tokenization_method = payment.source == :google_pay ? :android_pay : payment.source
        post = {
          card: {
            number: payment.number,
            exp_month: payment.month,
            exp_year: payment.year,
            tokenization_method:,
            eci: payment.eci,
            cryptogram: payment.payment_cryptogram
          }
        }
        add_billing_address_for_card_tokenization(post, options) if %i(apple_pay android_pay).include?(tokenization_method)
        token_response = api_request(:post, 'tokens', post, options)
        success = token_response['error'].nil?
        if success && token_response['id']
          Response.new(success, nil, token: token_response)
        elsif token_response['error']['message']
          Response.new(false, "The tokenization process fails. #{token_response['error']['message']}")
        else
          Response.new(false, "The tokenization process fails. #{token_response}")
        end
      end

      def get_payment_method_data_from_card(post, payment_method, options, responses)
        return create_payment_method_and_extract_token(post, payment_method, options, responses) unless off_session_request?(options) || adding_network_token_card_data?(payment_method)

        post[:payment_method_data] = add_payment_method_data(payment_method, options)
      end

      def create_payment_method_and_extract_token(post, payment_method, options, responses)
        payment_method_response = create_payment_method(payment_method, options)
        return payment_method_response if payment_method_response.failure?

        add_card_3d_secure_usage_supported(payment_method_response)

        responses << payment_method_response
        add_payment_method_token(post, payment_method_response.params['id'], options)
      end

      def add_payment_method_types(post, options)
        payment_method_types = options[:payment_method_types] if options[:payment_method_types]
        return if payment_method_types.nil?

        post[:payment_method_types] = Array(payment_method_types)
      end

      def add_exemption(post, options = {})
        return unless options[:confirm] && options[:moto]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:moto] = true if options[:moto]
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

        card_options = post[:payment_method_options][:card]
        card_options[:mit_exemption] = {}

        # Stripe PI accepts network_transaction_id and ds_transaction_id via mit field under card.
        # The network_transaction_id can be sent in nested under stored credentials OR as its own field (add_ntid handles when it is sent in on its own)
        # If it is sent is as its own field AND under stored credentials, the value sent under its own field is what will send.
        card_options[:mit_exemption][:ds_transaction_id] = stored_credential[:ds_transaction_id] if stored_credential[:ds_transaction_id]
        card_options[:mit_exemption][:network_transaction_id] = stored_credential[:network_transaction_id] if !(options[:setup_future_usage] == 'off_session') && (stored_credential[:network_transaction_id])

        add_stored_credential_transaction_type(post, options)
      end

      def add_stored_credential_transaction_type(post, options = {})
        return unless options[:stored_credential_transaction_type]

        stored_credential = options[:stored_credential]
        # Do not add anything unless these are present.
        return unless stored_credential[:reason_type] && stored_credential[:initiator]

        # Not compatible with off_session parameter.
        options.delete(:off_session)

        stored_credential_type = if stored_credential[:initial_transaction]
                                   return unless stored_credential[:initiator] == 'cardholder'

                                   initial_transaction_stored_credential(post, stored_credential)
                                 else
                                   subsequent_transaction_stored_credential(post, stored_credential)
                                 end

        card_options = post[:payment_method_options][:card]
        card_options[:stored_credential_transaction_type] = stored_credential_type
        card_options[:mit_exemption].delete(:network_transaction_id) if %w(setup_on_session stored_on_session).include?(stored_credential_type)
      end

      def initial_transaction_stored_credential(post, stored_credential)
        case stored_credential[:reason_type]
        when 'unscheduled'
          # Charge on-session and store card for future one-off payment use
          'setup_off_session_unscheduled'
        when 'recurring'
          # Charge on-session and store card for future recurring payment use
          'setup_off_session_recurring'
        else
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
        return unless options[:network_transaction_id]

        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:mit_exemption] = {}

        post[:payment_method_options][:card][:mit_exemption][:network_transaction_id] = options[:network_transaction_id]
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

      def add_billing_address_for_card_tokenization(post, options = {})
        return unless (billing = options[:billing_address] || options[:address])

        billing = add_address(billing, options)
        billing[:address].transform_keys! { |k| k == :postal_code ? :address_zip : k.to_s.prepend('address_').to_sym }

        post[:card][:name] = billing[:name]
        post[:card].merge!(billing[:address])
      end

      def add_error_on_requires_action(post, options = {})
        return unless options[:confirm]

        post[:error_on_requires_action] = true if options[:error_on_requires_action]
      end

      def request_three_d_secure(post, options = {})
        return unless options[:request_three_d_secure] && %w(any automatic challenge).include?(options[:request_three_d_secure])

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

      def add_billing_address(post, payment_method, options = {})
        return if payment_method.nil? || payment_method.is_a?(String)

        post[:payment_method_data] ||= {}
        if billing = options[:billing_address] || options[:address]
          post[:payment_method_data][:billing_details] = add_address(billing, options)
        end

        unless post[:payment_method_data][:billing_details]
          name = [payment_method.first_name, payment_method.last_name].compact.join(' ')
          post[:payment_method_data][:billing_details] = { name: }
        end
      end

      def add_shipping_address(post, options = {})
        return unless shipping = options[:shipping_address]

        post[:shipping] = add_address(shipping, options).except(:email)
        post[:shipping][:carrier] = (shipping[:carrier] || options[:shipping_carrier]) if shipping[:carrier] || options[:shipping_carrier]
        post[:shipping][:tracking_number] = (shipping[:tracking_number] || options[:shipping_tracking_number]) if shipping[:tracking_number] || options[:shipping_tracking_number]
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

      def add_name_only(post, payment_method)
        post[:billing_details] = {} unless post[:billing_details]

        name = [payment_method.first_name, payment_method.last_name].compact.join(' ')
        post[:billing_details][:name] = name
      end

      # This surfaces the three_d_secure_usage.supported field and saves it as an instance variable so that we can access it later on in the response
      def add_card_3d_secure_usage_supported(response)
        return unless response.params['card'] && response.params['card']['three_d_secure_usage']

        @card_3d_supported = response.params['card']['three_d_secure_usage']['supported']
      end

      def format_idempotency_key(options, suffix)
        return options unless options[:idempotency_key]

        options.merge(idempotency_key: "#{options[:idempotency_key]}-#{suffix}")
      end

      def success_from(response, options)
        if response['status'] == 'requires_action' && !options[:execute_threed]
          response['error'] = {}
          response['error']['message'] = 'Received unexpected 3DS authentication response, but a 3DS initiation flag was not included in the request.'
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
