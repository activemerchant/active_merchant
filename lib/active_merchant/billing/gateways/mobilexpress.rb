require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MobilexpressGateway < Gateway
      include Empty
      self.test_url = 'https://test.mobilexpress.com.tr/Checkout/v6/FastCheckoutService.asmx'
      self.live_url = 'https://www.mobilexpress.com.tr/Checkout/v6/FastCheckoutService.asmx'

      self.supported_countries = ['TR']
      self.default_currency = 'TRY'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.mobilexpress.com.tr/'
      self.display_name = 'Mobilexpress'

      STANDARD_ERROR_CODE_MAPPING = {
        'InvalidCardNum' => STANDARD_ERROR_CODE[:invalid_number],
        'InvalidMonth' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'InvalidYear' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'InvalidCVV' => STANDARD_ERROR_CODE[:invalid_cvc],
        'CardExpired' => STANDARD_ERROR_CODE[:expired_card],
        'CardRefused' => STANDARD_ERROR_CODE[:card_declined],
        'AuthenticationError' => STANDARD_ERROR_CODE[:config_error],
        'InvalidAmount' => STANDARD_ERROR_CODE[:processing_error],
        'InvalidInstallment' => STANDARD_ERROR_CODE[:processing_error],
        'InvalidBankPosId' => STANDARD_ERROR_CODE[:processing_error],
        'RefTransactionNotFound' => STANDARD_ERROR_CODE[:processing_error],
        'InvalidReturnURL' => STANDARD_ERROR_CODE[:processing_error],
        'ServerError' => STANDARD_ERROR_CODE[:processing_error],
      }.freeze
      ENV_NS = { 'xmlns:s' => 'http://schemas.xmlsoap.org/soap/envelope/' }
      SOAP_ACTION_NS = 'http://tempuri.org/'
      SOAP_XMLNS = { xmlns: SOAP_ACTION_NS }

      def initialize(options={})
        requires!(options, :merchant_key, :api_password)
        super
      end

      def purchase(money, payment, options={})
        method_name = payment.is_a?(String) ? 'ProcessPayment' : 'ProcessPaymentWithCard'

        request = build_soap_request do |xml|
          xml.send(method_name, SOAP_XMLNS) do
            xml.ProcessType 'sales'
            add_authentication(xml, options)
            add_invoice(xml, money, options)
            add_payment(xml, payment)
            add_customer_data(xml, options)
            add_transaction(xml, options)
          end
        end

        commit(method_name, request)
      end

      def store(credit_card, options={})
        request = build_soap_request do |xml|
          xml.SaveCreditCard(SOAP_XMLNS) do
            add_authentication(xml, options)
            add_customer_data(xml, options)
            add_payment_store(xml, credit_card)
          end
        end

        commit('SaveCreditCard', request)
      end

      def unstore(card_token, options={})
        request = build_soap_request do |xml|
          xml.DeleteCreditCard(SOAP_XMLNS) do
            add_authentication(xml, options)
            add_customer_data(xml, options)
            add_token_store(xml, card_token)
          end
        end

        commit('DeleteCreditCard', request)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((<MerchantKey>)[^<]*(</MerchantKey>))i, '\1[FILTERED]\2').
          gsub(%r((<APIpassword>)[^<]*(</APIpassword>))i, '\1[FILTERED]\2').
          gsub(%r((<CardNum>).+(</CardNum>))i, '\1[FILTERED]\2').
          gsub(%r((<CardNumber>).+(</CardNumber>))i, '\1[FILTERED]\2').
          gsub(%r((<CVV>).+(</CVV>))i, '\1[FILTERED]\2')
      end

      private

      def add_authentication(xml, options={})
        xml.MerchantKey @options[:merchant_key]
        xml.APIpassword @options[:api_password]
        xml.POSID @options[:pos_id] unless empty?(@options[:pos_id])
      end

      def add_customer_data(xml, options)
        xml.CustomerID options[:customer_id] unless empty?(options[:customer_id])
        xml.CustomerName options[:customer_name] unless empty?(options[:customer_name])
        xml.ClientIP options[:ip] unless empty?(options[:ip])
      end

      def add_transaction(xml, options)
        xml.TransactionId (options[:order_id] || SecureRandom.hex(10))
      end

      def add_token_store(xml, card_token)
        xml.CardToken card_token
      end

      def add_invoice(xml, money, options={})
        xml.TotalAmount amount(money)
        xml.Request3D false
      end

      def add_payment(xml, payment)
        if payment.is_a?(String)
          xml.CardToken payment
        else
          xml.CardNum payment.number
          xml.LastMonth format(payment.month, :two_digits)
          xml.LastYear format(payment.year, :four_digits)
          xml.CVV payment.verification_value if payment.verification_value.present?
        end
      end

      def add_payment_store(xml, payment)
        xml.CardNumber payment.number
        xml.CardHolderName payment.name
        xml.CardMonth format(payment.month, :two_digits)
        xml.CardYear format(payment.year, :four_digits)
      end

      def parse(action, body)
        parsed = {}

        doc = Nokogiri::XML(body).remove_namespaces!
        doc.xpath("//#{action}Response/#{action}Result/*").each do |node|
          if (node.elements.empty?)
            parsed[node.name.underscore.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name}_#{childnode.name}"
              parsed[name.underscore.to_sym] = childnode.text
            end
          end
        end

        if doc.xpath("//#{action}Response/#{action}Result/*").blank?
          # this happens when calling DeleteCreditCard as the response only has that enum
          # type in the response
          doc.xpath("//#{action}Response/#{action}Result").each do |node|
            parsed[node.name.underscore.to_sym] = node.text
          end
        end

        parsed
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

      def commit(action, xml)
        response = parse(action, ssl_post(url, xml, headers(action)))

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def build_soap_request
        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml['s'].Envelope(ENV_NS) do

            xml['s'].Body do
              yield(xml)
            end
          end
        end

        builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      def success_from(action, response)
        param = if action == 'DeleteCreditCard'
            response[:delete_credit_card_result]
          else
            response[:result_code]
          end

        param == 'Success'
      end

      def message_from(action, response)
        if action == 'DeleteCreditCard'
          response[:delete_credit_card_result]
        else
          response[:result_code]
        end
      end

      def authorization_from(action, response)
        if action == 'SaveCreditCard'
          response[:card_token]
        else
          [response[:mobilexpress_trans_id], response[:bank_auth_code]].join(';')
        end
      end

      def error_code_from(action, response)
        unless success_from(action, response)
          param = if action == 'DeleteCreditCard'
            response[:delete_credit_card_result]
          else
            response[:result_code]
          end
          STANDARD_ERROR_CODE_MAPPING.fetch(param, 'ServerError')
        end
      end
    end
  end
end
