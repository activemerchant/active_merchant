require 'pry'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PelotonGateway < Gateway
      self.test_url = 'http://test.peloton-technologies.com/EppTransaction.asmx'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ['CA','US']
      self.default_currency = 'CAD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.peloton-technologies.com/'
      self.display_name = 'Peloton'

      def initialize(options={})
        requires!(options, :client_id, :account_name, :password)
        # requires!(options, :merchant_id, :encryption_key, :username, :password)
        super
      end

      def purchase(amount, payment, options={})
        requires!(options, :type, :billing_country)
        # post = {}
        # add_invoice(post, money, options)
        # add_payment(post, payment)
        # add_address(post, payment, options)
        # add_customer_data(post, options)

        commit(build_purchase_request(amount, payment, options), options)
      end

      # def purchase(money, source, options = {})
      #   post = {}
      #   add_amount(post, money)
      #   add_invoice(post, options)
      #   add_source(post, source)
      #   add_address(post, options)
      #   add_transaction_type(post, purchase_action(source))
      #   add_customer_ip(post, options)
      # commit(post)
      # end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def build_purchase_request(amount, payment, options)
        #TODO: This is a preliminary implimentation of the payment body, address, etc. will need to be added - Lee Poohachoff
        xml = Builder::XmlMarkup.new :indent => 2
        add_transaction_amount(xml, amount)
        add_credit_card_data(xml, payment)
        add_canadian_address_verification_service(xml, options)
        add_address(xml, options)
        add_payment_type(xml, options)
        xml.target!
      end

      def parse(body)
        {}
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
      end

      # def setup_address_hash(options)
      #   options[:billing_address] = options[:billing_address] || options[:address] || {}
      #   options[:shipping_address] = options[:shipping_address] || {}
      # end

      def add_canadian_address_verification_service(xml, options)
        xml.tag! 'pel:CanadianAddressVerification', options[:canadian_address_verification] || 'false'
      end

      def add_transaction_amount(xml, amount)
        xml.tag! 'pel:Amount', amount(amount)
      end

      def add_payment_type(xml, options)
        xml.tag! 'pel:Type', options[:type]
      end

      def add_credit_card_data(xml, payment)
        xml.tag! 'pel:CardOwner', payment.first_name + " " + payment.last_name
        xml.tag! 'pel:CardNumber', payment.number
        xml.tag! 'pel:ExpiryMonth', format(payment.month, :two_digist)
        xml.tag! 'pel:ExpiryYear', format(payment.year, :two_digits)
        xml.tag! 'pel:CardVerificationDigits', payment.verification_value
      end

      def add_merchant_data(xml, options)
        xml.tag! 'pel:ClientId', @options[:client_id]
        xml.tag! 'pel:Password', @options[:password]
        xml.tag! 'pel:AccountName', @options[:account_name]

      end

      def add_payment_type(xml, options)
        xml.tag! 'pel:Type', options[:type]
        xml.tag! 'pel:OrderNumber', options[:order_number]
      end


      def add_address(xml, options)
        xml.tag! "pel:BillingName", options[:billing_name]
        xml.tag! "pel:BillingAddress1", options[:billing_address1]
        xml.tag! "pel:BillingAddress2", options[:billing_address2]
        xml.tag! "pel:BillingCity", options[:billing_city]
        xml.tag! "pel:BillingProvinceState", options[:billing_province_state]
        xml.tag! "pel:BillingCountry", options[:billing_country]
        xml.tag! "pel:BillingPostalZipCode", options[:billing_postal_zip_code]
        xml.tag! "pel:BillingEmailAddress", options[:billing_email_address]
        xml.tag! "pel:BillingPhoneNumber", options[:billing_phone_number]

        xml.tag! "pel:ShippingName", options[:shipping_name]
        xml.tag! "pel:ShippingAddress1", options[:shipping_address]
        xml.tag! "pel:ShippingAddress2", options[:shipping_address2]
        xml.tag! "pel:ShippingCity", options[:shipping_city]
        xml.tag! "pel:ShippingProvinceState", options[:shipping_province_state]
        xml.tag! "pel:ShippingCountry", options[:shipping_country]
        xml.tag! "pel:ShippingPostalZipCode", options[:shipping_postal_zip_code]
        xml.tag! "pel:ShippingEmailAddress", options[:shipping_email_address]
        xml.tag! "pel:ShippingPhoneNumber", options[:shipping_phone_number]
      end


      def build_request(body, options)
        xml = Builder::XmlMarkup.new indent: 2
          # xml.instruct!
          xml.tag! 'soapenv:Envelope', {'xmlns:soapenv' => 'http://schemas.xmlsoap.org/soap/envelope/', 'xmlns:pel' => "http://www.peloton-technologies.com/"} do
            xml.tag! 'soapenv:Header'
            xml.tag! 'soapenv:Body' do
              #FIXME: This is temoprary code, the method name will need to be changed for other functions - Lee Poohachoff
              xml.tag! 'pel:ProcessPayment' do
                xml.tag! 'pel:processPaymentRequest' do
                  add_merchant_data(xml, options)
                  xml << body
                end
              end
            end
          end
        xml.target!
      end

      def commit(body, options)
        url = (test? ? test_url : live_url)
        binding.pry
        response = parse(ssl_post(url, build_request(body, options), headers))

        success = response[:Success] == "true"
        message = response[:Message]
        message_code = response[:MessageCode]

        Response.new(success, message, response,
                     :test => test?)

        # message =
        #
        # Response.new(
        #     success_from(response),
        #     message_from(response),
        #     response,
        #     authorization: authorization_from(response),
        #     test: test?
        # )




        # <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        # <soap:Body>
        # <ProcessCustomerPaymentResponse xmlns="http://www.peloton-technologies.com/">
        # <ProcessCustomerPaymentResult>
        # <Success>true</Success>
        #             <Message>Success</Message>
        # <MessageCode>0</MessageCode>
        #             <TransactionRefCode>edd7cafb-474e-e411-80c5-005056a927b9</TransactionRefCode>
        # </ProcessCustomerPaymentResult>
        #       </ProcessCustomerPaymentResponse>
        # </soap:Body>
        # </soap:Envelope>
      end

      def headers
        { #'authorization' => basic_auth,
          #'Accept'        => 'application/xml',
          'Content-Type'  => 'text/xml; charset=utf-8' }
      end

    end
  end
end
