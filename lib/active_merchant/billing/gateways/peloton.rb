require 'nokogiri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PelotonGateway < Gateway
      self.test_url = 'https://test.peloton-technologies.com/EppTransaction.asmx'
      self.live_url = 'https://peloton-technologies.com/EppTransaction.asmx'

      self.supported_countries = ['CA','US']
      self.default_currency = 'CAD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.peloton-technologies.com/'
      self.display_name = 'Peloton'

      def initialize(options={})
        # requires!(options, :client_id, :account_name, :password)
        # requires!(options, :merchant_id, :encryption_key, :username, :password)
        super
      end

      def purchase(amount, payment, options={})
        options[:type] = 'P'

        @parent_operation_xml = 'ProcessPayment'
        @child_operation_xml = 'processPaymentRequest'
        commit(build_purchase_or_authorize_request(amount, payment, options), options)
      end

      def authorize(amount, payment, options={})
        options[:type] = 'PA'

        @parent_operation_xml = 'ProcessPayment'
        @child_operation_xml = 'processPaymentRequest'
        commit(build_purchase_or_authorize_request(amount, payment, options), options)
      end

      def capture(amount, options)
        @parent_operation_xml = 'CompletePreAuth'
        @child_operation_xml = 'completePreAuthRequest'
        commit(build_capture_request(amount, options),options)
      end

      def refund(amount, options)
        @parent_operation_xml = 'RefundPayment'
        @child_operation_xml = 'refundPaymentRequest'
        commit(build_refund_request(amount, options), options)
      end

      def void(options)

        @parent_operation_xml = 'CancelPreAuth'
        @child_operation_xml = 'cancelPreAuthRequest'
        commit(build_void_request(options),options)
      end

      private

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def build_purchase_or_authorize_request(amount, payment, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_transaction_amount(xml, amount)
        add_credit_card_data(xml, payment)
        add_canadian_address_verification_service(xml, options)
        add_address(xml, options)
        add_payment_type(xml, options)
        add_order_number(xml, options)
        xml.target!
      end

      def build_capture_request(amount, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_transaction_amount(xml, amount)
        add_transaction_ref_code(xml, options)
        add_order_number(xml, options)
        xml.target!
      end

      def build_refund_request(amount, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_transaction_amount(xml, amount)
        add_transaction_ref_code(xml, options)
        add_order_number(xml, options)
        xml.target!
      end

      def build_void_request(options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_transaction_ref_code(xml, options)
        add_order_number(xml, options)
        xml.target!
      end

      # def setup_address_hash(options)
      #   options[:billing_address] = options[:billing_address] || options[:address] || {}
      #   options[:shipping_address] = options[:shipping_address] || {}
      # end

      def add_canadian_address_verification_service(xml, options)
        xml.tag! 'CanadianAddressVerification', options[:canadian_address_verification] || 'false'
      end

      def add_transaction_amount(xml, amount)
        xml.tag! 'Amount', amount(amount)
      end

      def add_credit_card_data(xml, payment)
        xml.tag! 'CardOwner', payment.first_name + " " + payment.last_name
        xml.tag! 'CardNumber', payment.number
        xml.tag! 'ExpiryMonth', format(payment.month, :two_digits)
        xml.tag! 'ExpiryYear', format(payment.year, :two_digits)
        xml.tag! 'CardVerificationDigits', payment.verification_value
      end

      def add_merchant_data(xml, options)
        xml.tag! 'ClientId', @options[:client_id]
        xml.tag! 'Password', @options[:password]
        xml.tag! 'AccountName', @options[:account_name]

      end

      def add_payment_type(xml, options)
        xml.tag! 'Type', options[:type]
      end

      def add_order_number(xml, options)
        xml.tag! 'OrderNumber', options[:order_number]
      end

      def add_transaction_ref_code(xml, options)
        xml.tag! 'TransactionRefCode', options[:transaction_ref_code]
      end

      def add_address(xml, options)
        xml.tag! "BillingName", options[:billing_name]
        xml.tag! "BillingAddress1", options[:billing_address1]
        xml.tag! "BillingAddress2", options[:billing_address2]
        xml.tag! "BillingCity", options[:billing_city]
        xml.tag! "BillingProvinceState", options[:billing_province_state]
        xml.tag! "BillingCountry", options[:billing_country]
        xml.tag! "BillingPostalZipCode", options[:billing_postal_zip_code]
        xml.tag! "BillingEmailAddress", options[:billing_email_address]
        xml.tag! "BillingPhoneNumber", options[:billing_phone_number]

        xml.tag! "ShippingName", options[:shipping_name]
        xml.tag! "ShippingAddress1", options[:shipping_address]
        xml.tag! "ShippingAddress2", options[:shipping_address2]
        xml.tag! "ShippingCity", options[:shipping_city]
        xml.tag! "ShippingProvinceState", options[:shipping_province_state]
        xml.tag! "ShippingCountry", options[:shipping_country]
        xml.tag! "ShippingPostalZipCode", options[:shipping_postal_zip_code]
        xml.tag! "ShippingEmailAddress", options[:shipping_email_address]
        xml.tag! "ShippingPhoneNumber", options[:shipping_phone_number]
      end


      def build_request(body, options)
        xml = Builder::XmlMarkup.new indent: 2
          # xml.instruct!
          xml.tag! 'soapenv:Envelope', {'xmlns:soapenv' => 'http://schemas.xmlsoap.org/soap/envelope/', 'xmlns:pel' => "http://www.peloton-technologies.com/"} do
            xml.tag! 'soapenv:Header'
            xml.tag! 'soapenv:Body' do
              xml.tag! "#{@parent_operation_xml}", {'xmlns' => "http://www.peloton-technologies.com/"} do
                xml.tag! "#{@child_operation_xml}" do
                  add_merchant_data(xml, options)
                  xml.tag! 'ApplicationName', options [:application_name]
                  xml.tag! 'LanguageCode', options[:language_code]
                  xml << body
                end
              end
            end
          end
        xml.target!
      end


      def parse(xml)
        xml = Nokogiri::XML(xml)
        ns = {'xmlns' => "http://www.peloton-technologies.com/"}
        response = {}
        if xml.at_xpath("//soap:Fault")
          response[:fault_code] = xml.xpath("//faultcode").text
          response[:fault_string] = xml.xpath("//faultstring").text
        elsif xml.at_xpath("//xmlns:Success", ns)
          response[:success] = xml.xpath("//xmlns:Success", ns).text
          response[:message] = xml.xpath("//xmlns:Message", ns).text
          response[:message_code] = xml.xpath("//xmlns:MessageCode", ns).text
          response[:transaction_ref_code] = xml.xpath("//xmlns:TransactionRefCode", ns).text
        else
          response[:fatal_error] = 'Could not complete the request at this time.'
        end
        response
      end

      def commit(body, options)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, build_request(body, options), headers))

        success = response[:success] == 'true'
        message = response[:message]


        Response.new(success, message, response,
                     :test => test?,
                     :authorization => response[:transaction_ref_code])
      end

      def headers
        { 'Content-Type'  => 'text/xml; charset=utf-8' }
      end

    end
  end
end
