require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class LitleGateway < Gateway
      SCHEMA_VERSION = '8.18'

      self.test_url = 'https://www.testlitle.com/sandbox/communicator/online'
      self.live_url = 'https://payments.litle.com/vap/communicator/online'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      self.homepage_url = 'http://www.litle.com/'
      self.display_name = 'Litle & Co.'

      # Public: Create a new Litle gateway.
      #
      # options - A hash of options:
      #           :login         - The user.
      #           :password      - The password.
      #           :merchant_id   - The merchant id.
      def initialize(options={})
        requires!(options, :login, :password, :merchant_id)
        super
      end

      def purchase(money, payment_method, options={})
        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.sale(transaction_attributes(options)) do
            add_auth_purchase_params(doc, money, payment_method, options)
          end
        end

        commit(:sale, request)
      end

      def authorize(money, payment_method, options={})
        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.authorization(transaction_attributes(options)) do
            add_auth_purchase_params(doc, money, payment_method, options)
          end
        end

        commit(:authorization, request)
      end

      def capture(money, authorization, options={})
        transaction_id, _ = split_authorization(authorization)

        request = build_xml_request do |doc|
          add_authentication(doc)
          add_descriptor(doc, options)
          doc.capture_(transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
            doc.amount(money) if money
          end
        end

        commit(:capture, request)
      end

      def credit(money, authorization, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def refund(money, authorization, options={})
        transaction_id, _ = split_authorization(authorization)

        request = build_xml_request do |doc|
          add_authentication(doc)
          add_descriptor(doc, options)
          doc.credit(transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
            doc.amount(money) if money
          end
        end

        commit(:credit, request)
      end

      def verify(creditcard, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def void(authorization, options={})
        transaction_id, kind = split_authorization(authorization)

        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.send(void_type(kind), transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
          end
        end

        commit(void_type(kind), request)
      end

      def store(creditcard, options = {})
        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.registerTokenRequest(transaction_attributes(options)) do
            doc.orderId(truncated(options[:order_id]))
            doc.accountNumber(creditcard.number)
          end
        end

        commit(:registerToken, request)
      end

      private
      CARD_TYPE = {
        'visa'             => 'VI',
        'master'           => 'MC',
        'american_express' => 'AX',
        'discover'         => 'DI',
        'jcb'              => 'JC',
        'diners_club'      => 'DC'
      }

      AVS_RESPONSE_CODE = {
          '00' => 'Y',
          '01' => 'X',
          '02' => 'D',
          '10' => 'Z',
          '11' => 'W',
          '12' => 'A',
          '13' => 'A',
          '14' => 'P',
          '20' => 'N',
          '30' => 'S',
          '31' => 'R',
          '32' => 'U',
          '33' => 'R',
          '34' => 'I',
          '40' => 'E'
      }

      def void_type(kind)
        (kind == 'authorization') ? :authReversal : :void
      end

      def add_authentication(doc)
        doc.authentication do
          doc.user(@options[:login])
          doc.password(@options[:password])
        end
      end

      def add_auth_purchase_params(doc, money, payment_method, options)
        doc.orderId(truncated(options[:order_id]))
        doc.amount(money)
        add_order_source(doc, payment_method, options)
        add_billing_address(doc, payment_method, options)
        add_shipping_address(doc, payment_method, options)
        add_payment_method(doc, payment_method)
        add_pos(doc, payment_method)
        add_descriptor(doc, options)
      end

      def add_descriptor(doc, options)
        if options[:descriptor_name] || options[:descriptor_phone]
          doc.customBilling do
            doc.phone(options[:descriptor_phone]) if options[:descriptor_phone]
            doc.descriptor(options[:descriptor_name]) if options[:descriptor_name]
          end
        end
      end

      def add_payment_method(doc, payment_method)
        if payment_method.is_a?(String)
          doc.token do
            doc.litleToken(payment_method)
          end
        elsif payment_method.respond_to?(:track_data) && payment_method.track_data.present?
          doc.card do
            doc.track(payment_method.track_data)
          end
        else
          doc.card do
            doc.type_(CARD_TYPE[payment_method.brand])
            doc.number(payment_method.number)
            doc.expDate(exp_date(payment_method))
            doc.cardValidationNum(payment_method.verification_value)
          end
        end
      end

      def add_billing_address(doc, payment_method, options)
        return if payment_method.is_a?(String)

        doc.billToAddress do
          doc.name(payment_method.name)
          doc.email(options[:email]) if options[:email]

          add_address(doc, options[:billing_address])
        end
      end

      def add_shipping_address(doc, payment_method, options)
        return if payment_method.is_a?(String)

        doc.shipToAddress do
          add_address(doc, options[:shipping_address])
        end
      end

      def add_address(doc, address)
        return unless address

        doc.companyName(address[:company]) unless address[:company].blank?
        doc.addressLine1(address[:address1]) unless address[:address1].blank?
        doc.addressLine2(address[:address2]) unless address[:address2].blank?
        doc.city(address[:city]) unless address[:city].blank?
        doc.state(address[:state]) unless address[:state].blank?
        doc.zip(address[:zip]) unless address[:zip].blank?
        doc.country(address[:country]) unless address[:country].blank?
        doc.phone(address[:phone]) unless address[:phone].blank?
      end

      def add_order_source(doc, payment_method, options)
        if options[:order_source]
          doc.orderSource(options[:order_source])
        elsif payment_method.respond_to?(:track_data) && payment_method.track_data.present?
          doc.orderSource('retail')
        else
          doc.orderSource('ecommerce')
        end
      end

      def add_pos(doc, payment_method)
        return unless payment_method.respond_to?(:track_data) && payment_method.track_data.present?

        doc.pos do
          doc.capability('magstripe')
          doc.entryMode('completeread')
          doc.cardholderId('signature')
        end
      end

      def exp_date(payment_method)
        "#{format(payment_method.month, :two_digits)}#{format(payment_method.year, :two_digits)}"
      end

      def parse(kind, xml)
        parsed = {}

        doc = Nokogiri::XML(xml).remove_namespaces!
        doc.xpath("//litleOnlineResponse/#{kind}Response/*").each do |node|
          if (node.elements.empty?)
            parsed[node.name.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name}_#{childnode.name}"
              parsed[name.to_sym] = childnode.text
            end
          end
        end

        parsed
      end

      def commit(kind, request)
        parsed = parse(kind, ssl_post(url, request, headers))

        options = {
          authorization: authorization_from(kind, parsed),
          test: test?,
          :avs_result => { :code => AVS_RESPONSE_CODE[parsed[:fraudResult_avsResult]] },
          :cvv_result => parsed[:fraudResult_cardValidationResult]
        }

        Response.new(success_from(kind, parsed), parsed[:message], parsed, options)
      end

      def success_from(kind, parsed)
        return (parsed[:response] == '000') unless kind == :registerToken
        %w(000 801 802).include?(parsed[:response])
      end

      def authorization_from(kind, parsed)
        (kind == :registerToken) ? parsed[:litleToken] : "#{parsed[:litleTxnId]};#{kind}"
      end

      def split_authorization(authorization)
        transaction_id, kind = authorization.to_s.split(';')
        [transaction_id, kind]
      end

      def transaction_attributes(options)
        attributes = {}
        attributes[:id] = truncated(options[:id] || options[:order_id])
        attributes[:reportGroup] = options[:merchant] || 'Default Report Group'
        attributes[:customerId] = options[:customer]
        attributes.delete_if { |key, value| value == nil }
        attributes
      end

      def root_attributes
        {
          merchantId: @options[:merchant_id],
          version: SCHEMA_VERSION,
          xmlns: "http://www.litle.com/schema"
        }
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new
        builder.__send__('litleOnlineRequest', root_attributes) do |doc|
          yield(doc)
        end
        builder.doc.root.to_xml
      end

      def url
        test? ? test_url : live_url
      end

      def truncated(value)
        return unless value
        value[0..24]
      end

      def truncated_order_id(options)
        return unless options[:order_id]
        options[:order_id][0..24]
      end

      def truncated_id(options)
        return unless options[:id]
        options[:id][0..24]
      end

      def headers
        {
          'Content-Type' => 'text/xml'
        }
      end
    end
  end
end
