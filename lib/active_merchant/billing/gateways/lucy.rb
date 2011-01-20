module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class LucyGateway < Gateway
      TEST_URL = 'https://cpgtest.cynergydata.com/SmartPayments/transact2.asmx/ProcessCreditCard'
      LIVE_URL = 'https://payments.cynergydata.com/SmartPayments/transact2.asmx/ProcessCreditCard'
        
      ActiveMerchant::Billing::Base.gateway_mode = ActiveMerchant::Billing::Base.mode

      AVS_ERRORS = %w( A E N R W Z )
      PAYMENT_GATEWAY_RESPONSES = {
        -100 => "Generic Host Error",
        0 => "Approved",
        1 => "User Authentication Failed",
        2 => "Invalid Transaction",
        3 => "Invalid Transaction Type",
        4 => "Invalid Amount",
        5 => "Invalid Merchant Information",
        7 => "Field Format Error",
        8 => "Not a Transaction Server",
        9 => "Invalid Parameter Stream",
        10 => "Too Many Line Items",
        11 => "Client Timeout Waiting for Response",
        12 => "Decline",
        13 => "Referral",
        14 => "Transaction Type Not Supported In This Version",
        19 => "Original Transaction ID Not Found",
        20 => "Customer Reference Number Not Found",
        22 => "Invalid ABA Number",
        23 => "Invalid Account Number",
        24 => "Invalid Expiration Date",
        25 => "Transaction Type Not Supported by Host",
        26 => "Invalid Reference Number",
        27 => "Invalid Receipt Information",
        28 => "Invalid Check Holder Name",
        29 => "Invalid Check Number",
        30 => "Check DL Verification Requires DL State",
        40 => "Transaction did not connect",
        50 => "Insufficient Funds Available",
        99 => "General Error",
        100 => "Invalid Transaction Returned from Host",
        101 => "Timeout Value too Small or Invalid Time Out Value",
        102 => "Processor Not Available",
        103 => "Error Reading Response from Host",
        104 => "Timeout waiting for Processor Response",
        105 => "Credit Error",
        106 => "Host Not Available",
        107 => "Duplicate Suppression Timeout",
        108 => "Void Error",
        109 => "Timeout Waiting for Host Response",
        110 => "Duplicate Transaction",
        111 => "Capture Error",
        112 => "Failed AVS Check",
        113 => "Cannot Exceed Sales Cap",
        1000 => "Generic Host Error",
        1001 => "Invalid Login",
        1002 => "Insufficient Privilege or Invalid Amount",
        1003 => "Invalid Login Blocked",
        1004 => "Invalid Login Deactivated",
        1005 => "Transaction Type Not Allowed",
        1006 => "Unsupported Processor",
        1007 => "Invalid Request Message",
        1008 => "Invalid Version",
        1010 => "Payment Type Not Supported",
        1011 => "Error Starting Transaction",
        1012 => "Error Finishing Transaction",
        1013 => "Error Checking Duplicate",
        1014 => "No Records To Settle (in the current batch)",
        1015 => "No Records To Process (in the current batch)"
      } 
      self.ssl_strict = false

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.cynergydata.com/gateway'
      
      # The name of the gateway
      self.display_name = 'Lucy Gateway'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('Auth', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('Sale', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post = {:PNRef => authorization}
        commit('Capture', money, post)
      end
      
      def void(authorization, options = {})
        post = {:PNRef => authorization}
        commit('Void', nil, post)
      end
    
      private                       
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)      
        if address = options[:billing_address] || options[:address]
          post[:Zip] = address[:zip].to_s
          post[:Street] = address[:address].to_s
        end
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(post, creditcard)
        post[:CardNum] = creditcard.number
        post[:CVNum] = creditcard.verification_value if creditcard.verification_value?
        post[:ExpDate] = expdate(creditcard)
        post[:NameOnCard] = "#{creditcard.first_name} #{creditcard.last_name}"
        unless creditcard.track2.blank?
          post[:MagData] = creditcard.track2
        end
      end
      
      def parse(body)
        response = {}
        xml = REXML::Document.new(body)
        REXML::XPath.first(xml, "/Response").elements.to_a.each do |node|
          response[node.name.to_sym] = (node.text || '').strip
        end
        response[:test?] = true # test? ? true : fasle
        response

      end     
      
      def commit(action, money, parameters)
        parameters[:Amount] = amount(money) unless action == 'Void'

        # Only activate the test_request when the :test option is passed in
        parameters[:test_request] = @options[:test] ? 'TRUE' : 'FALSE'

        url = test? ? TEST_URL : LIVE_URL

        data = ssl_post(url, post_data(action, parameters))
        response = parse(data)
        message = message_from(response)

        # Return the response. The authorization can be taken out of the transaction_id
        # Test Mode on/off is something we have to parse from the response text.
        # It usually looks something like this
        #
        # (TESTMODE) Successful Sale
        test_mode = test? || message =~ /TESTMODE/

        Response.new(response[:Result].to_s == '0', message, response,
          :test => test_mode,
          :authorization => response[:PNRef],
          #:fraud_review => fraud_review?(response),
          #:avs_result => { :code => response[:avs_result_code] },
          :avs_result => { :code => (response[:GetAVSResult] if response[:GetAVSResult]) },
          :cvv_result => (response[:GetCVResult] if response[:GetCVResult])
        )
      end

      def message_from(response)
        PAYMENT_GATEWAY_RESPONSES[response[:Result].to_i]
      end
      
      def post_data(action, parameters = {})
        post = {}
        post[:UserName] = @options[:login]
        post[:Password] = @options[:password]
        post[:TransType] = action
        post[:CVNum] = parameters[:CVNum] || ""
        post[:CardNum] = parameters[:CardNum] || ""
        post[:ExpDate] = parameters[:ExpDate] || ""
        post[:ExtData] = parameters[:ExtData] || ""
        post[:InvNum] = parameters[:InvNum] || ""
        post[:MagData] = parameters[:MagData] || ""
        post[:NameOnCard] = parameters[:NameOnCard] || ""
        post[:PNRef] = parameters[:PNRef] || ""
        post[:Street] = parameters[:Streen] || ""
        post[:Zip] = parameters[:Zip] || ""

        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def expdate(creditcard)
        year = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)
        "#{month}#{year[-2..-1]}"
      end

      def split(response)
        response[1..-2].split("\r\n")
      end


    end
  end
end

