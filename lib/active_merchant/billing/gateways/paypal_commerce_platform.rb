require 'active_merchant/billing/gateways/paypal_commerce_platform/paypal_commerce_platform_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCommercePlatformGateway < Gateway
      include PaypalCommercePlatformCommon

      self.supported_countries = ['US']
      self.homepage_url        = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name        = 'PayPal Commerce Platform Checkout'

      def create_order(intent, options)
        requires!(options.merge!(intent.nil? ? { } : { intent: intent}), :intent, :purchase_units)

        post = { }
        add_intent(intent, post)
        add_purchase_units(options[:purchase_units], post)
        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].blank?
        add_application_context(options[:application_context], post) unless options[:application_context].blank?
        add_order_payer(options[:payer], post) unless options[:payer].blank?

        commit(:post, "v2/checkout/orders", post, options[:headers])
      end

      def get_token(options)
        requires!(options[:authorization], :username, :password)
        prepare_request_for_get_access_token(options)
      end

      def authorize(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = { }
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        add_application_context(options[:application_context], post) unless options[:application_context].nil?

        commit(:post, "v2/checkout/orders/#{ order_id }/authorize", post, options[:headers])
      end

      def handle_approve(operator_required_id, options)
        requires!(options.merge({ operator_required_id: operator_required_id }), :operator_required_id, :operator)
        options[:operator] == "authorize" ? authorize(operator_required_id, options) : capture(operator_required_id, options)
      end

      def capture(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = { }
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        add_application_context(options[:application_context], post) unless options[:application_context].nil?

        commit(:post, "v2/checkout/orders/#{ order_id }/capture", post, options[:headers])
      end

      def refund(capture_id, options={ })
        requires!({ capture_id: capture_id }, :capture_id)

        post = { }
        add_amount(options[:amount], post) unless options[:amount].nil?
        add_invoice(options[:invoice_id], post) unless options[:invoice_id].nil?
        add_note(options[:note_to_payer], post) unless options[:note_to_payer].nil?

        commit(:post, "v2/payments/captures/#{ capture_id }/refund", post, options[:headers])
      end

      def void(authorization_id, options)
        requires!({ authorization_id: authorization_id }, :authorization_id)
        post = { }
        commit(:post, "v2/payments/authorizations/#{ authorization_id }/void", post, options[:headers])
      end

      def update_order(order_id, options)
        requires!(options.merge!(order_id.nil? ? { } : { order_id: order_id}), :order_id, :body)

        post = [ ]
        options[:body].each do |update|
          requires!(update, :op, :path, :value)

          update_hsh = { }
          update_hsh[:op]    = update[:op]
          update_hsh[:path]  = update[:path]

          type = get_update_type(update_hsh[:path])
          add_amount(update[:value], update_hsh, :value)           if type.eql?("amount")
          add_shipping_address(update[:value], update_hsh, :value) if type.eql?("address")
          add_payment_instruction(update[:value], update_hsh, :value) if type.eql?("payment_instruction")

          post.append(update_hsh)
        end

        commit(:patch, "v2/checkout/orders/#{ order_id }", post, options[:headers])
      end

      def do_capture(authorization_id, options)
        requires!(options.merge!({ authorization_id: authorization_id  }), :authorization_id)

        post = { }
        add_amount(options[:amount], post) unless options[:amount].nil?
        add_invoice(options[:invoice_id], post) unless options[:invoice_id].nil?
        add_final_capture(options[:final_capture], post) unless options[:final_capture].nil?
        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].nil?
        add_note(options[:note_to_payer], post) unless options[:note_to_payer].nil?

        commit(:post, "v2/payments/authorizations/#{ authorization_id }/capture", post, options[:headers])
      end

      def create_billing_agreement_token(options)
        requires!(options, :payer, :plan)

        post = { }
        prepare_request_to_get_agreement_tokens(post, options)
        commit(:post, "v1/billing-agreements/agreement-tokens", post, options[:headers])
      end

      def create_agreement_for_approval(options)
        requires!(options, :token_id)
        post = { token_id: options[:token_id] }
        commit(:post, "v1/billing-agreements/agreements", post, options[:headers])
      end

      def update_billing_agreement(agreement_id, options)
        requires!(options.merge({ agreement_id: agreement_id }), :agreement_id, :body)

        post = { }
        post = add_update_basic_billing_attributes(post, options)
        commit(:patch, "v1/billing-agreements/agreements/#{ agreement_id }", post, options[:headers])
      end

      def cancel_billing_agreement(agreement_id, options)
        post = { }
        post[:note] = options[:note] unless options[:note].nil?

        commit(:post, "v1/billing-agreements/agreements/#{ agreement_id }/cancel", post, options[:headers])
      end

      def get_order_details(order_id, options)
        requires!(options.merge(order_id: order_id), :order_id)
        commit(:get, "v2/checkout/orders/#{ order_id }", nil, options[:headers])
      end

      def get_authorization_details(authorization_id, options)
        requires!(options.merge(authorization_id: authorization_id), :authorization_id)
        commit(:get, "v2/checkout/orders/#{ authorization_id }", nil, options[:headers])
      end

      def get_capture_details(capture_id, options)
        requires!(options.merge(capture_id: capture_id), :capture_id)
        commit(:get, "v2/payments/captures/#{ capture_id }", nil, options[:headers])
      end

      def get_refund_details(refund_id, options)
        requires!(options.merge(refund_id: refund_id), :refund_id)
        commit(:get, "v2/payments/refunds/#{ refund_id }", nil, options[:headers])
      end

      private

      def add_purchase_units(options, post)
        post[:purchase_units] = []

        options.map do |purchase_unit|
          requires!(purchase_unit, :amount)

          purchase_unit_hsh = {  }
          purchase_unit_hsh[:reference_id]      = purchase_unit[:reference_id] unless purchase_unit[:reference_id].nil?
          purchase_unit_hsh[:description]       = purchase_unit[:description] unless purchase_unit[:description].nil?
          purchase_unit_hsh[:shipping_method]   = purchase_unit[:shipping_method] unless purchase_unit[:shipping_method].nil?
          purchase_unit_hsh[:payment_group_id]  = purchase_unit[:payment_group_id] unless purchase_unit[:payment_group_id].nil?
          purchase_unit_hsh[:custom_id]         = purchase_unit[:custom_id] unless purchase_unit[:custom_id].nil?
          purchase_unit_hsh[:invoice_id]        = purchase_unit[:invoice_id] unless purchase_unit[:invoice_id].nil?
          purchase_unit_hsh[:soft_descriptor]   = purchase_unit[:soft_descriptor] unless purchase_unit[:soft_descriptor].nil?

          add_amount(purchase_unit[:amount], purchase_unit_hsh)
          add_payee(purchase_unit[:payee], purchase_unit_hsh) unless purchase_unit[:payee].nil?
          add_items(purchase_unit[:items], purchase_unit_hsh) unless purchase_unit[:items].nil?
          add_shipping(purchase_unit[:shipping], purchase_unit_hsh) unless purchase_unit[:shipping].nil?
          add_payment_instruction(purchase_unit[:payment_instruction], purchase_unit_hsh) unless purchase_unit[:payment_instruction].blank?

          post[:purchase_units] << purchase_unit_hsh
        end

        post
      end

      def add_application_context(options, post)
        post[:application_context]                      = { }
        post[:application_context][:return_url]         = options[:return_url] unless options[:return_url].nil?
        post[:application_context][:cancel_url]         = options[:cancel_url] unless options[:cancel_url].nil?
        post[:application_context][:landing_page]       = options[:landing_page] unless options[:landing_page].nil?
        post[:application_context][:locale]       = options[:locale] unless options[:locale].nil?
        post[:application_context][:user_action]        = options[:user_action] unless options[:user_action].nil?
        post[:application_context][:brand_name]         = options[:brand_name] unless options[:brand_name].nil?
        post[:application_context][:shipping_preference]= options[:shipping_preference] unless options[:shipping_preference].nil?

        add_payment_method(options[:payment_method], post) unless options[:payment_method].nil?
        add_stored_payment_source(options[:stored_payment_source], post) unless options[:stored_payment_source].nil?

        skip_empty(post, :application_context)
      end

      def add_stored_payment_source(options, post)
        post[:stored_payment_source] = { }
        post[:stored_payment_source][:payment_initiator] = options[:payment_initiator]
        post[:stored_payment_source][:payment_type] = options[:payment_type]
        post[:stored_payment_source][:usage] = options[:usage]
        add_network_transaction_reference(options[:network_transaction_reference], post)
        skip_empty(post, :stored_payment_source)
      end

      def add_network_transaction_reference(options, post)
        post[:network_transaction_reference]           = { }
        post[:network_transaction_reference][:id]      = options[:id]
        post[:network_transaction_reference][:date]    = options[:date]
        post[:network_transaction_reference][:network] = options[:network]
      end

      def add_payment_method(options, post)
        post[:payment_method] = { }
        post[:payment_method][:payer_selected] = options[:payer_selected]
        post[:payment_method][:payee_preferred] = options[:payee_preferred]
        post[:payment_method][:standard_entry_class_code] = options[:standard_entry_class_code]
        skip_empty(post, :payment_method)
      end

      def add_payment_instruction(options, post, key=:payment_instruction)
        post[key]                     = { }
        post[key][:platform_fees]     = []
        post[key][:disbursement_mode] = options[:disbursement_mode] unless options[:disbursement_mode].nil?

        options[:platform_fees].map do |platform_fee|
          requires!(platform_fee, :amount, :payee)

          platform_fee_hsh = { }
          add_amount(platform_fee[:amount], platform_fee_hsh)
          add_payee(platform_fee[:payee], platform_fee_hsh)

          post[key][:platform_fees] << platform_fee_hsh
        end

        skip_empty(post, key)
      end

      def add_intent(intent, post)
        post[:intent]  = intent
        post
      end

      def add_payee(payee_obj, obj_hsh)
        obj_hsh[:payee] = { }
        obj_hsh[:payee][:merchant_id]         = payee_obj[:merchant_id] unless payee_obj[:merchant_id].nil?
        obj_hsh[:payee][:email_address]       = payee_obj[:email_address] unless payee_obj[:email_address].nil?

        skip_empty(obj_hsh, :payee)
      end

      def add_amount(amount, post, key=:amount)
        requires!(amount, :currency_code, :value)

        post[key]                 = { }
        post[key][:currency_code] = amount[:currency_code]
        post[key][:value]         = amount[:value]

        add_breakdown_for_amount(amount[:breakdown], post, key) unless amount[:breakdown].blank?

        post
      end

      def add_breakdown_for_amount(options, post, key)
        post[key][:breakdown] = { }
        options.each do |item, _|
            add_amount(options[item], post[key][:breakdown], item)
        end
        skip_empty(post[key], :breakdown)
      end

      def add_items(options, post)
        post[:items] = []

        options.each do |item|
          requires!(item, :name, :quantity, :unit_amount)

          items_hsh = { }

          items_hsh[:name]     = item[:name]
          items_hsh[:sku]      = item[:sku] unless item[:sku].nil?
          items_hsh[:quantity] = item[:quantity]
          items_hsh[:description] = item[:description]
          items_hsh[:category] = item[:category] unless item[:category].nil?

          add_amount(item[:unit_amount], items_hsh, :unit_amount)
          add_amount(item[:tax], items_hsh, :tax) unless item[:tax].nil?

          post[:items] << items_hsh
        end
        post
      end

      def add_shipping(options, post)
        post[:shipping]           = { }
        post[:shipping][:address] = { }
        add_shipping_address(options[:address], post[:shipping]) unless options[:address].nil?

        skip_empty(post, :shipping)
      end

      def add_shipping_address(address, obj_hsh, key = :address)
        requires!(address, :admin_area_2, :postal_code, :country_code )

        obj_hsh[key] = { }
        obj_hsh[key][:address_line_1] = address[:address_line_1] unless address[:address_line_1].nil?
        obj_hsh[key][:address_line_2] = address[:address_line_2] unless address[:address_line_2].nil?
        obj_hsh[key][:admin_area_1]   = address[:admin_area_1] unless address[:admin_area_1].nil?
        obj_hsh[key][:admin_area_2]   = address[:admin_area_2]
        obj_hsh[key][:postal_code]    = address[:postal_code]
        obj_hsh[key][:country_code]   = address[:country_code]

        obj_hsh
      end

      def add_billing_address(address, obj_hsh)
        requires!(address, :country_code )

        obj_hsh[:billing_address] = { }
        obj_hsh[:billing_address][:address_line_1] = address[:address_line_1] unless address[:address_line_1].nil?
        obj_hsh[:billing_address][:admin_area_1]   = address[:admin_area_1] unless address[:admin_area_1].nil?
        obj_hsh[:billing_address][:admin_area_2]   = address[:admin_area_2] unless address[:admin_area_2].nil?
        obj_hsh[:billing_address][:postal_code]    = address[:postal_code] unless address[:postal_code].nil?
        obj_hsh[:billing_address][:country_code]   = address[:country_code] unless address[:country_code].nil?

        obj_hsh
      end

      def add_invoice(invoice_id, post)
        post[:invoice_id]  = invoice_id
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
        post[:payment_source] = { }

        add_customer_card(source[:card], post[:payment_source]) unless source[:card].nil?
        add_token(source[:token], post[:payment_source]) unless source[:token].nil?

        skip_empty(post, :payment_source)
      end

      def add_customer_card(card_details, post)
        requires!(card_details, :number, :expiry)

        post[:card] = { }
        post[:card][:name]          = card_details[:name] unless card_details[:name].nil?
        post[:card][:number]        = card_details[:number]
        post[:card][:expiry]        = card_details[:expiry]
        post[:card][:security_code] = card_details[:security_code] unless card_details[:security_code].nil?

        add_billing_address(card_details[:billing_address], post) unless card_details[:billing_address].nil?
      end

      def prepare_request_to_get_agreement_tokens(post, options)
        post[:description]            = options[:description] unless options[:description].nil?
        add_payer(post, options[:payer])
        add_plan(post, options[:plan])
        add_billing_agreement_shipping_address(post, options[:shipping_address], key = :shipping_address) unless options[:shipping_address].nil?
        post
      end

      def add_payer(obj_hsh, payer)
        obj_hsh[:payer] = { }
        obj_hsh[:payer][:payment_method] = payer[:payment_method]
        skip_empty(obj_hsh, :payer)
      end

      def add_plan(obj_hsh, options)
        requires!(options, :type, :merchant_preferences)
        obj_hsh[:plan]                              = { }
        obj_hsh[:plan][:type]                       = options[:type]
        add_merchant_preferences(obj_hsh[:plan], options[:merchant_preferences])
        obj_hsh
      end

      def add_merchant_preferences(obj_hsh, options)
        requires!(options, :return_url, :cancel_url, :skip_shipping_address)
        obj_hsh[:merchant_preferences]       = { }
        obj_hsh[:merchant_preferences][:return_url]                 = options[:return_url]
        obj_hsh[:merchant_preferences][:cancel_url]                 = options[:cancel_url]
        obj_hsh[:merchant_preferences][:accepted_pymt_type]         = options[:accepted_pymt_type] unless options[:accepted_pymt_type].nil?
        obj_hsh[:merchant_preferences][:skip_shipping_address]      = options[:skip_shipping_address]
        obj_hsh[:merchant_preferences][:immutable_shipping_address] = options[:immutable_shipping_address] unless options[:immutable_shipping_address].nil?
        obj_hsh
      end

      def add_billing_agreement_shipping_address(obj_hsh, address, key = :address)
        requires!(address, :line1, :postal_code, :country_code, :city, :state )

        obj_hsh[key]                  = { }
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
        post[:token]            = { }
        post[:token][:id]       = options[:id]
        post[:token][:type]     = options[:type]
        post
      end

      def add_update_basic_billing_attributes(post, options)
        hsh_collection = []
        options[:body].map do | hsh_obj|
          requires!(hsh_obj, :op, :path, :value)
          post[:op]                           = hsh_obj[:op]
          post[:path]                         = hsh_obj[:path]
          post[:value]                        = { }
          post[:value][:description]          = hsh_obj[:value][:description] unless hsh_obj[:value][:description].nil?
          post[:value][:merchant_custom_data] = hsh_obj[:value][:merchant_custom_data] unless hsh_obj[:value][:merchant_custom_data].nil?
          hsh_collection << post
        end
        hsh_collection
      end
      def add_order_payer(options, post)
        post[:payer] = { }
        add_payer_name(options[:name], post)

        post[:payer][:email_address] = options[:email_address]
        post[:payer][:payer_id] = options[:payer_id]
        post[:payer][:birth_date] = options[:birth_date]

        add_phone_number(options[:phone], post)
        add_tax_info(options[:tax_info], post)
        add_address(options[:address], [:post])
      end
      def add_phone_number(options, post)
        post[:phone] = { }
        post[:phone][:phone_type] = options[:phone_type]
        post[:phone][:phone_number] = { }
        post[:phone][:phone_number][:national_number] = options[:phone_number][:national_number]

        post
      end
      def add_tax_info(options, post)
        post[:tax_info]               = { }
        post[:tax_info][:tax_id]      = options[:tax_id]
        post[:tax_info][:tax_id_type] = options[:tax_id_type]
        post
      end
      def add_address(options, post)
        post[:address] = { }
        post[:address][:address_line_1]   = options[:address_line_1]
        post[:address][:address_line_2]   = options[:address_line_2]
        post[:address][:admin_area_2]     = options[:admin_area_2]
        post[:address][:admin_area_1]     = options[:admin_area_1]
        post[:address][:postal_code]      = options[:postal_code]
        post[:address][:country_code]     = options[:country_code]

        post
      end
      def add_payer_name(options, post)
        post[:name]                 = { }
        post[:name][:given_name]    = options[:given_name]
        post[:name][:surname]       = options[:surname]

        post
      end
    end
  end
end
