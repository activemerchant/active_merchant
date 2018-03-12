require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module IPPCore

      STANDARD_ERROR_CODE_MAPPING = {
        "05" => Gateway::STANDARD_ERROR_CODE[:card_declined],
        "06" => Gateway::STANDARD_ERROR_CODE[:processing_error],
        "14" => Gateway::STANDARD_ERROR_CODE[:invalid_number],
        "54" => Gateway::STANDARD_ERROR_CODE[:expired_card],
      }

      IPP_LIVE_URL = 'https://www.bambora.co.nz/interface/api/dts.asmx'
      IPP_TEST_URL = 'https://demo.bambora.co.nz/interface/api/dts.asmx'

      # def self.included(base)
      #   base.ipp_live_url = 'https://www.bambora.co.nz/interface/api/dts.asmx
      #   base.ipp_test_url = 'https://demo.bambora.co.nz/interface/api/dts.asmx
  
      #   base.ipp_supported_countries = ['AU']
      #   base.ipp_supported_cardtypes = [:visa, :master, :american_express, :diners_club, :jcb]
  
      #   base.ipp_homepage_url = 'http://www.bambora.co.nz/'
      #   base.ipp_display_name = 'IPP'
  
      #   base.ipp_money_format = :cents
      # end

      def ipp_purchase(money, payment, options={})
        ipp_commit("SubmitSinglePayment") do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            ipp_add_amount(xml, money)
            xml.TrnType "1"
            ipp_add_credit_card(xml, payment)
            ipp_add_credentials(xml)
            xml.TrnSource options[:ip]
          end
        end
      end

      def ipp_authorize(money, payment, options={})
        ipp_commit("SubmitSinglePayment") do |xml|
          xml.Transaction do
            xml.CustRef options[:order_id]
            ipp_add_amount(xml, money)
            xml.TrnType "2"
            ipp_add_credit_card(xml, payment)
            ipp_add_credentials(xml)
            xml.TrnSource options[:ip]
          end
        end
      end

      def ipp_capture(money, authorization, options={})
        ipp_commit("SubmitSingleCapture") do |xml|
          xml.Capture do
            xml.Receipt authorization
            ipp_add_amount(xml, money)
            ipp_add_credentials(xml)
          end
        end
      end

      def ipp_refund(money, authorization, options={})
        ipp_commit("SubmitSingleRefund") do |xml|
          xml.Refund do
            xml.Receipt authorization
            ipp_add_amount(xml, money)
            ipp_add_credentials(xml)
          end
        end
      end

      def ipp_supports_scrubbing?
        true
      end

      def ipp_scrub(transcript)
        transcript.
          gsub(%r((<CardNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<CVN>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<Password>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      private

      def ipp_add_credentials(xml)
        xml.Security do
          xml.UserName @options[:username]
          xml.Password @options[:password]
        end
      end

      def ipp_add_amount(xml, money)
        xml.Amount amount(money)
      end

      def ipp_add_credit_card(xml, payment)
        xml.CreditCard :Registered => "False" do
          xml.CardNumber payment.number
          xml.ExpM format(payment.month, :two_digits)
          xml.ExpY format(payment.year, :four_digits)
          xml.CVN payment.verification_value
          xml.CardHolderName payment.name
        end
      end

      def ipp_parse(body)
        element = Nokogiri::XML(body).root.first_element_child.first_element_child

        response = {}
        doc = Nokogiri::XML(element)
        doc.root.elements.each do |e|
          response[e.name.underscore.to_sym] = e.inner_text
        end
        response
      end

      def ipp_commit(action, &block)
        headers = {
          "Content-Type" => "text/xml; charset=utf-8",
          "SOAPAction" => "http://www.ippayments.com.au/interface/api/dts/#{action}",
        }
        response = ipp_parse(ssl_post(ipp_commit_url, ipp_new_submit_xml(action, &block), headers))

        Response.new(
          ipp_success_from(response),
          ipp_message_from(response),
          response,
          authorization: ipp_authorization_from(response),
          error_code: ipp_error_code_from(response),
          test: test?,
        )
      end

      def ipp_new_submit_xml(action)
        xml = Builder::XmlMarkup.new(indent: 2)
        xml.instruct!
        xml.soap :Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/" do
          xml.soap :Body do
            xml.__send__(action, "xmlns" => "http://www.ippayments.com.au/interface/api/dts") do
              xml.trnXML do
                inner_xml = Builder::XmlMarkup.new(indent: 2)
                yield(inner_xml)
                xml.cdata!(inner_xml.target!)
              end
            end
          end
        end
        xml.target!
      end

      def ipp_commit_url
        (test? ? IPP_TEST_URL : IPP_LIVE_URL)
      end

      def ipp_success_from(response)
        (response[:response_code] == "0")
      end

      def ipp_error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response[:declined_code]]
      end

      def ipp_message_from(response)
        response[:declined_message]
      end

      def ipp_authorization_from(response)
        response[:receipt]
      end
    end
  end
end
