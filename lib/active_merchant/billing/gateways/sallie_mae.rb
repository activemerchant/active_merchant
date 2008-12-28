module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SallieMaeGateway < Gateway
      TEST_URL = 'https://trans.salliemae.com/cgi-bin/process.cgi'
      LIVE_URL = 'https://example.com/live'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.example.net/'
      
      # The name of the gateway
      self.display_name = 'New Gateway'
      
      def initialize(options = {})
        #requires!(options, :login, :password)
        @options = options
        super
      end  

      # data = {
      #   :action  => "ns_quicksale_cc",
      #   :acctid  => @config[:account_id], # to test: "TEST0"
      #   :subid   => @config[:sub_id],
      #   :amount  => fields["credit_card_amount"],
      #   :ccnum   => fields["credit_card_number"], # to test: 5454545454545454
      #   :ccname  => fields["credit_card_name"],
      #   :cvv2    => fields["credit_card_cvv"],
      #   :expmon  => fields["credit_card_expiration_month"],
      #   :expyear => fields["credit_card_expiration_year"]
      # }

      # c = Curl::Easy.new("https://trans.salliemae.com/cgi-bin/process.cgi")
      # c.http_post(
      #   data.to_s(:params)
      # )
      
      
      def authorize(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('authonly', money, post)
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
        commit('capture', money, post)
      end
    
      private                       
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:ci_billaddr1] = address[:address1].to_s
          post[:ci_billaddr2] = address[:address2].to_s unless address[:address2].blank?
          post[:ci_billcity]  = address[:city].to_s
          post[:ci_billstate] = address[:state].to_s
          post[:ci_billzip]   = address[:zip].to_s       
        end

        if shipping_address = options[:shipping_address] || options[:address]
          post[:ci_shipaddr1] = shipping_address[:address1].to_s
          post[:ci_shipaddr2] = shipping_address[:address2].to_s unless shipping_address[:address2].blank?
          post[:ci_shipcity]  = shipping_address[:city].to_s
          post[:ci_shipstate] = shipping_address[:state].to_s
          post[:ci_shipzip]   = shipping_address[:zip].to_s
        end
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(post, creditcard)
        post[:ccnum]   = creditcard.number.to_s
        post[:ccname]  = creditcard.name.to_s
        post[:cvv2]    = creditcard.verificationvalue.to_s if creditcard.verificationvalue?
        post[:expmon]  = creditcard.month.to_s
        post[:expyear] = creditcard.year.to_s
      end
      
      def parse(body)
      end     
      
      def commit(action, money, parameters)
      end

      def message_from(response)
      end
      
      def post_data(action, parameters = {})
      end
    end
  end
end

