require 'nokogiri'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PelotonCustomerServiceGateway < Gateway
      #
      #
      #
      #
      #
      #
      #
      #
      #
      #
      # Returns an ActiveMerchant:Billing::Reponse object where authorization is a string of the Transaction ID
      # and customer ID separated by a semicolon (;)
      #
      self.test_url = 'https://test.peloton-technologies.com/EppCustomer.asmx'
      self.live_url = 'https://peloton-technologies.com/EppCustomer.asmx'

      self.supported_countries = ['CA']
      self.default_currency = 'CAD'
      self.supported_cardtypes = [:visa, :master]

      self.homepage_url = 'http://www.peloton-technologies.com/'
      self.display_name = 'Peloton Customer'

      def initialize(options={})
        requires!(options, :client_id, :account_name, :password)
        super
      end

      def create(payment, options = {})
        requires!(options, :order_id)

        @parent_operation_xml = 'CreateCustomerWithPreAuth'
        @child_operation_xml = 'createCustomerRequest'
        commit(build_create_request(payment, options), options)
      end

      private

      def build_create_request(payment, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_credit_card_data(xml, payment)
        add_canadian_address_verification_service(xml, options)
        add_address(xml, options)
        #TODO: determine if payment plan info is required or not
        #add_payment_plan(xml, options)
        add_customer_id(xml, options)
        add_order_number(xml, options)
        xml.target!
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

      def add_customer_id(xml, options)
        xml.tag! 'CustomerId', options[:customer_id]
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
        xml.tag! 'OrderNumber', options[:order_id]
      end

      def add_transaction_ref_code(xml, options)
        xml.tag! 'TransactionRefCode', options[:transaction_ref_code]
      end

      def add_payment_plan(xml, options)
        xml.tag! 'BillingAmount',         options[:amount]
        xml.tag! 'BillingIncrement',      options[:billing_increment]
        xml.tag! 'BillingPeriod',         options[:billing_period]
        xml.tag! 'BillingBeginDatetime',  options[:billing_begin_date_time]
      end

      def add_address(xml, options)
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address] || {}

        requires!(billing_address, :name, :address1, :city, :country, :zip, :phone)

        xml.tag! "BillingName",           billing_address[:name]
        xml.tag! "BillingAddress1",       billing_address[:address1]
        xml.tag! "BillingAddress2",       billing_address[:address2]
        xml.tag! "BillingCity",           billing_address[:city]
        xml.tag! "BillingProvinceState",  billing_address[:state]
        xml.tag! "BillingCountry",        billing_address[:country]
        xml.tag! "BillingPostalZipCode",  billing_address[:zip]
        xml.tag! "BillingEmailAddress",   options[:email]
        xml.tag! "BillingPhoneNumber",    billing_address[:phone]

        xml.tag! "ShippingName",          shipping_address[:name]
        xml.tag! "ShippingAddress1",      shipping_address[:address1]
        xml.tag! "ShippingAddress2",      shipping_address[:address2]
        xml.tag! "ShippingCity",          shipping_address[:city]
        xml.tag! "ShippingProvinceState", shipping_address[:state]
        xml.tag! "ShippingCountry",       shipping_address[:country]
        xml.tag! "ShippingPostalZipCode", shipping_address[:zip]
        xml.tag! "ShippingEmailAddress",  options[:email]
        xml.tag! "ShippingPhoneNumber",   shipping_address[:phone]
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
                xml.tag! 'ApplicationName', options[:application_name]
                xml.tag! 'LanguageCode', options[:language_code] || 'EN'
                xml.tag! 'Reference3', options[:description]
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
          response[:customer_id] = xml.xpath("//xmlns:CustomerId", ns).text
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
                     :authorization => response[:transaction_ref_code] + ";" + response[:customer_id])
      end

      def headers
        { 'Content-Type'  => 'text/xml; charset=utf-8' }
      end

    end
  end
end
