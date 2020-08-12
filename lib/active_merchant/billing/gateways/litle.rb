require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class LitleGateway < Gateway
      SCHEMA_VERSION = '9.14'

      self.test_url = 'https://www.testvantivcnp.com/sandbox/communicator/online'
      self.live_url = 'https://payments.vantivcnp.com/vap/communicator/online'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb]

      self.homepage_url = 'http://www.vantiv.com/'
      self.display_name = 'Vantiv eCommerce'

      def initialize(options={})
        requires!(options, :login, :password, :merchant_id)
        super
      end

      def purchase(money, payment_method, options={})
        request = build_xml_request do |doc|
          add_authentication(doc)
          if check?(payment_method)
            doc.echeckSale(transaction_attributes(options)) do
              add_echeck_purchase_params(doc, money, payment_method, options)
            end
          else
            doc.sale(transaction_attributes(options)) do
              add_auth_purchase_params(doc, money, payment_method, options)
            end
          end
        end
        check?(payment_method) ? commit(:echeckSales, request, money) : commit(:sale, request, money)
      end

      def authorize(money, payment_method, options={})
        request = build_xml_request do |doc|
          add_authentication(doc)
          if check?(payment_method)
            doc.echeckVerification(transaction_attributes(options)) do
              add_echeck_purchase_params(doc, money, payment_method, options)
            end
          else
            doc.authorization(transaction_attributes(options)) do
              add_auth_purchase_params(doc, money, payment_method, options)
            end
          end
        end
        check?(payment_method) ? commit(:echeckVerification, request, money) : commit(:authorization, request, money)
      end

      def capture(money, authorization, options={})
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

      def refund(money, payment, options={})
        request = build_xml_request do |doc|
          add_authentication(doc)
          add_descriptor(doc, options)
          doc.send(refund_type(payment), transaction_attributes(options)) do
            if payment.is_a?(String)
              transaction_id, = split_authorization(payment)
              doc.litleTxnId(transaction_id)
              doc.amount(money) if money
            elsif check?(payment)
              add_echeck_purchase_params(doc, money, payment, options)
            else
              add_auth_purchase_params(doc, money, payment, options)
            end
          end
        end

        commit(refund_type(payment), request)
      end

      def verify(creditcard, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(0, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def void(authorization, options={})
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

      def store(payment_method, options = {})
        request = build_xml_request do |doc|
          add_authentication(doc)
          doc.registerTokenRequest(transaction_attributes(options)) do
            doc.orderId(truncate(options[:order_id], 24))
            if payment_method.is_a?(String)
              doc.paypageRegistrationId(payment_method)
            elsif check?(payment_method)
              doc.echeckForToken do
                doc.accNum(payment_method.account_number)
                doc.routingNum(payment_method.routing_number)
              end
            else
              doc.accountNumber(payment_method.number)
              doc.cardValidationNum(payment_method.verification_value) if payment_method.verification_value
            end
          end
        end

        commit(:registerToken, request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<user>).+(</user>)), '\1[FILTERED]\2').
          gsub(%r((<password>).+(</password>)), '\1[FILTERED]\2').
          gsub(%r((<number>).+(</number>)), '\1[FILTERED]\2').
          gsub(%r((<accNum>).+(</accNum>)), '\1[FILTERED]\2').
          gsub(%r((<routingNum>).+(</routingNum>)), '\1[FILTERED]\2').
          gsub(%r((<cardValidationNum>).+(</cardValidationNum>)), '\1[FILTERED]\2').
          gsub(%r((<accountNumber>).+(</accountNumber>)), '\1[FILTERED]\2').
          gsub(%r((<paypageRegistrationId>).+(</paypageRegistrationId>)), '\1[FILTERED]\2').
          gsub(%r((<authenticationValue>).+(</authenticationValue>)), '\1[FILTERED]\2')
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
        if kind == 'authorization'
          :authReversal
        elsif kind == 'echeckSales'
          :echeckVoid
        else
          :void
        end
      end

      def refund_type(payment)
        _, kind, = split_authorization(payment)
        if check?(payment) || kind == 'echeckSales'
          :echeckCredit
        else
          :credit
        end
      end

      def check?(payment_method)
        return false if payment_method.is_a?(String)

        card_brand(payment_method) == 'check'
      end

      def add_authentication(doc)
        doc.authentication do
          doc.user(@options[:login])
          doc.password(@options[:password])
        end
      end

      def add_auth_purchase_params(doc, money, payment_method, options)
        doc.orderId(truncate(options[:order_id], 24))
        doc.amount(money)
        add_order_source(doc, payment_method, options)
        add_billing_address(doc, payment_method, options)
        add_shipping_address(doc, payment_method, options)
        add_payment_method(doc, payment_method, options)
        add_pos(doc, payment_method)
        add_descriptor(doc, options)
        add_merchant_data(doc, options)
        add_debt_repayment(doc, options)
        add_stored_credential_params(doc, options)
      end

      def add_merchant_data(doc, options={})
        if options[:affiliate] || options[:campaign] || options[:merchant_grouping_id]
          doc.merchantData do
            doc.affiliate(options[:affiliate]) if options[:affiliate]
            doc.campaign(options[:campaign]) if options[:campaign]
            doc.merchantGroupingId(options[:merchant_grouping_id]) if options[:merchant_grouping_id]
          end
        end
      end

      def add_echeck_purchase_params(doc, money, payment_method, options)
        doc.orderId(truncate(options[:order_id], 24))
        doc.amount(money)
        add_order_source(doc, payment_method, options)
        add_billing_address(doc, payment_method, options)
        add_payment_method(doc, payment_method, options)
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

      def add_debt_repayment(doc, options)
        doc.debtRepayment(true) if options[:debt_repayment] == true
      end

      def add_payment_method(doc, payment_method, options)
        if payment_method.is_a?(String)
          doc.token do
            doc.litleToken(payment_method)
            doc.expDate(format_exp_date(options[:basis_expiration_month], options[:basis_expiration_year])) if options[:basis_expiration_month] && options[:basis_expiration_year]
          end
        elsif payment_method.respond_to?(:track_data) && payment_method.track_data.present?
          doc.card do
            doc.track(payment_method.track_data)
          end
        elsif check?(payment_method)
          doc.echeck do
            doc.accType(payment_method.account_type.capitalize)
            doc.accNum(payment_method.account_number)
            doc.routingNum(payment_method.routing_number)
            doc.checkNum(payment_method.number) if payment_method.number
          end
        else
          doc.card do
            doc.type_(CARD_TYPE[payment_method.brand])
            doc.number(payment_method.number)
            doc.expDate(exp_date(payment_method))
            doc.cardValidationNum(payment_method.verification_value)
          end
          if payment_method.is_a?(NetworkTokenizationCreditCard)
            doc.cardholderAuthentication do
              doc.authenticationValue(payment_method.payment_cryptogram)
            end
          elsif options[:order_source]&.start_with?('3ds')
            doc.cardholderAuthentication do
              doc.authenticationValue(options[:cavv]) if options[:cavv]
              doc.authenticationTransactionId(options[:xid]) if options[:xid]
            end
          end
        end
      end

      def add_stored_credential_params(doc, options={})
        return unless options[:stored_credential]

        if options[:stored_credential][:initial_transaction]
          add_stored_credential_params_initial(doc, options)
        else
          add_stored_credential_params_used(doc, options)
        end
      end

      def add_stored_credential_params_initial(doc, options)
        case options[:stored_credential][:reason_type]
        when 'unscheduled'
          doc.processingType('initialCOF')
        when 'installment'
          doc.processingType('initialInstallment')
        when 'recurring'
          doc.processingType('initialRecurring')
        end
      end

      def add_stored_credential_params_used(doc, options)
        if options[:stored_credential][:reason_type] == 'unscheduled'
          if options[:stored_credential][:initiator] == 'merchant'
            doc.processingType('merchantInitiatedCOF')
          else
            doc.processingType('cardholderInitiatedCOF')
          end
        end
        doc.originalNetworkTransactionId(options[:stored_credential][:network_transaction_id])
      end

      def add_billing_address(doc, payment_method, options)
        return if payment_method.is_a?(String)

        doc.billToAddress do
          if check?(payment_method)
            doc.name(payment_method.name)
            doc.firstName(payment_method.first_name)
            doc.lastName(payment_method.last_name)
          else
            doc.name(payment_method.name)
          end
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
        order_source = order_source(options)
        if order_source
          doc.orderSource(order_source)
        elsif payment_method.is_a?(NetworkTokenizationCreditCard) && payment_method.source == :apple_pay
          doc.orderSource('applepay')
        elsif payment_method.is_a?(NetworkTokenizationCreditCard) && payment_method.source == :android_pay
          doc.orderSource('androidpay')
        elsif payment_method.respond_to?(:track_data) && payment_method.track_data.present?
          doc.orderSource('retail')
        else
          doc.orderSource('ecommerce')
        end
      end

      def order_source(options={})
        return options[:order_source] unless options[:stored_credential]

        order_source = nil

        case options[:stored_credential][:reason_type]
        when 'unscheduled'
          if options[:stored_credential][:initiator] == 'merchant'
            # For merchant-initiated, we should always set order source to
            # 'ecommerce'
            order_source = 'ecommerce'
          else
            # For cardholder-initiated, we rely on #add_order_source's
            # default logic to set orderSource appropriately
            order_source = options[:order_source]
          end
        when 'installment'
          order_source = 'installment'
        when 'recurring'
          order_source = 'recurring'
        end

        order_source
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
        format_exp_date(payment_method.month, payment_method.year)
      end

      def format_exp_date(month, year)
        "#{format(month, :two_digits)}#{format(year, :two_digits)}"
      end

      def parse(kind, xml)
        parsed = {}

        doc = Nokogiri::XML(xml).remove_namespaces!
        doc.xpath("//litleOnlineResponse/#{kind}Response/*").each do |node|
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
          %w(response message).each do |attribute|
            parsed[attribute.to_sym] = doc.xpath('//litleOnlineResponse').attribute(attribute).value
          end
        end

        parsed
      end

      def commit(kind, request, money=nil)
        parsed = parse(kind, ssl_post(url, request, headers))

        options = {
          authorization: authorization_from(kind, parsed, money),
          test: test?,
          avs_result: { code: AVS_RESPONSE_CODE[parsed[:fraudResult_avsResult]] },
          cvv_result: parsed[:fraudResult_cardValidationResult]
        }

        Response.new(success_from(kind, parsed), parsed[:message], parsed, options)
      end

      def success_from(kind, parsed)
        return (parsed[:response] == '000') unless kind == :registerToken

        %w(000 801 802).include?(parsed[:response])
      end

      def authorization_from(kind, parsed, money)
        kind == :registerToken ? parsed[:litleToken] : "#{parsed[:litleTxnId]};#{kind};#{money}"
      end

      def split_authorization(authorization)
        transaction_id, kind, money = authorization.to_s.split(';')
        [transaction_id, kind, money]
      end

      def transaction_attributes(options)
        attributes = {}
        attributes[:id] = truncate(options[:id] || options[:order_id], 24)
        attributes[:reportGroup] = options[:merchant] || 'Default Report Group'
        attributes[:customerId] = options[:customer]
        attributes.delete_if { |key, value| value == nil }
        attributes
      end

      def root_attributes
        {
          merchantId: @options[:merchant_id],
          version: SCHEMA_VERSION,
          xmlns: 'http://www.litle.com/schema'
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

      def headers
        {
          'Content-Type' => 'text/xml'
        }
      end
    end
  end
end
