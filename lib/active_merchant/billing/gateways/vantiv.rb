# frozen_string_literal: true
require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Public: Vantiv gateway
    #
    # This gateway was previously known as `LitleGateway`. Vantiv bought Litle
    # in 2012. The URLs and the XML format (LitleXML) still reference the old
    # name.
    class VantivGateway < Gateway
      self.test_url = "https://www.testlitle.com/sandbox/communicator/online"
      self.live_url = "https://payments.litle.com/vap/communicator/online"

      self.supported_countries = ["US"]
      self.default_currency = "USD"
      self.supported_cardtypes = [
        :visa,
        :master,
        :american_express,
        :discover,
        :diners_club,
        :jcb
      ]

      self.homepage_url = "http://www.vantiv.com/"
      self.display_name = "Vantiv"

      AVS_RESPONSE_CODE = {
        "00" => "Y",
        "01" => "X",
        "02" => "D",
        "10" => "Z",
        "11" => "W",
        "12" => "A",
        "13" => "A",
        "14" => "P",
        "20" => "N",
        "30" => "S",
        "31" => "R",
        "32" => "U",
        "33" => "R",
        "34" => "I",
        "40" => "E"
      }.freeze

      CARD_TYPE = {
        "visa"             => "VI",
        "master"           => "MC",
        "american_express" => "AX",
        "discover"         => "DI",
        "jcb"              => "JC",
        "diners_club"      => "DC"
      }.freeze

      DEFAULT_HEADERS = {
        "Content-Type" => "text/xml"
      }.freeze

      DEFAULT_REPORT_GROUP = "Default Report Group"

      POS_CAPABILITY = "magstripe"
      POS_ENTRY_MODE = "completeread"
      POS_CARDHOLDER_ID = "signature"

      RESPONSE_CODE_APPROVED = "000"
      RESPONSE_CODES_APPROVED = [
        "000", # approved
        "801", # account number registered
        "802" # account number previously registered
      ].freeze

      SCHEMA_VERSION = "9.4"

      SCRUBBED_PATTERNS = [
        %r((<user>).+(</user>)),
        %r((<password>).+(</password>)),
        %r((<number>).+(</number>)),
        %r((<cardValidationNum>).+(</cardValidationNum>)),
        %r((<accountNumber>).+(</accountNumber>)),
        %r((<paypageRegistrationId>).+(</paypageRegistrationId>)),
        %r((<authenticationValue>).+(</authenticationValue>))
      ].freeze

      SCRUBBED_REPLACEMENT = "\\1[FILTERED]\\2"

      SOURCE_APPLE_PAY = "applepay"
      SOURCE_RETAIL = "retail"
      SOURCE_ECOMMERCE = "ecommerce"

      VOID_TYPE_AUTHORIZATION = "authorization"

      XML_NAMESPACE = "http://www.litle.com/schema"
      XML_REQUEST_ROOT = "litleOnlineRequest"
      XML_RESPONSE_NODES = %w[message response].freeze
      XML_RESPONSE_ROOT = "litleOnlineResponse"

      # Public: Create a new Vantiv gateway.
      #
      # options - A hash of options:
      #           :login         - The user.
      #           :password      - The password.
      #           :merchant_id   - The merchant id.
      def initialize(options = {})
        requires!(options, :login, :password, :merchant_id)
        super
      end

      def authorize(money, payment_method, options = {})
        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.authorization(transaction_attributes(options)) do
            add_auth_purchase_params(doc, money, payment_method, options)
          end
        end

        commit(:authorization, request, money)
      end

      def capture(money, authorization, options = {})
        transaction_id, = split_authorization(authorization)

        request = build_xml_request do |doc|
          add_authentication(doc)
          add_descriptor(doc, options)
          doc.capture_(transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
            doc.amount(money) if money
          end
        end

        commit(:capture, request, money)
      end

      def credit(money, authorization, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      def purchase(money, payment_method, options = {})
        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.sale(transaction_attributes(options)) do
            add_auth_purchase_params(doc, money, payment_method, options)
          end
        end

        commit(:sale, request, money)
      end

      def refund(money, authorization, options = {})
        transaction_id, = split_authorization(authorization)

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

      def scrub(transcript)
        SCRUBBED_PATTERNS.inject(transcript) do |text, pattern|
          text.gsub(pattern, SCRUBBED_REPLACEMENT)
        end
      end

      def store(payment_method, options = {})
        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.registerTokenRequest(transaction_attributes(options)) do
            doc.orderId(truncate(options[:order_id], 24))
            if payment_method_is_paypage_registration_id?(payment_method)
              doc.paypageRegistrationId(payment_method)
            else
              doc.accountNumber(payment_method.number)

              if payment_method.verification_value
                doc.cardValidationNum(payment_method.verification_value)
              end
            end
          end
        end

        commit(:registerToken, request)
      end

      def supports_scrubbing?
        true
      end

      def verify(creditcard, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def void(authorization, options = {})
        transaction_id, kind, money = split_authorization(authorization)

        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.send(void_type(kind), transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
            doc.amount(money) if void_type(kind) == :authReversal
          end
        end

        commit(void_type(kind), request)
      end

    private

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

      def add_auth_purchase_params(doc, money, payment_method, options)
        doc.orderId(truncate(options[:order_id], 24))
        doc.amount(money)
        add_order_source(doc, payment_method, options)
        add_billing_address(doc, payment_method, options)
        add_shipping_address(doc, payment_method, options)
        add_payment_method(doc, payment_method)
        add_pos(doc, payment_method)
        add_descriptor(doc, options)
        add_debt_repayment(doc, options)
      end

      def add_authentication(doc)
        doc.authentication do
          doc.user(@options[:login])
          doc.password(@options[:password])
        end
      end

      def add_billing_address(doc, payment_method, options)
        return if payment_method_is_token?(payment_method)

        doc.billToAddress do
          doc.name(payment_method.name)
          doc.email(options[:email]) if options[:email]

          add_address(doc, options[:billing_address])
        end
      end

      def add_debt_repayment(doc, options)
        doc.debtRepayment(true) if options[:debt_repayment] == true
      end

      def add_descriptor(doc, options)
        name = options[:descriptor_name]
        phone = options[:descriptor_phone]

        return unless name || phone

        doc.customBilling do
          doc.phone(options[:descriptor_phone]) if phone
          doc.descriptor(options[:descriptor_name]) if name
        end
      end

      def add_order_source(doc, payment_method, options)
        if options[:order_source]
          doc.orderSource(options[:order_source])
        elsif payment_method_is_apple_pay?(payment_method)
          doc.orderSource(SOURCE_APPLE_PAY)
        elsif payment_method_has_track_data?(payment_method)
          doc.orderSource(SOURCE_RETAIL)
        else
          doc.orderSource(SOURCE_ECOMMERCE)
        end
      end

      def add_payment_method(doc, payment_method)
        if payment_method_is_token?(payment_method)
          doc.token do
            doc.litleToken(payment_method)
          end
        elsif payment_method_has_track_data?(payment_method)
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
          if payment_method_is_network_tokenized?(payment_method)
            doc.cardholderAuthentication do
              doc.authenticationValue(payment_method.payment_cryptogram)
            end
          end
        end
      end

      def add_pos(doc, payment_method)
        return unless payment_method_has_track_data?(payment_method)

        doc.pos do
          doc.capability(POS_CAPABILITY)
          doc.entryMode(POS_ENTRY_MODE)
          doc.cardholderId(POS_CARDHOLDER_ID)
        end
      end

      def add_shipping_address(doc, payment_method, options)
        return if payment_method_is_token?(payment_method)

        doc.shipToAddress do
          add_address(doc, options[:shipping_address])
        end
      end

      def authorization_from(kind, parsed, money)
        if kind == :registerToken
          parsed[:litleToken]
        else
          "#{parsed[:litleTxnId]};#{kind};#{money}"
        end
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new
        builder.public_send(XML_REQUEST_ROOT, root_attributes) do |doc|
          yield(doc)
        end
        builder.doc.root.to_xml
      end

      def commit(kind, request, money = nil)
        parsed = parse(kind, ssl_post(url, request, headers))

        options = {
          authorization: authorization_from(kind, parsed, money),
          test: test?,
          avs_result: {
            code: AVS_RESPONSE_CODE[parsed[:fraudResult_avsResult]]
          },
          cvv_result: parsed[:fraudResult_cardValidationResult]
        }

        Response.new(
          success_from(kind, parsed),
          parsed[:message],
          parsed,
          options
        )
      end

      def exp_date(payment_method)
        formatted_month = format(payment_method.month, :two_digits)
        formatted_year = format(payment_method.year, :two_digits)

        "#{formatted_month}#{formatted_year}"
      end

      def headers
        DEFAULT_HEADERS
      end

      def parse(kind, xml)
        parsed = {}

        doc = Nokogiri::XML(xml).remove_namespaces!
        doc.xpath("//#{XML_RESPONSE_ROOT}/#{kind}Response/*").each do |node|
          if node.elements.empty?
            parsed[node.name.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name}_#{childnode.name}"
              parsed[name.to_sym] = childnode.text
            end
          end
        end

        if parsed.empty?
          XML_RESPONSE_NODES.each do |attribute|
            parsed[attribute.to_sym] = doc
                                       .xpath("//#{XML_RESPONSE_ROOT}")
                                       .attribute(attribute)
                                       .value
          end
        end

        parsed
      end

      def payment_method_has_track_data?(payment_method)
        payment_method.respond_to?(:track_data) &&
          payment_method.track_data.present?
      end

      def payment_method_is_apple_pay?(payment_method)
        payment_method_is_network_tokenized?(payment_method) &&
          payment_method.source == :apple_pay
      end

      def payment_method_is_network_tokenized?(payment_method)
        payment_method.is_a?(NetworkTokenizationCreditCard)
      end

      # Limited support for paypage at this time - if string in that context
      # then it's a paypage registration id
      def payment_method_is_paypage_registration_id?(payment_method)
        payment_method.is_a?(String)
      end

      def payment_method_is_token?(payment_method)
        payment_method.is_a?(String)
      end

      def root_attributes
        {
          merchantId: @options[:merchant_id],
          version: SCHEMA_VERSION,
          xmlns: XML_NAMESPACE
        }
      end

      def split_authorization(authorization)
        transaction_id, kind, money = authorization.to_s.split(";")
        [transaction_id, kind, money]
      end

      def success_from(kind, parsed)
        approved = (parsed[:response] == RESPONSE_CODE_APPROVED)
        return approved unless kind == :registerToken

        RESPONSE_CODES_APPROVED.include?(parsed[:response])
      end

      def transaction_attributes(options)
        attributes = {}
        attributes[:id] = truncate(options[:id] || options[:order_id], 24)
        attributes[:reportGroup] = options[:merchant] || DEFAULT_REPORT_GROUP
        attributes[:customerId] = options[:customer]
        attributes.delete_if { |_key, value| value.nil? }
        attributes
      end

      def url
        test? ? test_url : live_url
      end

      def void_type(kind)
        kind == VOID_TYPE_AUTHORIZATION ? :authReversal : :void
      end
    end
  end
end
