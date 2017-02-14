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

      CHECK_TYPE = {
        "personal" => {
          "checking" => "Checking",
          "savings"  => "Savings"
        },
        "business" => {
          "checking" => "Corporate",
          "savings"  => "Corp Savings"
        }
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

      # Public: Vantiv token object represents the tokenized credit card number
      # from Vantiv. Unlike other vault-like solutions, Vantiv only stores the
      # "account number".
      #
      # Example:
      #   token = ActiveMerchant::Billing::VantivGateway::Token.new(
      #     "1234567890",
      #     month: "9",
      #     year: "2021",
      #     verification_value: "424"
      #   )
      #
      # This is based on `PaymentToken` so all options are stored in the
      # metadata attribute.
      class Token < PaymentToken
        attr_reader :metadata

        alias litle_token payment_data

        def month
          metadata.fetch("month", "")
        end

        def verification_value
          metadata.fetch("verification_value", "")
        end

        def year
          metadata.fetch("year", "")
        end
      end

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

      # Public: Authorize that a customer has submitted a valid payment method
      # and that they have sufficient funds for the transation.
      #
      # Supported payment methods:
      #   * `CreditCard`
      #   * `NetworkTokenizationCreditCard`
      #   * `Token`
      #
      # Vantiv transaction: `authorization`
      def authorize(money, payment_method, options = {})
        request = build_authenticated_xml_request do |doc|
          doc.authorization(transaction_attributes(options)) do
            add_auth_purchase_params(doc, money, payment_method, options)
          end
        end

        commit(:authorization, request, money)
      end

      # Public: Capture the referenced authorization transaction to transfer
      # funds from the customer to the merchant.
      #
      # Supported authorization:
      #   * Authorization (`String`)
      #
      # Vantiv transaction: `capture`
      def capture(money, authorization, options = {})
        transaction_id, = split_authorization(authorization)

        request = build_authenticated_xml_request do |doc|
          doc.capture_(transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
            doc.amount(money) if money.present?
          end
        end

        commit(:capture, request, money)
      end

      # [DEPRECATED] Public: Refund money to a customer.
      #
      #  See `#refund`
      def credit(money, authorization, options = {})
        ActiveMerchant.deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end

      # Public: A single transaction to authorize and transfer funds from
      # the customer to the merchant.
      #
      # Supported payment methods:
      #   * `CreditCard`
      #   * `NetworkTokenizationCreditCard`
      #   * `Token`
      #
      # Vantiv transaction: `sale`
      def purchase(money, payment_method, options = {})
        kind = :sale
        request = build_authenticated_xml_request do |doc|
          if payment_method_is_check?(payment_method)
            doc.echeckSale(transaction_attributes(options)) do
              add_auth_purchase_params(doc, money, payment_method, options)
            end
            kind = :echeckSales
          else
            doc.sale(transaction_attributes(options)) do
              add_auth_purchase_params(doc, money, payment_method, options)
            end
          end
        end

        commit(kind, request, money)
      end

      # Public: Refund money to a customer.
      #
      # Supported authorization:
      #   * Authorization (`String`)
      #
      # Vantiv transaction: `credit`
      def refund(money, authorization, options = {})
        transaction_id, = split_authorization(authorization)

        request = build_authenticated_xml_request do |doc|
          doc.credit(transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
            doc.amount(money) if money.present?
            add_descriptor(doc, options)
          end
        end

        commit(:credit, request)
      end

      # Public: Scrub text for sensitive values.
      #
      # See `SCRUBBED_PATTERNS` above.
      def scrub(transcript)
        SCRUBBED_PATTERNS.inject(transcript) do |text, pattern|
          text.gsub(pattern, SCRUBBED_REPLACEMENT)
        end
      end

      # Public: Submit a payment method and receive a Vantiv token in return.
      #
      # Supported payment_methods:
      #   * `CreditCard`
      #   * PayPage registration Id (String)
      #
      # Vantiv transaction: `registerTokenRequest`
      def store(payment_method, options = {})
        request = build_authenticated_xml_request do |doc|
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

      # Public: Indicates if this gateway supports scrubbing.
      #
      # See `#scrub`
      def supports_scrubbing?
        true
      end

      # Public: Verify a customer's payment method by performing an
      # authorize and void.
      #
      # Note: This isn't a supported gateway function - it is a combination
      # of two actions. The `authorize` action must support the payment
      # method in order for this to work.
      #
      # Vantiv transactions: `authorize` + `void`
      def verify(payment_method, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, payment_method, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      # Public: Void (cancel) a transaction that occurred during the same
      # business day.
      #
      # Vantiv supports `void` transactions for:
      #  * `capture`
      #  * `credit` (refund)
      #  * `sale`
      #
      # This action checks if the `authorization` param is for an `authorize`
      # action. If so, an `authReversal` is submitted.
      #
      # Vantiv transaction: `void` or `authReversal`
      def void(authorization, options = {})
        transaction_id, kind, money = split_authorization(authorization)
        money = options[:amount] if options[:amount].present?

        request = build_authenticated_xml_request do |doc|
          doc.send(void_type(kind), transaction_attributes(options)) do
            doc.litleTxnId(transaction_id)
            doc.amount(money) if void_type(kind) == :authReversal
          end
        end

        commit(void_type(kind), request)
      end

    private

      # Private: Add address elements common to billing and shipping
      def add_address(doc, address, customer, options)
        doc.name(customer[:name]) unless customer[:name].blank?
        doc.firstName(customer[:first_name]) unless customer[:first_name].blank?
        doc.lastName(customer[:last_name]) unless customer[:last_name].blank?
        doc.addressLine1(address[:address1]) unless address[:address1].blank?
        doc.addressLine2(address[:address2]) unless address[:address2].blank?
        doc.city(address[:city]) unless address[:city].blank?
        doc.state(address[:state]) unless address[:state].blank?
        doc.zip(address[:zip]) unless address[:zip].blank?
        doc.country(address[:country]) unless address[:country].blank?
        doc.email(options[:email]) unless options[:email].blank?
        doc.phone(address[:phone]) unless address[:phone].blank?
      end

      def add_auth_purchase_params(doc, money, payment_method, options)
        doc.orderId(truncate(options[:order_id], 24))
        doc.amount(money)
        add_order_source(doc, payment_method, options)
        add_billing_address(doc, payment_method, options)
        add_shipping_address(doc, options)
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

      # Private: Add billing address information
      #
      # The `billToAddress` element is always added
      def add_billing_address(doc, payment_method, options)
        address = options[:billing_address] || {}
        customer = address_customer(payment_method, address)

        doc.billToAddress do
          add_address(doc, address, customer, options)
          doc.companyName(address[:company]) unless address[:company].blank?
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
        source = if options[:order_source]
                   options[:order_source]
                 elsif payment_method_is_apple_pay?(payment_method)
                   SOURCE_APPLE_PAY
                 elsif payment_method_has_track_data?(payment_method)
                   SOURCE_RETAIL
                 else
                   SOURCE_ECOMMERCE
                 end

        doc.orderSource(source)
      end

      def add_payment_method(doc, payment_method)
        if payment_method_is_check?(payment_method)
          doc.echeck do
            holder_type = payment_method.account_holder_type
            account_type = payment_method.account_type
            doc.accType(CHECK_TYPE[holder_type][account_type])
            doc.accNum(payment_method.account_number)
            doc.routingNum(payment_method.routing_number)

            check_number = payment_method.number
            doc.checkNum(check_number) if check_number.present?
          end
        elsif payment_method_is_token?(payment_method)
          doc.token do
            token = payment_method.litle_token
            doc.litleToken(token) if token.present?

            expiration = exp_date(payment_method)
            doc.expDate(expiration) if expiration.present?

            cvv = payment_method.verification_value
            doc.cardValidationNum(cvv) if cvv.present?
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

      # Private: Add shipping address information
      def add_shipping_address(doc, options)
        address = options[:shipping_address]
        return if address.blank?

        # Shipping address only accepts `name`
        customer = { name: address[:name] }

        doc.shipToAddress do
          add_address(doc, address, customer, options)
        end
      end

      # Private: Determine customer name attributes for an address
      def address_customer(payment_method, address)
        payment = {}

        {}.tap do |customer|
          %i[name first_name last_name].each do |attribute|
            # Get value from payment method if possible
            if payment_method_has_customer_name?(payment_method)
              payment[attribute] = payment_method.public_send(attribute)
            end

            # Payment method information takes precendence over address
            customer[attribute] = payment[attribute] || address[attribute]
          end
        end
      end

      def authorization_from(kind, parsed, money)
        if kind == :registerToken
          parsed[:litleToken]
        else
          "#{parsed[:litleTxnId]};#{kind};#{money}"
        end
      end

      # Private: Build the xml request and add authentication before yielding
      def build_authenticated_xml_request
        build_xml_request do |doc|
          add_authentication(doc)
          yield(doc)
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

      def payment_method_has_customer_name?(payment_method)
        payment_method.respond_to?(:name)
      end

      def payment_method_has_track_data?(payment_method)
        payment_method.respond_to?(:track_data) &&
          payment_method.track_data.present?
      end

      def payment_method_is_apple_pay?(payment_method)
        payment_method_is_network_tokenized?(payment_method) &&
          payment_method.source == :apple_pay
      end

      def payment_method_is_check?(payment_method)
        payment_method.is_a?(Check)
      end

      def payment_method_is_network_tokenized?(payment_method)
        payment_method.is_a?(NetworkTokenizationCreditCard)
      end

      # Limited support for paypage at this time - if string in that context
      # then it's a paypage registration id
      def payment_method_is_paypage_registration_id?(payment_method)
        payment_method.is_a?(String)
      end

      # TODO: Remove string check once `Token` is fully supported
      def payment_method_is_token?(payment_method)
        payment_method.is_a?(String) || payment_method.is_a?(Token)
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
        return @options[:url] if @options[:url].present?

        test? ? test_url : live_url
      end

      def void_type(kind)
        kind == VOID_TYPE_AUTHORIZATION ? :authReversal : :void
      end
    end
  end
end
