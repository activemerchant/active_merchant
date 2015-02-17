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
        requires!(options, :login, :password)
        # Assign options to Class Instance
        @options = options
        super
      end

      def purchase(money, payment, options={})
        # Purchase is sale tranaction, we create an array of params and then call the processing function
        post = {}
        # CC Data, Cheque Data
        add_payment(post, payment)
        # Invoice Data
        add_invoice(post, money, options)
        # Address, Shipping Address Data
        add_address(post, options)
        # Customer Data (IP, EMail)
        add_customer_data(post, options)
        # Custom Data
        add_custom_data(post, options)
        # Call the commit function to pass on the params to gateway
        commit('sale', post)
      end

      def authorize(money, payment, options={})
        # Authorize transaction, same as purchase only we do not charge the card
        post = {}
        # CC Data, Check Data
        add_payment(post, payment)
        # Invoice Data
        add_invoice(post, money, options)
        # Address, Shipping Address Data
        add_address(post, options)
        # Customer Data (IP, EMail)
        add_customer_data(post, options)
        # Custom Data
        add_custom_data(post, options)
        # Call the commit function to pass on the params to gateway
        commit('auth', post)
      end

      def capture(money, authorization, options={})
        # Capture transaction, only payment and customer address is required
        post = {}
        # Invoice Data
        add_invoice(post, money, options)
        # Add Authorization
        add_authorization(post, authorization, options)
        # Call the commit function to pass on the params to gateway
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        # Refund transaction, we need to pass on the authorization number along with amount for refund to locate previous trnsaction
        post = {}
        # Invoice Data
        add_invoice(post, money, options)
        # Add Authorization
        add_authorization(post, authorization, options)
        # Call the commit function to pass on the params to gateway
        commit('refund', post)
      end

      def void(authorization, options={})
        # Void transaction, we need to pass on only authorization number for voiding transaction
        post = {}
        # Add Authorization
        add_authorization(post, authorization, options)
        # Call the commit function to pass on the params to gateway
        commit('void', post)
      end

      def verify(credit_card, options={})
        # Verify is two step process, first we fire the authorize then we capture the auth and issue void
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
          gsub(%r((<GatewayUserName>)[^<]+(<))i, '\1[FILTERED]\2').
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
        # Add the authorization code
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
        # Agms support only USD so we do not pass though currency convertor function
        # post[:currency] = (options[:currency] || currency(money))
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
        # Remove the namespaces
        doc.remove_namespaces!
        response = {}
        # Extract the response data from the ProcessTransactionResult node
        doc.xpath("//ProcessTransactionResult//*").each do |node|
          response[node.name] = node.children.text
        end
        response
      end

      def commit(action, parameters)
        # Process the params as per action
        # URL to fire the request
        url = (test? ? test_url : live_url)
        # Build the data which is passed to ssl_post later
        data = post_data(action, parameters)
        header = {}
        # Assign soap headers
        header['SOAPAction'] = "https://gateway.agms.com/roxapi/ProcessTransaction"
        header['Content-Type'] = "text/xml; charset=utf-8"
        # Pass the post info to ssl_post method, standard for active_merchant
        response = parse(ssl_post(url, data, header))
        # Process the response, parse into standard Response object, uses function to parse and generate the standard object
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
                  xml.GatewayUserName(@options[:login])
                  xml.GatewayPassword(@options[:password])
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

