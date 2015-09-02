require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class IppGateway < Gateway
      self.live_url = 'https://www.ippayments.com.au/interface/api'
      self.test_url = 'https://demo.ippayments.com.au/interface/api'

      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]

      self.homepage_url = 'http://www.ippayments.com.au/'
      self.display_name = 'IPP'

      self.money_format = :cents

      self.default_currency = 'AUD'

      STANDARD_ERROR_CODE_MAPPING = {
        "05" => STANDARD_ERROR_CODE[:card_declined],
        "06" => STANDARD_ERROR_CODE[:processing_error],
        "14" => STANDARD_ERROR_CODE[:invalid_number],
        "54" => STANDARD_ERROR_CODE[:expired_card],
      }

      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      def purchase(money, payment, options={})
        commit("SubmitSinglePayment") do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            add_amount(xml, money)
            xml.TrnType "1"
            add_credit_card(xml, payment)
            add_credentials(xml)
            xml.TrnSource options[:ip]
          end
        end
      end

      def authorize(money, payment, options={})
        commit("SubmitSinglePayment") do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            add_amount(xml, money)
            xml.TrnType "2"
            add_credit_card(xml, payment)
            add_credentials(xml)
            xml.TrnSource options[:ip]
          end
        end
      end

      def capture(money, authorization, options={})
        commit("SubmitSingleCapture") do |xml|
          xml.Capture do
            xml.Receipt authorization
            add_amount(xml, money)
            add_credentials(xml)
          end
        end
      end

      def void(money, authorization, options={})
        commit("SubmitSingleVoid") do |xml|
          xml.Void do
            xml.Receipt authorization
            add_amount(xml, money)
            add_credentials(xml)
          end
        end
      end

      def refund(money, authorization, options={})
        commit("SubmitSingleRefund") do |xml|
          xml.Refund do
            xml.Receipt authorization
            add_amount(xml, money)
            add_credentials(xml)
          end
        end
      end

      def store(payment, options={})
        commit("TokeniseCreditCard", "sipp", "tokeniseCreditCardXML") do |xml|
          xml.TokeniseCreditCard do
            xml.UserName @options[:username]
            xml.Password @options[:password]
            xml.CardNumber payment.number
            xml.ExpM format(payment.month, :two_digits)
            xml.ExpY format(payment.year, :four_digits)
            xml.TokeniseAlgorithmID "2"
            if options.has_key?(:customer_storage_number)
              xml.CustomerStorageNumber options[:customer_storage_number]
            end
          end
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<CardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<CVN>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<Password>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      def add_credentials(xml)
        xml.Security do
          xml.UserName @options[:username]
          xml.Password @options[:password]
        end
      end

      def add_amount(xml, money)
        xml.Amount amount(money)
      end

      def add_credit_card(xml, payment)
        xml.CreditCard :Registered => "False" do
          xml.CardNumber payment.number
          xml.ExpM format(payment.month, :two_digits)
          xml.ExpY format(payment.year, :four_digits)
          xml.CVN payment.verification_value
          xml.CardHolderName payment.name
        end
      end

      def parse(body)
        element = Nokogiri::XML(body).root.first_element_child.first_element_child

        response = {}
        doc = Nokogiri::XML(element)
        doc.root.elements.each do |e|
          response[e.name.underscore.to_sym] = e.inner_text
        end
        response
      end

      def commit(action, api_type="dts", outer_xml="trnXML", &block)
        headers = {
          "Content-Type" => "text/xml; charset=utf-8",
          "SOAPAction" => "http://www.ippayments.com.au/interface/api/#{api_type}/#{action}",
        }
        response = parse(ssl_post(commit_url(api_type), new_submit_xml(action, api_type, outer_xml, &block), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          error_code: error_code_from(response),
          test: test?,
        )
      end

      def new_submit_xml(action, api_type, outer_xml)
        xml = Builder::XmlMarkup.new(indent: 2)
        xml.instruct!
        xml.soap :Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/" do
          xml.soap :Body do
            xml.__send__(action, "xmlns" => "http://www.ippayments.com.au/interface/api/#{api_type}") do
              xml.__send__(outer_xml) do
                inner_xml = Builder::XmlMarkup.new(indent: 2)
                yield(inner_xml)
                xml.cdata!(inner_xml.target!)
              end
            end
          end
        end
        xml.target!
      end

      def commit_url(api_type)
        "#{test? ? test_url : live_url}/#{api_type}.asmx"
      end

      def success_from(response)
        if response.has_key?(:return_value)
          (response[:return_value] == "0")
        else
          (response[:response_code] == "0")
        end
      end

      def error_code_from(response)
        if response.has_key?(:return_value)
          case response[:return_value]
          when '5' then Gateway::STANDARD_ERROR_CODE[:invalid_number]
          when '99' then Gateway::STANDARD_ERROR_CODE[:processing_error]
          else response[:return_value]
          end
        else
          STANDARD_ERROR_CODE_MAPPING[response[:declined_code]]
        end
      end

      def message_from(response)
        if response.has_key?(:return_value)
          case response[:return_value]
          when '0' then ''
          when '1' then 'Invalid username/password'
          when '4' then 'Invalid CustomerStorageNumber'
          when '5' then 'Invalid Credit Card Number'
          when '99' then 'Exception encountered'
          else "Error #{response[:return_value]}"
          end
        else
          response[:declined_message]
        end
      end

      def authorization_from(response)
        response[:receipt] || response[:token]
      end
    end
  end
end
