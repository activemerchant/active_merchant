begin
  require 'tclink'
rescue LoadError
  # Ignore, but we will fail hard if someone actually tries to use this gateway 
end

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    
    # To get started using TrustCommerce with active_merchant, download the tclink library from http://www.trustcommerce.com/tclink.html,
    # following the instructions available there to get it working on your system. Once it is installed, you should be able to make sure
    # that it is visible to your ruby install by opening irb and typing "require 'tclink'", which should return "true".
    #
    # TO USE:
    # First, make sure you have everything setup correctly and all of your dependencies in place with:
    # 
    #   require 'rubygems'
    #   require 'active_merchant'
    #
    # ActiveMerchant expects amounts to be Integer values in cents
    #
    #   tendollar = 1000
    #
    # Next, create a credit card object using a TC approved test card.
    #
    #   creditcard = ActiveMerchant::Billing::CreditCard.new(
    #	    :number => '4111111111111111',
    #	    :month => 8,
    #	    :year => 2006,
    #	    :first_name => 'Longbob',
    #     :last_name => 'Longsen'
    #   )
    #
    # To finish setting up, create the active_merchant object you will be using, with the TrustCommerce gateway. If you have a
    # functional TrustCommerce account, replace login and password with your account info. Otherwise the defaults will work for
    # testing.
    #
    #   gateway = ActiveMerchant::Billing::Base.gateway(:trust_commerce).new(:login => "TestMerchant", :password => "password")
    #
    # Now we are ready to process our transaction
    #
    #   response = gateway.purchase(tendollar, creditcard)
    #
    # Sending a transaction to TrustCommerce with active_merchant returns a Response object, which consistently allows you to:
    #
    # 1) Check whether the transaction was successful
    #
    #   response.success?
    #
    # 2) Retrieve any message returned by TrustCommerce, either a "transaction was successful" note or an explanation of why the
    # transaction was rejected.
    #
    #   response.message
    #
    # 3) Retrieve and store the unique transaction ID returned by Trust Commerece, for use in referencing the transaction in the future.
    #
    #   response.params["transid"]
    #
    # This should be enough to get you started with Trust Commerce and active_merchant. For further information, review the methods
    # below and the rest of active_merchant's documentation, as well as Trust Commerce's user and developer documentation.
    
    class TrustCommerceGateway < Gateway
      SUCCESS_TYPES = ["approved", "accepted"]
      
      DECLINE_CODES = {
        "decline"       => "The credit card was declined",
        "avs"           => "AVS failed; the address entered does not match the billing address on file at the bank",
        "cvv"           => "CVV failed; the number provided is not the correct verification number for the card",
        "call"          => "The card must be authorized manually over the phone",
        "expiredcard"   => "Issuer was not certified for card verification",
        "carderror"     => "Card number is invalid",
        "authexpired"   => "Attempt to postauth an expired (more than 14 days old) preauth",
        "fraud"         => "CrediGuard fraud score was below requested threshold",
        "blacklist"     => "CrediGuard blacklist value was triggered", 
        "velocity"      => "CrediGuard velocity control value was triggered",
        "dailylimit"    => "Daily limit in transaction count or amount as been reached",
        "weeklylimit"   => "Weekly limit in transaction count or amount as been reached",
        "monthlylimit"  => "Monthly limit in transaction count or amount as been reached"
      }
      
      BADDATA_CODES = {
        "missingfields"       => "One or more parameters required for this transaction type were not sent",
        "extrafields"         => "Parameters not allowed for this transaction type were sent",
        "badformat"           => "A field was improperly formatted, such as non-digit characters in a number field",
        "badlength"           => "A field was longer or shorter than the server allows",
        "merchantcantaccept"  => "The merchant can't accept data passed in this field",
        "mismatch"            => "Data in one of the offending fields did not cross-check with the other offending field"
      }
      
      ERROR_CODES = {
        "cantconnect"   => "Couldn't connect to the TrustCommerce gateway",
        "dnsfailure"    => "The TCLink software was unable to resolve DNS hostnames",
        "linkfailure"   => "The connection was established, but was severed before the transaction could complete",
        "failtoprocess" => "The bank servers are offline and unable to authorize transactions"
      }
      
      # URL
      attr_reader :url 
      attr_reader :response
      attr_reader :options

      self.money_format = :cents
      self.supported_cardtypes = [:visa, :master, :discover, :american_express, :diners_club, :jcb]
      self.supported_countries = ['US']
      self.homepage_url = 'http://www.trustcommerce.com/'
      self.display_name = 'TrustCommerce'
      
      # Creates a new TrustCommerceGateway
      # 
      # The gateway requires that a valid login and password be passed
      # in the +options+ hash.
      # 
      # ==== Options
      #
      # * <tt>:login</tt> -- The TrustCommerce account login.
      # * <tt>:password</tt> -- The TrustCommerce account password.
      # * <tt>:test => +true+ or +false+</tt> -- Perform test transactions
      #
      # ==== Test Account Credentials
      # * <tt>:login</tt> -- TestMerchant
      # * <tt>:password</tt> -- password
      def initialize(options = {})
        requires!(options, :login, :password)
      
        @options = options
        super
      end
      
      def test?
        @options[:test] || Base.gateway_mode == :test
      end
      
      # authorize() is the first half of the preauth(authorize)/postauth(capture) model. The TC API docs call this
      # preauth, we preserve active_merchant's nomenclature of authorize() for consistency with the rest of the library. This
      # method simply checks to make sure funds are available for a transaction, and returns a transid that can be used later to
      # postauthorize (capture) the funds.
      
      def authorize(money, creditcard_or_billing_id, options = {})
        parameters = {
          :amount => amount(money),
        }                                                             
        
        add_payment_source(parameters, creditcard_or_billing_id)
        add_address(parameters, options)
        commit('preauth', parameters)
      end
      
      # purchase() is a simple sale. This is one of the most common types of transactions, and is extremely simple. All that you need
      # to process a purchase are an amount in cents or a money object and a creditcard object or billingid string.
      
      def purchase(money, creditcard_or_billing_id, options = {})        
        parameters = {
          :amount => amount(money),
        }                                                             
        
        add_payment_source(parameters, creditcard_or_billing_id)
        add_address(parameters, options)
        commit('sale', parameters)
      end

      # capture() is the second half of the preauth(authorize)/postauth(capture) model. The TC API docs call this
      # postauth, we preserve active_merchant's nomenclature of capture() for consistency with the rest of the library. To process
      # a postauthorization with TC, you need an amount in cents or a money object, and a TC transid.
      
      def capture(money, authorization, options = {})
        parameters = {
          :amount => amount(money),
          :transid => authorization,
        }
                                                  
        commit('postauth', parameters)
      end
      
      # credit() allows you to return money to a card that was previously billed. You need to supply the amount, in cents or a money object,
      # that you want to refund, and a TC transid for the transaction that you are refunding.
      
      def credit(money, identification, options = {})  
        parameters = {
          :amount => amount(money),
          :transid => identification
        }
                                                  
        commit('credit', parameters)
      end
      
      # recurring() a TrustCommerce account that is activated for Citatdel, TrustCommerce's
      # hosted customer billing info database.
      #
      # Recurring billing uses the same TC action as a plain-vanilla 'store', but we have a separate method for clarity. It can be called
      # like store, with the addition of a required 'periodicity' parameter:
      # 
      # The parameter :periodicity should be specified as either :bimonthly, :monthly, :biweekly, :weekly, :yearly or :daily
      #
      #   gateway.recurring(tendollar, creditcard, :periodicity => :weekly)
      #
      # You can optionally specify how long you want payments to continue using 'payments'
            
      def recurring(money, creditcard, options = {})        
        requires!(options, [:periodicity, :bimonthly, :monthly, :biweekly, :weekly, :yearly, :daily] )
      
        cycle = case options[:periodicity]
        when :monthly
          '1m'
        when :bimonthly
          '2m'
        when :weekly
          '1w'
        when :biweekly
          '2w'
        when :yearly
          '1y'
        when :daily
          '1d'
        end
        
        parameters = {
          :amount => amount(money),
          :cycle => cycle,
          :verify => options[:verify] || 'y',
          :billingid => options[:billingid] || nil,
          :payments => options[:payments] || nil,
        }
        
        add_creditcard(parameters, creditcard)
                                                  
        commit('store', parameters)
      end      
      
      # store() requires a TrustCommerce account that is activated for Citatdel. You can call it with a credit card and a billing ID
      # you would like to use to reference the stored credit card info for future captures. Use 'verify' to specify whether you want
      # to simply store the card in the DB, or you want TC to verify the data first.
      
      def store(creditcard, options = {})   
        parameters = {
          :verify => options[:verify] || 'y',
          :billingid => options[:billingid] || nil,
        }
        
        add_creditcard(parameters, creditcard)
        add_address(parameters, options)                              
        commit('store', parameters)
      end
      
      # To unstore a creditcard stored in Citadel using store() or recurring(), all that is required is the billing id. When you run
      # unstore() the information will be removed and a Response object will be returned indicating the success of the action.
      def unstore(identification, options = {})
        parameters = {
          :billingid => identification,
        }
                                                  
        commit('unstore', parameters)
      end      
          
      private
      def add_payment_source(params, source)
        if source.is_a?(String)
          add_billing_id(params, source)
        else
          add_creditcard(params, source)
        end
      end
      
      def expdate(creditcard)
        year  = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end
      
      def add_creditcard(params, creditcard)
        params[:media]     = "cc"
        params[:name]      = creditcard.name
        params[:cc]        = creditcard.number      
        params[:exp]       = expdate(creditcard)
        params[:cvv]       = creditcard.verification_value if creditcard.verification_value?
      end
      
      def add_billing_id(params, billingid)
        params[:billingid] = billingid
      end
      
      def add_address(params, options)
        address = options[:billing_address] || options[:address]
        
        if address          
          params[:address1]  = address[:address1] unless address[:address1].blank?
          params[:address2]  = address[:address2] unless address[:address2].blank?
          params[:city]      = address[:city]     unless address[:city].blank?
          params[:state]     = address[:state]    unless address[:state].blank?
          params[:zip]       = address[:zip]      unless address[:zip].blank?
          params[:country]   = address[:country]  unless address[:country].blank?
          params[:avs]       = 'n'
        end        
      end
      
      def clean_and_stringify_params(parameters)
        # TCLink wants us to send a hash with string keys, and activemerchant pushes everything around with
        # symbol keys. Before sending our input to TCLink, we convert all our keys to strings and dump the symbol keys.
        # We also remove any pairs with nil values, as these confuse TCLink.
        parameters.keys.reverse.each do |key|
          if parameters[key]
            parameters[key.to_s] = parameters[key]
          end
          parameters.delete(key)
        end
      end
  
      def commit(action, parameters)
        test = test? || parameters[:test_request]
        parameters[:custid]      = @options[:login]
        parameters[:password]    = @options[:password]
        parameters[:demo]        = test ? 'y' : 'n'
        parameters[:action]      = action
                
        if result = test_result_from_cc_number(parameters[:cc])
          return result
        end
        
        begin        
          clean_and_stringify_params(parameters)
        
          data = TCLink.send(parameters)
          # to be considered successful, transaction status must be either "approved" or "accepted"
          success = SUCCESS_TYPES.include?(data["status"])
          message = message_from(data)
       
          Response.new(success, message, data, :test => test, :authorization => data["transid"] )
        rescue NameError => e 
          if e.message =~ /constant TCLink/
            raise 'Trust Commerce requires "tclink" library from http://www.trustcommerce.com/tclink.html'        
          else
            raise
          end
        end
        
      end
      
      def message_from(data)        
        status = case data["status"]
        when "decline" 
          return DECLINE_CODES[data["declinetype"]]
        when "baddata"
          return BADDATA_CODES[data["error"]]
        when "error"
          return ERROR_CODES[data["errortype"]]
        else
          return "The transaction was successful"
        end
      end
      
    end
  end
end