module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CommercegateGateway < Gateway
      self.test_url = self.live_url = 'https://secure.commercegate.com/gateway/nvp'
      
      self.money_format = :dollars

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.commercegate.com/'

      # The name of the gateway
      self.display_name = 'CommerceGate'
      
      DEBUG = false;


      def initialize(options = {})
        requires!(options, :apiUsername, :apiPassword)
        super
      end
      
      # Test transaction to verify connectivity and return a simple response for client to parse. 
      # Credentials are verified using SYSTEM_TEST.
      def systemtest()
        result = commit('SYSTEM_TEST', options)
      end

      # An auth or authorization is also known as a pre-auth or hold. 
      # The funds on a card are held until the auth expires or is captured. An authorization can be captured (settled) or not. 
      # Most processors/ acquirers have a time limit on how long auth can stay available for capture. 
      # Please check with technical support on the length of time an auth is available for your acount.
      def authorize(creditcard, options = {})
        post = options        
        add_creditcard(post, creditcard)
        commit('AUTH', post)
      end
      
      # A capture will complete or settle a previous authorization, completing the transaction processor and money movement. 
      # The amount captured is equal to the authorization amount.
      def capture(transID, options = {})
        post = options
        post[:transID] = transID
        commit('CAPTURE', post)
      end
      
      # A sale or purchase is “basically” the same as a pre-auth (auth) and a capture (settle) in one transaction. 
      # This action will return a token for rebill operations
      def sale(creditcard, options = {})
        post = options        
        add_creditcard(post, creditcard)
        commit('SALE', post)
      end
      
      # A refund is returning funds back to the card after a successful sale or auth/capture that has
      # refund or matched credit since the original authorization code is used to match the transaction being refunded. 
      # A refund is returning all the original funds back to the card.
      def refund(transID, options = {})
        post = options
        post[:transID] = transID
        commit('REFUND', post)
      end
      
      # A rebill auth or authorization is used for subsequent authorizations. 
      # The credit card information isn't required on this action. 
      # A token from either an inital auth or sale action must be passed in to reference the credit card on file.
      def rebill_auth(token, options = {})
        rebill('REBILL_AUTH', token, options)
      end
      
      # A rebill sale is used for subsequent sales. The credit card information isn't required on this action. 
      # A token from either an inital auth or sale action must be passed in to reference the credit card on file.
      def rebill_sale(token, options = {})
        rebill('REBILL_SALE', token, options)
      end
      
      # A void auth will inform the processor this authorization will not be capture
      # and in most cases will release the held funds on the card. 
      # Please check with technical support on the length of time an authorization can be voided.
      def void_auth(transID)
        void('VOID_AUTH', transID)
      end
      
      # TODO
      # A void capture will inform the processor to cancel or void the capture. A capture can
      # only be voided if it hasn’t been submitted on the processor side. Typically, this is the same day or before the EOD processing on the
      # processor side. Please check with technical support on the length of time an authorization is available to be captured.
      #def void_capture(transID)
      #  void('VOID_CAPTURE', transID)
      #end
      
      # A sale can only be voided if it hasn’t been submitted on the processor side. 
      # Typically, this is the same day or before the EOD processing on the processor side. 
      # Please check with technical support on the length of time an sale is available to be voided for your account.
      #def void_sale(transID)
      #  void('VOID_SALE', transID)        
      #end
      
      # A refund can only be voided if it hasn’t been submitted on the processor side. 
      # Typically, this is the same day or before the EOD processing on the processor side. 
      # Please check with technical support on the length of time an refund is available to be voided for your account.
      #def void_refund(transID)
      #  void('VOID_REFUND', transID)        
      #end
      
      private

      def add_creditcard(params, creditcard)
        params[:firstName]   = creditcard.first_name()
        params[:lastName]    = creditcard.last_name()
        params[:cardNumber]  = creditcard.number()
        params[:expiryMonth] = creditcard.month()
        params[:expiryYear]  = creditcard.year()
        params[:cvv]         = creditcard.verification_value if creditcard.verification_value?
      end
      
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
      
      def parse(body)
        if (DEBUG) 
          puts("raw reply to parse: " + body) 
        end

        results = {}

        body.split(/\&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end

        results
      end
      
      def void(action, transID)
        post = {}
        post[:transID] = transID
        commit(action, post)        
      end
      
      def rebill(action, token, options)
        post = options
        post[:token] = token
        commit(action, post)
      end

      def commit(action, parameters)
        parameters[:apiUsername] = @options[:apiUsername]
        parameters[:apiPassword] = @options[:apiPassword]
        parameters[:action]      = action

        request = post_data(parameters)
        
        if (DEBUG) 
          puts("request: " + request) 
        end
        
        data = parse(ssl_post(self.live_url, request))

      end
      
      def post_data(parameters)
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

