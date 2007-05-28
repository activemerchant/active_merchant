require 'rexml/document'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    class MonerisGateway < Gateway
      attr_reader :url 
      attr_reader :response
      attr_reader :options
      
      self.supported_countries = ['CA']
      self.supported_cardtypes = [:visa, :master]
      self.homepage_url = 'http://www.moneris.com/'
      self.display_name = 'Moneris'

      TEST_URL = 'https://esqa.moneris.com/gateway2/servlet/MpgRequest'
      LIVE_URL = 'https://www3.moneris.com/gateway2/servlet/MpgRequest'
        
      # login is your Store ID
      # password is your API Token
      def initialize(options = {})
        requires!(options, :login, :password)
      
        @options = {
          :strict_ssl => true,
          :crypt_type => 7
        }.update(options)
      
        @url = test? ? TEST_URL : LIVE_URL      
        
        super      
      end      
    
      def authorize(money, creditcard, options = {})
        requires!(options, :order_id)

        parameters = {
          :order_id => options[:order_id],
          :cust_id => options[:customer],
          :amount => amount(money),
          :pan => creditcard.number,
          :expdate => expdate(creditcard),
          :crypt_type => options[:crypt_type] || @options[:crypt_type]
        }                                                             
      
        commit('preauth', parameters)      
      end
      
      # Pass in <tt>order_id</tt> and optionally a <tt>customer</tt> parameter
      def purchase(money, creditcard, options = {})
        requires!(options, :order_id)
      
        parameters = {
          :order_id => options[:order_id],
          :cust_id => options[:customer],
          :amount => amount(money),
          :pan => creditcard.number,
          :expdate => expdate(creditcard),
          :crypt_type => options[:crypt_type] || @options[:crypt_type]
        }                                                             
      
        commit('purchase', parameters)      
      end
     
      # Moneris requires both the order_id and the transaction number of
      # the original authorization.  To maintain the same interface as the other
      # gateways the two numbers are concatenated together with a ; separator as
      # the authorization number returned by authorization
      def capture(money, authorization, options = {})
        txn_number, order_id = authorization.split(';')

          parameters = {
            :txn_number => txn_number,
            :order_id => order_id,
            :comp_amount => amount(money),
            :crypt_type => options[:crypt_type] || @options[:crypt_type]
          }

        commit('completion', parameters)      
      end

      def void(authorization, options = {})
        txn_number, order_id = authorization.split(';')

          parameters = {
            :txn_number => txn_number,
            :order_id => order_id,
            :crypt_type => options[:crypt_type] || @options[:crypt_type]
          }

        commit('purchasecorrection', parameters)      
      end
   
      private                       
    
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{year[-2..-1]}#{month}"
      end
  
      def commit(action, parameters)                                 
        if result = test_result_from_cc_number(parameters[:pan])
          return result
        end
        
        data = ssl_post @url, post_data(action, parameters)
        @response = parse(data)

        success = (response[:response_code] and response[:complete] and (0..49).include?(response[:response_code].to_i) )
        message = message_form(response[:message])
        authorization = "#{response[:trans_id]};#{response[:receipt_id]}" if response[:trans_id] && response[:receipt_id]
        
        Response.new(success, message, @response,
          :test => test?,
          :authorization => authorization
        )
      end
                                               
      # Parse moneris response xml into a convinient hash
      def parse(xml)
        #  "<?xml version=\"1.0\"?><response><receipt>".
        #  "<ReceiptId>Global Error Receipt</ReceiptId>".
        #  "<ReferenceNum>null</ReferenceNum>
        #  <ResponseCode>null</ResponseCode>".
        #  "<ISO>null</ISO> 
        #  <AuthCode>null</AuthCode>
        #  <TransTime>null</TransTime>".
        #  "<TransDate>null</TransDate>
        #  <TransType>null</TransType>
        #  <Complete>false</Complete>".
        #  "<Message>null</Message>
        #  <TransAmount>null</TransAmount>".
        #  "<CardType>null</CardType>".
        #  "<TransID>null</TransID>
        #  <TimedOut>null</TimedOut>".
        #  "</receipt></response>      

        response = {:message => "Global Error Receipt", :complete => false}

        xml = REXML::Document.new(xml)          

        xml.elements.each('//receipt/*') do |node|

          response[node.name.underscore.to_sym] = normalize(node.text)

        end unless xml.root.nil?

        response
      end     

      def post_data(action, parameters = {})
        xml   = REXML::Document.new
        root  = xml.add_element("request")
        root.add_element("store_id").text = options[:login]
        root.add_element("api_token").text = options[:password]
        transaction = root.add_element(action)

        # Must add the elements in the correct order
        actions[action].each do |key|
          transaction.add_element(key.to_s).text = parameters[key] unless parameters[key].blank?
        end
        
        xml.to_s
      end
    
      def message_form(message)
        return 'Unspecified error' if message.blank?
        message.gsub(/[^\w]/, ' ').split.join(" ").capitalize
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
    
      def actions
        ACTIONS
      end

      ACTIONS = {
           "purchase"         => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
           "preauth"          => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
           "command"          => [:order_id],
           "refund"           => [:order_id, :amount, :txn_number, :crypt_type],
           "indrefund"        => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
           "completion"       => [:order_id, :comp_amount, :txn_number, :crypt_type],
           "purchasecorrection" => [:order_id, :txn_number, :crypt_type],
           "cavvpurcha"       => [:order_id, :cust_id, :amount, :pan, :expdate, :cav],
           "cavvpreaut"       => [:order_id, :cust_id, :amount, :pan, :expdate, :cavv],
           "transact"         => [:order_id, :cust_id, :amount, :pan, :expdate, :crypt_type],
           "Batchcloseall"    => [],
           "opentotals"       => [:ecr_number],
           "batchclose"       => [:ecr_number],
      }    
    end
  end
end
