module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class XChargeGateway < Gateway
      TEST_URL = 'https://test.t3secure.net/x-chargeweb.dll'
      LIVE_URL = 'https://gw.t3secure.net/x-chargeweb.dll'
      
      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = ['US']
      
      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      
      # The homepage URL of the gateway
      self.homepage_url = 'http://www.x-charge.com/'
      
      # The name of the gateway
      self.display_name = 'X-Charge'
      
      self.money_format = :dollars
      
      def initialize(options = {})
        requires!(options, :XWebID, :AuthKey, :TerminalID, :Industry)
        @options = {
          :SpecVersion => "XWeb3.0", 
          :POSType => "PC",
          :Mode => test? ? "DEVELOPMENT" : "PRODUCTION",
          :PinCapabilities => "FALSE",
          :TrackCapabilities => "NONE",
        }.merge!(options)
        super
      end  
      
      # TODO: authorize with alias
      def authorize(money, creditcard, options = {})
        params = @options.merge(
          :TransactionType => "CreditAuthTransaction",
          :Amount => amount(money),
          :CustomerPresent => "FALSE",
          :CardPresent => "FALSE",
          :ECI => "7",
          :DuplicateMode => test? ? "CHECKING_OFF" : "CHECKING_ON"
        )
        add_invoice(params, options)
        add_creditcard(params, creditcard)        
        add_address(params, options)        
        add_customer_data(params, options)
        
        commit(params)
      end
      
      # Runs a credit sale transaction either with a creditcard or an Alias
      # pass options :CreateAlias => true to create an alias from the purchase
      # TODO: update alias
      def purchase(money, payment_source, options = {})
        params = @options.merge(
          :TransactionType => "CreditSaleTransaction",
          :Amount => amount(money),
          :CustomerPresent => "FALSE",
          :CardPresent => "FALSE",
          :ECI => "7",
          :DuplicateMode => test? ? "CHECKING_OFF" : "CHECKING_ON"
        )
        add_invoice(params, options)
        
        if payment_source.is_a?(String)
          params[:Alias] = payment_source
        else
          add_creditcard(params, payment_source)
        end

        add_invoice(params, options)
        add_address(params, options)   
        add_customer_data(params, options)
             
        commit(params)
      end                       
      
      def capture(money, authorization, options = {})
        params = @options.merge(
          :TransactionType => "CreditCaptureTransaction",
          :Amount => amount(money),
          :TransactionID => authorization,
          :DuplicateMode => test? ? "CHECKING_OFF" : "CHECKING_ON"
        )

        add_invoice(params, options)
        add_customer_data(params, options)
        
        commit(params)
      end
    
      def void(identification, options={})
        params = @options.merge(
          :TransactionType => "CreditVoidTransaction",
          :TransactionID => identification,
          :DuplicateMode => test? ? "CHECKING_OFF" : "CHECKING_ON"
        )
        add_invoice(params, options)
        add_customer_data(params, options)
        commit(params)
      end
      
      def return(money, identification)
        params = @options.merge(
          :TransactionType => "CreditReturnTransaction",
          :Amount => amount(money),
          :TransactionID => identification,
          :CustomerPresent => "FALSE",
          :CardPresent => "FALSE",
          :DuplicateMode => test? ? "CHECKING_OFF" : "CHECKING_ON"
        )
        add_invoice(params, options)
        add_customer_data(params, options)
        commit(params)
      end
      
      def alias_create(creditcard, options={})
        params = @options.merge(
          :TransactionType => "AliasCreateTransaction"
        )
        add_creditcard(params, creditcard)
        add_address(params, options)
        add_customer_data(params, options)
        commit(params)
      end

      def alias_update(identification, creditcard)
        params = @options.merge(
          :TransactionType => "AliasUpdateTransaction",
          :Alias => identification
        )
        add_creditcard(params, creditcard)
        add_customer_data(params, options)
        commit(params)
      end
      
      def alias_lookup(identification)
        params = @options.merge(
          :TransactionType => "AliasLookupTransaction",
          :Alias => identification
        )
        add_customer_data(params, options)
        commit(params)
      end
      
      def alias_delete(identification)
        params = @options.merge(
          :TransactionType => "AliasDeleteTransaction",
          :Alias => identification
        )
        add_customer_data(params, options)
        commit(params)
      end
      
      private                       
      
      def add_customer_data(params, options)
        params[:UserID] = options[:customer] if options.has_key? :customer
      end

      def add_address(params, options)
        if billing_address = options[:billing_address] || options[:address]
          params[:Address] =  billing_address[:address1].to_s
          params[:ZipCode] =  billing_address[:zip].to_s
        end
      end

      def add_invoice(params, options)
        params[:InvoiceNumber] = options[:order_id] if options.has_key? :order_id
      end
      
      def add_creditcard(params, creditcard)     
         params.merge!(
          :AcctNum  => creditcard.number,
          :ExpDate  => format(creditcard.month, :two_digits)+format(creditcard.year, :two_digits)
         )

         # don't include card code if it's blank or if this an alias update
         unless creditcard.verification_value.blank? || params[:TransactionType] == "AliasUpdateTransaction"
           params[:CardCode] = creditcard.verification_value
         end
      end   
      
      def commit(parameters)
        response = CGI.parse(ssl_get((test? ? TEST_URL : LIVE_URL) +"?"+encode(parameters)))        
        Response.new( success?(response), response["ResponseDescription"].to_s, response, 
          :test => test?, 
          :authorization => response["Alias"].to_s.blank? ? response["TransactionID"].to_s : response["Alias"].to_s,
          :avs_result => { :code => response["AVSResponseCode"].to_s },
          :cvv_result => response["CardCodeResponse"].to_s
        )
      end
      
      def success?(response)
        ["000", "003", "005"].include? response["ResponseCode"].to_s
      end
      
      # encodes hash to querystring parameters
      def encode(hash)
        hash.collect{|(k,v)| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
      end
    end
  end
end