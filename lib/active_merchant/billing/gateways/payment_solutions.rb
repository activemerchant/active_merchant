require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymentSolutionsGateway < Gateway
      include Empty
      self.test_url = 'https://staging.paymentsolutionsinc.net/Services/Aspca/Payment/PsiWcfService.svc'
      self.live_url = 'https://client.paymentsolutionsinc.net/Services/Payment/PsiWcfService.svc'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://paymentsolutionsinc.net/'
      self.display_name = 'Payment Solutions Inc'

      APPROVED, DECLINED, ERROR, FRAUD_REVIEW = 1, 2, 3, 4
      SOAP_ACTION_NS = 'http://www.paymentsolutionsinc.net/IPsiService/'
      SOAP_XMLNS = { xmlns: 'http://www.paymentsolutionsinc.net/' }
      PSI_NS = {
        'xmlns:d4p1' => 'http://schemas.datacontract.org/2004/07/PsiService',
        'xmlns:i' => 'http://www.w3.org/2001/XMLSchema-instance'
      }
      ENV_NS = { 'xmlns:s' => 'http://schemas.xmlsoap.org/soap/envelope/' }
      NS = {
        'xmlns:xsi'  => 'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:env'  => 'http://schemas.xmlsoap.org/soap/envelope/',
        'xmlns:ins0' => 'http://schemas.datacontract.org/2004/07/PsiService'
      }
      CARD_TYPE_MAP = {
        :visa => 'Visa',
        :master => 'MasterCard',
        :american_express => 'AmericanExpress',
        :discover => 'Discover'
      }

      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      def test_connection(message, options={})
        request = build_soap_request do |xml|
          xml.TestConnection(SOAP_XMLNS) do
            add_message(xml, message)
          end
        end

        commit('TestConnection', request)
      end

      def purchase(money, payment, options={})
        request = build_soap_request do |xml|
          xml.SendCreditCardPayment(SOAP_XMLNS) do
            add_authentication(xml, options)
            xml.paymentInfo(PSI_NS) do
              add_amount(xml, money)
              add_order_id(xml, options)
              add_credit_card(xml, payment, options)
              add_customer_data(xml, payment, options)
              add_payment(xml, options)
            end
          end
        end

        commit('SendCreditCardPayment', request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<d4p1:UserName>)[^<]*(</d4p1:UserName>))i, '\1[FILTERED]\2').
          gsub(%r((<d4p1:Password>)[^<]*(</d4p1:Password>))i, '\1[FILTERED]\2').
          gsub(%r((<d4p1:CardNo>).+(</d4p1:CardNo>))i, '\1[FILTERED]\2').
          gsub(%r((<d4p1:Cvv>).+(</d4p1:Cvv>))i, '\1[FILTERED]\2')
      end

      private

      def add_message(xml, message)
        xml.message message
      end

      def add_customer_data(xml, payment, options)
        xml['d4p1'].Donor do
          address = options[:billing_address] || options[:address]
          xml['d4p1'].Address1 address[:address1] if address[:address1]
          xml['d4p1'].City address[:city] if address[:city]
          xml['d4p1'].Employer nil
          xml['d4p1'].FirstName payment.first_name
          xml['d4p1'].LastName payment.last_name
          xml['d4p1'].Phone address[:phone] if address[:phone]
          xml['d4p1'].PostalCode address[:zip] if address[:zip]
          xml['d4p1'].SendEmail address[:email].present?
          xml['d4p1'].StateProvince address[:state] if address[:state]
          xml['d4p1'].Address2 address[:address2] if address[:address2]
          xml['d4p1'].Country address[:country] if address[:country]
          xml['d4p1'].Email address[:email] if address[:email]
        end
      end

      def add_order_id(xml, options)
        xml['d4p1'].ClientTransactionId truncate(options[:order_id], 20)
      end

      def add_amount(xml, money)
        xml['d4p1'].Amount amount(money)
      end

      def add_payment(xml, options={})
        xml['d4p1'].Frequency empty?(options[:frequency]) ? 'Monthly' : options[:frequency]
        xml['d4p1'].MarketSource truncate(options[:market_source], 200) if options[:market_source].present?
        xml['d4p1'].PayCode options[:pay_code] if options[:pay_code].present?
        xml['d4p1'].PayType empty?(options[:pay_type]) ? 'OneTime' : options[:pay_type]
        xml['d4p1'].ProcessDateTime Time.current.strftime("%FT%T")
        xml['d4p1'].ProgramCode options[:program_code] if options[:program_code].present?
      end

      def add_credit_card(xml, payment, options={})
        xml['d4p1'].CreditCard do
          xml['d4p1'].CardNo payment.number
          xml['d4p1'].ExpMonth format(payment.month, :two_digits)
          xml['d4p1'].ExpYear format(payment.year, :four_digits)
          xml['d4p1'].Cvv payment.verification_value if payment.verification_value.present?
          xml['d4p1'].Type CARD_TYPE_MAP[card_brand(payment).to_sym]
        end
      end

      def parse(body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!

        response = {}

        response[:response_code] = if(element = doc.at_xpath("//SendCreditCardPaymentResult/ResponseCode"))
          (empty?(element.content) ? nil : element.content.to_i)
        end

        response[:response_message] = if(element = doc.at_xpath("//SendCreditCardPaymentResult/ResponseMessage"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:transaction_id] = if(element = doc.at_xpath("//SendCreditCardPaymentResult/ClientTransactionId"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:authorization_code] = if(element = doc.at_xpath("//SendCreditCardPaymentResult/AuthorizationCode"))
          (empty?(element.content) ? nil : element.content)
        end

        response[:approved] = if(element = doc.at_xpath("//SendCreditCardPaymentResult/Approved"))
          (empty?(element.content) ? false : element.content)
        end

        response
      end

      def headers(action)
        {
          'Content-Type'    => 'text/xml',
          'SOAPAction'      => "#{SOAP_ACTION_NS}#{action}",
          'Accept-Encoding' => 'identity'
        }
      end

      def url
        test? ? test_url : live_url
      end

      def commit(action, xml, amount=nil)
        response = parse(ssl_post(url, xml, headers(action)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response[:approved] == 'true' && response[:response_code] == APPROVED
      end

      def message_from(response)
        response[:response_message]
      end

      def authorization_from(response)
        response[:authorization_code]
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['s'].Envelope(ENV_NS) do

            xml['s'].Body do
              yield(xml)
            end
          end
        end

        builder.to_xml
      end

      def add_authentication(xml, options={})
        xml.credentials(PSI_NS) do
          xml['d4p1'].Password @options[:password]
          xml['d4p1'].SourceIpAddress options[:ip] unless empty?(options[:ip])
          xml['d4p1'].UserName @options[:username]
        end
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
