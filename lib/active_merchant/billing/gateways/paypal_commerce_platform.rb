# frozen_string_literal: true

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # The PaypalCommercePlatformGateway uses v2 APIs of the PayPal RESTful services except for getting the access token
    # and for billing agreements, in which case v1 of the API is used.
    # The supported flows include:
    # 1. PayPal Checkout (Direct Merchants and PayPal Commerce Platform)
    # 2. Advanced Card Payments
    # 3. PayPal Billing Agreements
    #
    # A separate create_order method has been created that enables the caller to manually approve the order
    # before going on to capture or authorize the order. A manual approval of the order is not required if a
    # credit card is provided as a payment source.
    class PaypalCommercePlatformGateway < Gateway
      self.supported_countries = %w[AU AT BE BG CA CY CZ DK EE FI FR GR HU IT LV LI LT LU MT NL NO PL PT RO SK SI ES SE US GB]
      self.homepage_url        = 'https://www.paypal.com/us/business/platforms-and-marketplaces'
      self.display_name        = 'PayPal Commerce Platform'
      self.default_currency    = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover jcb]
      # Paypal URL's
      URLS = {
        test_url: 'https://api.sandbox.paypal.com',
          live_url: 'https://api.paypal.com'
      }.freeze

      # Constants
      ALLOWED_INTENT              = %w[CAPTURE AUTHORIZE].freeze
      ALLOWED_ITEM_CATEGORY       = %w[DIGITAL_GOODS PHYSICAL_GOODS].freeze
      ALLOWED_DISBURSEMENT_MODE   = %w[INSTANT DELAYED].freeze
      ALLOWED_LANDING_PAGE        = %w[LOGIN BILLING NO_PREFERENCE].freeze
      ALLOWED_SHIPPING_PREFERENCE = %w[NO_SHIPPING GET_FROM_FILE SET_PROVIDED_ADDRESS].freeze
      ALLOWED_USER_ACTION         = %w[CONTINUE PAY_NOW].freeze
      ALLOWED_PAYEE_PREFERRED     = %w[UNRESTRICTED IMMEDIATE_PAYMENT_REQUIRED].freeze
      ALLOWED_STANDARD_ENTRIES    = %w[TEL WEB CCD PPD].freeze
      ALLOWED_PAYMENT_INITIATOR   = %w[CUSTOMER MERCHANT].freeze
      ALLOWED_PAYMENT_TYPE        = %w[ONE_TIME RECURRING UNSCHEDULED].freeze
      ALLOWED_USAGE               = %w[FIRST SUBSEQUENT DERIVED].freeze
      ALLOWED_NETWORK             = %w[VISA MASTERCARD DISCOVER AMEX SOLO JCB STAR DELTA SWITCH MAESTRO CB_NATIONALE CONFIGOGA CONFIDIS ELECTRON CETELEM CHINA_UNION_PAY].freeze
      ALLOWED_PHONE_TYPE          = %w[FAX HOME MOBILE OTHER PAGER].freeze
      ALLOWED_TAX_TYPE            = %w[BR_CPF BR_CNPJ].freeze
      ALLOWED_OP_PATCH            = %w[add remove replace move copy test].freeze
      ALLOWED_TOKEN_TYPE          = %w[BILLING_AGREEMENT].freeze
      ALLOWED_PAYMENT_METHOD      = %w[PAYPAL].freeze
      ALLOWED_PLAN_TYPE           = %w[MERCHANT_INITIATED_BILLING MERCHANT_INITIATED_BILLING_SINGLE_AGREEMENT CHANNEL_INITIATED_BILLING CHANNEL_INITIATED_BILLING_SINGLE_AGREEMENT RECURRING_PAYMENTS PRE_APPROVED_PAYMENTS].freeze
      ALLOWED_ACCEPT_PAYMENT_TYPE = %w[INSTANT ECHECK ANY].freeze
      ALLOWED_EXTERNAL_FUNDING    = %w[CREDIT PAY_UPON_INVOICE].freeze

      # Initialize the attributes
      def initialize(options = {})
        super
      end

      # Fetches bearer token from server by using provided credentials
      def get_access_token(options)
        requires!(options[:authorization], :username, :password)
        options = prepare_request_to_get_access_token(options)
        commit(:post, 'v1/oauth2/token?grant_type=client_credentials', {}, options[:headers])
      end

      # Purchase method only for the case a credit card is provided as payment source.
      # Creates the order and captures it.
      def purchase(options)
        requires!(options, :payment_source)
        response = create_order('CAPTURE', options)
        order_id = response.params['id']
        capture(order_id, options)
      end

      # Creates an order with the intent type(CAPTURE / AUTHORIZE) which is being passed in +intent+ parameter.
      # In case of non CC order, a manual approval step will need to be performed using the returned approval link
      def create_order(intent, options)
        requires!(options.merge!(intent.nil? ? {} : { intent: intent }), :intent, :purchase_units)

        post = {}
        add_intent(intent, post)
        add_purchase_units(options[:purchase_units], post)
        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].blank?
        add_application_context(options[:application_context], post) unless options[:application_context].blank?
        add_order_payer(options[:payer], post) unless options[:payer].blank?

        commit(:post, 'v2/checkout/orders', post, options[:headers])
      end

      # Fetches order details for the provided order id
      def get_order_details(order_id, options)
        requires!(options.merge(order_id: order_id), :order_id)
        commit(:get, "v2/checkout/orders/#{order_id}", nil, options[:headers])
      end

      # Updates the order details for the provided path in the options
      def update_order(order_id, options)
        requires!(options.merge!(order_id.nil? ? {} : { order_id: order_id }), :order_id, :body)

        post = []
        options[:body].each do |update|
          requires!(update, :op, :path, :value)

          update_hsh = {}
          update_hsh[:op]    = update[:op] if ALLOWED_OP_PATCH.include?(update[:op])
          update_hsh[:path]  = update[:path]
          update_hsh[:from]  = update[:from] unless update[:from].nil?

          type = get_update_type(update_hsh[:path])
          case type
          when 'amount'
            add_amount(update[:value], update_hsh, :value)
          when 'custom_id', 'description', 'soft_descriptor', 'invoice_id', 'intent', 'email_address'
            add_single_value(update[:value], update_hsh, :value)
          when 'name'
            add_name(update[:value], update_hsh, :value)
          when 'address'
            add_shipping_address(update[:value], update_hsh, :value)
          when 'payment_instruction'
            add_payment_instruction(update[:value], update_hsh, :value)
          else
            update_hsh[:value] = add_purchase_unit(update[:value])
          end
          post.append(update_hsh)
        end

        commit(:patch, "v2/checkout/orders/#{order_id}", post, options[:headers])
      end

      # Authorizes an order with provided order id. If a CC is not used as the payment source, then the order
      # must be approved before calling this method.
      def authorize(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = {}
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        add_application_context(options[:application_context], post) unless options[:application_context].nil?

        commit(:post, "v2/checkout/orders/#{order_id}/authorize", post, options[:headers])
      end

      # Captures the amount from payer for the associated authorization request.
      def capture_authorization(authorization_id, options)
        requires!(options.merge!({ authorization_id: authorization_id }), :authorization_id)

        post = {}
        add_amount(options[:amount], post) unless options[:amount].nil?
        add_invoice(options[:invoice_id], post) unless options[:invoice_id].nil?
        add_final_capture(options[:final_capture], post) unless options[:final_capture].nil?
        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].nil?
        add_note(options[:note_to_payer], post) unless options[:note_to_payer].nil?

        commit(:post, "v2/payments/authorizations/#{authorization_id}/capture", post, options[:headers])
      end

      # Fetches authorization details for the provided authorization id
      def get_authorization_details(authorization_id, options)
        requires!(options.merge(authorization_id: authorization_id), :authorization_id)
        commit(:get, "v2/payments/authorizations/#{authorization_id}", nil, options[:headers])
      end

      # Captures an order for the provided order_id. If a CC is not used as the payment source, then the order
      # must be approved before calling this method.
      def capture(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = {}
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        add_application_context(options[:application_context], post) unless options[:application_context].nil?

        commit(:post, "v2/checkout/orders/#{order_id}/capture", post, options[:headers])
      end

      # Fetches capture details for the provided capture id
      def get_capture_details(capture_id, options)
        requires!(options.merge(capture_id: capture_id), :capture_id)
        commit(:get, "v2/payments/captures/#{capture_id}", nil, options[:headers])
      end

      # Refunds the amount to payer for the associated capture id
      def refund(capture_id, options = {})
        requires!({ capture_id: capture_id }, :capture_id)

        post = {}
        add_amount(options[:amount], post) unless options[:amount].nil?
        add_invoice(options[:invoice_id], post) unless options[:invoice_id].nil?
        add_note(options[:note_to_payer], post) unless options[:note_to_payer].nil?

        commit(:post, "v2/payments/captures/#{capture_id}/refund", post, options[:headers])
      end

      # Fetches refund details for the provided refund id
      def get_refund_details(refund_id, options)
        requires!(options.merge(refund_id: refund_id), :refund_id)
        commit(:get, "v2/payments/refunds/#{refund_id}", nil, options[:headers])
      end

      # Cancels the authorization operation performed for the associated authorization id
      def void(authorization_id, options)
        requires!({ authorization_id: authorization_id }, :authorization_id)
        post = {}
        commit(:post, "v2/payments/authorizations/#{authorization_id}/void", post, options[:headers])
      end

      # Creates the billing agreement token for the provided details in the options
      def create_billing_agreement_token(options)
        requires!(options, :payer, :plan)
        post = {}
        prepare_request_to_get_agreement_tokens(post, options)
        commit(:post, 'v1/billing-agreements/agreement-tokens', post, options[:headers])
      end

      # Fetches billing details for the created billing token
      def get_billing_agreement_token_details(billing_agreement_token, options)
        requires!(options.merge(billing_agreement_token: billing_agreement_token), :billing_agreement_token)
        commit(:get, "v1/billing-agreements/agreement-tokens/#{billing_agreement_token}", nil, options[:headers])
      end

      # Creates the billing agreement id for the approved billing token
      def create_billing_agreement(options)
        requires!(options, :token_id)
        post = { token_id: options[:token_id] }
        commit(:post, 'v1/billing-agreements/agreements', post, options[:headers])
      end

      # Fetches agreement details for the associated billing agreement id
      def get_billing_agreement_details(billing_token, options)
        requires!(options.merge(billing_token: billing_token), :billing_token)
        commit(:get, "v1/billing-agreements/agreements/#{billing_token}", nil, options[:headers])
      end

      # Updates the billing agreement details
      def update_billing_agreement(agreement_id, options)
        requires!(options.merge({ agreement_id: agreement_id }), :agreement_id, :body)
        post = {}
        post = add_update_basic_billing_attributes(post, options)
        commit(:patch, "v1/billing-agreements/agreements/#{agreement_id}", post, options[:headers])
      end

      # Cancels the billing agreement plan for the associated agreement
      def cancel_billing_agreement(agreement_id, options)
        post = {}
        post[:note] = options[:note] unless options[:note].nil?
        commit(:post, "v1/billing-agreements/agreements/#{agreement_id}/cancel", post, options[:headers])
      end

      # Indicates scrubbing support
      def supports_scrubbing?
        true
      end

      # Method to filter the sensitive data.
      def scrub(transcript)
        transcript.
          gsub(/(Authorization: Bearer )\w+-\w+/, '\1[FILTERED]').
          gsub(/(Authorization: Basic )\w+=/, '\1[FILTERED]').
          gsub(/(payment_source\[card\]\[security_code\]=)\d+/, '\1[FILTERED]').
          gsub(/(payment_source\[card\]\[number\]=)\d+/, '\1[FILTERED]').
          gsub(/(payment_source\[card\]\[expiry\]=)\d+-\d+/, '\1[FILTERED]')
      end

      private

      def add_purchase_units(options, post)
        post[:purchase_units] = []
        options.map do |purchase_unit|
          post[:purchase_units] << add_purchase_unit(purchase_unit)
        end
        post
      end

      def add_purchase_unit(purchase_unit)
        requires!(purchase_unit, :amount)
        purchase_unit_hsh = {}
        purchase_unit_hsh[:reference_id]    = purchase_unit[:reference_id] unless purchase_unit[:reference_id].nil?
        purchase_unit_hsh[:description]     = purchase_unit[:description] unless purchase_unit[:description].nil?
        purchase_unit_hsh[:shipping_method] = purchase_unit[:shipping_method] unless purchase_unit[:shipping_method].nil?
        purchase_unit_hsh[:payment_group_id] = purchase_unit[:payment_group_id] unless purchase_unit[:payment_group_id].nil?
        purchase_unit_hsh[:custom_id]       = purchase_unit[:custom_id] unless purchase_unit[:custom_id].nil?
        purchase_unit_hsh[:invoice_id]      = purchase_unit[:invoice_id] unless purchase_unit[:invoice_id].nil?
        purchase_unit_hsh[:soft_descriptor] = purchase_unit[:soft_descriptor] unless purchase_unit[:soft_descriptor].nil?

        add_amount(purchase_unit[:amount], purchase_unit_hsh)
        add_payee(purchase_unit[:payee], purchase_unit_hsh) unless purchase_unit[:payee].nil?
        add_items(purchase_unit[:items], purchase_unit_hsh) unless purchase_unit[:items].nil?
        add_shipping(purchase_unit[:shipping], purchase_unit_hsh) unless purchase_unit[:shipping].nil?
        add_payment_instruction(purchase_unit[:payment_instruction], purchase_unit_hsh) unless purchase_unit[:payment_instruction].blank?
        purchase_unit_hsh
      end

      def add_application_context(options, post)
        post[:application_context] = {}
        post[:application_context][:return_url] = options[:return_url] unless options[:return_url].nil?
        post[:application_context][:cancel_url] = options[:cancel_url] unless options[:cancel_url].nil?
        post[:application_context][:landing_page] = options[:landing_page] unless options[:landing_page].nil? || !ALLOWED_LANDING_PAGE.include?(options[:landing_page])
        post[:application_context][:locale] = options[:locale] unless options[:locale].nil?
        post[:application_context][:user_action] = options[:user_action] unless options[:user_action].nil? || !ALLOWED_USER_ACTION.include?(options[:user_action])
        post[:application_context][:brand_name] = options[:brand_name] unless options[:brand_name].nil?
        post[:application_context][:shipping_preference] = options[:shipping_preference] unless options[:shipping_preference].nil? || !ALLOWED_SHIPPING_PREFERENCE.include?(options[:shipping_preference])

        add_payment_method(options[:payment_method], post) unless options[:payment_method].nil?
        add_stored_payment_source(options[:stored_payment_source], post) unless options[:stored_payment_source].nil?
        skip_empty(post, :application_context)
      end

      def add_stored_payment_source(options, post)
        requires!(options, :payment_initiator, :payment_type)
        post[:stored_payment_source] = {}
        post[:stored_payment_source][:payment_initiator] = options[:payment_initiator] if ALLOWED_PAYMENT_INITIATOR.include?(options[:payment_initiator])
        post[:stored_payment_source][:payment_type]      = options[:payment_type] if ALLOWED_PAYMENT_TYPE.include?(options[:payment_type])
        post[:stored_payment_source][:usage] = options[:usage] if ALLOWED_USAGE.include?(options[:usage])
        add_network_transaction_reference(options[:previous_network_transaction_reference], post)
        skip_empty(post, :stored_payment_source)
      end

      def add_network_transaction_reference(options, post)
        requires!(options, :id, :network)
        post[:previous_network_transaction_reference] = {}
        post[:previous_network_transaction_reference][:id]      = options[:id]
        post[:previous_network_transaction_reference][:date]    = options[:date]
        post[:previous_network_transaction_reference][:network] = options[:network] if ALLOWED_NETWORK.include?(options[:network])
        post
      end

      def add_payment_method(options, post)
        post[:payment_method] = {}
        post[:payment_method][:payer_selected] = options[:payer_selected]
        post[:payment_method][:payee_preferred]           = options[:payee_preferred] if ALLOWED_PAYEE_PREFERRED.include?(options[:payee_preferred])
        post[:payment_method][:standard_entry_class_code] = options[:standard_entry_class_code] if ALLOWED_STANDARD_ENTRIES.include?(options[:standard_entry_class_code])
        skip_empty(post, :payment_method)
      end

      def add_payment_instruction(options, post, key = :payment_instruction)
        post[key]                     = {}
        post[key][:platform_fees]     = []
        post[key][:disbursement_mode] = options[:disbursement_mode] unless options[:disbursement_mode].nil? || !ALLOWED_DISBURSEMENT_MODE.include(options[:disbursement_mode])

        options[:platform_fees].map do |platform_fee|
          requires!(platform_fee, :amount, :payee)
          platform_fee_hsh = {}
          add_amount(platform_fee[:amount], platform_fee_hsh)
          add_payee(platform_fee[:payee], platform_fee_hsh)
          post[key][:platform_fees] << platform_fee_hsh
        end
        skip_empty(post, key)
      end

      def add_intent(intent, post)
        post[:intent] = intent if ALLOWED_INTENT.include?(intent)
        post
      end

      def add_payee(payee_obj, obj_hsh)
        obj_hsh[:payee] = {}
        obj_hsh[:payee][:merchant_id]   = payee_obj[:merchant_id] unless payee_obj[:merchant_id].nil?
        obj_hsh[:payee][:email_address] = payee_obj[:email_address] unless payee_obj[:email_address].nil?
        skip_empty(obj_hsh, :payee)
      end

      def add_amount(amount, post, key = :amount)
        requires!(amount, :currency_code, :value)

        post[key] = {}
        post[key][:currency_code] = amount[:currency_code] || currency(amount[:value])
        post[key][:value]         = amount[:value]

        add_breakdown_for_amount(amount[:breakdown], post, key) unless amount[:breakdown].blank?
        post
      end

      def add_single_value(value, post, key = :value)
        post[key] = value
        post
      end

      def add_breakdown_for_amount(options, post, key)
        post[key][:breakdown] = {}
        options.each do |item, _|
          add_amount(options[item], post[key][:breakdown], item)
        end
        skip_empty(post[key], :breakdown)
      end

      def add_items(options, post)
        post[:items] = []

        options.each do |item|
          requires!(item, :name, :quantity, :unit_amount)

          items_hsh = {}
          items_hsh[:name]        = item[:name]
          items_hsh[:sku]         = item[:sku] unless item[:sku].nil?
          items_hsh[:quantity]    = item[:quantity]
          items_hsh[:description] = item[:description]
          items_hsh[:category] = item[:category] unless item[:category].nil? || !ALLOWED_ITEM_CATEGORY.include?(item[:category])

          add_amount(item[:unit_amount], items_hsh, :unit_amount)
          add_amount(item[:tax], items_hsh, :tax) unless item[:tax].nil?

          post[:items] << items_hsh
        end
        post
      end

      def add_shipping(options, post)
        post[:shipping]           = {}
        post[:shipping][:address] = {}
        add_name(options[:name], post[:shipping]) unless options[:name].nil?
        add_shipping_address(options[:address], post[:shipping]) unless options[:address].nil?
        skip_empty(post, :shipping)
      end

      def add_name(options, post, key = :name)
        post[key] = {}
        post[key][:full_name] = options[:full_name]
        skip_empty(post[key], :full_name)
      end

      def add_shipping_address(address, obj_hsh, key = :address)
        requires!(address, :admin_area_2, :postal_code, :country_code)

        obj_hsh[key] = {}
        obj_hsh[key][:address_line_1] = address[:address_line_1] unless address[:address_line_1].nil?
        obj_hsh[key][:address_line_2] = address[:address_line_2] unless address[:address_line_2].nil?
        obj_hsh[key][:admin_area_1]   = address[:admin_area_1] unless address[:admin_area_1].nil?
        obj_hsh[key][:admin_area_2]   = address[:admin_area_2]
        obj_hsh[key][:postal_code]    = address[:postal_code]
        obj_hsh[key][:country_code]   = address[:country_code]
        obj_hsh
      end

      def add_billing_address(address, obj_hsh)
        requires!(address, :country_code)

        obj_hsh[:billing_address] = {}
        obj_hsh[:billing_address][:address_line_1] = address[:address_line_1] unless address[:address_line_1].nil?
        obj_hsh[:billing_address][:admin_area_1]   = address[:admin_area_1] unless address[:admin_area_1].nil?
        obj_hsh[:billing_address][:admin_area_2]   = address[:admin_area_2] unless address[:admin_area_2].nil?
        obj_hsh[:billing_address][:postal_code]    = address[:postal_code] unless address[:postal_code].nil?
        obj_hsh[:billing_address][:country_code]   = address[:country_code] unless address[:country_code].nil?
        obj_hsh
      end

      def add_invoice(invoice_id, post)
        post[:invoice_id] = invoice_id
        post
      end

      def add_final_capture(final_capture, post)
        post[:final_capture] = final_capture
        post
      end

      def add_note(note, post)
        post[:note_to_payer] = note
        post
      end

      def add_payment_source(source, post)
        post[:payment_source] = {}
        add_customer_card(source[:card], post[:payment_source]) unless source[:card].nil?
        add_token(source[:token], post[:payment_source]) unless source[:token].nil?
        skip_empty(post, :payment_source)
      end

      def add_customer_card(card_details, post)
        requires!(card_details, :number, :expiry, :name, :security_code)

        post[:card] = {}
        post[:card][:name]          = card_details[:name]
        post[:card][:number]        = card_details[:number]
        post[:card][:expiry]        = card_details[:expiry]
        post[:card][:security_code] = card_details[:security_code]
        add_billing_address(card_details[:billing_address], post) unless card_details[:billing_address].nil?
        verify_card(post[:card])
        post
      end

      def verify_card(card)
        defaults = {
          number: card[:number],
            first_name: card[:name],
            last_name: card[:name],
            verification_value: card[:security_code],
            month: card[:expiry].split('-')[1].to_i,
            year: card[:expiry].split('-')[0].to_i
        }
        @visa_card = ActiveMerchant::Billing::CreditCard.new(defaults)
        raise "Invalid Credit Card Format. Message: Missing #{@visa_card.validate}" unless @visa_card.validate.empty?
      end

      def prepare_request_to_get_agreement_tokens(post, options)
        requires!(options, :payer, :plan)
        post[:description]            = options[:description] unless options[:description].nil?
        post[:merchant_custom_data]   = options[:merchant_custom_data] unless options[:merchant_custom_data].nil?
        add_payer(post, options[:payer])
        add_plan(post, options[:plan])
        add_billing_agreement_shipping_address(post, options[:shipping_address], :shipping_address) unless options[:shipping_address].nil?
        post
      end

      def add_payer(obj_hsh, payer)
        obj_hsh[:payer] = {}
        obj_hsh[:payer][:payment_method] = payer[:payment_method] if ALLOWED_PAYMENT_METHOD.include?(payer[:payment_method])
        add_billing_agreement_payer_info_details(options[:payer_info], post) unless options[:payer_info].nil?
        skip_empty(obj_hsh, :payer)
      end

      def add_plan(obj_hsh, options)
        requires!(options, :type)
        obj_hsh[:plan] = {}
        obj_hsh[:plan][:type] = options[:type] if ALLOWED_PLAN_TYPE.include?(options[:type])
        add_merchant_preferences(obj_hsh[:plan], options[:merchant_preferences])
        obj_hsh
      end

      def add_merchant_preferences(obj_hsh, options)
        requires!(options, :return_url, :cancel_url, :skip_shipping_address)
        obj_hsh[:merchant_preferences] = {}
        obj_hsh[:merchant_preferences][:return_url]                 = options[:return_url]
        obj_hsh[:merchant_preferences][:cancel_url]                 = options[:cancel_url]
        obj_hsh[:merchant_preferences][:accepted_pymt_type]         = options[:accepted_pymt_type] unless options[:accepted_pymt_type].nil? || !ALLOWED_ACCEPT_PAYMENT_TYPE.include?(options[:accepted_pymt_type])
        obj_hsh[:merchant_preferences][:skip_shipping_address] = options[:skip_shipping_address]
        obj_hsh[:merchant_preferences][:immutable_shipping_address] = options[:immutable_shipping_address] unless options[:immutable_shipping_address].nil?
        obj_hsh[:merchant_preferences][:experience_id]              = options[:experience_id] unless options[:experience_id].nil?
        obj_hsh[:merchant_preferences][:notify_url]                 = options[:notify_url] unless options[:notify_url].nil?
        obj_hsh[:merchant_preferences][:external_selected_funding_instrument_type] = options[:external_selected_funding_instrument_type] unless options[:external_selected_funding_instrument_type].nil? || !ALLOWED_EXTERNAL_FUNDING.include?(options[:external_selected_funding_instrument_type])

        add_accepted_legal_country_codes(options[:accepted_legal_country_codes], obj_hsh) unless options[:accepted_legal_country_codes].nil?
        obj_hsh
      end

      def add_billing_agreement_shipping_address(obj_hsh, address, key = :address)
        requires!(address, :line1, :postal_code, :country_code, :city, :state)

        obj_hsh[key] = {}
        obj_hsh[key][:line1]          = address[:line1]
        obj_hsh[key][:line2]          = address[:line2]
        obj_hsh[key][:city]           = address[:city]
        obj_hsh[key][:state]          = address[:state]
        obj_hsh[key][:postal_code]    = address[:postal_code]
        obj_hsh[key][:country_code]   = address[:country_code]
        obj_hsh[key][:recipient_name] = address[:recipient_name] unless address[:recipient_name].nil?
        obj_hsh
      end

      def add_token(options, post)
        requires!(options, :id, :type)
        post[:token] = {}
        post[:token][:id]   = options[:id]
        post[:token][:type] = options[:type] if ALLOWED_TOKEN_TYPE.include?(options[:type])
        post
      end

      def add_update_basic_billing_attributes(post, options)
        hsh_collection = []
        options[:body].map do |hsh_obj|
          requires!(hsh_obj, :op, :path, :value)
          post[:op]                           = hsh_obj[:op]
          post[:path]                         = hsh_obj[:path]
          post[:from]                         = hsh_obj[:from] unless hsh_obj[:from].nil?
          post[:value]                        = {}
          post[:value][:description]          = hsh_obj[:value][:description] unless hsh_obj[:value][:description].nil?
          post[:value][:merchant_custom_data] = hsh_obj[:value][:merchant_custom_data] unless hsh_obj[:value][:merchant_custom_data].nil?
          post[:value][:notify_url] = hsh_obj[:value][:notify_url] unless hsh_obj[:value][:notify_url].nil?
          hsh_collection << post
        end
        hsh_collection
      end

      def add_order_payer(options, post)
        post[:payer] = {}
        post[:payer][:email_address] = options[:email_address]
        post[:payer][:payer_id]      = options[:payer_id]
        post[:payer][:birth_date]    = options[:birth_date]

        add_payer_name(options[:name], post)
        add_phone_number(options[:phone], post)
        add_tax_info(options[:tax_info], post)
        add_address(options[:address], post)
      end

      def add_phone_number(options, post)
        post[:phone] = {}
        post[:phone][:phone_type]   = options[:phone_type] if ALLOWED_PHONE_TYPE.include?(options[:phone_type])
        post[:phone][:phone_number] = {}
        post[:phone][:phone_number][:national_number] = options[:phone_number][:national_number]
        post
      end

      def add_tax_info(options, post)
        post[:tax_info]               = {}
        post[:tax_info][:tax_id]      = options[:tax_id]
        post[:tax_info][:tax_id_type] = options[:tax_id_type] if ALLOWED_TAX_TYPE.include?(options[:tax_id_type])
        post
      end

      def add_address(options, post)
        post[:address] = {}
        post[:address][:address_line_1] = options[:address_line_1]
        post[:address][:address_line_2] = options[:address_line_2]
        post[:address][:admin_area_2]   = options[:admin_area_2]
        post[:address][:admin_area_1]   = options[:admin_area_1]
        post[:address][:postal_code]    = options[:postal_code]
        post[:address][:country_code]   = options[:country_code]
        post
      end

      def add_payer_name(options, post)
        post[:name] = {}
        post[:name][:given_name] = options[:given_name]
        post[:name][:surname]    = options[:surname]
        post
      end

      def add_billing_agreement_payer_info_details(options, post)
        post[:payer_info] = {}
        post[:payer_info][:email]      = options[:email]
        post[:payer_info][:suffix]     = options[:suffix]
        post[:payer_info][:first_name] = options[:first_name]
        post[:payer_info][:last_name]  = options[:last_name]
        post[:payer_info][:payer_id]   = options[:payer_id]
        post[:payer_info][:phone]      = options[:phone]

        add_billing_agreement_shipping_address(post, options[:billing_address], :billing_address)
        post
      end

      def add_accepted_legal_country_codes(options, post)
        post[:accepted_legal_country_codes] = []
        options[:country_code].each do |country_code|
          post[:accepted_legal_country_codes] << country_code
        end
        post
      end

      def base_url
        test? ? URLS[:test_url] : URLS[:live_url]
      end

      def commit(method, url, parameters = nil, options = {})
        response               = api_request(method, "#{base_url}/#{url}", parameters, options)
        response['webhook_id'] = options[:webhook_id] if options[:webhook_id]
        success                = success_from(response, options)

        Response.new(
          success,
          message_from(success, response),
          response
        )
      end

      def skip_empty(obj_hsh, key)
        obj_hsh.delete(key) if obj_hsh[key].empty?
      end

      # Prepare API request to hit remote endpoint \
      # to appropriate method(POST, GET, PUT, PATCH).
      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        parameters = parameters.nil? ? nil : parameters.to_json
        begin
          raw_response = ssl_request(method, endpoint, parameters, opt_headers)
          response     = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response     = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def headers(params)
        params[:headers]
      end

      def parse(raw_response)
        raw_response = raw_response.nil? || raw_response.empty? ? '{}' : raw_response
        JSON.parse(raw_response)
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def message_from(success, response)
        success ? 'Transaction Successfully Completed' : response['message']
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the PayPal API. '
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'error' => {
            'message' => msg
          }
        }
      end

      def success_from(response, _options)
        !response.key?('name') && response['debug_id'].nil?
      end

      def get_update_type(path)
        path.split('/').last
      end

      def prepare_request_to_get_access_token(options)
        basic_token = encoded_credentials(options[:authorization][:username], options[:authorization][:password])
        options[:headers] = { 'authorization' => "basic #{basic_token}" }
        options
      end

      def encoded_credentials(username, password)
        Base64.encode64("#{username}:#{password}").delete("\n")
      end

      def return_response(http, request)
        response = http.request(request)
        JSON.parse(response.body)['access_token']
      end
    end
  end
end
