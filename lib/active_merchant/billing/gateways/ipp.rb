require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IppGateway < Gateway
      self.test_url = 'https://demo.ippayments.com.au/interface/api/dts.asmx'
      self.live_url = 'https://www.ippayments.com.au/interface/api/dts.asmx'

      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      self.homepage_url = 'http://www.ippayments.com.au/'
      self.display_name = 'IPP'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :login, :password)
        super
      end

      def purchase(money, payment, options={})
        data = new_ipp_submit_single_payment_xml do |xml|
          xml << "<![CDATA[\n"
          xml << new_ipp_submit_single_payment_credit_xml(money, payment, options)
          xml << "]]>\n"
        end
        commit("http://www.ippayments.com.au/interface/api/dts/SubmitSinglePayment", data)
      end

      private

      def new_xml
        xml = Builder::XmlMarkup.new(:indent => 2)
        yield xml
        xml.target!
      end

      def new_ipp_xml
        new_xml do |xml|
          xml.instruct!
          xml.soap :Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/" do
            xml.soap :Body do
              yield xml
            end
          end
        end
      end

      def new_ipp_submit_single_payment_xml
        new_ipp_xml do |xml|
          xml.SubmitSinglePayment "xmlns" => "http://www.ippayments.com.au/interface/api/dts" do
            xml.trnXML do
              yield xml
            end
          end
        end
      end

      def new_ipp_submit_single_payment_credit_xml(money, payment, options)
        new_xml do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            xml.Amount money.to_s
            xml.TrnType "1"
            xml.CreditCard :Registered => "False" do
              xml.CardNumber payment.number
              xml.ExpM format(payment.month, :two_digits)
              xml.ExpY format(payment.year, :four_digits)
              xml.CVN payment.verification_value
              xml.CardHolderName payment.name
            end
            xml.Security do
              xml.UserName @options[:login]
              xml.Password @options[:password]
            end
            xml.TrnSource options[:ip]
          end
        end
      end

      def parse_response(body)
        response = {}
        doc = Nokogiri::XML(body)
        doc.root.elements.each do |e|
          response[e.name.underscore.to_sym] = e.inner_text
        end
        response
      end

      def parse(body)
        doc = Nokogiri::XML(body)
        parse_response(doc.root.first_element_child.first_element_child.inner_text)
      end

      def commit(action, data)
        url = (test? ? test_url : live_url)
        headers = {
          "Content-Type" => "text/xml; charset=utf-8",
          "SOAPAction" => action,
        }
        response = parse(ssl_post(url, data, headers))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response[:response_code] == "0"
      end

      def message_from(response)
        response[:declined_message]
      end

      def authorization_from(response)
        response[:receipt]
      end
    end
  end
end
