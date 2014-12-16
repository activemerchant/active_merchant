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
        data = new_submit_single_payment_ipp_xml do |xml|
          xml << "<![CDATA[\n"
          xml << new_submit_single_payment_credit_purchase_xml(money, payment, options)
          xml << "]]>\n"
        end
        commit("http://www.ippayments.com.au/interface/api/dts/SubmitSinglePayment", data)
      end

      def authorize(money, payment, options={})
        data = new_submit_single_payment_ipp_xml do |xml|
          xml << "<![CDATA[\n"
          xml << new_submit_single_payment_credit_authorize_xml(money, payment, options)
          xml << "]]>\n"
        end
        commit("http://www.ippayments.com.au/interface/api/dts/SubmitSinglePayment", data)
      end

      def capture(money, authorization, options={})
        data = new_submit_single_capture_ipp_xml do |xml|
          xml << "<![CDATA[\n"
          xml << new_submit_single_capture_xml(money, authorization, options)
          xml << "]]>\n"
        end
        commit("http://www.ippayments.com.au/interface/api/dts/SubmitSingleCapture", data)
      end

      def void(authorization, options={})
        new_void_response(authorization)
      end

      def refund(money, authorization, options={})
        data = new_submit_single_refund_ipp_xml do |xml|
          xml << "<![CDATA[\n"
          xml << new_submit_single_refund_xml(money, authorization, options)
          xml << "]]>\n"
        end
        commit("http://www.ippayments.com.au/interface/api/dts/SubmitSingleRefund", data)
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

      def new_submit_single_payment_ipp_xml
        new_ipp_xml do |xml|
          xml.SubmitSinglePayment "xmlns" => "http://www.ippayments.com.au/interface/api/dts" do
            xml.trnXML do
              yield xml
            end
          end
        end
      end

      def new_submit_single_capture_ipp_xml
        new_ipp_xml do |xml|
          xml.SubmitSingleCapture "xmlns" => "http://www.ippayments.com.au/interface/api/dts" do
            xml.trnXML do
              yield xml
            end
          end
        end
      end

      def new_submit_single_refund_ipp_xml
        new_ipp_xml do |xml|
          xml.SubmitSingleRefund "xmlns" => "http://www.ippayments.com.au/interface/api/dts" do
            xml.trnXML do
              yield xml
            end
          end
        end
      end

      def new_submit_single_payment_credit_purchase_xml(money, payment, options)
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

      def new_submit_single_payment_credit_authorize_xml(money, payment, options)
        new_xml do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            xml.Amount money.to_s
            xml.TrnType "2"
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

      def new_submit_single_capture_xml(money, authorization, options)
        new_xml do |xml|
          xml.Capture do
            xml.Receipt authorization
            xml.Amount money
            xml.Security do
              xml.UserName @options[:login]
              xml.Password @options[:password]
            end
          end
        end
      end

      def new_submit_single_refund_xml(money, authorization, options)
        new_xml do |xml|
          xml.Refund do
            xml.Receipt authorization
            xml.Amount money
            xml.Security do
              xml.UserName @options[:login]
              xml.Password @options[:password]
            end
          end
        end
      end

      def parse_response(body)
        params = {}
        doc = Nokogiri::XML(body)
        doc.root.elements.each do |e|
          params[e.name.underscore.to_sym] = e.inner_text
        end
        params
      end

      def parse(body)
        doc = Nokogiri::XML(body)
        element = doc.root.first_element_child.first_element_child
        parse_response(element.inner_text)
      end

      def commit(action, data)
        headers = {
          "Content-Type" => "text/xml; charset=utf-8",
          "SOAPAction" => action,
        }
        params = parse(ssl_post(commit_url, data, headers))
        new_response(params)
      end

      def commit_url
        test? ? test_url : live_url
      end

      def new_response(params)
        Response.new(
          success_from(params),
          message_from(params),
          params,
          authorization: authorization_from(params),
          test: test?
        )
      end

      def success_from(params)
        params[:response_code] == "0"
      end

      def message_from(params)
        params[:declined_message]
      end

      def authorization_from(params)
        params[:receipt]
      end

      def new_void_response(authorization)
        params = {
        }
        Response.new(
          true,
          "",
          params,
          authorization: authorization,
          test: test?
        )
      end
    end
  end
end
