require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BpointGateway < Gateway
      self.live_url = 'https://www.bpoint.com.au/evolve/service_1_4_4.asmx'

      self.supported_countries = ['AU']
      self.default_currency = 'AUD'
      self.supported_cardtypes = %i[visa master american_express diners_club]

      self.homepage_url = 'https://www.bpoint.com.au/bpoint'
      self.display_name = 'BPoint'

      def initialize(options={})
        requires!(options, :username, :password, :merchant_number)
        super
      end

      def store(credit_card, options={})
        options[:crn1] ||= 'DEFAULT'
        request_body = soap_request do |xml|
          add_token(xml, credit_card, options)
        end
        commit(request_body)
      end

      def purchase(amount, credit_card, options={})
        request_body = soap_request do |xml|
          process_payment(xml) do |payment_xml|
            add_purchase(payment_xml, amount, credit_card, options)
          end
        end
        commit(request_body)
      end

      def authorize(amount, credit_card, options={})
        request_body = soap_request do |xml|
          process_payment(xml) do |payment_xml|
            add_authorize(payment_xml, amount, credit_card, options)
          end
        end
        commit(request_body)
      end

      def capture(amount, authorization, options={})
        request_body = soap_request do |xml|
          process_payment(xml) do |payment_xml|
            add_capture(payment_xml, amount, authorization, options)
          end
        end
        commit(request_body)
      end

      def refund(amount, authorization, options={})
        request_body = soap_request do |xml|
          process_payment(xml) do |payment_xml|
            add_refund(payment_xml, amount, authorization, options)
          end
        end
        commit(request_body)
      end

      def void(authorization, options={})
        request_body = soap_request do |xml|
          process_payment(xml) do |payment_xml|
            add_void(payment_xml, authorization, options)
          end
        end
        commit(request_body)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options.merge(amount: 100)) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<password>).+(</password>)), '\1[FILTERED]\2').
          gsub(%r((<CardNumber>).+(</CardNumber>)), '\1[FILTERED]\2').
          gsub(%r((<CVC>).+(</CVC>)), '\1[FILTERED]\2')
      end

      private

      def soap_request
        Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
          xml.send('soap12:Envelope', soap_envelope_attributes) {
            xml.send('soap12:Body') {
              yield(xml) if block_given?
            }
          }
        end.to_xml
      end

      def soap_envelope_attributes
        { 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:soap12' => 'http://www.w3.org/2003/05/soap-envelope' }
      end

      def process_payment(xml)
        xml.send('ProcessPayment', { 'xmlns' => 'urn:Eve_1_4_4' }) {
          credentials_xml(xml)
          xml.send('txnReq') {
            yield(xml) if block_given?
          }
        }
      end

      def add_token(xml, credit_card, options)
        xml.send('AddToken', { 'xmlns' => 'urn:Eve_1_4_4' }) {
          credentials_xml(xml)
          xml.send('tokenRequest') {
            xml.send('CRN1', options[:crn1])
            xml.send('CRN2', '')
            xml.send('CRN3', '')
            xml.send('CardNumber', credit_card.number)
            xml.send('ExpiryDate', expdate(credit_card))
          }
        }
      end

      def credentials_xml(xml)
        xml.send('username', @options[:username])
        xml.send('password', @options[:password])
        xml.send('merchantNumber', @options[:merchant_number])
      end

      def add_purchase(xml, amount, credit_card, options)
        payment_xml(xml, 'PAYMENT', amount, options)
        credit_card_xml(xml, credit_card)
      end

      def add_authorize(xml, amount, credit_card, options)
        payment_xml(xml, 'PREAUTH', amount, options)
        credit_card_xml(xml, credit_card)
      end

      def add_capture(xml, amount, transaction_number, options)
        payment_xml(xml, 'CAPTURE', amount, options)
        transaction_number_xml(xml, transaction_number)
      end

      def add_refund(xml, amount, transaction_number, options)
        payment_xml(xml, 'REFUND', amount, options)
        transaction_number_xml(xml, transaction_number)
      end

      def add_void(xml, transaction_number, options)
        # The amount parameter is required for void requests on BPoint.
        amount = options[:amount]
        payment_xml(xml, 'REVERSAL', amount, options)
        transaction_number_xml(xml, transaction_number)
      end

      def payment_xml(xml, payment_type, amount, options)
        xml.send('PaymentType', payment_type)
        xml.send('TxnType', 'WEB_SHOP')
        xml.send('BillerCode', options.fetch(:biller_code, ''))
        xml.send('MerchantReference', options[:order_id]) if options[:order_id]
        xml.send('CRN1', options[:crn1]) if options[:crn1]
        xml.send('CRN2', options[:crn2]) if options[:crn2]
        xml.send('CRN3', options[:crn3]) if options[:crn3]
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
        parse(ssl_post(live_url, request_body, request_headers))
      end

      def request_headers
        { 'Content-Type' => 'application/soap+xml; charset=utf-8' }
      end

      def parse(body)
        response_for(Nokogiri::XML(body).remove_namespaces!)
      end

      def response_for(xml_doc)
        if xml_doc.xpath('//ProcessPaymentResponse').any?
          ProcessPaymentResponse.new(xml_doc, self).to_response
        elsif xml_doc.xpath('//AddTokenResponse').any?
          AddTokenResponse.new(xml_doc, self).to_response
        end
      end

      class BPointResponse
        attr_reader :xml_doc, :gateway, :params

        def initialize(xml_doc, gateway)
          @xml_doc = xml_doc
          @gateway = gateway
          @params = init_params
        end

        def to_response
          Response.new(success?, message, params, options)
        end

        private

        def init_params
          {}.tap do |h|
            xml_doc.xpath(response_node).each do |node|
              if node.elements.empty?
                h[node.name.to_sym] = node.text
              else
                node.elements.each do |childnode|
                  name = "#{node.name}_#{childnode.name}"
                  h[name.to_sym] = childnode.text
                end
              end
            end
          end
        end

        def response_node
          "//#{self.class.name.split('::').last}/*"
        end

        def options
          { authorization: params[authorization_key], test: gateway.test? }
        end
      end

      class ProcessPaymentResponse < BPointResponse
        private

        def authorization_key
          :ProcessPaymentResult_TransactionNumber
        end

        def success?
          params[:ProcessPaymentResult_ResponseCode] == '0'
        end

        def message
          params[:ProcessPaymentResult_AuthorisationResult] || params[:response_ResponseMessage]
        end
      end

      class AddTokenResponse < BPointResponse
        private

        def authorization_key
          :AddTokenResult_Token
        end

        def success?
          params[:response_ResponseCode] == 'SUCCESS'
        end

        def message
          params[:response_ResponseCode].capitalize
        end
      end
    end
  end
end
