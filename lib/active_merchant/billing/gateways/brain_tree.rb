module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class BrainTreeGateway < Gateway
      URL = 'https://secure.braintreepaymentgateway.com/api/transact.php'
      attr_reader :url 
      attr_reader :response
      attr_reader :options

      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.homepage_url = 'http://www.braintreepaymentsolutions.com'
      self.display_name = 'Braintree'

      AVS_MESSAGES = {
        "X" => "Exact match, 9-character numeric ZIP",
        "Y" => "Exact match, 5-character numeric ZIP",
        "D" => "Exact match, 5-character numeric ZIP",
        "M" => "Exact match, 5-character numeric ZIP",
        "A" => "Address match only",
        "B" => "Address match only",
        "W" => "9-character numeric ZIP match only",
        "Z" => "5-character Zip match only",
        "P" => "5-character Zip match only",        
        "L" => "5-character Zip match only",
        "N" => "No address or ZIP match",
        "C" => "No address or ZIP match",
        "U" => "Address unavailable",
        "G" => "Non-U.S. Issuer does not participate",
        "I" => "Non-U.S. Issuer does not participate",
        "R" => "Issuer system unavailable",
        "E" => "Not a mail/phone order",
        "S" => "Service not supported",
        "0" => "AVS Not Available",
        "O" => "AVS Not Available",
        "B" => "AVS Not Available"
      }
      
      CARD_CODE_MESSAGES = {
        "M" => "CVV2/CVC2 Match",
        "N" => "CVV2/CVC2 No Match",
        "P" => "Not Processed",
        "S" => "Merchant has indicated that CVV2/CVC2 is not present on card",
        "U" => "Issuer is not certified and/or has not provided Visa encryption keys"
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, creditcard,options)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('auth', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_payment_source(post, creditcard,options)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('sale', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post ={}
        post[:transactionid] = authorization
        commit('capture', money, post)
      end
    
      private                             
      def add_customer_data(post, options)
        if options.has_key? :email
          post[:email] = options[:email]
        end

        if options.has_key? :ip
          post[:ipaddress] = options[:ip]
        end        
      end

      def add_address(post, creditcard, options)     
        if address = options[:billing_address] || options[:address]
          post[:address1]    = address[:address1].to_s
          post[:address2]    = address[:address2].to_s unless address[:address2].blank?
          post[:company]    = address[:company].to_s
          post[:phone]      = address[:phone].to_s
          post[:zip]        = address[:zip].to_s       
          post[:city]       = address[:city].to_s
          post[:country]    = address[:country].to_s
          post[:state]      = address[:state].blank?  ? 'n/a' : address[:state]
        end         
      end

      def add_invoice(post, options)
        post[:orderid] = options[:order_id].to_s.gsub(/[^\w.]/, '')
      end
      
      def add_payment_source(params, source,options)
        if source.is_a?(String)
          add_customer_vault_id(params, source)
        else
          add_creditcard(params, source,options)
        end
      end
      
      def add_customer_vault_id(params,vault_id)
        params[:customer_vault_id] = vault_id
      end
      
      def add_creditcard(post, creditcard,options)   
        post[:customer_vault] = "add_customer" if options[:store]
        
        post[:ccnumber]  = creditcard.number
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
        post[:ccexp]  = expdate(creditcard)
        post[:firstname] = creditcard.first_name
        post[:lastname]  = creditcard.last_name   
      end
      
      def parse(body)
        results = {}
        body.split(/&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end
        results[:card_code_message] = CARD_CODE_MESSAGES[results[:cvvresponse]] if results[:cvvresponse]
        results[:avs_message]       = AVS_MESSAGES[results["avsresponse"]] if results["avsresponse"]
        results
        
      end     
      
      def commit(action, money, parameters)
        parameters[:amount]  = amount(money) if money
        
        if result = test_result_from_cc_number(parameters[:ccnumber])
          return result
        end
        
        data = ssl_post URL, post_data(action,parameters)

        @response = parse(data)

        Response.new(@response["response"]=="1", message_from(@response), @response, 
            :authorization => @response["transactionid"],
            :test => test?
        )
        
      end
      
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
      

      def message_from(response)
         r=response["responsetext"]
         case r
         when "SUCCESS","Approved"
           "This transaction has been approved"
         when "DECLINE"
           "This transaction has been declined"
          else
            r
          end
      end
      
      def post_data(action, parameters = {})
        post = {}
        post[:username]      = @options[:login]
        post[:password]   = @options[:password]
        post[:type]       = action

        request = post.merge(parameters).map {|key,value| "#{key}=#{CGI.escape(value.to_s)}"}.join("&")
        request        
      end
      
    end
  end
end

