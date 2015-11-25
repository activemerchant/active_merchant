require 'nokogiri'

module ActiveMerchant
  module Billing
    class VancoGateway < Gateway
      include Empty

      self.test_url = 'https://www.vancodev.com/cgi-bin/wstest2.vps'
      self.live_url = 'https://www.vancoservices.com/cgi-bin/ws2.vps'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://vancopayments.com/'
      self.display_name = 'Vanco Payment Solutions'

      def initialize(options={})
        requires!(options, :user_id, :password, :client_id)
        super
      end

      def purchase(money, payment_method, options={})
        MultiResponse.run do |r|
          r.process { commit(login_request) }
          r.process { commit(purchase_request(money, payment_method, r.params["response_sessionid"], options)) }
        end
      end

      def refund(money, authorization, options={})
        MultiResponse.run do |r|
          r.process { commit(login_request) }
          r.process { commit(refund_request(money, authorization, r.params["response_sessionid"])) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<Password>).+(</Password>))i, '\1[FILTERED]\2').
          gsub(%r((<CardCVV2>).+(</CardCVV2>))i, '\1[FILTERED]\2').
          gsub(%r((<AccountNumber>).+(</AccountNumber>))i, '\1[FILTERED]\2')
      end

      private

      def parse(xml)
        response = {}

        doc = Nokogiri::XML(xml)
        doc.root.xpath('*').each do |node|
          if (node.elements.empty?)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              childnode_to_response(response, node, childnode)
            end
          end
        end

        response
      end

      def childnode_to_response(response, node, childnode)
        name = "#{node.name.downcase}_#{childnode.name.downcase}"
        if name == "response_errors" && !childnode.elements.empty?
          add_errors_to_response(response, childnode.to_s)
        else
          response[name.downcase.to_sym] = childnode.text
        end
      end

      def add_errors_to_response(response, errors_xml)
        errors_hash = Hash.from_xml(errors_xml).values.first
        response[:response_errors] = errors_hash

        error = errors_hash["Error"]
        if error.kind_of?(Hash)
          response[:error_message] = error["ErrorDescription"]
          response[:error_codes] = error["ErrorCode"]
        elsif error.kind_of?(Array)
          error_str = error.map { |e| e["ErrorDescription"]}.join(". ")
          error_codes = error.map { |e| e["ErrorCode"]}.join(", ")
          response[:error_message] = "#{error_str}."
          response[:error_codes] = error_codes
        end
      end

      def commit(request)
        response = parse(ssl_post(url, request, headers))

        succeeded = success_from(response)
        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        !response[:response_errors]
      end

      def message_from(succeeded, response)
        return "Success" if succeeded
        response[:error_message]
      end

      def authorization_from(response)
        [
          response[:response_customerref],
          response[:response_paymentmethodref],
          response[:response_transactionref]
        ].join("|")
      end

      def split_authorization(authorization)
        authorization.to_s.split('|')
      end

      def purchase_request(money, payment_method, session_id, options)
        build_xml_request do |doc|
          add_auth(doc, "EFTAddCompleteTransaction", session_id)

          doc.Request do
            doc.RequestVars do
              add_client_id(doc)
              add_amount(doc, money, options)
              add_payment_method(doc, payment_method, options)
              add_options(doc, options)
              add_purchase_noise(doc)
            end
          end
        end
      end

      def refund_request(money, authorization, session_id)
        build_xml_request do |doc|
          add_auth(doc, "EFTAddCredit", session_id)

          doc.Request do
            doc.RequestVars do
              add_client_id(doc)
              add_amount(doc, money, options)
              add_reference(doc, authorization)
              add_refund_noise(doc)
            end
          end
        end
      end

      def add_request(doc, request_type)
        doc.RequestType(request_type)
        doc.RequestID(SecureRandom.hex(15))
        doc.RequestTime(Time.now)
        doc.Version(2)
      end

      def add_auth(doc, request_type, session_id)
        doc.Auth do
          add_request(doc, request_type)
          doc.SessionID(session_id)
        end
      end

      def add_reference(doc, authorization)
        customer_ref, payment_method_ref, transaction_ref = split_authorization(authorization)
        doc.CustomerRef(customer_ref)
        doc.PaymentMethodRef(payment_method_ref)
        doc.TransactionRef(transaction_ref)
      end

      def add_amount(doc, money, options)
        if empty?(options[:fund_id])
          doc.Amount(amount(money))
        else
          doc.Funds do
            doc.Fund do
              doc.FundID(options[:fund_id])
              doc.FundAmount(amount(money))
            end
          end
        end
      end

      def add_payment_method(doc, payment_method, options)
        if card_brand(payment_method) == 'check'
          add_echeck(doc, payment_method)
        else
          add_credit_card(doc, payment_method, options)
        end
      end

      def add_credit_card(doc, credit_card, options)
        doc.AccountNumber(credit_card.number)
        doc.CustomerName("#{credit_card.last_name}, #{credit_card.first_name}")
        doc.CardExpMonth(format(credit_card.month, :two_digits))
        doc.CardExpYear(format(credit_card.year, :two_digits))
        doc.CardCVV2(credit_card.verification_value)
        doc.CardBillingName(credit_card.name)
        doc.AccountType("CC")
        add_billing_address(doc, options)
      end

      def add_billing_address(doc, options)
        address = options[:billing_address]
        return unless address

        doc.CardBillingAddr1(address[:address1])
        doc.CardBillingAddr2(address[:address2])
        doc.CardBillingCity(address[:city])
        doc.CardBillingState(address[:state])
        doc.CardBillingZip(address[:zip])
        doc.CardBillingCountryCode(address[:country])
      end

      def add_echeck(doc, echeck)
        if echeck.account_type == "savings"
          doc.AccountType("S")
        else
          doc.AccountType("C")
        end

        doc.CustomerName("#{echeck.last_name}, #{echeck.first_name}")
        doc.AccountNumber(echeck.account_number)
        doc.RoutingNumber(echeck.routing_number)
        doc.TransactionTypeCode("WEB")
      end

      def add_purchase_noise(doc)
        doc.StartDate("0000-00-00")
        doc.FrequencyCode("O")
      end

      def add_refund_noise(doc)
        doc.ContactName("Bilbo Baggins")
        doc.ContactPhone("1234567890")
        doc.ContactExtension("None")
        doc.ReasonForCredit("Refund requested")
      end

      def add_options(doc, options)
        doc.CustomerIPAddress(options[:ip]) if options[:ip]
      end

      def add_client_id(doc)
        doc.ClientID(@options[:client_id])
      end

      def login_request
        build_xml_request do |doc|
          doc.Auth do
            add_request(doc, "Login")
          end

          doc.Request do
            doc.RequestVars do
              doc.UserID(@options[:user_id])
              doc.Password(@options[:password])
            end
          end
        end
      end

      def build_xml_request
        builder = Nokogiri::XML::Builder.new
        builder.__send__("VancoWS") do |doc|
          yield(doc)
        end
        builder.to_xml
      end

      def url
        (test? ? test_url : live_url)
      end

      def headers
        {
          'Content-Type' => 'text/xml'
        }
      end

    end
  end
end
