require 'nokogiri'
require 'securerandom'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ElementGateway < Gateway
      self.test_url = 'https://certtransaction.elementexpress.com'
      self.live_url = 'https://transaction.elementexpress.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover diners_club jcb]

      self.homepage_url = 'http://www.elementps.com'
      self.display_name = 'Element'

      SERVICE_TEST_URL = 'https://certservices.elementexpress.com'
      SERVICE_LIVE_URL = 'https://services.elementexpress.com'

      NETWORK_TOKEN_TYPE = {
        apple_pay: '2',
        google_pay: '1'
      }

      def initialize(options = {})
        requires!(options, :account_id, :account_token, :application_id, :acceptor_id, :application_name, :application_version)
        super
      end

      def purchase(money, payment, options = {})
        action = payment.is_a?(Check) ? 'CheckSale' : 'CreditCardSale'

        request = build_soap_request do |xml|
          xml.send(action, xmlns: 'https://transaction.elementexpress.com') do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
            add_address(xml, options)
          end
        end

        commit(action, request, money)
      end

      def authorize(money, payment, options = {})
        request = build_soap_request do |xml|
          xml.CreditCardAuthorization(xmlns: 'https://transaction.elementexpress.com') do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
            add_address(xml, options)
          end
        end

        commit('CreditCardAuthorization', request, money)
      end

      def capture(money, authorization, options = {})
        trans_id, = split_authorization(authorization)
        options[:trans_id] = trans_id

        request = build_soap_request do |xml|
          xml.CreditCardAuthorizationCompletion(xmlns: 'https://transaction.elementexpress.com') do
            add_credentials(xml)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
          end
        end

        commit('CreditCardAuthorizationCompletion', request, money)
      end

      def refund(money, authorization, options = {})
        trans_id, = split_authorization(authorization)
        options[:trans_id] = trans_id

        request = build_soap_request do |xml|
          xml.CreditCardReturn(xmlns: 'https://transaction.elementexpress.com') do
            add_credentials(xml)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
          end
        end

        commit('CreditCardReturn', request, money)
      end

      def credit(money, payment, options = {})
        request = build_soap_request do |xml|
          xml.CreditCardCredit(xmlns: 'https://transaction.elementexpress.com') do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
          end
        end

        commit('CreditCardCredit', request, money)
      end

      def void(authorization, options = {})
        trans_id, trans_amount = split_authorization(authorization)
        options.merge!({ trans_id: trans_id, trans_amount: trans_amount, reversal_type: '1' }) #Integer Enum replaced String Enum for ReversalType in XML API

        request = build_soap_request do |xml|
          xml.CreditCardReversal(xmlns: 'https://transaction.elementexpress.com') do
            add_credentials(xml)
            add_transaction(xml, trans_amount, options)
            add_terminal(xml, options)
          end
        end

        commit('CreditCardReversal', request, trans_amount)
      end

      def store(payment, options = {})
        request = build_soap_request do |xml|
          xml.PaymentAccountCreate(xmlns: 'https://services.elementexpress.com') do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_payment_account(xml, payment, options[:payment_account_reference_number] || SecureRandom.hex(20))
            add_address(xml, options)
          end
        end

        commit('PaymentAccountCreate', request, nil)
      end

      def verify(credit_card, options = {})
        request = build_soap_request do |xml|
          xml.CreditCardAVSOnly(xmlns: 'https://transaction.elementexpress.com') do
            add_credentials(xml)
            add_payment_method(xml, credit_card)
            add_transaction(xml, 0, options)
            add_terminal(xml, options)
            add_address(xml, options)
          end
        end

        # send request with the transaction amount set to 0
        commit('CreditCardAVSOnly', request, 0)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<AccountToken>).+?(</AccountToken>))i, '\1[FILTERED]\2').
          gsub(%r((<CardNumber>).+?(</CardNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<CVV>).+?(</CVV>))i, '\1[FILTERED]\2').
          gsub(%r((<AccountNumber>).+?(</AccountNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<RoutingNumber>).+?(</RoutingNumber>))i, '\1[FILTERED]\2')
      end

      private

      def add_credentials(xml)
        xml.Credentials do
          xml.AccountID @options[:account_id]
          xml.AccountToken @options[:account_token]
          xml.AcceptorID @options[:acceptor_id]
        end
        xml.Application do
          xml.ApplicationID @options[:application_id]
          xml.ApplicationName @options[:application_name]
          xml.ApplicationVersion @options[:application_version]
        end
      end

      def add_payment_method(xml, payment)
        if payment.is_a?(String)
          add_payment_account_id(xml, payment)
        elsif payment.is_a?(Check)
          add_echeck(xml, payment)
        elsif payment.is_a?(NetworkTokenizationCreditCard)
          add_network_tokenization_card(xml, payment)
        else
          add_credit_card(xml, payment)
        end
      end

      def add_payment_account(xml, payment, payment_account_reference_number)
        xml.PaymentAccount do
          xml.PaymentAccountType payment_account_type(payment)
          xml.PaymentAccountReferenceNumber payment_account_reference_number
        end
      end

      def add_payment_account_id(xml, payment)
        xml.ExtendedParameters do
          xml.Key 'PaymentAccount'
          xml.Value('xsi:type' => 'PaymentAccount') do
            xml.PaymentAccountID payment
          end
        end
      end

      def add_transaction(xml, money, options = {})
        xml.Transaction do
          xml.ReversalType options[:reversal_type] if options[:reversal_type]
          xml.TransactionID options[:trans_id] if options[:trans_id]
          xml.TransactionAmount amount(money.to_i) if money
          xml.MarketCode market_code(money, options) if options[:market_code] || money
          xml.ReferenceNumber options[:order_id].present? ? options[:order_id][0, 50] : SecureRandom.hex(20)
          xml.TicketNumber options[:ticket_number] if options[:ticket_number]
          xml.MerchantSuppliedTransactionID options[:merchant_supplied_transaction_id] if options[:merchant_supplied_transaction_id]
          xml.PaymentType options[:payment_type] if options[:payment_type]
          xml.SubmissionType options[:submission_type] if options[:submission_type]
          xml.DuplicateCheckDisableFlag options[:duplicate_check_disable_flag].to_s == 'true' ? 'True' : 'False' unless options[:duplicate_check_disable_flag].nil?
          xml.DuplicateOverrideFlag options[:duplicate_override_flag].to_s == 'true' ? 'True' : 'False' unless options[:duplicate_override_flag].nil?
          xml.MerchantDescriptor options[:merchant_descriptor] if options[:merchant_descriptor]
        end
      end

      def market_code(money, options)
        options[:market_code] || '0'
      end

      def add_terminal(xml, options)
        xml.Terminal do
          xml.TerminalID options[:terminal_id] || '01'
          xml.CardPresentCode options[:card_present_code] || '0'
          xml.CardholderPresentCode '0'
          xml.CardInputCode '0'
          xml.CVVPresenceCode '0'
          xml.TerminalCapabilityCode '0'
          xml.TerminalEnvironmentCode '0'
          xml.MotoECICode '0'
        end
      end

      def add_credit_card(xml, payment)
        xml.Card do
          xml.CardNumber payment.number
          xml.ExpirationMonth format(payment.month, :two_digits)
          xml.ExpirationYear format(payment.year, :two_digits)
          xml.CardholderName payment.first_name + ' ' + payment.last_name
          xml.CVV payment.verification_value
        end
      end

      def add_echeck(xml, payment)
        xml.DemandDepositAccount do
          xml.AccountNumber payment.account_number
          xml.RoutingNumber payment.routing_number
          xml.DDAAccountType payment.account_type.capitalize
        end
      end

      def add_network_tokenization_card(xml, payment)
        xml.Card do
          xml.CardNumber payment.number
          xml.ExpirationMonth format(payment.month, :two_digits)
          xml.ExpirationYear format(payment.year, :two_digits)
          xml.CardholderName "#{payment.first_name} #{payment.last_name}"
          xml.Cryptogram payment.payment_cryptogram
          #xml.ElectronicCommerceIndicator payment.eci if payment.eci.present? #MotoECICode in Terminal tag replaces this field's purpose for the XML API
          xml.WalletType NETWORK_TOKEN_TYPE.fetch(payment.source, '0')
        end
      end

      def add_address(xml, options)
        if address = options[:billing_address] || options[:address]
          address[:email] ||= options[:email]
          xml.Address do
            xml.BillingAddress1 address[:address1] if address[:address1]
            xml.BillingAddress2 address[:address2] if address[:address2]
            xml.BillingCity address[:city] if address[:city]
            xml.BillingState address[:state] if address[:state]
            xml.BillingZipcode address[:zip] if address[:zip]
            xml.BillingEmail address[:email] if address[:email]
            xml.BillingPhone address[:phone_number] if address[:phone_number]
          end
        end
        if shipping_address = options[:shipping_address]
          xml.Address do
            xml.ShippingAddress1 shipping_address[:address1] if shipping_address[:address1]
            xml.ShippingAddress2 shipping_address[:address2] if shipping_address[:address2]
            xml.ShippingCity shipping_address[:city] if shipping_address[:city]
            xml.ShippingState shipping_address[:state] if shipping_address[:state]
            xml.ShippingZipcode shipping_address[:zip] if shipping_address[:zip]
            xml.ShippingEmail shipping_address[:email] if shipping_address[:email]
            xml.ShippingPhone shipping_address[:phone_number] if shipping_address[:phone_number]
          end
        end
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        root = doc.root.xpath('//response/*')

        root = doc.root.xpath('//Response/*') if root.empty?

        root.each do |node|
          if node.elements.empty?
            response[node.name.downcase] = node.text
          else
            node_name = node.name.downcase
            response[node_name] = Hash.new

            node.elements.each do |childnode|
              response[node_name][childnode.name.downcase] = childnode.text
            end
          end
        end

        response
      end

      def commit(action, xml, amount)
        response = parse(ssl_post(url(action), xml, headers(action)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(action, response, amount),
          avs_result: success_from(response) ? avs_from(response) : nil,
          cvv_result: success_from(response) ? cvv_from(response) : nil,
          test: test?
        )
      end

      def authorization_from(action, response, amount)
        if action == 'PaymentAccountCreate'
          response['paymentaccount']['paymentaccountid']
        else
          "#{response['transaction']['transactionid']}|#{amount}" if response['transaction']
        end
      end

      def success_from(response)
        response['expressresponsecode'] == '0'
      end

      def message_from(response)
        response['expressresponsemessage']
      end

      def avs_from(response)
        AVSResult.new(code: response['card']['avsresponsecode']) if response['card']
      end

      def cvv_from(response)
        CVVResult.new(response['card']['cvvresponsecode']) if response['card']
      end

      def split_authorization(authorization)
        authorization.split('|')
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          yield(xml)
        end

        builder.to_xml
      end

      def payment_account_type(payment)
        if payment.is_a?(Check)
          payment_account_type = '1'
        else
          payment_account_type = '0'
        end
        payment_account_type
      end

      def url(action)
        if action == 'PaymentAccountCreate'
          test? ? SERVICE_TEST_URL : SERVICE_LIVE_URL
        else
          test? ? test_url : live_url
        end
      end

      def interface(action)
        return 'transaction' if action != 'PaymentAccountCreate'
        return 'services' if action == 'PaymentAccountCreate'
      end

      def headers(action)
        {
          'Content-Type' => 'text/xml'
        }
      end
    end
  end
end
