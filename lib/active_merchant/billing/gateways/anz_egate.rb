module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AnzEgateGateway < Gateway
      GATEWAY_URL = 'https://migs.mastercard.com.au/vpcdps'
      VIRTUAL_PAYMENT_CLIENT_API_VERION = 1
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.money_format = :cents
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.anz.com.au'
      
      # The name of the gateway
      self.display_name = 'ANZ eGate'

            
      def initialize(options = {})
        requires!(options, :merchant_id, :access_code)
        @options = options
        super
      end  
      
      def purchase(money, creditcard, options = {})
        requires!(options, :invoice, :order_id)
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_amount(post, money)
        add_transaction_id(post, options)
             
        commit('pay', post)
      end                       
    
      def credit(money, identification, options = {})
        requires!(options, :username, :password, :order_id)
        params = {}
        add_transaction_id(params, options)
        add_identification(params, identification)
        add_username_password(params, options)
        add_amount(params, money)
        commit('refund', params)
      end
      
      def query(options = {})
        requires!(options, :order_id)
        post = {}
        add_transaction_id(post, options)
        add_username_password(post, options)
        commit('queryDR', post)
      end
    
      private                       
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)      
      end

      def add_invoice(post, options)
        return post.merge!(:vpc_TicketNo  => options[:invoice], 
                           :vpc_OrderInfo => options[:invoice])
      end
      
      def add_creditcard(post, creditcard)
        expiry = "#{creditcard.year.to_s[-2,2]}#{sprintf("%.2i", creditcard.month)}"
        return post.merge!(:vpc_CardNum => creditcard.number,
                           :vpc_CardSecurityCode => creditcard.verification_value,
                           :vpc_CardExp => "#{expiry}")
      end

      def add_amount(post, money)
        post[:vpc_Amount] = money.to_i
      end

      def add_transaction_id(post, options)
        return post.merge!(:vpc_MerchTxnRef => options[:order_id])
      end

      def add_username_password(post, options)
        return post.merge!(:vpc_User     => options[:username],
                           :vpc_Password => options[:password])
      end

      def add_identification(post, identification)
        return post.merge!(:vpc_TransactionNo => identification,
                           :vpc_TransNo => identification)
      end

      def post_data(action, parameters)
        return parameters.merge(:vpc_Version      => VIRTUAL_PAYMENT_CLIENT_API_VERION,
                                :vpc_AccessCode   => @options[:access_code],
                                :vpc_Merchant     => @options[:merchant_id],
                                :vpc_Command      => action).to_query
      end

      def parse(body)
        params = CGI::parse(body)
        hash = {}
        params.each do |key, value|
          hash[key] = value[0]
        end
        hash
      end
      
      def commit(action, parameters)
        payment_params = post_data(action, parameters)
        response = ssl_post(GATEWAY_URL, payment_params)
        message_from(response)
      end

      def message_from(response_str)
        response = parse(response_str)
        authorization = response['vpc_TransactionNo']
        success = (response['vpc_TxnResponseCode'] == '0')
        message = CGI.unescape(response['vpc_Message']) if response['vpc_Message']
        Response.new(success, message, response, :authorization => authorization, :test => test?)
      end
    end
  end
end

