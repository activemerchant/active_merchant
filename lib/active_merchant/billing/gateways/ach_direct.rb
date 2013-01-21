module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AchDirectGateway < Gateway
      TEST_URL = 'https://www.paymentsgateway.net/cgi-bin/posttest.pl'
      LIVE_URL = 'https://www.paymentsgateway.net/cgi-bin/postauth.pl'
  
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
  
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
  
      # The homepage URL of the gateway
      self.homepage_url = 'http://paymentsgateway.achdirect.com/'
  
      # The name of the gateway
      self.display_name = 'ACH Direct Payments Gateway(AGI)'
      self.money_format = :dollars
   
      #TRANSACTION_CODES
      SALE = 10
      AUTH_ONLY = 11
      CAPTURE = 12
      CREDIT = 13
      VOID = 14
      PRE_AUTH = 15
  
      #RESPONSE PREFIXES
      APPROVED = "A"
      DECLINED = "U"
      FORMAT_ERROR = "F"
      EXCEPTION = "E"
  
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end
      
      def credit(money, creditcard, options = {})
        post = {}
        # add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
        commit(CREDIT, money, post)
      end
  
      def void(auth, transaction_id)
        post = {}
        post[:pg_original_authorization_code] = auth
        post[:pg_original_trace_number] = transaction_id
        commit(VOID, nil, post)
      end
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
    
        commit(AUTH_ONLY, money, post)
      end
  
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)
        add_customer_data(post, options)
         
        commit(SALE, money, post)
      end
 
      def capture(money, authorization, options = {})
        post = {:trans_id => authorization}
        add_customer_data(post, options)
        commit(CAPTURE, money, post)
      end
 
      # def self.supported_cardtypes
      # [:visa, :master, :american_express]
      # end
     
      private
  
      def add_customer_data(post, options)
        post[:ecom_billto_online_email] = options[:email] if options.has_key? :email
        post[:pg_consumer_id] = options[:customer] if options.has_key? :customer
      end
 
      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:ecom_billto_postal_name_first] = address[:first_name].to_s
          post[:ecom_billto_postal_name_last] = address[:last_name].to_s
          post[:pg_billto_postal_name_company] = address[:company].to_s
          post[:ecom_billto_postal_street_line1] = address[:address1].to_s
          post[:ecom_billto_postal_street_line2] = address[:address2].to_s
          post[:ecom_billto_postal_city] = address[:city].to_s
          post[:ecom_billto_postal_stateprov] = address[:state].blank? ? 'n/a' : address[:state]
          post[:ecom_billto_postal_postalcode] = address[:zip].to_s
          post[:ecom_billto_postal_countrycode] = address[:country].to_s
          post[:ecom_billto_telecom_phone_number] = address[:phone].to_s
        end
      end
 
      def add_invoice(post, options)
        post[:ecom_consumerorderid] = options[:order_id]
      end
  
      def add_creditcard(post, creditcard)
        post[:ecom_payment_card_type] = creditcard.type
        post[:ecom_payment_card_number] = creditcard.number
        post[:ecom_payment_card_verification] = creditcard.verification_value if creditcard.verification_value?
        post[:ecom_payment_card_expdate_year] = creditcard.year
        post[:ecom_payment_card_expdate_month] = creditcard.month
        post[:ecom_payment_card_name] = creditcard.name
      end
  
      def post_data(action, parameters = {})
        post = {}
 
        post[:pg_merchant_id] = @options[:login]
        post[:pg_password] = @options[:password]
        post[:pg_transaction_type] = action
        post[:pg_avs_method] = "11000" unless (action == VOID or action == CREDIT) # 0=no check, 1=check but don't fail, 2=check and fail
 
        # post[:version] = API_VERSION
        # post[:relay_response] = "FALSE"
        # post[:delim_data] = "TRUE"
        # post[:delim_char] = ","
        # post[:encap_char] = "$"
 
        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request += "&endofdata"
      end
  
      def parse(msg)
        resp = {}
        msg.split("\n").each do |li|
          key, value = li.split("=")
          resp[key.to_sym] = value.to_s.strip
        end
        resp
      end
  
      def commit(action, money, parameters)
        parameters[:pg_total_amount] = amount(money) unless action == VOID
    
        url = test? ? TEST_URL : LIVE_URL
 
        request = post_data(action, parameters)
        # puts "Sending request to gateway: #{request}" if test?
        data = ssl_post url, request
        # puts "Response from gateway was: #{data}" if test?
 
        @response = parse(data)
        
        Response.new(success?(@response), @response[:pg_response_description], @response,
          :test => test?,
          :authorization => @response[:pg_authorization_code],
          :avs_code => @response[:pg_avs_result],
          :transaction_id => @response[:pg_trace_number]
        )
      end
 
      def success?(resp)
        resp[:pg_response_type] == APPROVED
      end
  
    end
  end
end