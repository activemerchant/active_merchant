require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DibsGateway < Gateway
      self.live_url = 'https://api.dibspayment.com/merchant/v1/JSON/Transaction/'
      
      # Each transation type has own url ending 
      # https://api.dibspayment.com/merchant/v1/JSON/Transaction/ACTION_URL[:action]
      ACTION_URL = {
        :authorize       => 'AuthorizeCard',
        :refund          => 'RefundTransaction',
        :cancel          => 'CancelTransaction',
        :capture         => 'CaptureTransaction',
        :createticket    => 'CreateTicket',
        :authorizeticket => 'AuthorizeTicket'  
      }
      
      # The statuses that DIBS return on a successfull transaction.
      SUCCESS_TYPES = ["ACCEPT", "PENDING"]
      
      # Set the default currency separator!
      self.money_format = :cents
      
      # Set the default currency
      self.default_currency = 'DKK'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['DK', 'SE', 'NO']

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa,:visa_se, :master, :american_express, :american_express_dk ,:discover, 
                                  :forbrugsforeningen, :jcb, :visa_electron, :maestro, :maestro_dk, :diners_club, 
                                  :diners_club_dk, :eurocard, :mastercard, :eurocard_dk, :mastercard_dk, :dankort]

      # The homepage URL of the gateway
      self.homepage_url = 'http://www.dibspayment.com/'

      # The name of the gateway
      self.display_name = 'Dibs Payment Window'
      
      # Creates a new DibsGateway
      #
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      #
      # ==== Options
      #
      # * <tt>:login</tt> -- MerchantId that customer has in DIBS system
      # * <tt>:password</tt> -- HMAC code. This is SHA-256 encrypted hash that corresponds to the merchantId.
      # 
      def initialize(options = {})
        requires!(options, :login, :password)
        super
      end
      
      # authorize() performs the first part of a credit card transaction (the authorisation). 
      # The authorisation includes e.g. credit- and debit-card control and reservation of 
      # the required amount for later capture. 
      # Please note that this service requires a PCI certification, as directed by Visa International.
      def authorize(money, creditcard, options = {})
        post = {} #{:amount => money}.merge(options)
        
        add_order_id(post, options)
        add_creditcard(post, creditcard, options)
        add_amount(post, money, options)
        add_currency(post, options)
        add_customer_data(post, options)
        add_test(post)
        commit(:authorize, post)
      end
      
      # create_ticket() performs a credit- and debit-card check 
      # and saves the credit card information for recurring payments
      def create_ticket(creditcard, options = {}) 
        post = {}
        
        add_order_id(post, options)
        add_creditcard(post, creditcard, options)
        add_currency(post, options)
        add_customer_data(post, options)
        add_test(post)
        commit(:createticket, post)
      end
      
      # () make a recurring payment using a ticket previously created either 
      # via the create_ticket() or using the authorize().
      def recurring(authorization, money ,options = {}) 
         post = {
          :ticketId => authorization
        }        
        
        add_order_id(post, options)
        add_amount(post, money ,options) 
        add_currency(post, options)
        commit(:authorizeticket, post)
      end
      
      # capture() the second part of any transaction is the capture process. 
      # Usually this take place at the time of shipping the goods to the customer, 
      # and is normally accessed via the DIBS administration interface. 
      def capture(money, authorization ,options = {})
        post = {
          :amount=> money
        }
        
        add_reference(post, authorization)
        commit(:capture, post)
      end   
      
      # void() service cancels an authorization. 
      # If the acquirer used supports reversals, the system automatically 
      # sends one such along and thereby releasing any reserved amounts.
      def void(authorization) 
        post = {
          :transactionId => authorization
        }
        
        commit(:cancel, post)
      end
      
      # credit() is an alias for refund(). See refund()
      def credit(money, authorization, options = {})
        deprecated CREDIT_DEPRECATION_MESSAGE
        refund(money, authorization, options)
      end
      
      # refund() refunds a captured transaction and transfers 
      # the money back to the card holders account.
      def refund(money, authorization ,options = {}) 
        post = {
          :amount => money
        }
        
        add_reference(post, authorization)
        commit(:refund, post)
      end

      private
      def add_creditcard(post, creditcard, options)
        post[:cardNumber]   = creditcard.number
        post[:expMonth]     = creditcard.month
        post[:expYear]      = creditcard.year
        post[:cvc]          = creditcard.verification_value
        post[:issueNumber]  = options[:issueNumber]
      end

      def commit(action, post)
        headers  = {'Content-Type' => 'application/x-www-form-urlencoded'}
        response = JSON::parse(ssl_post(self.live_url + ACTION_URL[action], 
                                        post_data(post), 
                                        headers))
        
        success = SUCCESS_TYPES.include?(response["status"])
        message = message_from(response)
       
        Response.new(success, message, response,
          :test => test? ? 1 : 0,
          :authorization => [:authorizeticket, :createticket].include?(action) ? response["ticketId"] : response["transactionId"]
        )
      end

      def message_from(data)
        status = case data["status"]
        when "DECLINE"
          return data["declineReason"]
        when "PENDING"
          return "PENDING"
        when "ERROR"
          return data["declineReason"]
        else
          return "The transaction was successful"
        end
      end

      def post_data(post)
        post[:merchantId] = @options[:login]
        check_fileds(post)
        calc_mac(post)
        'q='.concat(post.to_json)
      end
      
      # MAC calculation according to algorithm on DIBS tech site 
      # http://tech.dibspayment.com/dibs_api/flexwin/other_features/mac_calculation/
      def calc_mac(post) 
        string = "";
        post.sort_by {|sym| sym.to_s}.map do |key,value|
          if key != "MAC"
            if string.length > 0 
              string += "&"
            end
              string += "#{key}=#{value}"
           end 
        end
        post[:MAC] = OpenSSL::HMAC.hexdigest('sha256', hexto_sring(@options[:password]), string)  
      end
      
      def hexto_sring(hex)
        string = ""
        var = hex.scan(/.{2}/)
        var.map do |value|
          string += value.hex.chr
        end
        return string
      end
    
      def add_reference(post, authorizaion)
        post[:transactionId] = authorizaion
      end
    
      def add_order_id(post, options)
        post[:orderId] = options[:orderId]
      end
    
      def add_amount(post, money ,options, currency = true) 
       post[:amount] = money
      end
   
      def add_currency(post, options)
       post[:currency] = options[:currency]
      end
     
      def add_customer_data(post, options)
        post[:clientIp] = options[:clientIp]
      end 
      
      def test?
        if ActiveMerchant::Billing::Base.mode == :test
          return true
        end
      end 
      
      def check_fileds(post)
        post.each do |key,value|
          if value.nil? 
            post.delete(key)
          end
        end
      end 
      
      def add_test(post)
        if ActiveMerchant::Billing::Base.mode == :test
          post[:test] = true
        end
      end
     
    end
  end
end

