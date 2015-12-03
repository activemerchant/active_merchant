# Agms Gateway uses nokogiri to build the xml request
require 'nokogiri'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AgmsGateway < Gateway
      self.test_url = 'https://gateway.agms.com/roxapi/agms.asmx'
      self.live_url = 'https://gateway.agms.com/roxapi/agms.asmx'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :dinner_club, :jcb]

      self.homepage_url = 'http://onlinepaymentprocessing.com/'
      self.display_name = 'AGMS Gateway'

      STANDARD_ERROR_CODE_MAPPING = {
        "2" => STANDARD_ERROR_CODE[:card_declined],
        "10" => STANDARD_ERROR_CODE[:processing_error],
        "20" => STANDARD_ERROR_CODE[:processing_error],
        "30" => STANDARD_ERROR_CODE[:processing_error],
      }

      def initialize(options={})
        # Initialize the gateway
        requires!(options, :gateway_username, :gateway_password)
        @options = options
        super
      end

      def purchase(money, payment, options={})
        ## Purchase is sale transaction, an array of params is assembled and then passed on to processing function
        # CC Data, Check Data, Invoice Data, Address, Shipping Address Data
        # Customer Data (IP, EMail), Custom Data
        post = {}
        add_payment(post, payment)
        add_invoice(post, money, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_custom_data(post, options)
        commit('sale', post)
      end

      def authorize(money, payment, options={})
        ## Authorize transaction, same as purchase,  card is not not charged
        # CC Data, Check Data, Invoice Data, Address, Shipping Address Data
        # Customer Data (IP, EMail), Custom Data
        post = {}
        add_payment(post, payment)
        add_invoice(post, money, options)
        add_address(post, options)
        add_customer_data(post, options)
        add_custom_data(post, options)
        commit('auth', post)
      end

      def capture(money, authorization, options={})
        ## Capture transaction, only payment and customer address is required
        # Invoice Data, Authorization
        post = {}
        add_invoice(post, money, options)
        add_authorization(post, authorization, options)
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        ## Refund transaction, authorization number, amount
        # Invoice Data, Authorization
        post = {}
        add_invoice(post, money, options)
        add_authorization(post, authorization, options)
        commit('refund', post)
      end

      def void(authorization, options={})
        ## Void transaction, authorization number
        # Authorization
        post = {}
        add_authorization(post, authorization, options)
        commit('void', post)
      end

      def verify(credit_card, options={})
        ## Verify is two step process, authorize then we capture the auth and issue void
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        # Indicates whether before dumping the params it remove the sensitive information
        true
      end

      def scrub(transcript)
        # Scrubbing logic, we remove CCNumber, CVV, GatewayUserName and GatewayPassword before it is dumped
        # The module also support dumping of all the request response in file for debugging and stubbing, this ensure no sensitive info is dumped
        transcript.
          gsub(%r((<CCNumber>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<CVV>)[^<]+(<))i, '\1[FILTERED]\2').
          gsub(%r((<GatewayPassword>)[^<]+(<))i, '\1[FILTERED]\2')
      end

      # Private methods
      private

      def add_payment(post, payment)
        # Add payment, by default we deal with card only and assign payment to card data
        creditcard = payment
        post[:CCNumber]  = creditcard.number
        post[:CVV] = creditcard.verification_value if creditcard.verification_value?
        post[:CCExpDate]  = expdate(creditcard)
        post[:FirstName] = creditcard.first_name
        post[:LastName]  = creditcard.last_name   
      end

      def add_authorization(post, authorization, options)
        # Add the authorization code to params
        post[:TransactionID] = authorization
      end 

      def add_invoice(post, money, options)
        # Add invoice, here money can be in multiple currency but since we deal with only USD we assign it directly, refer active_merchant docs
        post[:Amount] = amount(money)
        if options.has_key? :order_id
          post[:OrderID] = options[:order_id]
        end
        if options.has_key? :description
          post[:OrderDescription] = options[:description]
        end
        if options.has_key? :invoice
          post[:PONumber] = options[:invoice]
        end
      end

      def add_address(post, options)
        # Assign billing and shipping address
        billing_address = options[:billing_address] || options[:address]
        shipping_address = options[:shipping_address]
        unless billing_address.blank? or billing_address.values.blank?
          post[:Address1]    = billing_address[:address1].to_s
          post[:Address2]    = billing_address[:address2].to_s unless billing_address[:address2].blank?
          post[:Company]     = billing_address[:company].to_s
          post[:Phone]       = billing_address[:phone].to_s
          post[:Zip]         = billing_address[:zip].to_s       
          post[:City]        = billing_address[:city].to_s
          post[:Country]     = billing_address[:country].to_s
          post[:State]       = billing_address[:state].blank?  ? 'n/a' : billing_address[:state]
        end    
        unless shipping_address.blank? or shipping_address.values.blank?
          post[:ShippingAddress1]    = shipping_address[:address1].to_s
          post[:ShippingAddress2]    = shipping_address[:address2].to_s unless shipping_address[:address2].blank?
          post[:ShippingCompany]     = shipping_address[:company].to_s
          post[:ShippingPhone]       = shipping_address[:phone].to_s
          post[:ShippingZip]         = shipping_address[:zip].to_s       
          post[:ShippingCity]        = shipping_address[:city].to_s
          post[:ShippingCountry]     = shipping_address[:country].to_s
          post[:ShippingState]       = shipping_address[:state].blank?  ? 'n/a' : shipping_address[:state]
        end
      end

      def add_customer_data(post, options)
        # Add additional customer data in params
        if options.has_key? :email
          post[:EMail] = options[:email]
        end

        if options.has_key? :ip
          post[:IPAddress] = options[:ip]
        end   
      end

      def add_custom_data(post, options)
        # Add customs data in the params
        if options.has_key? :custom_field_1
          post[:Custom_Field_1] = options[:custom_field_1]
        end   
        if options.has_key? :custom_field_2
          post[:Custom_Field_2] = options[:custom_field_2]
        end   
        if options.has_key? :custom_field_3
          post[:Custom_Field_3] = options[:custom_field_3]
        end   
        if options.has_key? :custom_field_4
          post[:Custom_Field_4] = options[:custom_field_4]
        end   
        if options.has_key? :custom_field_5
          post[:Custom_Field_5] = options[:custom_field_5]
        end   
        if options.has_key? :custom_field_6
          post[:Custom_Field_6] = options[:custom_field_6]
        end   
        if options.has_key? :custom_field_7
          post[:Custom_Field_7] = options[:custom_field_7]
        end   
        if options.has_key? :custom_field_8
          post[:Custom_Field_8] = options[:custom_field_8]
        end   
        if options.has_key? :custom_field_9
          post[:Custom_Field_9] = options[:custom_field_9]
        end   
        if options.has_key? :custom_field_1
          post[:Custom_Field_10] = options[:custom_field_10]
        end   
      end

      
      def parse(body)
        # Parse the response body
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!
        response = {}
        doc.xpath("//ProcessTransactionResult//*").each do |node|
          response[node.name] = node.children.text
        end
        response
      end

      def commit(action, parameters)
        # Process the params as per action
        url = (test? ? test_url : live_url)
        data = post_data(action, parameters)
        header = {}
        header['SOAPAction'] = "https://gateway.agms.com/roxapi/ProcessTransaction"
        header['Content-Type'] = "text/xml; charset=utf-8"
        response = parse(ssl_post(url, data, header))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: avs_result_from(response),
          error_code: error_code_from(response),
          test: test?
        )
      end

      def success_from(response)
        # Return True / False to indicate success or failure
        response["STATUS_CODE"] == '1'
      end

      def error_code_from(response)
        # Return the error code, we map with our code mapping to return Standard Error Code for active_merchant
        STANDARD_ERROR_CODE_MAPPING[response["STATUS_CODE"]]
      end

      def message_from(response)
        # Return the message from gateway
        response["STATUS_MSG"]
      end

      def authorization_from(response)
        # Return the authorization code
        response["TRANS_ID"]
      end

      def avs_result_from(response)
        # Returns the avs data
        avs_result = {}
        avs_result['code'] = response["AVS_CODE"]
        avs_result['message'] = response["AVS_MSG"]
        avs_result
      end

      def post_data(action, parameters = {})
        # Build the post data
        builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
          xml['soap'].Envelope('xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance", 'xmlns:xsd' => "http://www.w3.org/2001/XMLSchema", 'xmlns:soap' => "http://schemas.xmlsoap.org/soap/envelope/") do
            xml['soap'].Body do
              xml.ProcessTransaction('xmlns' => "https://gateway.agms.com/roxapi/") do
                xml.objparameters do
                  xml.GatewayUserName(@options[:gateway_username])
                  xml.GatewayPassword(@options[:gateway_password])
                  xml.TransactionType(action)
                  parameters.each do |label, value|
                    xml.send(label, value)
                  end
                end
                
              end
            end
          end
        end 
        builder.to_xml
      end

      def expdate(creditcard)
        # Convert the CC year and month to standard format
        year  = sprintf("%.04i", creditcard.year.to_i)
        month = sprintf("%.02i", creditcard.month.to_i)
        "#{month}#{year[-2..-1]}"
      end

    end
  end
end

