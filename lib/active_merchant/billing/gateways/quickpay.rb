require 'rexml/document'
require 'digest/md5'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QuickpayGateway < Gateway
      URL = 'https://secure.quickpay.dk/api'

      self.default_currency = 'DKK'  
      self.money_format = :cents
      self.supported_cardtypes = [ :dankort, :forbrugsforeningen, :visa, :master, :american_express, :diners_club, :jcb, :maestro ]
      self.supported_countries = ['DK']
      self.homepage_url = 'http://quickpay.dk/'
      self.display_name = 'Quickpay'
      
      PROTOCOL = 3
      
      MD5_CHECK_FIELDS = {
        :authorize => [:protocol, :msgtype, :merchant, :ordernumber, :amount, :currency, :autocapture, :cardnumber, :expirationdate, :cvd, :cardtypelock],
        :capture   => [:protocol, :msgtype, :merchant, :amount, :transaction],
        :cancel    => [:protocol, :msgtype, :merchant, :transaction],
        :refund    => [:protocol, :msgtype, :merchant, :amount, :transaction],
        :subscribe => [:protocol, :msgtype, :merchant, :ordernumber, :cardnumber, :expirationdate, :cvd, :cardtypelock, :description],
        :recurring => [:protocol, :msgtype, :merchant, :ordernumber, :amount, :currency, :autocapture, :transaction],
        :status    => [:protocol, :msgtype, :merchant, :transaction],
        :chstatus  => [:protocol, :msgtype, :merchant],
      }
      
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
        
        add_amount(post, money, options)
        add_creditcard(post, creditcard, options)
        add_invoice(post, options)
        add_autocapture(post, options)

        commit(:authorize, post)
      end
      
      def subscribe(money, creditcard, options = {})                       
        post = {}
        
        add_creditcard(post, creditcard, options)
        add_invoice(post, options)
        add_description(post, options)

        commit(:subscribe, post)
      end
      
      def recurring(money, options = {})
        post = {}
        
        add_invoice(post, options)
        add_amount(post, money, options)
        add_autocapture(post, options)
        add_reference(post, options)
        
        commit(:recurring, post)
      end
      
      def cancel(identification, options = {})
        post = {}
        
        add_reference(post, identification)
        
        commit(:cancel, post)
      end
      
      def capture(money, authorization, options = {})
        post = {}
        
        add_reference(post, authorization)
        add_amount_without_currency(post, money)
        
        commit(:capture, post)
      end
      
      def refund(money, identification, options = {})
        post = {}

        add_amount_without_currency(post, money)
        add_reference(post, identification)

        commit(:refund, post)
      end
      
      def status(identification, options = {})
        post = {}
        
        add_reference(post, identification)
        
        commit(:status, post)
      end
      
      def chstatus(identification, options = {})
        post = {}
        
        commit(:status, post)
      end
    
      # Alternative names for messages

      # Known as 'refund' in the QuickPay API
      def credit(money, identification, options = {})
        refund(money, identification, options)
      end

      # Authorize with autocapture
      def purchase(money, creditcard, options = {})
        authorize(money, creditcard, options.merge(:autocapture => true))
      end
      
      # Known as 'cancel' in the QuickPay API
      def void(identification, options = {})
        cancel(identification, options)
      end
    
      private                       
  
      def add_amount(post, money, options = {})
        post[:amount]   = amount(money)
        post[:currency] = options[:currency] || currency(money)
      end
      
      def add_amount_without_currency(post, money, options = {})
        post[:amount] = amount(money)
      end
      
      def add_invoice(post, options)
        post[:ordernumber] = format_order_number(options[:order_id])
      end
      
      def add_creditcard(post, credit_card, options)
        post[:cardnumber]     = credit_card.number   
        post[:cvd]            = credit_card.verification_value
        post[:expirationdate] = expdate(credit_card)
        post[:cardtypelock]   = options[:cardtypelock] unless options[:cardtypelock].blank?
      end
      
      def add_reference(post, identification)
        post[:transaction] = identification
      end
      
      def add_autocapture(post, options)
        post[:autocapture] = (options[:autocapture] == true || options[:autocapture].to_s == '1') ? '1' : '0'
      end
      
      def add_description(post, options)
        post[:description] = options[:description]
      end
      
      def commit(action, params)
        post_data = post_data(action, params)
        response_data = ssl_post(URL, post_data)

        puts URL
        puts post_data
        puts response_data

        response = parse(response_data)
        
        Response.new(successful?(response), message_from(response), response, 
          :test => test?, 
          :authorization => response[:transaction]
        )
      end
      
      def successful?(response)
        response[:qpstat] == APPROVED
      end

      def parse(data)
        response = {}
        
        doc = REXML::Document.new(data)
        
        doc.root.elements.each do |element|
          response[element.name.to_sym] = element.text
        end
        
        response
      end

      def message_from(response)
        case response[:qpstat]
        when '008'   # Error in request data
          response[:qpstatmsg].to_s
          #.scan(/[A-Z][a-z0-9 \/]+/).to_sentence
        else          
          response[:qpstatmsg].to_s
        end
      end
      
      def post_data(action, params = {})
        params[:protocol] = PROTOCOL
        params[:msgtype]  = action.to_s
        params[:merchant] = @options[:login]
        #params[:testmode] = '1' if test?
        params[:md5check] = generate_check_hash(action, params)
        
        params.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
  
      def generate_check_hash(action, params)
        puts action
        string = MD5_CHECK_FIELDS[action].collect do |key|
          params[key]
        end.join('')
        
        # Add the md5checkword
        string << @options[:password].to_s

        puts string
        
        Digest::MD5.hexdigest(string)
      end
      
      def expdate(credit_card)
        year  = format(credit_card.year, :two_digits)
        month = format(credit_card.month, :two_digits)

        "#{year}#{month}"
      end
      
      # Limited to 20 digits max
      def format_order_number(number)
        number.to_s.gsub(/[^\w_]/, '').rjust(4, "0")[0...20]
      end
    end
  end
end

