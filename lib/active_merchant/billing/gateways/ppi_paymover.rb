module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PpiPaymoverGateway < Gateway
      API_VERSION = '4'
      DEBUG = false
      
      APPROVED, DECLINED, NOT_POSSIBLE = '1', '100', '6'
      FRAUD_REVIEW = '8'
      
      DEFAULT_INDUSTRY = 'DIRECT_MARKETING'
      TRANSACTION_CONDITION_CODES = {
        :card_present_swiped => 7,
        :card_present_swiped_no_sig => 8,
        :card_present_keyed => 9,
        :debit_card_swiped_w_pin => 60,
        :ebt_card_keyed_w_pin => 61,
        :mail_or_fax_order => 1,
        :telephone_order => 2,
        :secure_ecommerce => 5,
        :recurring_payment => 6,
        :prearranged_payments => 50,
        :ach_telephone => 51,
        :ach_web => 52
      }
      
      TEST_URL = 'https://etrans.paygateway.com/TransactionManager'
      LIVE_URL = 'https://example.com/live'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.ppipaymover.com/'
      
      # The name of the gateway
      self.display_name = 'PPI Paymover'
      
      # Creates a new PPIPaymoverGateway
      #
      # The gateway requires that a valid login token is passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- The PPI Paymover Token (REQUIRED)
      # * <tt>:version_id</tt> -- The version of your application, passed through with request
      # * <tt>:cartridge_type</tt> -- A unique string that identifies your application.  Defaults to "Rails - ActiveMerchant"
      # * <tt>:industry</tt> -- Set the default industry passed with transactions.  One of "DIRECT_MARKETING", "RETAIL",
      #                         "LODGING", or "RESTAURANT".  Defaults to "DIRECT MARKETING". You can override this on
      #                         a per-transaction basis.
      # * <tt>:condition_code</tt> -- Set the default transaction condition code passed with transactions.  Defaults
      #                               to 5 (Secure Ecommerce).  You can override this on a per-transaction basis.
      def initialize(options = {})
        requires!(options, :login)
        options[:cartridge_type] ||= "Rails - ActiveMerchant"
        options[:industry] ||= DEFAULT_INDUSTRY
        options[:condition_code] ||= TRANSACTION_CONDITION_CODES[:secure_ecommerce]
        
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        
        add_default_options(post, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)        
        add_customer_data(post, options)
        
        commit('AUTH', money, post)
      end
      
      def purchase(money, creditcard, options = {})
        post = {}
        
        add_default_options(post, options)
        add_invoice(post, options)
        add_creditcard(post, creditcard)        
        add_address(post, creditcard, options)   
        add_customer_data(post, options)
             
        commit('SALE', money, post)
      end                       
    
      def capture(money, authorization, options = {})
        post = {:order_id => authorization}
        add_customer_data(post, options)
        commit('CAPTURE', money, post)
      end

      # Void a previous transaction
      #
      # ==== Parameters
      #
      # * <tt>authorization</tt> - The authorization returned from the previous authorize request.
      def void(authorization, options = {})
        post = {:order_id => authorization}
        add_customer_data(post, options)
        
        resp = commit('VOID', nil, post)
        
        if resp.success?
          # Attempt the second void (for purchase and auth/capture transactions)
          second = commit('VOID', nil, post)
          if second.params['response_code'] == NOT_POSSIBLE
            # Second transaction wasn't necessary
            return resp
          else
            return second
          end
        else
          return resp
        end
      end
      
      # Credit an account.
      #
      # This transaction is also referred to as a Refund and indicates to the gateway that
      # money should flow from the merchant to the customer.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be credited to the customer as an Integer value in cents.
      # * <tt>identification</tt> -- The ID of the original transaction against which the credit is being issued. (REQUIRED)
      # * <tt>options</tt> -- A hash of parameters.
      def credit(money, identification, options = {})
        post = { :order_id => identification }
        add_customer_data(post, options)

        commit('CREDIT', money, post)
      end


      
    
      private                       
      
      def add_customer_data(post, options)
        post[:bill_email] = options[:email] unless options[:email].blank?
        post[:order_customer_id] = options[:customer] unless options[:customer].blank?
        post[:customer_ip_address] = options[:customer_ip] unless options[:ip].blank?
      end

      def add_address(post, creditcard, options)      
        if address = options[:billing_address] || options[:address]
          post[:bill_address_one]  = address[:address1].to_s
          post[:bill_address_two]  = address[:address2].to_s
          post[:bill_company]      = address[:company].to_s
          post[:bill_phone]        = address[:phone].to_s
          post[:bill_postal_code]  = address[:zip].to_s
          post[:bill_city]         = address[:city].to_s
          post[:bill_country_code] = address[:country].to_s
          post[:bill_state_or_province]   = address[:state].blank?  ? 'n/a' : address[:state]
        end
        
        if address = options[:shipping_address]
          post[:ship_first_name]   = address[:first_name].to_s
          post[:ship_last_name]    = address[:last_name].to_s
          post[:ship_address_one]  = address[:address1].to_s
          post[:ship_address_two]  = address[:address2].to_s
          post[:ship_company]      = address[:company].to_s
          post[:ship_phone]        = address[:phone].to_s
          post[:ship_postal_code]  = address[:zip].to_s
          post[:ship_city]         = address[:city].to_s
          post[:ship_country_code] = address[:country].to_s
          post[:ship_state_or_province] = address[:state].blank?  ? 'n/a' : address[:state]
        end
      end

      def add_invoice(post, options)
        post[:order_id]          = options[:order_id] unless options[:order_id].blank?
        post[:order_description] = options[:description]
      end
      
      def add_creditcard(post, creditcard)      
        post[:credit_card_number]   = creditcard.number
        post[:credit_card_verification_number]  = creditcard.verification_value if creditcard.verification_value?
        post[:expire_month] = creditcard.month
        post[:expire_year] = creditcard.year
        post[:bill_first_name] = creditcard.first_name
        post[:bill_last_name]  = creditcard.last_name
      end
      
      def parse(body)
        results = {}
        
        body.split(/\n/).each do |pair|
          key,val = pair.split('=')
          results[key] = val
        end
        
        results
      end     
      
      def commit(action, money, parameters)
        parameters[:charge_total] = amount(money) unless action == 'VOID'
        
        url = test? ? TEST_URL : LIVE_URL
        
        if DEBUG
          puts "Posting to: #{url}"
          puts "-----------"
        end
        
        data = ssl_post url, post_data(action, parameters)
        
        if DEBUG
          puts "RAW RESPONSE:"
          puts data.inspect
          puts "----------"
        end

        response = parse(data)
        
        if DEBUG
          puts "RESPONSE:"
          puts response.inspect
          puts "----------"
        end

        message = message_from(response)

        Response.new(success?(response), message, response, 
          :test => test?, 
          :authorization => response['order_id'],
          :fraud_review => fraud_review?(response),
          :avs_result => response['avs_code'],
          :cvv_result => response['credit_card_verification_response']
        )
      end

      def success?(response)
        if DEBUG
          puts "Response code: #{response['response_code']} == #{APPROVED}"
        end
        response['response_code'] == APPROVED
      end
      
      def fraud_review?(response)
        return response['response_code'] == DECLINED && response['secondary_response_code'] == FRAUD_REVIEW
      end

      def message_from(response)
        return response['response_code_text']
      end
      
      def post_data(action, parameters = {})
        post = {}

        post[:account_token]     = @options[:login]
        post[:protocol_version]  = API_VERSION
        post[:version_id]        = @options[:version_id] if @options[:version_id]
        post[:charge_type]       = action
        post[:transaction_type]  = "CREDIT_CARD"
        post[:cartridge_type]    = @options[:cartridge_type]

        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        
        if DEBUG
          puts "REQUEST:"
          puts request.inspect
          puts "-----------"
        end
        
        request
      end
      
      def add_default_options(post, options)
        post[:transaction_condition_code] = options[:condition_code] || @options[:condition_code]
        post[:industry] = options[:industry] || @options[:industry]
      end
      
    end
  end
end

