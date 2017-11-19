module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WorldpayGateway < Gateway
      self.test_url = 'https://secure-test.worldpay.com/jsp/merchant/xml/paymentService.jsp'
      self.live_url = 'https://secure.worldpay.com/jsp/merchant/xml/paymentService.jsp'

      self.default_currency = 'GBP'
      self.money_format = :cents
      self.supported_countries = %w(HK GB AU AD BE CH CY CZ DE DK ES FI FR GI GR HU IE IL IT LI LU MC MT NL NO NZ PL PT SE SG SI SM TR UM VA)
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :laser, :switch]
      self.currencies_without_fractions = %w(HUF IDR ISK JPY KRW)
      self.currencies_with_three_decimal_places = %w(BHD KWD OMR RSD TND)
      self.homepage_url = 'http://www.worldpay.com/'
      self.display_name = 'Worldpay Global'

      CARD_CODES = {
        'visa'             => 'VISA-SSL',
        'master'           => 'ECMC-SSL',
        'discover'         => 'DISCOVER-SSL',
        'american_express' => 'AMEX-SSL',
        'jcb'              => 'JCB-SSL',
        'maestro'          => 'MAESTRO-SSL',
        'laser'            => 'LASER-SSL',
        'diners_club'      => 'DINERS-SSL',
        'switch'           => 'MAESTRO-SSL'
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment_method, options = {})
        MultiResponse.run do |r|
          r.process{authorize(money, payment_method, options)}
          r.process{capture(money, r.authorization, options.merge(:authorization_validated => true))}
        end
      end

      def authorize(money, payment_method, options = {})
        requires!(options, :order_id)
        authorize_request(money, payment_method, options)
      end

      def capture(money, authorization, options = {})
        MultiResponse.run do |r|
          r.process{inquire_request(authorization, options, "AUTHORISED")} unless options[:authorization_validated]
          if r.params
            authorization_currency = r.params['amount_currency_code']
            options = options.merge(:currency => authorization_currency) if authorization_currency.present?
          end
          r.process{capture_request(money, authorization, options)}
        end
      end

      def void(authorization, options = {})
        MultiResponse.run do |r|
          r.process{inquire_request(authorization, options, "AUTHORISED")}
          r.process{cancel_request(authorization, options)}
        end
      end

      def refund(money, authorization, options = {})
        response = MultiResponse.run do |r|
          r.process { inquire_request(authorization, options, "CAPTURED", "SETTLED", "SETTLED_BY_MERCHANT") }
          r.process { refund_request(money, authorization, options) }
        end

        return response if response.success?
        return response unless options[:force_full_refund_if_unsettled]

        void(authorization, options ) if response.params["last_event"] == "AUTHORISED"
      end

      # Credits only function on a Merchant ID/login/profile flagged for Payouts
      #   aka Credit Fund Transfers (CFT), whereas normal purchases, refunds,
      #   and other transactions should be performed on a normal eCom-flagged
      #   merchant ID.
      def credit(money, payment_method, options = {})
        credit_request(money, payment_method, options.merge(:credit => true))
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((<cardNumber>)\d+(</cardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<cvc>)[^<]+(</cvc>)), '\1[FILTERED]\2')
      end

      private

      def authorize_request(money, payment_method, options)
        commit('authorize', build_authorization_request(money, payment_method, options), "AUTHORISED")
      end

      def capture_request(money, authorization, options)
        commit('capture', build_capture_request(money, authorization, options), :ok)
      end

      def cancel_request(authorization, options)
        commit('cancel', build_void_request(authorization, options), :ok)
      end

      def inquire_request(authorization, options, *success_criteria)
        commit('inquiry', build_order_inquiry_request(authorization, options), *success_criteria)
      end

      def refund_request(money, authorization, options)
        commit('refund', build_refund_request(money, authorization, options), :ok)
      end

      def credit_request(money, payment_method, options)
        commit('credit', build_authorization_request(money, payment_method, options), :ok)
      end

      def build_request
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct! :xml, :encoding => 'UTF-8'
        xml.declare! :DOCTYPE, :paymentService, :PUBLIC, "-//WorldPay//DTD WorldPay PaymentService v1//EN", "http://dtd.worldpay.com/paymentService_v1.dtd"
        xml.tag! 'paymentService', 'version' => "1.4", 'merchantCode' => @options[:login] do
          yield xml
        end
        xml.target!
      end

      def build_order_modify_request(authorization)
        build_request do |xml|
          xml.tag! 'modify' do
            xml.tag! 'orderModification', 'orderCode' => authorization do
              yield xml
            end
          end
        end
      end

      def build_order_inquiry_request(authorization, options)
        build_request do |xml|
          xml.tag! 'inquiry' do
            xml.tag! 'orderInquiry', 'orderCode' => authorization
          end
        end
      end

      def build_authorization_request(money, payment_method, options)
        build_request do |xml|
          xml.tag! 'submit' do
            xml.tag! 'order', order_tag_attributes(options) do
              xml.description(options[:description].blank? ? "Purchase" : options[:description])
              add_amount(xml, money, options)
              if options[:order_content]
                xml.tag! 'orderContent' do
                  xml.cdata! options[:order_content]
                end
              end
              add_payment_method(xml, money, payment_method, options)
              add_email(xml, options)
              if options[:hcg_additional_data]
                add_hcg_additional_data(xml, options)
              end
            end
          end
        end
      end

      def order_tag_attributes(options)
        { 'orderCode' => options[:order_id], 'installationId' => options[:inst_id] || @options[:inst_id] }.reject{|_,v| !v}
      end

      def build_capture_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.tag! 'capture' do
            time = Time.now
            xml.tag! 'date', 'dayOfMonth' => time.day, 'month' => time.month, 'year'=> time.year
            add_amount(xml, money, options)
          end
        end
      end

      def build_void_request(authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.tag! 'cancel'
        end
      end

      def build_refund_request(money, authorization, options)
        build_order_modify_request(authorization) do |xml|
          xml.tag! 'refund' do
            add_amount(xml, money, options.merge(:debit_credit_indicator => "credit"))
          end
        end
      end

      def add_amount(xml, money, options)
        currency = options[:currency] || currency(money)

        amount_hash = {
          :value => localized_amount(money, currency),
          'currencyCode' => currency,
          'exponent' => currency_exponent(currency)
        }

        if options[:debit_credit_indicator]
          amount_hash.merge!('debitCreditIndicator' => options[:debit_credit_indicator])
        end

        xml.tag! 'amount', amount_hash
      end

      def add_payment_method(xml, amount, payment_method, options)
        if payment_method.is_a?(String)
          if options[:merchant_code]
            xml.tag! 'payAsOrder', 'orderCode' => payment_method, 'merchantCode' => options[:merchant_code] do
              add_amount(xml, amount, options)
            end
          else
            xml.tag! 'payAsOrder', 'orderCode' => payment_method do
              add_amount(xml, amount, options)
            end
          end
        else
          xml.tag! 'paymentDetails', credit_fund_transfer_attribute(options) do
            xml.tag! CARD_CODES[card_brand(payment_method)] do
              xml.tag! 'cardNumber', payment_method.number
              xml.tag! 'expiryDate' do
                xml.tag! 'date', 'month' => format(payment_method.month, :two_digits), 'year' => format(payment_method.year, :four_digits)
              end

              xml.tag! 'cardHolderName', payment_method.name
              xml.tag! 'cvc', payment_method.verification_value

              add_address(xml, (options[:billing_address] || options[:address]))
            end
            if options[:ip] && options[:session_id]
              xml.tag! 'session', 'shopperIPAddress' => options[:ip], 'id' => options[:session_id]
            else
              xml.tag! 'session', 'shopperIPAddress' => options[:ip] if options[:ip]
              xml.tag! 'session', 'id' => options[:session_id] if options[:session_id]
            end
          end
        end
      end

      def add_email(xml, options)
        return unless options[:email]
        xml.tag! 'shopper' do
          xml.tag! 'shopperEmailAddress', options[:email]
        end
      end

      def add_address(xml, address)
        return unless address

        address = address_with_defaults(address)

        xml.tag! 'cardAddress' do
          xml.tag! 'address' do
            if m = /^\s*([^\s]+)\s+(.+)$/.match(address[:name])
              xml.tag! 'firstName', m[1]
              xml.tag! 'lastName', m[2]
            end
            xml.tag! 'address1', address[:address1]
            xml.tag! 'address2', address[:address2] if address[:address2]
            xml.tag! 'postalCode', address[:zip]
            xml.tag! 'city', address[:city]
            xml.tag! 'state', address[:state]
            xml.tag! 'countryCode', address[:country]
            xml.tag! 'telephoneNumber', address[:phone] if address[:phone]
          end
        end
      end

      def add_hcg_additional_data(xml, options)
        xml.tag! 'hcgAdditionalData' do
          options[:hcg_additional_data].each do |k, v|
            xml.tag! "param", {name: k.to_s}, v
          end
        end
      end

      def address_with_defaults(address)
        address ||= {}
        address.delete_if { |_, v| v.blank? }
        address.reverse_merge!(default_address)
      end

      def default_address
        {
          address1: 'N/A',
          zip: '0000',
          city: 'N/A',
          state: 'N/A',
          country: 'US'
        }
      end

      def parse(action, xml)
        parse_element({:action => action}, REXML::Document.new(xml))
      end

      def parse_element(raw, node)
        node.attributes.each do |k, v|
          raw["#{node.name.underscore}_#{k.underscore}".to_sym] = v
        end
        if node.has_elements?
          raw[node.name.underscore.to_sym] = true unless node.name.blank?
          node.elements.each{|e| parse_element(raw, e) }
        else
          raw[node.name.underscore.to_sym] = node.text unless node.text.nil?
        end
        raw
      end

      def commit(action, request, *success_criteria)
        xmr = ssl_post(url, request, 'Content-Type' => 'text/xml', 'Authorization' => encoded_credentials)
        raw = parse(action, xmr)
        success, message = success_and_message_from(raw, success_criteria)

        Response.new(
          success,
          message,
          raw,
          :authorization => authorization_from(raw),
          :error_code => error_code_from(success, raw),
          :test => test?)

      rescue ActiveMerchant::ResponseError => e
        if e.response.code.to_s == "401"
          return Response.new(false, "Invalid credentials", {}, :test => test?)
        else
          raise e
        end
      end

      def url
        test? ? self.test_url : self.live_url
      end

      # success_criteria can be:
      #   - a string or an array of strings (if one of many responses)
      #   - An array of strings if one of many responses could be considered a
      #     success.
      def success_and_message_from(raw, success_criteria)
        success = (success_criteria.include?(raw[:last_event]) || raw[:ok].present?)
        if success
          message = "SUCCESS"
        else
          message = (raw[:iso8583_return_code_description] || raw[:error] || required_status_message(raw, success_criteria))
        end

        [ success, message ]
      end

      def error_code_from(success, raw)
        unless success == "SUCCESS"
          raw[:iso8583_return_code_code] || raw[:error_code] || nil
        end
      end

      def required_status_message(raw, success_criteria)
        if(!success_criteria.include?(raw[:last_event]))
          "A transaction status of #{success_criteria.collect{|c| "'#{c}'"}.join(" or ")} is required."
        end
      end

      def authorization_from(raw)
        pair = raw.detect{|k,v| k.to_s =~ /_order_code$/}
        (pair ? pair.last : nil)
      end

      def credit_fund_transfer_attribute(options)
        return unless options[:credit]
        {'action' => "REFUND"}
      end

      def encoded_credentials
        credentials = "#{@options[:login]}:#{@options[:password]}"
        "Basic #{[credentials].pack('m').strip}"
      end

      def currency_exponent(currency)
        return 0 if non_fractional_currency?(currency)
        return 3 if three_decimal_currency?(currency)
        return 2
      end
    end
  end
end
