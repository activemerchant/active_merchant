require 'active_merchant/billing/gateways/paypal/paypal_checkout_common'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCheckoutGateway < Gateway
      include PaypalCheckoutCommon
      
      self.supported_countries = ['AU', 'AT', 'BE', 'BG', 'CA', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'GR', 'HU', 'IT', 'LV', 'LI', 'LT', 'LU', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE', 'US', 'GB']
      self.homepage_url        = 'https://www.paypal.com/us/business/platforms-and-marketplaces'
      self.display_name        = 'PayPal Commerce Platform'
      self.default_currency    = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]

      def create_access_token()
        default_headers = {
            "Content-Type" => "application/x-www-form-urlencoded"
        }
        commit(:post, "v1/oauth2/token?grant_type=client_credentials", nil, default_headers)
      end

      def create_order(intent, options)
        requires!(options.merge!(intent.nil? ? {} : { intent: intent}), :intent, :purchase_units)

        post = {}
        add_intent(intent, post)
        add_purchase_units(options[:purchase_units], post)
        add_order_payer(options[:payer], post) unless options[:payer].blank?
        commit(:post, "v2/checkout/orders", post, options[:headers])
      end

      def authorize(order_id, options={})
        requires!({ order_id: order_id }, :order_id)

        post = {}
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        commit(:post, "v2/checkout/orders/#{ order_id }/authorize", post, options[:headers])
      end

      def capture(order_id, options={})
        requires!({ order_id: order_id }, :order_id)

        post = {}
        add_payment_source(options[:payment_source], post) unless options[:payment_source].nil?
        commit(:post, "v2/checkout/orders/#{ order_id }/capture", post, options[:headers])
      end

      def refund(capture_id, options={})
        requires!({ capture_id: capture_id }, :capture_id)

        post = {}
        add_amount(options[:amount], post) unless options[:amount].nil?
        post[:invoice_id]  = options[:invoice_id] unless options[:invoice_id].nil?
        post[:note_to_payer] = options[:note_to_payer] unless options[:note_to_payer].nil?
        commit(:post, "v2/payments/captures/#{ capture_id }/refund", post, options[:headers])
      end

      def void(authorization_id, options={})
        requires!({ authorization_id: authorization_id }, :authorization_id)
        post = {}
        commit(:post, "v2/payments/authorizations/#{ authorization_id }/void", post, options[:headers])
      end

      def do_capture(authorization_id, options={})
        requires!(options.merge!({ authorization_id: authorization_id  }), :authorization_id)

        post = {}
        add_amount(options[:amount], post) unless options[:amount].nil?
        post[:invoice_id]    = invoice_id unless options[:invoice_id].nil?
        post[:final_capture] = final_capture unless options[:final_capture].nil?
        post[:note_to_payer] = options[:note_to_payer] unless options[:note_to_payer].nil?

        commit(:post, "v2/payments/authorizations/#{ authorization_id }/capture", post, options[:headers])
      end

      def get_order_details(order_id, options={})
        requires!(options.merge(order_id: order_id), :order_id)
        commit(:get, "v2/checkout/orders/#{ order_id }", nil, options[:headers])
      end

      def get_authorization_details(authorization_id, options={})
        requires!(options.merge(authorization_id: authorization_id), :authorization_id)
        commit(:get, "v2/payments/authorizations/#{ authorization_id }", nil, options[:headers])
      end

      def get_capture_details(capture_id, options={})
        requires!(options.merge(capture_id: capture_id), :capture_id)
        commit(:get, "v2/payments/captures/#{ capture_id }", nil, options[:headers])
      end

      def get_refund_details(refund_id, options={})
        requires!(options.merge(refund_id: refund_id), :refund_id)
        commit(:get, "v2/payments/refunds/#{ refund_id }", nil, options[:headers])
      end

      private

      def add_purchase_units(options, post)
        post[:purchase_units] = []
        options.map do |purchase_unit|
          post[:purchase_units] << construct_purchase_unit(purchase_unit)
        end
        post
      end

      def construct_purchase_unit(purchase_unit)
        requires!(purchase_unit, :amount)
        purchase_unit_hsh = {}
        purchase_unit_hsh[:reference_id]    = purchase_unit[:reference_id] unless purchase_unit[:reference_id].nil?
        purchase_unit_hsh[:description]     = purchase_unit[:description] unless purchase_unit[:description].nil?
        purchase_unit_hsh[:shipping_method] = purchase_unit[:shipping_method] unless purchase_unit[:shipping_method].nil?
        purchase_unit_hsh[:payment_group_id]= purchase_unit[:payment_group_id] unless purchase_unit[:payment_group_id].nil?
        purchase_unit_hsh[:custom_id]       = purchase_unit[:custom_id] unless purchase_unit[:custom_id].nil?
        purchase_unit_hsh[:invoice_id]      = purchase_unit[:invoice_id] unless purchase_unit[:invoice_id].nil?
        purchase_unit_hsh[:soft_descriptor] = purchase_unit[:soft_descriptor] unless purchase_unit[:soft_descriptor].nil?

        add_amount(purchase_unit[:amount], purchase_unit_hsh)
        add_payee(purchase_unit[:payee], purchase_unit_hsh) unless purchase_unit[:payee].nil?
        add_items(purchase_unit[:items], purchase_unit_hsh) unless purchase_unit[:items].nil?
        add_shipping(purchase_unit[:shipping], purchase_unit_hsh) unless purchase_unit[:shipping].nil?
        purchase_unit_hsh
      end

      def add_intent(intent, post)
        post[:intent]  = intent if ALLOWED_INTENT.include?(intent)
        post
      end

      def add_payee(payee_obj, obj_hsh)
        obj_hsh[:payee] = {}
        obj_hsh[:payee][:merchant_id]   = payee_obj[:merchant_id] unless payee_obj[:merchant_id].nil?
        obj_hsh[:payee][:email_address] = payee_obj[:email_address] unless payee_obj[:email_address].nil?
        skip_empty(obj_hsh, :payee)
      end

      def add_amount(amount, post, key=:amount)
        requires!(amount, :currency_code, :value)

        post[key] = {}
        post[key][:currency_code] = amount[:currency_code] || currency(amount[:value])
        post[key][:value]         = localized_amount(amount[:value], post[key][:currency_code]).to_s

        add_breakdown_for_amount(amount[:breakdown], post, key) unless amount[:breakdown].blank?
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
          items_hsh[:category]    = item[:category] unless item[:category].nil? || !ALLOWED_ITEM_CATEGORY.include?(item[:category])

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

      def skip_empty(obj_hsh, key)
        obj_hsh.delete(key) if obj_hsh[key].empty?
      end

      def add_name(options, post, key=:name)
        post[key] = {}
        post[key][:full_name] = options[:full_name]
        skip_empty(post[key], :full_name)
      end

      def add_shipping_address(address, obj_hsh, key = :address)
        requires!(address, :admin_area_2, :postal_code, :country_code )

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
        requires!(address, :country_code )

        obj_hsh[:billing_address] = {}
        obj_hsh[:billing_address][:address_line_1] = address[:address_line_1] unless address[:address_line_1].nil?
        obj_hsh[:billing_address][:admin_area_1]   = address[:admin_area_1] unless address[:admin_area_1].nil?
        obj_hsh[:billing_address][:admin_area_2]   = address[:admin_area_2] unless address[:admin_area_2].nil?
        obj_hsh[:billing_address][:postal_code]    = address[:postal_code] unless address[:postal_code].nil?
        obj_hsh[:billing_address][:country_code]   = address[:country_code] unless address[:country_code].nil?
        obj_hsh
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
            month: card[:expiry].split("-")[1].to_i,
            year: card[:expiry].split("-")[0].to_i
        }
        @card_object = ActiveMerchant::Billing::CreditCard.new(defaults)
        raise "Invalid Credit Card Format. Message: Missing #{@card_object.validate}" unless @card_object.validate.empty?
      end

      def add_token(options, post)
        requires!(options, :id, :type)
        post[:token] = {}
        post[:token][:id]   = options[:id]
        post[:token][:type] = options[:type] if ALLOWED_TOKEN_TYPE.include?(options[:type])
        post
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
    end
  end
end
