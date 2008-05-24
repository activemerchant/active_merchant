module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SageGateway < Gateway
      URL = 'https://www.sagepayments.net/cgi-bin/eftBankcard.dll?transaction'
          
      self.supported_countries = ['US', 'CA']
      
      # Credit cards supported by Sage
      # * VISA
      # * MasterCard
      # * AMEX
      # * Diners
      # * Carte Blanche
      # * Discover
      # * JCB
      # * Sears
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :diners_club]
      self.homepage_url = 'http://www.sagepayments.com'
      self.display_name = 'Sage Payment Solutions'
      
      # Transactions types:
      # <tt>01</tt> - Sale
      # <tt>02</tt> - AuthOnly 
      # <tt>03</tt> - Force/PriorAuthSale 
      # <tt>04</tt> - Void 
      # <tt>06</tt> - Credit 
      # <tt>11</tt> - PriorAuthSale by Reference*
      TRANSACTIONS = {
        :purchase           => '01',
        :authorization      => '02',
        :capture            => '11',
        :void               => '04',
        :credit             => '06'
      }
      
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, credit_card, options = {})
        post = {}
        add_transaction_data(post, money, credit_card, options)
        commit(:authorization, post)
      end
      
      def purchase(money, credit_card, options = {})
        post = {}
        add_transaction_data(post, money, credit_card, options)
        commit(:purchase, post)
      end                       
    
      # The +money+ amount is not used. The entire amount of the 
      # initial authorization will be captured.
      def capture(money, reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:capture, post)
      end
      
      def void(reference, options = {})
        post = {}
        add_reference(post, reference)
        commit(:void, post)
      end
      
      def credit(money, credit_card, options = {})
        post = {}
        add_transaction_data(post, money, credit_card, options)
        commit(:credit, post)
      end
          
      private
      def exp_date(credit_card)
        year  = sprintf("%.4i", credit_card.year)
        month = sprintf("%.2i", credit_card.month)

        "#{month}#{year[-2..-1]}"
      end
      
      def add_invoice(post, options)
        post[:T_ordernum] = options[:order_id].slice(0, 20)
        post[:T_tax] = amount(options[:tax]) unless options[:tax].blank?
        post[:T_shipping] = amount(options[:tax]) unless options[:tax].blank?
      end
      
      def add_reference(post, reference)
        post[:T_reference] = reference
      end
      
      def add_amount(post, money)
        post[:T_amt] = amount(money)
      end
      
      def add_customer_data(post, options)
        post[:T_customer_number] = options[:customer]
      end

      def add_addresses(post, options)
        billing_address   = options[:billing_address] || options[:address] || {}
        
        post[:C_address]    = billing_address[:address1]
        post[:C_city]       = billing_address[:city]
        post[:C_state]      = billing_address[:state]
        post[:C_zip]        = billing_address[:zip]
        post[:C_country]    = billing_address[:country] 
        post[:C_telephone]  = billing_address[:phone]
        post[:C_fax]        = billing_address[:fax]
        post[:C_email]      = options[:email]
        
        if shipping_address = options[:shipping_address]
          post[:C_ship_name]    = shipping_address[:name]
          post[:C_ship_address] = shipping_address[:address1]
          post[:C_ship_city]    = shipping_address[:city]
          post[:C_ship_state]   = shipping_address[:state]
          post[:C_ship_zip]     = shipping_address[:zip] 
          post[:C_ship_country] = shipping_address[:country]
        end
      end

      def add_credit_card(post, credit_card)
        post[:C_name]       = credit_card.name
        post[:C_cardnumber] = credit_card.number
        post[:C_exp]        = exp_date(credit_card)
        post[:C_cvv]        = credit_card.verification_value if credit_card.verification_value?
      end
      
      def add_transaction_data(post, money, credit_card, options)
        add_amount(post, money)
        add_invoice(post, options)
        add_credit_card(post, credit_card)        
        add_addresses(post, options)        
        add_customer_data(post, options)
      end
      
      def parse(data)
        response = {}
        response[:success]          = data[1,1]
        response[:code]             = data[2,6]
        response[:message]          = data[8,32].strip
        response[:front_end]        = data[40, 2]
        response[:cvv_result]       = data[42, 1]
        response[:avs_result]       = data[43, 1].strip
        response[:risk]             = data[44, 2]
        response[:reference]        = data[46, 10]
        
        response[:order_number], response[:recurring] = data[57...-1].split("\034")
        response
      end     
      
      def commit(action, params)
        response = parse(ssl_post(URL, post_data(action, params)))
        
        Response.new(success?(response), response[:message], response, 
          :test => test?, 
          :authorization => response[:reference],
          :avs_result => { :code => response[:avs_result] },
          :cvv_result => response[:cvv_result]
        )
      end
      
      def success?(response)
        response[:success] == 'A'
      end

      def post_data(action, params = {})
        params[:M_id]  = @options[:login]
        params[:M_key] = @options[:password]
        params[:T_code] = TRANSACTIONS[action]
        
        params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
    end
  end
end

