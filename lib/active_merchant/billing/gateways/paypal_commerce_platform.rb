require 'active_merchant/billing/gateways/paypal/paypal_common_api'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCommercePlatformGateway < Gateway
      TEST_URL = 'https://api.sandbox.paypal.com'
      LIVE_URL = 'https://api.paypal.com'
      NON_STANDARD_LOCALE_CODES = {
          'DK' => 'da_DK',
          'IL' => 'he_IL',
          'ID' => 'id_ID',
          'JP' => 'jp_JP',
          'NO' => 'no_NO',
          'BR' => 'pt_BR',
          'RU' => 'ru_RU',
          'SE' => 'sv_SE',
          'TH' => 'th_TH',
          'TR' => 'tr_TR',
          'CN' => 'zh_CN',
          'HK' => 'zh_HK',
          'TW' => 'zh_TW'
      }
      self.supported_countries = ['US']
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PPCP Checkout'
      self.currencies_without_fractions = %w(HUF JPY TWD)

      def initialize(options = { })
        @base_url = TEST_URL
      end

      def create_order(intent, options)
        requires!(options.merge!(intent == nil ? { } : { intent: intent }), :intent, :purchase_units)

        post = { }
        add_intent(intent, post)

        add_purchase_units(options[:purchase_units], post)

        add_payment_instruction(options[:payment_instruction], post) unless options[:payment_instruction].blank?

        add_application_context(options[:application_context], post) unless options[:application_context].blank?

        commit(:post, "v2/checkout/orders", post, options[:headers])
      end

      def get_token(options)
        requires!(options[:authorization], :username, :password)

        prepare_request_to_get_access_token(options)
      end

      def authorize(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = { }

        commit(:post, "v2/checkout/orders/#{ order_id }/authorize", post, options[:headers])
      end

      def handle_approve(operator_required_id, options)
        requires!(options.merge({ operator_required_id: operator_required_id }), :operator_required_id, :operator)

        options[:operator] == "authorize" ? authorize(operator_required_id, options) : capture(operator_required_id, options)
      end

      def capture(order_id, options)
        requires!({ order_id: order_id }, :order_id)

        post = { }

        commit(:post, "v2/checkout/orders/#{ order_id }/capture", post, options[:headers])
      end

      def refund(capture_id, options={ })
        requires!({ capture_id: capture_id }, :capture_id)

        post = { }
        add_amount(options[:body][:amount], post) unless options[:body][:amount].nil?

        add_invoice(options[:body][:invoice_id], post) unless options[:body][:invoice_id].nil?

        add_note(options[:body][:note_to_payer], post) unless options[:body][:note_to_payer]

        commit(:post, "v2/payments/captures/#{ capture_id }/refund", post, options[:headers])
      end

      def void(authorization_id, options)
        requires!({ authorization_id: authorization_id }, :authorization_id)

        post = { }

        commit(:post, "v2/payments/authorizations/#{ authorization_id }/void", post, options[:headers])
      end

      def update_order(order_id, options)
        requires!(options.merge!({ order_id: order_id }), :order_id, :op, :path, :value)

        patch("v2/checkout/orders/#{ order_id }", options)
      end

      def disburse(options)
        requires!(options[:body], :reference_type, :reference_id)

        post("v1/payments/referenced-payouts-items", options)
      end

      def do_capture(authorization_id, options)
        requires!(options.merge!({ authorization_id: authorization_id  }), :authorization_id)

        post = {}
        add_amount(options[:body][:amount], post) unless options[:body][:amount].nil?

        add_invoice(options[:body][:invoice_id], post) unless options[:body][:invoice_id].nil?

        add_final_capture(options[:body][:final_capture], post) unless options[:body][:final_capture].nil?

        add_payment_instruction(options[:body][:payment_instruction], post) unless options[:body][:payment_instruction].nil?

        commit(:post, "v2/payments/authorizations/#{ authorization_id }/capture", post, options[:headers])
      end

      def get_order_details(order_id, options)
        requires!(options.merge(order_id: order_id), :order_id)

        commit(:get, "/v2/checkout/orders/#{ order_id }", nil, options[:headers])
      end

      def get_authorization_details(authorization_id, options)
        requires!(options.merge(authorization_id: authorization_id), :authorization_id)

        commit(:get, "/v2/checkout/orders/#{ authorization_id }", nil, options[:headers])
      end

      def get_capture_details(capture_id, options)
        requires!(options.merge(capture_id: capture_id), :capture_id)

        commit(:get, "/v2/payments/captures/#{ capture_id }", nil, options[:headers])
      end

      def get_refund_details(refund_id, options)
        requires!(options.merge(refund_id: refund_id), :refund_id)

        commit(:get, "/v2/payments/refunds/#{ refund_id }", nil, options[:headers])
      end

      # <-********************Private Methods**********************->
      private
      def add_purchase_units(options, post)
        post[:purchase_units] = []

        options.map do |purchase_unit|
          purchase_unit_hsh = {  }
          purchase_unit_hsh[:reference_id]              = purchase_unit[:reference_id]
          purchase_unit_hsh[:description]               = purchase_unit[:description] unless purchase_unit[:description].nil?
          ## Amount
          add_amount(purchase_unit[:amount], purchase_unit_hsh) unless purchase_unit[:amount].blank?
          ## Payee
          purchase_unit_hsh[:payee]                     = { }
          purchase_unit_hsh[:payee][:merchant_id]       = purchase_unit[:payee][:merchant_id]

          add_items(purchase_unit[:items], purchase_unit_hsh) unless purchase_unit[:items].blank?
          add_shipping(purchase_unit[:shipping], purchase_unit_hsh) unless purchase_unit[:shipping].blank?

          purchase_unit_hsh[:shipping_method]  = purchase_unit[:shipping_method]

          add_payment_instruction(purchase_unit[:payment_instruction], purchase_unit_hsh) unless purchase_unit[:payment_instruction].blank?

          purchase_unit_hsh[:payment_group_id]  = purchase_unit[:payment_group_id]
          purchase_unit_hsh[:custom_id]         = purchase_unit[:custom_id]
          purchase_unit_hsh[:invoice_id]        = purchase_unit[:invoice_id]
          purchase_unit_hsh[:soft_descriptor]   = purchase_unit[:soft_descriptor]

          post[:purchase_units] << purchase_unit_hsh
        end
        post
      end

      def add_application_context(options, post)
        post[:application_context]                = { }
        post[:application_context][:return_url]   = options[:return_url]
        post[:application_context][:cancel_url]   = options[:cancel_url]
      end

      def add_payment_instruction(options, post)
        post[:payment_instruction] = { }

        post[:payment_instruction][:platform_fees] = []
        options[:platform_fees].map do |platform_fee|
          platform_fee_hsh                          = { }

          add_amount(platform_fee[:amount], platform_fee_hsh)

          platform_fee_hsh[:payee]                  = { }
          platform_fee_hsh[:payee][:email_address] = platform_fee[:payee][:email_address]

          post[:payment_instruction][:platform_fees] << platform_fee_hsh
        end
        post
      end

      def add_intent(intent, post)
        post[:intent]  = intent
        post
      end

      def add_amount(amount, post)
        post[:amount] = {}
        post[:amount][:currency_code]   = amount[:currency_code]
        post[:amount][:value]           = amount[:value]
        add_breakdown_for_amount(amount[:breakdown], post) unless amount[:breakdown].blank?
        post
      end

      def add_breakdown_for_amount(options, post)
        post[:breakdown] = { }
        options.each do |key, value|
          post[:breakdown][key] = { }
          post[:breakdown][key][:currency_code] = options[key][:currency_code]
          post[:breakdown][key][:value]         = options[key][:value]
        end
        post
      end

      def add_items(options, post)
        post[:items] = []
        options.each do |item|
          items_hsh = { }
          items_hsh[:name]                        = item[:name]
          items_hsh[:sku]                         = item[:sku]
          items_hsh[:quantity]                    = item[:quantity]
          items_hsh[:category]                    = item[:category]
          items_hsh[:unit_amount]                 = { }

          items_hsh[:unit_amount][:currency_code] = item[:unit_amount][:currency_code]
          items_hsh[:unit_amount][:value]         = item[:unit_amount][:value]

          items_hsh[:tax]                 = { }
          items_hsh[:tax][:currency_code] = item[:tax][:currency_code]
          items_hsh[:tax][:value]         = item[:tax][:value]

          post[:items] << items_hsh
        end
        post
      end

      def add_shipping(options, post)
        post[:shipping]             = { }
        post[:shipping][:address]   = { }

        post[:shipping][:address][:address_line_1]    = options[:address][:address_line_1]
        post[:shipping][:address][:address_line_2]    = options[:address][:address_line_1]
        post[:shipping][:address][:admin_area_1]      = options[:address][:admin_area_1]
        post[:shipping][:address][:admin_area_2]      = options[:address][:admin_area_2]
        post[:shipping][:address][:postal_code]       = options[:address][:postal_code]
        post[:shipping][:address][:country_code]      = options[:address][:country_code]

        post
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

      def commit(method, url, parameters = nil, options = {})
        #post('v2/checkout/orders', options)
        response = api_request(method, "#{ @base_url }/#{ url }", parameters, options)
        success = success_from(response, options)
        success ? success : response_error(response)
      end

      def success_from(response, options)
        response
      end

      def response_error(raw_response)
        puts raw_response
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end
      def api_version(options)
        options[:version] || @options[:version] || self.class::DEFAULT_API_VERSION
      end

      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, endpoint, parameters.to_json, opt_headers)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        raw_response = raw_response.nil? ? "{}": raw_response
        eval(raw_response)
      end

      def headers(params)
        params[:headers]
      end

      def prepare_request_to_get_access_token(options)
        @options = options
        "basic #{ encoded_credentials }"
      end

      def encoded_credentials
        Base64.encode64("#{ @options[:authorization][:username] }:#{ @options[:authorization][:password] }").gsub("\n", "")
      end

    end
  end
end
