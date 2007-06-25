require 'net/http'
require 'net/https'
require 'digest/md5'
require 'active_merchant/billing/response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # The Gateway class is the base class for all ActiveMerchant gateway
    # implementations. The list of gateway functions that concrete
    # gateway classes can and should implement include the following:
    # 
    # === Core operations supported by most gateways
    # * purchase(money, creditcard, options = {})
    # * authorize(money, creditcard, options = {})
    # * capture(money, authorization, options = {})
    # * void(identification, options = {})
    # * credit(money, identification, options = {})
    class Gateway
      include PostsData
      include RequiresParameters
      include CreditCardFormatting
      
      DEBIT_CARDS = [ :switch, :solo, :maestro ]
      
      # The format of the amounts used by the gateway
      # :dollars => '12.50'
      # :cents => '1250'
      class_inheritable_accessor :money_format
      self.money_format = :dollars
      
      # The default currency for the transactions if no currency is provided
      class_inheritable_accessor :default_currency
      
      # The countries of merchants the gateway supports
      class_inheritable_accessor :supported_countries
      self.supported_countries = []
      
      # The supported card types for the gateway
      class_inheritable_accessor :supported_cardtypes
      self.supported_cardtypes = []
      
      class_inheritable_accessor :homepage_url
      class_inheritable_accessor :display_name
      
      # The application making the calls to the gateway
      # Useful for things like the PayPal build notation (BN) id fields
      class_inheritable_accessor :application_id
      self.application_id = 'ActiveMerchant'
      
      # Return the matching gateway for the provider
      # * <tt>bogus</tt>: BogusGateway - Does nothing ( for testing)
      # * <tt>moneris</tt>: MonerisGateway
      # * <tt>authorize_net</tt>: AuthorizeNetGateway
      # * <tt>trust_commerce</tt>: TrustCommerceGateway
      # 
      #   ActiveMerchant::Base.gateway('moneris').new
      def self.gateway(name)
        ActiveMerchant::Billing.const_get("#{name.to_s.downcase}_gateway".camelize)
      end                        
             
      # Does this gateway support credit cards of the passed type?
      def self.supports?(type)
        supported_cardtypes.include?(type.intern)
      end       
    
      attr_reader :options
      # Initialize a new gateway 
      # 
      # See the documentation for the gateway you will be using to make sure there
      # are no other required options
      def initialize(options = {})    
        @ssl_strict = options[:ssl_strict] || false
      end
                                     
      # Are we running in test mode?
      def test?
        Base.gateway_mode == :test
      end
            
      private
      def name 
        self.class.name.scan(/\:\:(\w+)Gateway/).flatten.first
      end
      
      def test_result_from_cc_number(number)
        return false unless test?
        
        case number.to_s
        when '1', 'success' 
          Response.new(true, 'Successful test mode response', {:receiptid => '#0001'}, :test => true, :authorization => '5555')
        when '2', 'failure' 
          Response.new(false, 'Failed test mode response', {:receiptid => '#0001'}, :test => true)
        when '3', 'error' 
          raise Error, 'big bad exception'
        else 
          false
        end
      end
      
      # Return a string with the amount in the appropriate format
      def amount(money)
        return nil if money.nil?
        cents = money.respond_to?(:cents) ? money.cents : money 

        if money.is_a?(String) or cents.to_i < 0
          raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.' 
        end

        case self.money_format
        when :cents
          cents.to_s
        else
          sprintf("%.2f", cents.to_f/100)
        end
      end
      
      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end
      
      def requires_start_date_or_issue_number?(credit_card)
        return false if credit_card.type.blank?
        
        DEBIT_CARDS.include?(credit_card.type.to_sym)
      end
      
      def generate_unique_id
         md5 = Digest::MD5.new
         now = Time.now
         md5 << now.to_s
         md5 << String(now.usec)
         md5 << String(rand(0))
         md5 << String($$)
         md5 << self.class.name
         md5.hexdigest
      end
    end
  end
end
