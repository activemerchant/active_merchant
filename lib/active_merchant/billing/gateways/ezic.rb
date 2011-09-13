module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    #
    # EZIC has an agent/reseller program so there are various other gateways that
    # can simply subclass this gateway and provided the required information such 
    # as gateway URL etc.
    #
    # This is only a partial implementation of what the gateway is capable of
    #
    class EzicGateway < Gateway
      TEST_URL = 'https://secure.bluefingateway.com:1402/gw/sas/direct3.1'
      LIVE_URL = 'https://secure.bluefingateway.com:1402/gw/sas/direct3.1'

      # There is no testing gateway, the account has to be in test mode or run this specific CC number
      TESTING_CC = '4444333322221111'

      AUTH_ONLY, SALE, CAPTURE = 'A', 'S', 'D'
      PAY_TYPE = 'C'

      SUCCESS, PENDING, SUCCESS_AUTH_ONLY, FAILED, SETTLEMENT_FAILED, DUPLICATE = '1', 'I', 'T', '0', 'F', 'D'
      SUCCESS_CODES = [SUCCESS, SUCCESS_AUTH_ONLY, PENDING]
      FAILURE_CODES = [FAILED, SETTLEMENT_FAILED, DUPLICATE]

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.ezic.com/'

      # The name of the gateway
      self.display_name = 'EZIC Gateway'


      # the :login parameter is the "account_id" provided by bluefin
      def initialize(options = {})
        requires!(options, :login)
        @options = options
        super
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
        post = {:orig_id => authorization}
        commit(CAPTURE, money, post)
      end


      private                       


      def add_customer_data(post, options)
      end


      def add_address(post, creditcard, options)
        if address = options[:billing_address] || options[:address]
          post[:bill_street]  = address[:address1].to_s
          post[:cust_phone]   = address[:phone].to_s
          post[:bill_zip]     = address[:zip].to_s
          post[:bill_city]    = address[:city].to_s
          post[:bill_country] = address[:country].blank? ? 'US' : address[:country].to_s
          post[:bill_state]   = address[:state].to_s
        end    
      end


      def add_invoice(post, options)
      end


      def add_creditcard(post, creditcard)
        post[:bill_name1]  = creditcard.first_name
        post[:bill_name2]  = creditcard.last_name
        post[:card_number] = test? ? TESTING_CC : creditcard.number
        post[:card_cvv2]   = creditcard.verification_value if creditcard.verification_value?
        post[:card_expire] = expdate(creditcard)      
      end


      def parse(body)
        hash = CGI::parse body
        # convert string keys to symbol keys (could use HashWithIndifferentAccess)
        hash.to_options!
        # for some reason CGI::parse leaves each value as an array
        hash.each {|k, v| hash[k] = v.first if v.is_a? Array } 
        hash
      end     


      def commit(action, money, parameters)
        parameters[:amount] = amount(money)
        url = test? ? TEST_URL : LIVE_URL

        data = ssl_post url, post_data(action, parameters)

        response = parse(data)
        message = message_from(response)

        # Return the response. 
        # a returned test response has the text "TEST" in the auth_msg
        test_mode = test? || message =~ /TEST/         
        Response.new(success?(response), message, response, 
          :test => test_mode, 
          :authorization => response[:auth_code],
          :avs_result => { :code => response[:avs_code] },
          :cvv_result => response[:cvv2_code]
        )
      end


      def message_from(response)
        message = ""

        case response[:status_code]
        when SUCCESS
          message = "Success"
        when PENDING
          message = "Pending"
        when SUCCESS_AUTH_ONLY
          message = "Successful Authorization"
        when FAILED
          message = "Failed"
        when SETTLEMENT_FAILED
          message = "Settlement Failed"
        when DUPLICATE
          message = "Duplicate Transaction"
        end

        message += " - #{response[:auth_msg]}" if response[:auth_msg].present?  
        message += " - #{response[:reason_code2]}" if response[:reason_code2].present?  
        message
      end


      def post_data(action, parameters = {})
        post = {}
        post[:account_id]     = @options[:login]
        post[:pay_type]       = PAY_TYPE
        post[:tran_type]      = action

        # combine with the other parameters and URL encode
        request = post.merge(parameters)
        request.to_query
      end


      def success?(response)
        SUCCESS_CODES.include? response[:status_code]
      end


      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

    end
  end
end

