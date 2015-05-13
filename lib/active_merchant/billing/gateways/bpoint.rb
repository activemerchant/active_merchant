require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BpointGateway < Gateway
      self.test_url = 'https://www.bpoint.com.au/evolve/service_1_4_4.asmx'
      self.live_url = 'https://www.bpoint.com.au/evolve/service_1_4_4.asmx'

      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'https://www.bpoint.com.au/bpoint'
      self.display_name = 'BPoint'

      STANDARD_ERROR_CODE_MAPPING = {}

      RESPONSE_MAPPING = {
        :response_code => 'ResponseCode',
        :authorization_result => 'AuthorisationResult',
        :original_transaction_number => 'TransactionNumber'
      }

      def initialize(options={})
        requires!(options, :username, :password, :merchant_number)
        super
      end

      def purchase(amount, credit_card, options={})
        request_body = request_body_xml do |xml|
          add_payment(xml, amount, credit_card)
        end
        response_for(commit(request_body))
      end

      def authorize(amount, credit_card, options={})
        request_body = request_body_xml do |xml|
          add_preauth(xml, amount, credit_card)
        end
        response_for(commit(request_body))
      end

      def capture(amount, transaction_number)
        request_body = request_body_xml do |xml|
          add_capture(xml, amount, transaction_number)
        end
        response_for(commit(request_body))
      end

      def refund(amount, transaction_number)
        request_body = request_body_xml do |xml|
          add_refund(xml, amount, transaction_number)
        end
        response_for(commit(request_body))
      end

      def void(amount, transaction_number, options={})
        request_body = request_body_xml do |xml|
          add_reversal(xml, amount, transaction_number)
        end
        response_for(commit(request_body))
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(100, r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<password>).+(</password>)), '\1[FILTERED]\2').
          gsub(%r((<merchantNumber>).+(</merchantNumber>)), '\1[FILTERED]\2').
          gsub(%r((<CardNumber>).+(</CardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<CVC>).+(</CVC>)), '\1[FILTERED]\2')
      end

      private

      ####################
      # Request processing
      ####################

      def request_body_xml
        Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
          xml.send('soap12:Envelope', soap_envelope_attributes) {
            xml.send('soap12:Body') {
              xml.send('ProcessPayment', { 'xmlns' => 'urn:Eve_1_4_4' }) {
                xml.send('username', @options[:username])
                xml.send('password', @options[:password])
                xml.send('merchantNumber', @options[:merchant_number])
                xml.send('txnReq') {
                  yield(xml) if block_given?
                }
              }
            }
          }
        end.to_xml
      end

      def soap_envelope_attributes
        { 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope' }
      end

      def add_payment(xml, amount, credit_card)
        payment_xml(xml, 'PAYMENT', amount)
        credit_card_xml(xml, credit_card)
      end

      def add_preauth(xml, amount, credit_card)
        payment_xml(xml, 'PREAUTH', amount)
        credit_card_xml(xml, credit_card)
      end

      def add_capture(xml, amount, transaction_number)
        payment_xml(xml, 'CAPTURE', amount)
        transaction_number_xml(xml, transaction_number)
      end

      def add_refund(xml, amount, transaction_number)
        payment_xml(xml, 'REFUND', amount)
        transaction_number_xml(xml, transaction_number)
      end

      def add_reversal(xml, amount, transaction_number)
        payment_xml(xml, 'REVERSAL', amount)
        transaction_number_xml(xml, transaction_number)
      end

      def payment_xml(xml, payment_type, amount)
        xml.send('PaymentType', payment_type)
        xml.send('TxnType', 'WEB_SHOP')
        xml.send('BillerCode', '')
        xml.send('MerchantReference', '')
        xml.send('CRN1', '')
        xml.send('CRN2', '')
        xml.send('CRN3', '')
        xml.send('Amount', amount)
      end

      def credit_card_xml(xml, credit_card)
        xml.send('CardNumber', credit_card.number)
        xml.send('ExpiryDate', expdate(credit_card))
        xml.send('CVC', credit_card.verification_value)
      end

      def transaction_number_xml(xml, transaction_number)
        xml.send('OriginalTransactionNumber', transaction_number)
      end

      def commit(request_body)
        parse(ssl_post(commit_url, request_body, request_headers))
      end

      def commit_url
        test? ? test_url : live_url
      end

      def request_headers
        { "Content-Type" => "application/soap+xml; charset=utf-8" }
      end

      #####################
      # Response processing
      #####################

      def parse(body)
        xml_doc = Nokogiri::XML(body)
        xml_doc.remove_namespaces!
        Hash.new.tap do |h|
          RESPONSE_MAPPING.each do |k,v|
            h[k] = payment_response(xml_doc, v)
          end
        end
      end

      def payment_response(xml_doc, node_name)
        xml_doc.xpath("//ProcessPaymentResult/#{node_name}").text
      end

      def response_for(response)
        Response.new(
          success?(response),
          message_from(response),
          response,
          authorization: original_transaction_number_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success?(response)
        response[:response_code] == '0'
      end

      def message_from(response)
        response[:authorization_result]
      end

      def original_transaction_number_from(response)
        response[:original_transaction_number]
      end

      def error_code_from(response)
        success?(response) ? '' : STANDARD_ERROR_CODE[:card_declined]
      end
    end
  end
end
