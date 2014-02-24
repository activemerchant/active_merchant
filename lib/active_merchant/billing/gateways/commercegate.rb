module ActiveMerchant #:nodoc:

  module Billing #:nodoc:
    class CommercegateGateway < Gateway
      self.test_url = self.live_url = 'https://secure.commercegate.com/gateway/nvp'
      
      self.supported_countries = %w(AD AE AT AU BA BE BG BN CA CH CY CZ DE DK EE EG ES FI FR GB
                                    GI GL GR HK HR HU ID IE IL IM IN IS IT LI LK LT LU LV MC MT 
                                    MU MV MX MY NL NO NZ PH PL PT QA RO RU SA SE SG SI SK SM TR 
                                    UA UM US VA)
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
        add_auth_purchase_options(post, amount(money), options)
        commit('AUTH', post)
      end

      # A capture will complete or settle a previous authorization, completing the transaction processor and money movement. 
      # The amount captured is equal to the authorization amount.
      def capture(money, authorization, options = {})
        post = {}        
        post[:currencyCode] = options[:currency] || currency(money) 
        post[:amount] = amount(money) 
        post[:transID] = authorization
        commit('CAPTURE', post)
      end

      # A purchase is “basically” the same as a pre-auth (auth) and a capture (settle) in one transaction. 
      def purchase(money, creditcard, options = {})
        post = {}        
        add_creditcard(post, creditcard)
        add_auth_purchase_options(post, amount(money), options)
        commit('SALE', post)        
      end

      # A refund is returning funds back to the card after a successful purchase or auth/capture that has
      # refund or matched credit since the original authorization code is used to match the transaction being refunded. 
      # A refund is returning all the original funds back to the card.     
      def refund(money, identification, options = {})
        post = {}     
        post[:currencyCode] = options[:currency] || currency(money) 
        post[:amount] = amount(money)         
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
            
      def add_gateway_specific_options(post, options)
        post[:siteID]  = options[:site_id]
        post[:offerID] = options[:offer_id]        
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
        add_gateway_specific_options(post, options)
        
        post[:customerIP]  = options[:ip]        
        post[:amount]      = money
        post[:email]       = options[:email]
        post[:currencyCode]= options[:currency]
        post[:merchAcc]    = options[:merchant]

      end

      def add_creditcard(params, creditcard)
        params[:firstName]   = creditcard.first_name
        params[:lastName]    = creditcard.last_name
        params[:cardNumber]  = creditcard.number
        params[:expiryMonth] = creditcard.month
        params[:expiryYear]  = creditcard.year
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
          results[key] = CGI.unescape(val)
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
        
        options = {
          :authorization => response['transID'],
          :test => test?
        }
        
        if action == 'AUTH' or action == 'SALE'          
          options[:avs_result] = { :code => response[:avsCode] }
          options[:cvv_result] = response[:cvvCode]
        end
        
        Response.new(successful?(response), message_from(response), response, options)

      end
      
      def parse_error_response(response_error, action)
        response = {:action => action, :returnCode => '-1', :returnText => response_error}
      end
      
      def successful?(response)
        response['returnCode'] == '0'
      end

      def message_from(response)
        unless response['returnText'].nil? or response['returnText'] == ''
          response['returnText']
        else
          "Unknown error. Ask support for details."
        end
      end
      
      def post_data(parameters)
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

