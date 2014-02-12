module ActiveMerchant #:nodoc:

  module Billing #:nodoc:
    class CommercegateGateway < Gateway
      self.test_url = self.live_url = 'https://secure.commercegate.com/gateway/nvp'
      
      self.supported_countries = 'All except Iran, Iraq, Syria, North Korea'
      self.money_format = :dollars
      self.default_currency = 'EUR'

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.commercegate.com/'

      # The name of the gateway
      self.display_name = 'CommerceGate'
      
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end

      # An auth or authorization is also known as a pre-auth or hold. 
      # The funds on a card are held until the auth expires or is captured. An authorization can be captured (settled) or not. 
      # Most processors/ acquirers have a time limit on how long auth can stay available for capture. 
      # Please check with technical support on the length of time an auth is available for your acount. 
      def authorize(money, creditcard, options = {})
        post = {}
        add_creditcard(post, creditcard)
        add_auth_purchase_options(post, money, options)
        commit('AUTH', post)
      end

      # A capture will complete or settle a previous authorization, completing the transaction processor and money movement. 
      # The amount captured is equal to the authorization amount.
      # For CG gateway money should be nil, authorization is transaction ID returned by authorize method
      def capture(money, authorization, options = {})
        post = options
        post[:transID] = authorization
        commit('CAPTURE', post)
      end

      # A purchase is “basically” the same as a pre-auth (auth) and a capture (settle) in one transaction. 
      def purchase(money, creditcard, options = {})
        post = {}        
        add_creditcard(post, creditcard)
        add_auth_purchase_options(post, money, options)
        commit('SALE', post)        
      end

      # A refund is returning funds back to the card after a successful purchase or auth/capture that has
      # refund or matched credit since the original authorization code is used to match the transaction being refunded. 
      # A refund is returning all the original funds back to the card.
      # For CG gateway money should be nil, identification is transaction ID returned by capture|purchase methods     
      def refund(money, identification, options = {})
        post = options
        post[:transID] = identification
        commit('REFUND', post)        
      end

      # A void will inform the processor this authorization will not be capture
      # and in most cases will release the held funds on the card. 
      # Please check with technical support on the length of time an authorization can be voided.
      # For CG gateway identificationis transaction ID returned by authorize method
      def void(identification, options = {})
        post = {}
        post[:transID] = identification
        commit('VOID_AUTH', post)
      end

      private
      
      def add_gateway_specific_options(post, gateway_specific_options)
        post[:siteID]  = gateway_specific_options[:siteID]
        post[:offerID] = gateway_specific_options[:offerID]        
      end
        
      def add_address(post, address)
        post[:address]     = address[:address1]
        post[:city]        = address[:city]
        post[:state]       = address[:state]
        post[:postalCode]  = address[:zip]
        post[:countryCode] = address[:country]
      end  
        
      def add_auth_purchase_options(post, money, options)
        add_address(post, options[:address])
        add_gateway_specific_options(post, options[:gateway_specific_options])
        
        post[:customerIP]  = options[:ip]        
        post[:amount]      = money
        post[:email]       = options[:email]
        post[:currencyCode]= options[:currency]
        post[:merchAcc]    = options[:merchant]

      end

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
        results = {}

        body.split(/\&/).each do |pair|
          key,val = pair.split(/=/)
          results[key] = val
        end

        results
      end
      
      def commit(action, parameters)
        parameters[:apiUsername] = @options[:login]
        parameters[:apiPassword] = @options[:password]
        parameters[:action]      = action
        begin
          response = parse(ssl_post(self.live_url, post_data(parameters)))
        rescue ResponseError => e
          response = parse_error_response(e, action)  
        end
          
        Response.new(successful?(response), message_from(response), response,
          :test => false,
          :authorization => response['transID']
        )

      end
      
      def parse_error_response(response_error, action)
        response = {:action => action, :returnCode => '-1', :returnText => response_error}
      end
      
      def successful?(response)
        response['returnCode'] == '0'
      end

      def message_from(response)
        CGI.unescape(response['returnText'])
      end
      
      def post_data(parameters)
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

