module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class <%= class_name %>Gateway < Gateway
      TEST_URL = 'https://example.com/test'
      LIVE_URL = 'https://example.com/live'
      
      attr_reader :url 
      attr_reader :response
      attr_reader :options

      def initialize(options = {})
        #requires!(options, :login, :password)
        @options = options
        super
      end  
      
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
    
      def self.supported_cardtypes
        [:visa, :master, :american_express]
      end
         
      private                       
      
      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)      
      end

      def add_invoice(post, options)
      end
      
      def add_creditcard(post, creditcard)      
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

