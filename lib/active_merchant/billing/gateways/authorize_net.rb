module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
        
    class AuthorizeNetGateway < Gateway
      API_VERSION = '3.1'
      
      class_inheritable_accessor :test_url, :live_url
    
      self.test_url = "https://test.authorize.net/gateway/transact.dll"
      self.live_url = "https://secure.authorize.net/gateway/transact.dll"
    
      APPROVED, DECLINED, ERROR = 1, 2, 3

      RESPONSE_CODE, RESPONSE_REASON_CODE, RESPONSE_REASON_TEXT = 0, 2, 3
      AVS_RESULT_CODE, TRANSACTION_ID, CARD_CODE_RESPONSE_CODE  = 5, 6, 38

      CARD_CODE_ERRORS = %w( N S )

      CARD_CODE_MESSAGES = {
        "M" => "Card verification number matched",
        "N" => "Card verification number didn't match",
        "P" => "Card verification number was not processed",
        "S" => "Card verification number should be on card but was not indicated",
        "U" => "Issuer was not certified for card verification"
      }

      AVS_ERRORS = %w( A E N R W Z )

      AVS_MESSAGES = {
        "A" => "Street address matches billing information, zip/postal code does not",
        "B" => "Address information not provided for address verification check",
        "E" => "Address verification service error",
        "G" => "Non-U.S. card-issuing bank",
        "N" => "Neither street address nor zip/postal match billing information",
        "P" => "Address verification not applicable for this transaction",
        "R" => "Payment gateway was unavailable or timed out",
        "S" => "Address verification service not supported by issuer",
        "U" => "Address information is unavailable",
        "W" => "9-digit zip/postal code matches billing information, street address does not",
        "X" => "Street address and 9-digit zip/postal code matches billing information",
        "Y" => "Street address and 5-digit zip/postal code matches billing information",
        "Z" => "5-digit zip/postal code matches billing information, street address does not",
      }
     
      # URL
      attr_reader :url 
      attr_reader :response
      attr_reader :options
      
      self.supported_countries = ['US']
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.homepage_url = 'http://www.authorize.net/'
      self.display_name = 'Authorize.net'

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, options)        
        add_customer_data(post, options)
        
        commit('AUTH_ONLY', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, options)   
        add_customer_data(post, options)
             
        commit('AUTH_CAPTURE', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post = {:trans_id => authorization}
        add_customer_data(post, options)
        commit('PRIOR_AUTH_CAPTURE', money, post)
      end

      def void(authorization, options = {})
        post = {:trans_id => authorization}
        commit('VOID', nil, post)
      end
      
      def credit(money, identification, options = {})
        requires!(options, :card_number)
        
        post = { :trans_id => identification,
                 :card_num => options[:card_number]
               }

        commit('CREDIT', money, post)
      end
       
      private                       
      def commit(action, money, parameters)
        parameters[:amount]       = amount(money) unless action == 'VOID'
        
        # Only activate the test_request when the :test option is passed in
        parameters[:test_request] = @options[:test] ? 'TRUE' : 'FALSE'                                  
        
        if result = test_result_from_cc_number(parameters[:card_num])
          return result
        end
        
        url = test? ? self.test_url : self.live_url
        data = ssl_post url, post_data(action, parameters)

        @response = parse(data)

        success = @response[:response_code] == APPROVED
        message = message_from(@response)

        # Return the response. The authorization can be taken out of the transaction_id 
        # Test Mode on/off is something we have to parse from the response text.
        # It usually looks something like this
        #
        #   (TESTMODE) Successful Sale
        #
        
        test_mode = test? || message =~ /TESTMODE/
        
        Response.new(success, message, @response, 
            :test => test_mode, 
            :authorization => @response[:transaction_id]
        )        
      end
                                               
      def parse(body)
        fields = split(body)
                
        results = {         
          :response_code => fields[RESPONSE_CODE].to_i,
          :response_reason_code => fields[RESPONSE_REASON_CODE], 
          :response_reason_text => fields[RESPONSE_REASON_TEXT],
          :avs_result_code => fields[AVS_RESULT_CODE],
          :transaction_id => fields[TRANSACTION_ID],
          :card_code => fields[CARD_CODE_RESPONSE_CODE]          
        }      
        
        
        results[:card_code_message] = CARD_CODE_MESSAGES[results[:card_code]] if results[:card_code]
        results[:avs_message]       = AVS_MESSAGES[results[:avs_result_code]] if results[:avs_result_code]
        
        results
      end     

      def post_data(action, parameters = {})
        post = {}

        post[:version]    = API_VERSION
        post[:login]      = @options[:login]
        post[:tran_key]   = @options[:password]
        post[:relay_response] = "FALSE"
        post[:type]       = action
        post[:delim_data] = "TRUE"
        post[:delim_char] = ","
        post[:encap_char] = "$"

        request = post.merge(parameters).collect { |key, value| "x_#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def add_invoice(post, options)
        post[:invoice_num] = options[:order_id]
        post[:description] = options[:description]
      end
      
      def add_creditcard(post, creditcard)      
        post[:card_num]  = creditcard.number
        post[:card_code] = creditcard.verification_value if creditcard.verification_value?
        post[:exp_date]  = expdate(creditcard)
        post[:first_name] = creditcard.first_name
        post[:last_name]  = creditcard.last_name
      end
      
      def add_customer_data(post, options)
        if options.has_key? :email
          post[:email] = options[:email]
          post[:email_customer] = false
        end
        
        if options.has_key? :customer
          post[:cust_id] = options[:customer]
        end
        
        if options.has_key? :ip
          post[:customer_ip] = options[:ip]
        end        
      end

      def add_address(post, options)      

        if address = options[:billing_address] || options[:address]
          post[:address]    = address[:address1].to_s
          post[:company]    = address[:company].to_s
          post[:phone]      = address[:phone].to_s
          post[:zip]        = address[:zip].to_s       
          post[:city]       = address[:city].to_s
          post[:country]    = address[:country].to_s
          post[:state]      = address[:state].blank?  ? 'n/a' : address[:state]
        end        
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
      
      def message_from(results)        
        if results[:response_code] == DECLINED
          return CARD_CODE_MESSAGES[results[:card_code]] if CARD_CODE_ERRORS.include?(results[:card_code])
          return AVS_MESSAGES[results[:avs_result_code]] if AVS_ERRORS.include?(results[:avs_result_code])
        end
        
        return results[:response_reason_text][0..-2] # Forget the punctuation at the end
      end
        
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
      
      def split(response)
        response[1..-2].split(/\$,\$/)
      end
    end
    
    AuthorizedNetGateway = AuthorizeNetGateway
  end
end
