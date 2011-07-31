module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MaxxGateway < Gateway
      TEST_URL = 'https://www.maxxgateway.com/api/transact.php'
      LIVE_URL = 'https://www.maxxgateway.com/api/transact.php'
        
      ActiveMerchant::Billing::Base.gateway_mode = ActiveMerchant::Billing::Base.mode

      AVS_ERRORS = %w( A E N R W Z )
      PAYMENT_GATEWAY_RESPONSES = {
        100 => "Approved",
        200 => "Declined",
        201 => "Do Not Honor",
        202 => "Insufficient Funds",
        203 => "Over Limit",
        204 => "Transaction Not Allowed",
        220 => "Incorrect Payment Data",
        221 => "No Such Card Issuer",
        222 => "No Card Number on file with Issuer",
        223 => "Expired Card",
        224 => "Invalid Expiration Date",
        225 => "Invalid Card Security Code",
        240 => "Call Issuer for Further Information",
        250 => "Pick Up Card",
        251 => "Lost Card",
        252 => "Stolen Card",
        253 => "Fradulant Card",
        260 => "Declined with further Instructions Available",
        261 => "Declined - Stop All Recurring Payments",
        262 => "Declined - Stop this Recurring Program",
        263 => "Declined - Update Cardholder Data Available",
        264 => "Declined - Retry in a few days",
        300 => "Rejected by Gateway",
        400 => "Error Returned by Processor",
        410 => "Invalid Merchant Configuration",
        411 => "Merchant Account is Inactive",
        420 => "Communication Error",
        421 => "Communication Error with Issuer",
        430 => "Duplicate Transaction at Processor",
        440 => "Processor Format Error",
        441 => "Invalid Transaction Information",
        460 => "Processor Feature not Available",
        461 => "Unsupported Card Type"
      } 

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'https://www.maxxgateway.com'
      
      # The name of the gateway
      self.display_name = 'Maxx Payment Gateway'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        
        commit('auth', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        commit('sale', money, post)
      end                       
      
      def credit(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        commit('refund', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post = {:PNRef => authorization}
        commit('capture', money, post)
      end
      
      def void(authorization, options = {})
        post = {:PNRef => authorization}
        commit('void', nil, post)
      end
    
      private                       
      
      def add_address(post, creditcard, options)      
        if address = options[:billing_address] || options[:address]
          post[:address1] = options[:address].to_s
          post[:city] = options[:city].to_s
          post[:state] = options[:state].to_s
          post[:zip] = options[:zip].to_s
        end
      end

      def add_creditcard(post, creditcard)
        post[:ccnumber] = creditcard.number
        post[:cvv] = creditcard.verification_value if creditcard.verification_value?
        post[:ccexp] = expdate(creditcard)
        post[:firstname] = "#{creditcard.first_name}"
        post[:lastname] = "#{creditcard.last_name}"
        post[:track_1] = creditcard.track1 unless creditcard.track1.blank?
        post[:track_2] = creditcard.track2 unless creditcard.track2.blank?
      end
      
      def parse(body)
        split(body)
      end     
      
      def commit(action, money, parameters)
        parameters[:amount] = (action == 'void' ? "" : amount(money))

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

        Response.new(response[:response_code].to_s == '100', message, response,
          :test => test_mode,
          #:authorization => response[:PNRef],
          :authorization => response[:authcode],
          :avs_result => { :code => (response[:avsresponse] if response[:avsresponse]) },
          :cvv_result => (response[:cvvresponse] if response[:cvvresponse])
        )
      end

      def message_from(response)
        PAYMENT_GATEWAY_RESPONSES[response[:response_code].to_i]
      end
      
      def post_data(action, parameters = {})
        post = {}
        post[:username] = @options[:login]
        post[:password] = @options[:password]
        post[:type] = action
        post[:cvv] = parameters[:cvv] || ""
        post[:ccnumber] = parameters[:ccnumber] || ""
        post[:ccexp] = parameters[:ccexp] || ""
        post[:track_1] = parameters[:track_1] || ""
        post[:track_2] = parameters[:track_2] || ""
        post[:transactionid] = parameters[:transactionid] || ""
        post[:firstname] = parameters[:firstname] || ""
        post[:lastname] = parameters[:lastname] || ""
        post[:address1] = parameters[:address1] || ""
        post[:city] = parameters[:city] || ""
        post[:state] = parameters[:state] || ""
        post[:zip] = parameters[:zip] || ""
        #post[:ExtData] = parameters[:ExtData] || ""
        #post[:InvNum] = parameters[:InvNum] || ""
        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end

      def expdate(creditcard)
        year = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)
        "#{month}#{year[-2..-1]}"
      end

      def split(response)
        hash = {}
        response = response.split('&')
        response.each do |k|
          hash[(k.split('=')[0]).to_sym] = k.split('=')[1]
        end
        hash
      end


    end
  end
end

