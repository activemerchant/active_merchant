module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FederatedCanadaGateway < Gateway
			# Same URL for both test and live, testing is done by using the test username (demo) and password (password).
      URL = 'https://secure.federatedgateway.com/api/transact.php'
			
			APPROVED, DECLINED, ERROR = 1, 2, 3
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['CA']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.example.net/'
      
      # The name of the gateway
      self.display_name = 'New Gateway'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  

      def credit(money, identification, options = {}) # also referred to as refund
        post = { :transactionid => identification}
        commit('refund', money, post)
      end
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('auth', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('sale', money, post)
      end                       
    
      def capture(money, authorization, options = {})
				options[:transactionid] = authorization
        commit('capture', money, options)
      end
    
      private                       
      
      def add_customer_data(post, options)
				post[:firstname] = options[:first_name]
				post[:lastname] = options[:last_name]
				post[:phone] = options[:phone]				
				post[:email] = options[:email]
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:company] = address[:company].to_s	
          post[:address1] = address[:address1].to_s
          post[:address2] = address[:address2].to_s
          post[:city]    = address[:city].to_s
          post[:state]   = address[:state].to_s
          post[:zip]     = address[:zip].to_s
          post[:country] = address[:country].to_s
        end
        if address = options[:shipping_address]
          post[:shipping_firstname] = address[:first_name].to_s
          post[:shipping_lastname] = address[:last_name].to_s
          post[:shipping_company] = address[:company].to_s
          post[:shipping_address1] = address[:address1].to_s
          post[:shipping_address2] = address[:address2].to_s
          post[:shipping_city]    = address[:city].to_s
          post[:shipping_state]   = address[:state].to_s
          post[:shipping_zip]     = address[:zip].to_s
          post[:shipping_country] = address[:country].to_s
          post[:shipping_email]   = address[:email].to_s
        end
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(post, creditcard)
				post[:ccnumber] = creditcard.number
				post[:ccexp] = expdate(creditcard)
				post[:cvv] = creditcard.verification_value
      end

      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)
        "#{month}#{year[-2..-1]}"
      end
      
      def parse(body)
				body.split('&').inject({}) do |memo, x|
					k, v = x.split('=')
					memo[k] = v
					memo
				end
      end     
      
      def commit(action, money, parameters)
				parameters[:amount] = amount(money)
        data = ssl_post(URL, post_data(action, parameters))
				response = parse(data)
				message = message_from(response)
				test_mode = test?

				Response.new(success?(response), message, response, 
					:test => test?,
					:authorization => response['transactionid'],					
          :avs_result => response['avsresponse'],					
          :cvv_result => response['cvvresponse']
        )
      end

			def success?(response)
				response['response'] == '1'
			end
			
			def test?
				(@options[:login].eql?('demo')) && (@options[:password].eql?('password'))
			end

      def message_from(response)
				case response['response'].to_i
				when 1
					"Transaction Approved"
				when 2
					"Transaction Declined"
				else
					"Error in transaction data or system error"
				end
      end
      
      def post_data(action, parameters = {})
				parameters[:type] = action
				parameters[:username] = @options[:login]
				parameters[:password] = @options[:password]
				parameters.map{|k, v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
      end
    end
  end
end

