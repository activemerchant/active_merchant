module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EProcessingNetworkGateway < Gateway
      self.money_format = :dollars
      self.test_url = self.live_url = 'https://www.eProcessingNetwork.Com/cgi-bin/tdbe/transact.pl'
      
      RESPONSE_CODE, AVS_RESULT_CODE, CVV_RESPONSE_CODE, TRANSACTION_ID = 0, 1, 2, 4
      
      CARD_CODE_ERRORS = %w( N S )
      AVS_ERRORS = %w( A E N R W Z )
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.eProcessingNetwork.com/'
      
      # The name of the gateway
      self.display_name = 'eProcessingNetwork'
      
      # Creates a new EProcessingNetworkGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The ePN API Login ID (REQUIRED)
      # * <tt>:password</tt> -- The ePN Transaction Security Key. (REQUIRED)
      # * <tt>:billing_address</tt> -- Customer's billing address. (REQUIRED)
      #   Street address and ZIP code are mandatory and used for the AVS lookup.
      # * <tt>:test</tt> -- +true+ or +false+. If true, perform transactions against the test account. 
      #   Otherwise, perform transactions against the provided account information.
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      # Performs an authorization, which reserves the funds on the customer's credit card, but does not
      # charge the card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized. Either an Integer value in cents or a Money object.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, creditcard, options = {})
        requires!(options, :billing_address)
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('AuthOnly', money, post)
      end
      
      # Perform a purchase, which is essentially an authorization and capture in a single operation.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased. Either an Integer value in cents or a Money object.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, creditcard, options = {})
        post = {}
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('Sale', money, post)
      end   
      
      # Captures the funds from an authorized transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured.  Either an Integer value in cents or a Money object.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      def capture(money, authorization, options = {})
        post = {:TransID => authorization}    # Must pass TID in TransID
        commit('Auth2Sale', money, post)
      end
      
      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount of the original transaction.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request.
      def void(money, authorization, options = {})
        post = {:TransID => authorization}
        commit('Void', money, post)
      end
      
 
      private                       
      
      def add_customer_data(post, options)
      end

      # Adds the customer's address to the POST request.
      # eProcessingNetwork REQUIRES street address and ZIP code.
      def add_address(post, creditcard, options)    
        if address = options[:billing_address] || options[:address]
          post[:Address]  = address[:address1].to_s
          post[:Zip]      = address[:zip].to_s
          # City, State are optional and will be viewable in ePN reports.
          #post[:City]     = address[:city].to_s
          #post[:State]    = address[:state].to_s
        end
      end

      def add_invoice(post, options)
        post[:Inv]          = options[:order_id]
        post[:Description]  = options[:description] || ''
      end
      
      def add_creditcard(post, creditcard)
        post[:CardNo]     = creditcard.number
        post[:CVV2]       = creditcard.verification_value if creditcard.verification_value?
        post[:CVV2Type]   = creditcard.verification_value? ? '1' : '0'
        post[:ExpMonth]   = creditcard.month
        post[:ExpYear]    = creditcard.year
        post[:FirstName]  = creditcard.first_name
        post[:LastName]   = creditcard.last_name
      end
      
      def success?(response)
        response[:response_code] == 'Y'
      end
      
      def parse(body)
        fields = body.split(',')
        
        results = {
          :response_code => fields[RESPONSE_CODE][1..1],
          :response_reason_code => fields[RESPONSE_CODE][1..1],
          :response_reason_text => fields[RESPONSE_CODE][2..-2],
        }
        if fields.size > 1
          results[:avs_result_code] = fields[AVS_RESULT_CODE][-3..-3]
          results[:transaction_id] = fields[TRANSACTION_ID][1..-2]
          results[:card_code] = fields[CVV_RESPONSE_CODE][-3..-3]
        end

        results
      end     
      
      def commit(action, money, parameters)
        url = test? ? self.test_url : self.live_url

        # Inv must be passed report to receive a transaction ID
        parameters[:Inv] = 'report' unless parameters[:Inv]
        parameters[:Total] = amount(money)
        
        data = ssl_post url, post_data(action, parameters)
        
        response = parse(data)
        message = message_from(response)
        Response.new(success?(response), message, response,
          :test => @options[:test] || test?,
          :authorization => response[:transaction_id],
          :avs_result => { :code => response[:avs_result_code] },
          :cvv_result => response[:card_code]
        )
      end

      def message_from(response)
        unless response[:response_code] == 'Y'
          return CVVResult.messages[response[:card_code]] if CARD_CODE_ERRORS.include?(response[:card_code])
          return AVSResult.messages[response[:avs_result_code]] if AVS_ERRORS.include?(response[:avs_result_code])
        end
        
        return response[:response_reason_text].nil? ? '' : response[:response_reason_text]
      end
      
      def post_data(action, parameters = {})  
        parameters[:ePNAccount]   = @options[:login]
        parameters[:RestrictKey]  = @options[:password]
        parameters[:TranType]     = action
        parameters[:Email]        = ''
        parameters[:HTML]         = 'No'
        
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

