require 'nokogiri'
require 'securerandom'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ElementGateway < Gateway
      self.test_url = 'https://certtransaction.elementexpress.com/express.asmx'
      self.live_url = 'https://transaction.elementexpress.com/express.asmx'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      self.homepage_url = 'http://www.elementps.com'
      self.display_name = 'Element'

      SERVICE_TEST_URL = 'https://certservices.elementexpress.com/express.asmx'
      SERVICE_LIVE_URL = 'https://service.elementexpress.com/express.asmx'

      def initialize(options={})
        requires!(options, :account_id, :account_token, :application_id, :acceptor_id, :application_name, :application_version)
        super
      end

      def purchase(money, payment, options={})
        action = payment.is_a?(Check) ? "CheckSale" : "CreditCardSale"

        request = build_soap_request do |xml|
          xml.send(action, xmlns: "https://transaction.elementexpress.com") do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
            add_address(xml, options)
          end
        end

        commit(action, request, money)
      end

      def authorize(money, payment, options={})
        request = build_soap_request do |xml|
          xml.CreditCardAuthorization(xmlns: "https://transaction.elementexpress.com") do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
            add_address(xml, options)
          end
        end

        commit('CreditCardAuthorization', request, money)
      end

      def capture(money, authorization, options={})
        trans_id, _ = split_authorization(authorization)
        options.merge!({trans_id: trans_id})

        request = build_soap_request do |xml|
          xml.CreditCardAuthorizationCompletion(xmlns: "https://transaction.elementexpress.com") do
            add_credentials(xml)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
          end
        end

        commit('CreditCardAuthorizationCompletion', request, money)
      end

      def refund(money, authorization, options={})
        trans_id, _ = split_authorization(authorization)
        options.merge!({trans_id: trans_id})

        request = build_soap_request do |xml|
          xml.CreditCardReturn(xmlns: "https://transaction.elementexpress.com") do
            add_credentials(xml)
            add_transaction(xml, money, options)
            add_terminal(xml, options)
          end
        end

        commit('CreditCardReturn', request, money)
      end

      def void(authorization, options={})
        trans_id, trans_amount = split_authorization(authorization)
        options.merge!({trans_id: trans_id, trans_amount: trans_amount, reversal_type: "Full"})

        request = build_soap_request do |xml|
          xml.CreditCardReversal(xmlns: "https://transaction.elementexpress.com") do
            add_credentials(xml)
            add_transaction(xml, trans_amount, options)
            add_terminal(xml, options)
          end
        end

        commit('CreditCardReversal', request, trans_amount)
      end

      def store(payment, options = {})
        request = build_soap_request do |xml|
          xml.PaymentAccountCreate(xmlns: "https://services.elementexpress.com") do
            add_credentials(xml)
            add_payment_method(xml, payment)
            add_payment_account(xml, payment, options[:payment_account_reference_number] || SecureRandom.hex(20))
            add_address(xml, options)
          end
        end

        commit('PaymentAccountCreate', request, nil)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
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
        xml.credentials do
          xml.AccountID @options[:account_id]
          xml.AccountToken @options[:account_token]
          xml.AcceptorID @options[:acceptor_id]
        end
        xml.application do
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
        else
          add_credit_card(xml, payment)
        end
      end

      def add_payment_account(xml, payment, payment_account_reference_number)
        xml.paymentAccount do
          xml.PaymentAccountType payment_account_type(payment)
          xml.PaymentAccountReferenceNumber payment_account_reference_number
        end
      end

      def add_payment_account_id(xml, payment)
        xml.extendedParameters do
          xml.ExtendedParameters do
            xml.Key "PaymentAccount"
            xml.Value("xsi:type" => "PaymentAccount") do
              xml.PaymentAccountID payment
            end
          end
        end
      end

      def add_transaction(xml, money, options = {})
        xml.transaction do
          xml.ReversalType options[:reversal_type] if options[:reversal_type]
          xml.TransactionID options[:trans_id] if options[:trans_id]
          xml.TransactionAmount amount(money.to_i) if money
          xml.MarketCode "Default" if money
          xml.ReferenceNumber options[:order_id] || SecureRandom.hex(20)
        end
      end

      def add_terminal(xml, options)
        xml.terminal do
          xml.TerminalID "01"
          xml.CardPresentCode "UseDefault"
          xml.CardholderPresentCode "UseDefault"
          xml.CardInputCode "UseDefault"
          xml.CVVPresenceCode "UseDefault"
          xml.TerminalCapabilityCode "UseDefault"
          xml.TerminalEnvironmentCode "UseDefault"
          xml.MotoECICode "NonAuthenticatedSecureECommerceTransaction"
        end
      end

      def add_credit_card(xml, payment)
        xml.card do
          xml.CardNumber payment.number
          xml.ExpirationMonth format(payment.month, :two_digits)
          xml.ExpirationYear format(payment.year, :two_digits)
          xml.CardholderName payment.first_name + " " + payment.last_name
          xml.CVV payment.verification_value
        end
      end

      def add_echeck(xml, payment)
        xml.demandDepositAccount do
          xml.AccountNumber payment.account_number
          xml.RoutingNumber payment.routing_number
          xml.DDAAccountType payment.account_type.capitalize
        end
      end

      def add_address(xml, options)
        if address = options[:billing_address] || options[:address]
          xml.address do
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
          xml.address do
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
        root = doc.root.xpath("//response/*")

        if root.empty?
          root = doc.root.xpath("//Response/*")
        end

        root.each do |node|
          if (node.elements.empty?)
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
        if action == "PaymentAccountCreate"
          response["paymentaccount"]["paymentaccountid"]
        else
          "#{response['transaction']['transactionid']}|#{amount}" if response['transaction']
        end
      end

      def success_from(response)
        response["expressresponsecode"] == "0"
      end

      def message_from(response)
        response["expressresponsemessage"]
      end

      def avs_from(response)
        AVSResult.new(code: response["card"]["avsresponsecode"]) if response["card"]
      end

      def cvv_from(response)
        CVVResult.new(response["card"]["cvvresponsecode"]) if response["card"]
      end

      def split_authorization(authorization)
        authorization.split("|")
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['soap'].Envelope('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                               'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                               'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/') do

            xml['soap'].Body do
              yield(xml)
            end
          end
        end

        builder.to_xml
      end

      def payment_account_type(payment)
        if payment.is_a?(Check)
          payment_account_type = payment.account_type
        else
          payment_account_type = "CreditCard"
        end
        payment_account_type
      end

      def url(action)
        if action == "PaymentAccountCreate"
          url = (test? ? SERVICE_TEST_URL : SERVICE_LIVE_URL)
        else
          url = (test? ? test_url : live_url)
        end
      end

      def interface(action)
        return "transaction" if action != "PaymentAccountCreate"
        return "services" if action == "PaymentAccountCreate"
      end

      def headers(action)
        {
          "Content-Type" => "text/xml; charset=utf-8",
          "SOAPAction" => "https://#{interface(action)}.elementexpress.com/#{action}"
        }
      end
    end
  end
end
