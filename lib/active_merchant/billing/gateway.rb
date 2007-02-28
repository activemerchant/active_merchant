require 'net/http'
require 'net/https'
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
      
      # The format of the amounts used by the gateway
      # :dollars => '12.50'
      # :cents => '1250'
      class_inheritable_accessor :money_format
      self.money_format = :dollars
      
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
                                                                  
      # Get a list of supported credit card types for this gateway
      def self.supported_cardtypes
        []
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
    end
  end
end
