# Originally contributed by Lucas Carlson  (mailto:lucas@rufy.com)
require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # First, make sure you have everything setup correctly and all of your dependencies in place with:
    # 
    #   require 'rubygems'
    #   require 'active_merchant'
    #
    # ActiveMerchant expects the amounts to be given as an Integer in cents. In this case, $10 US becomes 1000.
    #
    #   tendollar = 1000
    #
    # Next, create a credit card object using a TC approved test card.
    #
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #	    :number => '4111111111111111',
    #	    :month => 8,
    #	    :year => 2006,
    #	    :first_name => 'Longbob',
    #     :last_name => 'Longsen'
    #   )
    #   options = {
    #     :order_id => '1230123',
    #     :email => 'bob@testbob.com',
    #     :address => { :address1 => '47 Bobway',
    #                   :city => 'Bobville', 
    #                   :state => 'WA',
    #                   :country => 'Australia',
    #                   :zip => '2000'
    #                 }
    #     :description => 'purchased items'
    #   }
    #
    # To finish setting up, create the active_merchant object you will be using, with the eWay gateway. If you have a
    # functional eWay account, replace :login with your account info. 
    #
    #   gateway = ActiveMerchant::Billing::Base.gateway(:eway).new(:login => '87654321')
    #
    # Now we are ready to process our transaction
    #
    #   response = gateway.purchase(tendollar, creditcard, options)
    #
    # Sending a transaction to TrustCommerce with active_merchant returns a Response object, which consistently allows you to:
    #
    # 1) Check whether the transaction was successful
    #
    #   response.success?
    #
    # 2) Retrieve any message returned by eWay, either a "transaction was successful" note or an explanation of why the
    # transaction was rejected.
    #
    #   response.message
    #
    # 3) Retrieve and store the unique transaction ID returned by eWway, for use in referencing the transaction in the future.
    #
    #   response.authorization
    #
    # This should be enough to get you started with eWay and active_merchant. For further information, review the methods
    # below and the rest of active_merchant's documentation.

    class EwayGateway < Gateway 
      TEST_URL     = 'https://www.eway.com.au/gateway/xmltest/testpage.asp'
      LIVE_URL     = 'https://www.eway.com.au/gateway/xmlpayment.asp'
      
      TEST_CVN_URL = 'https://www.eway.com.au/gateway_cvn/xmltest/testpage.asp'
      LIVE_CVN_URL = 'https://www.eway.com.au/gateway_cvn/xmlpayment.asp'
      
      MESSAGES = {
        "00" => "Transaction was successfully processed",
        "A8" => "Amount is invalid",
        "A9" => "Card number is invalid",
        "AA" => "Account is invalid",
        "AB" => "Card expiry date is invalid",
        "01" => "Card verification number didn't match",
        "05" => "Card verification number didn't match"
      }
      
      attr_reader :url 
      attr_reader :response
      attr_reader :options
	
	    self.money_format = :cents
      self.supported_countries = ['AU']
      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'http://www.eway.com.au/'
      self.display_name = 'eWAY'
	    
    	def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
    	end

      # ewayCustomerEmail, ewayCustomerAddress, ewayCustomerPostcode
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)

        post = {}
        add_creditcard(post, creditcard)
        add_address(post, options)  
        add_customer_data(post, options)
        add_invoice_data(post, options)
        # The request fails if all of the fields aren't present
        add_optional_data(post)
    
        commit(money, post)
      end
    
      private                       
      def add_creditcard(post, creditcard)
        post[:CardNumber]  = creditcard.number
        post[:CardExpiryMonth]  = sprintf("%.2i", creditcard.month)
        post[:CardExpiryYear] = sprintf("%.4i", creditcard.year)[-2..-1]
        post[:CustomerFirstName] = creditcard.first_name
        post[:CustomerLastName]  = creditcard.last_name
        post[:CardHoldersName] = creditcard.name
              
        post[:CVN] = creditcard.verification_value if creditcard.verification_value?
      end 

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:CustomerAddress]    = [ address[:address1], address[:address2], address[:city], address[:state], address[:country] ].compact.join(', ')
          post[:CustomerPostcode]   = address[:zip]
        end
      end

      def add_customer_data(post, options)
        post[:CustomerEmail] = options[:email]
      end
      
      def add_invoice_data(post, options)
        post[:CustomerInvoiceRef] = options[:order_id]
        post[:CustomerInvoiceDescription] = options[:description]
      end

      def add_optional_data(post)
        post[:TrxnNumber] = nil
        post[:Option1] = nil
        post[:Option2] = nil
        post[:Option3] = nil     
      end

      def commit(money, parameters)
          
        parameters[:TotalAmount] = amount(money)
        
        if result = test_result_from_cc_number(parameters[:CardNumber])
          return result
        end

        data = ssl_post gateway_url(parameters[:CVN], test?), post_data(parameters)
        
        @response = parse(data)

        success = (response[:ewaytrxnstatus] == "True")
        message = message_from(response[:ewaytrxnerror])
    
        Response.new(success, message, @response,
          :authorization => response[:ewayauthcode]
        )      
      end
                                             
      # Parse eway response xml into a convinient hash
      def parse(xml)
        #  "<?xml version=\"1.0\"?>".
        #  <ewayResponse>
        #  <ewayTrxnError></ewayTrxnError>
        #  <ewayTrxnStatus>True</ewayTrxnStatus>
        #  <ewayTrxnNumber>10002</ewayTrxnNumber>
        #  <ewayTrxnOption1></ewayTrxnOption1>
        #  <ewayTrxnOption2></ewayTrxnOption2>
        #  <ewayTrxnOption3></ewayTrxnOption3>
        #  <ewayReturnAmount>10</ewayReturnAmount>
        #  <ewayAuthCode>123456</ewayAuthCode>
        #  <ewayTrxnReference>987654321</ewayTrxnReference>
        #  </ewayResponse>     

        response = {}

        xml = REXML::Document.new(xml)          
        xml.elements.each('//ewayResponse/*') do |node|

          response[node.name.downcase.to_sym] = normalize(node.text)

        end unless xml.root.nil?

        response
      end   

      def post_data(parameters = {})
        parameters[:CustomerID] = @options[:login]
        
        xml   = REXML::Document.new
        root  = xml.add_element("ewaygateway")
        
        parameters.each do |key, value|
          root.add_element("eway#{key}").text = value
        end    
        xml.to_s
      end
    
      def message_from(message)
        return '' if message.blank?
        MESSAGES[message[0,2]] || message
      end

      # Make a ruby type out of the response string
      def normalize(field)
        case field
        when "true"   then true
        when "false"  then false
        when ""       then nil
        when "null"   then nil
        else field
        end        
      end
      
      def gateway_url(cvn, test)
        if cvn
          test ? TEST_CVN_URL : LIVE_CVN_URL
        else
          test ? TEST_URL : LIVE_URL
        end
      end
    end
  end
end
