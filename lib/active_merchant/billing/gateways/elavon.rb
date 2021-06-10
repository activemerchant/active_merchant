require 'active_merchant/billing/gateways/viaklix'
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ElavonGateway < Gateway
      include Empty

      class_attribute :test_url, :live_url, :delimiter, :actions

      self.test_url = 'https://api.demo.convergepay.com/VirtualMerchantDemo/processxml.do'
      self.live_url = 'https://api.convergepay.com/VirtualMerchant/processxml.do'

      self.display_name = 'Elavon MyVirtualMerchant'
      self.supported_countries = %w(US CA PR DE IE NO PL LU BE NL MX)
      self.supported_cardtypes = %i[visa master american_express discover]
      self.homepage_url = 'http://www.elavon.com/'
      self.money_format = :dollars
      self.default_currency = 'USD'

      self.delimiter = "\n"
      self.actions = {
        purchase: 'CCSALE',
        credit: 'CCCREDIT',
        refund: 'CCRETURN',
        authorize: 'CCAUTHONLY',
        capture: 'CCFORCE',
        capture_complete: 'CCCOMPLETE',
        void: 'CCDELETE',
        store: 'CCGETTOKEN',
        update: 'CCUPDATETOKEN',
        verify: 'CCVERIFY'
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment_method, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:purchase]
          xml.ssl_amount            amount(money)

          if payment_method.is_a?(String)
            add_token(xml, payment_method)
          else
            add_creditcard(xml, payment_method)
          end

          add_invoice(xml, options)
          add_salestax(xml, options)
          add_currency(xml, money, options)
          add_address(xml, options)
          add_customer_email(xml, options)
          add_test_mode(xml, options)
          add_ip(xml, options)
          add_auth_purchase_params(xml, options)
          add_level_3_fields(xml, options) if options[:level_3_data]
        end
        commit(request)
      end

      def authorize(money, creditcard, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:authorize]
          xml.ssl_amount            amount(money)

          add_salestax(xml, options)
          add_invoice(xml, options)
          add_creditcard(xml, creditcard)
          add_currency(xml, money, options)
          add_address(xml, options)
          add_customer_email(xml, options)
          add_test_mode(xml, options)
          add_ip(xml, options)
          add_auth_purchase_params(xml, options)
          add_level_3_fields(xml, options) if options[:level_3_data]
        end
        commit(request)
      end

      def capture(money, authorization, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]

          if options[:credit_card]
            xml.ssl_transaction_type self.actions[:capture]
            xml.ssl_amount amount(money)
            add_salestax(xml, options)
            add_approval_code(xml, authorization)
            add_invoice(xml, options)
            add_creditcard(xml, options[:credit_card])
            add_currency(xml, money, options)
            add_address(xml, options)
            add_customer_email(xml, options)
            add_test_mode(xml, options)
          else
            xml.ssl_transaction_type self.actions[:capture_complete]
            xml.ssl_amount amount(money)
            add_currency(xml, money, options)
            add_txn_id(xml, authorization)
            add_partial_shipment_flag(xml, options)
            add_test_mode(xml, options)
          end
        end
        commit(request)
      end

      def refund(money, identification, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:refund]
          xml.ssl_amount            amount(money)
          add_txn_id(xml, identification)
          add_test_mode(xml, options)
        end
        commit(request)
      end

      def void(identification, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:void]

          add_txn_id(xml, identification)
          add_test_mode(xml, options)
        end
        commit(request)
      end

      def credit(money, creditcard, options = {})
        raise ArgumentError, 'Reference credits are not supported. Please supply the original credit card or use the #refund method.' if creditcard.is_a?(String)

        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:credit]
          xml.ssl_amount            amount(money)
          add_invoice(xml, options)
          add_creditcard(xml, creditcard)
          add_currency(xml, money, options)
          add_address(xml, options)
          add_customer_email(xml, options)
          add_test_mode(xml, options)
        end
        commit(request)
      end

      def verify(credit_card, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:verify]
          add_creditcard(xml, credit_card)
          add_address(xml, options)
          add_test_mode(xml, options)
          add_ip(xml, options)
        end
        commit(request)
      end

      def store(creditcard, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:store]
          xml.ssl_add_token 'Y'
          add_creditcard(xml, creditcard)
          add_address(xml, options)
          add_customer_email(xml, options)
          add_test_mode(xml, options)
          add_verification(xml, options)
        end
        commit(request)
      end

      def update(token, creditcard, options = {})
        request = build_xml_request do |xml|
          xml.ssl_vendor_id         @options[:ssl_vendor_id] || options[:ssl_vendor_id]
          xml.ssl_transaction_type  self.actions[:update]
          add_token(xml, token)
          add_creditcard(xml, creditcard)
          add_address(xml, options)
          add_customer_email(xml, options)
          add_test_mode(xml, options)
        end
        commit(request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<ssl_pin>)(.*)(</ssl_pin>)), '\1[FILTERED]\3').
          gsub(%r((<ssl_card_number>)(.*)(</ssl_card_number>)), '\1[FILTERED]\3').
          gsub(%r((<ssl_cvv2cvc2>)(.*)(</ssl_cvv2cvc2>)), '\1[FILTERED]\3')
      end

      private

      def add_invoice(xml, options)
        xml.ssl_invoice_number    truncate((options[:order_id] || options[:invoice]), 25)
        xml.ssl_description       truncate(options[:description], 255)
      end

      def add_approval_code(xml, authorization)
        xml.ssl_approval_code authorization.split(';').first
      end

      def add_txn_id(xml, authorization)
        xml.ssl_txn_id authorization.split(';').last
      end

      def add_creditcard(xml, creditcard)
        xml.ssl_card_number   creditcard.number
        xml.ssl_exp_date      expdate(creditcard)

        add_verification_value(xml, creditcard) if creditcard.verification_value?

        xml.ssl_first_name    truncate(creditcard.first_name, 20)
        xml.ssl_last_name     truncate(creditcard.last_name, 30)
      end

      def add_currency(xml, money, options)
        currency = options[:currency] || currency(money)
        return unless currency && (@options[:multi_currency] || options[:multi_currency])

        xml.ssl_transaction_currency currency
      end

      def add_token(xml, token)
        xml.ssl_token token
      end

      def add_verification_value(xml, creditcard)
        xml.ssl_cvv2cvc2            creditcard.verification_value
        xml.ssl_cvv2cvc2_indicator  1
      end

      def add_customer_email(xml, options)
        xml.ssl_email truncate(options[:email], 100) unless empty?(options[:email])
      end

      def add_salestax(xml, options)
        return unless options[:tax].present?

        xml.ssl_salestax options[:tax]
      end

      def add_address(xml, options)
        billing_address = options[:billing_address] || options[:address]

        if billing_address
          xml.ssl_avs_address     truncate(billing_address[:address1], 30)
          xml.ssl_address2        truncate(billing_address[:address2], 30)
          xml.ssl_avs_zip         truncate(billing_address[:zip].to_s.gsub(/[^a-zA-Z0-9]/, ''), 9)
          xml.ssl_city            truncate(billing_address[:city], 30)
          xml.ssl_state           truncate(billing_address[:state], 10)
          xml.ssl_company         truncate(billing_address[:company], 50)
          xml.ssl_phone           truncate(billing_address[:phone], 20)
          xml.ssl_country         truncate(billing_address[:country], 50)
        end

        if shipping_address = options[:shipping_address]
          xml.ssl_ship_to_address1    truncate(shipping_address[:address1], 30)
          xml.ssl_ship_to_address2    truncate(shipping_address[:address2], 30)
          xml.ssl_ship_to_city        truncate(shipping_address[:city], 30)
          xml.ssl_ship_to_company     truncate(shipping_address[:company], 50)
          xml.ssl_ship_to_country     truncate(shipping_address[:country], 50)
          xml.ssl_ship_to_first_name  truncate(shipping_address[:first_name], 20)
          xml.ssl_ship_to_last_name   truncate(shipping_address[:last_name], 30)
          xml.ssl_ship_to_phone       truncate(shipping_address[:phone], 10)
          xml.ssl_ship_to_state       truncate(shipping_address[:state], 2)
          xml.ssl_ship_to_zip         truncate(shipping_address[:zip], 10)
        end
      end

      def add_verification(xml, options)
        xml.ssl_verify 'Y' if options[:verify]
      end

      def add_test_mode(xml, options)
        xml.ssl_test_mode 'TRUE' if options[:test_mode]
      end

      def add_partial_shipment_flag(xml, options)
        xml.ssl_partial_shipment_flag 'Y' if options[:partial_shipment_flag]
      end

      def add_ip(xml, options)
        xml.ssl_cardholder_ip options[:ip] if options.has_key?(:ip)
      end

      def add_auth_purchase_params(xml, options)
        xml.ssl_dynamic_dba                     options[:dba] if options.has_key?(:dba)
        xml.ssl_merchant_initiated_unscheduled  merchant_initiated_unscheduled(options) if merchant_initiated_unscheduled(options)
        xml.ssl_customer_code                   options[:customer] if options.has_key?(:customer)
        xml.ssl_customer_number                 options[:customer_number] if options.has_key?(:customer_number)
        xml.ssl_entry_mode                      entry_mode(options) if entry_mode(options)
        add_custom_fields(xml, options) if options[:custom_fields]
        add_stored_credential(xml, options) if options[:stored_credential]
      end

      def add_custom_fields(xml, options)
        options[:custom_fields]&.each do |key, value|
          xml.send(key.to_sym, value)
        end
      end

      def add_level_3_fields(xml, options)
        level_3_data = options[:level_3_data]
        xml.ssl_customer_code           level_3_data[:customer_code] if level_3_data[:customer_code]
        xml.ssl_salestax                level_3_data[:salestax] if level_3_data[:salestax]
        xml.ssl_salestax_indicator      level_3_data[:salestax_indicator] if level_3_data[:salestax_indicator]
        xml.ssl_level3_indicator        level_3_data[:level3_indicator] if level_3_data[:level3_indicator]
        xml.ssl_ship_to_zip             level_3_data[:ship_to_zip] if level_3_data[:ship_to_zip]
        xml.ssl_ship_to_country         level_3_data[:ship_to_country] if level_3_data[:ship_to_country]
        xml.ssl_shipping_amount         level_3_data[:shipping_amount] if level_3_data[:shipping_amount]
        xml.ssl_ship_from_postal_code   level_3_data[:ship_from_postal_code] if level_3_data[:ship_from_postal_code]
        xml.ssl_discount_amount         level_3_data[:discount_amount] if level_3_data[:discount_amount]
        xml.ssl_duty_amount             level_3_data[:duty_amount] if level_3_data[:duty_amount]
        xml.ssl_national_tax_indicator  level_3_data[:national_tax_indicator] if level_3_data[:national_tax_indicator]
        xml.ssl_national_tax_amount     level_3_data[:national_tax_amount] if level_3_data[:national_tax_amount]
        xml.ssl_order_date              level_3_data[:order_date] if level_3_data[:order_date]
        xml.ssl_other_tax               level_3_data[:other_tax] if level_3_data[:other_tax]
        xml.ssl_summary_commodity_code  level_3_data[:summary_commodity_code] if level_3_data[:summary_commodity_code]
        xml.ssl_merchant_vat_number     level_3_data[:merchant_vat_number] if level_3_data[:merchant_vat_number]
        xml.ssl_customer_vat_number     level_3_data[:customer_vat_number] if level_3_data[:customer_vat_number]
        xml.ssl_freight_tax_amount      level_3_data[:freight_tax_amount] if level_3_data[:freight_tax_amount]
        xml.ssl_vat_invoice_number      level_3_data[:vat_invoice_number] if level_3_data[:vat_invoice_number]
        xml.ssl_tracking_number         level_3_data[:tracking_number] if level_3_data[:tracking_number]
        xml.ssl_shipping_company        level_3_data[:shipping_company] if level_3_data[:shipping_company]
        xml.ssl_other_fees              level_3_data[:other_fees] if level_3_data[:other_fees]
        add_line_items(xml, level_3_data) if level_3_data[:line_items]
      end

      def add_line_items(xml, level_3_data)
        xml.LineItemProducts {
          level_3_data[:line_items].each do |line_item|
            xml.product {
              line_item.each do |key, value|
                prefixed_key = "ssl_line_Item_#{key}"
                xml.send(prefixed_key, value)
              end
            }
          end
        }
      end

      def add_stored_credential(xml, options)
        network_transaction_id = options.dig(:stored_credential, :network_transaction_id)
        case
        when network_transaction_id.nil?
          return
        when network_transaction_id.to_s.include?('|')
          oar_data, ps2000_data = options[:stored_credential][:network_transaction_id].split('|')
          xml.ssl_oar_data oar_data unless oar_data.nil? || oar_data.empty?
          xml.ssl_ps2000_data ps2000_data unless ps2000_data.nil? || ps2000_data.empty?
        when network_transaction_id.to_s.length > 22
          xml.ssl_oar_data options.dig(:stored_credential, :network_transaction_id)
        else
          xml.ssl_ps2000_data options.dig(:stored_credential, :network_transaction_id)
        end
      end

      def merchant_initiated_unscheduled(options)
        return options[:merchant_initiated_unscheduled] if options[:merchant_initiated_unscheduled]
        return 'Y' if options.dig(:stored_credential, :initiator) == 'merchant' && options.dig(:stored_credential, :reason_type) == 'unscheduled'
      end

      def entry_mode(options)
        return options[:entry_mode] if options[:entry_mode]
        return 12 if options[:stored_credential]
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.txn do
            xml.ssl_merchant_id       @options[:login]
            xml.ssl_user_id           @options[:user]
            xml.ssl_pin               @options[:password]
            yield(xml)
          end
        end

        builder.to_xml.gsub("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n", '')
      end

      def commit(request)
        request = "xmldata=#{request}".delete('&')

        response = parse(ssl_post(test? ? self.test_url : self.live_url, request, headers))

        Response.new(
          response[:result] == '0',
          response[:result_message] || response[:errorMessage],
          response,
          test: @options[:test] || test?,
          authorization: authorization_from(response),
          error_code: response[:errorCode],
          avs_result: { code: response[:avs_response] },
          cvv_result: response[:cvv2_response],
          network_transaction_id: build_network_transaction_id(response)
        )
      end

      def build_network_transaction_id(response)
        "#{response[:oar_data]}|#{response[:ps2000_data]}"
      end

      def headers
        {
          'Accept' => 'application/xml',
          'Content-type' => 'application/x-www-form-urlencoded'
        }
      end

      def parse(body)
        xml = Nokogiri::XML(body)
        response = Hash.from_xml(xml.to_s)['txn']

        response.deep_transform_keys { |key| key.gsub('ssl_', '').to_sym }
      end

      def authorization_from(response)
        [response[:approval_code], response[:txn_id]].join(';')
      end

      def truncate(value, size)
        return nil unless value

        difference = value.force_encoding('iso-8859-1').length - value.length

        return value.delete('&"<>').to_s[0, (size - difference)]
      end
    end
  end
end
