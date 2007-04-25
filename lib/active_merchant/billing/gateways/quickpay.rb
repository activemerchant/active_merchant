require 'rexml/document'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickpayGateway < Gateway
      URL = 'https://secure.quickpay.dk/transaction.php'
      
      attr_reader :url 
      attr_reader :response
      attr_reader :options
      
      class_inheritable_accessor :default_currency
      self.default_currency = 'DKK'
      
      self.money_format = :cents
      
      TRANSACTIONS = {
        :sale          => '1100',
        :capture       => '1220',
        :void          => '1420',
        :credit        => 'credit'
      }
      
      POS_CODES = {
        :mail               => '100020100110',
        :phone              => '100030100110',
        :internet           => 'L00500L00130',
        :internet_secure    => 'K00500K00130',
        :internet_edankort  => 'KM0500R00130',
        :internet_recurring => 'K00540K00130' 
      }
      
      MD5_CHECK_FIELDS = {
        :sale    => [:msgtype, :cardnumber, :amount, :expirationdate, :posc, :ordernum, :currency, :cvd, :merchant, :authtype, :reference, :transaction],
        :capture => [:msgtype, :amount, :merchant, :transaction],
        :void    => [:msgtype, :merchant, :transaction],
        :credit  => [:msgtype, :amount, :merchant, :transaction]
      }
      
      CURRENCIES = [ 'DKK', 'EUR', 'NOK', 'GBP', 'USD' ]
      
      APPROVED = '000'
      
      # The login is the QuickpayId
      # The password is the md5checkword from the Quickpay admin interface
      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end  
      
      def authorize(money, creditcard, options = {})
        post = {}
        
        add_amount(post, money)
        add_creditcard(post, creditcard)        
        add_invoice(post, options)

        commit(:sale, post)
      end
      
      def purchase(money, creditcard, options = {})
        if result = test_result_from_cc_number(creditcard.number)
          return result
        end
        
        auth = authorize(money, creditcard, options)
        auth.success? ? capture(money, auth.authorization) : auth
      end                       
    
      def capture(money, authorization, options = {})
        post = {}
        
        add_reference(post, authorization)
        add_amount(post, money)
        
        commit(:capture, post)
      end
      
      def void(identification, options = {})
        post = {}
        
        add_reference(post, identification)
        
        commit(:void, post)
      end
      
      def credit(money, identification, options = {})
        post = {}
        
        add_amount(post, money)
        add_reference(post, identification)
        
        commit(:credit, post)
      end
    
      # Supported Credit Cards
      # MasterCard, herunder Eurocard
      # Maestro
      # Visa
      # Visa Electron
      # JCB
      # American Express
      def self.supported_cardtypes
        [ :visa, :master, :american_express, :jcb ]
      end
         
      private                       
  
      def add_amount(post, money)
        post[:amount]   = amount(money)
        post[:currency] = currency(money)
      end
      
      def add_invoice(post, options)
        post[:ordernum] = options[:order_id]
        post[:posc]   = POS_CODES[:internet_secure]
      end
      
      def add_creditcard(post, credit_card)
        post[:cardnumber]     = credit_card.number
        post[:cvd]            = credit_card.verification_value
        post[:expirationdate] = expdate(credit_card) 
      end
      
      def add_reference(post, identification)
        post[:transaction] = identification
      end
      
      def commit(action, params)
        
        if result = test_result_from_cc_number(params[:cardnumber])
          return result
        end
        
        data = ssl_post URL, post_data(action, params)

        @response = parse(data)
        
        success = @response[:qpstat] == APPROVED
        message = message_from(@response)
        
        Response.new(success, message, @response, 
            :test => test?, 
            :authorization => @response[:transaction]
        )
      end

      def parse(data)
        response = {}
        
        doc = REXML::Document.new(data)
        
        doc.root.attributes.each do |name, value|
          response[name.to_sym] = value
        end
        
        response
      end

      def message_from(response)
        case response[:qpstat]
        when '008'
          response[:qpstatmsg].to_s.scan(/[A-Z][a-z0-9 \/]+/).to_sentence
        else
          response[:qpstatmsg].to_s
        end
      end
      
      def post_data(action, params = {})
        params[:merchant]   = @options[:login]
        params[:msgtype]    = TRANSACTIONS[action]
        
        check_field = (action == :sale) ? :md5checkV2 : :md5check
        params[check_field] = generate_check_hash(action, params)
        
        request = params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
  
      def generate_check_hash(action, params)
        string = MD5_CHECK_FIELDS[action].collect do |key|
          params[key]
        end.join('')
        
        # Add the md5checkword
        string << @options[:password].to_s
        
        Digest::MD5.hexdigest(string)
      end
      
      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end
      
      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{year}#{month}"
      end
    end
  end
end

