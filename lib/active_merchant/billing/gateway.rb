require 'net/http'
require 'net/https'
require 'digest/md5'
require 'active_merchant/billing/response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # 
    # == Description
    # The Gateway class is the base class for all ActiveMerchant gateway implementations. 
    # 
    # The list of gateway functions that concrete gateway classes can and should implement include 
    # the following:
    # 
    # * <tt>purchase(money, creditcard, options = {})</tt>
    # * <tt>authorize(money, creditcard, options = {})</tt>
    # * <tt>capture(money, authorization, options = {})</tt>
    # * <tt>void(identification, options = {})</tt>
    # * <tt>credit(money, identification, options = {})</tt>
    # 
    # == Setting Up Your Gateway
    # Aside from the obvious authorization parameters (login and password), you can set up your 
    # gateway using numerous options. Be sure to reference your gateway of choice's documentation 
    # before overriding it's default values that may be defined.
    # 
    # * <tt>Gateway.default_currency</tt>: sets the default currency if none is provided. See 
    #   http://en.wikipedia.org/wiki/ISO_4217#Active_codes for active currency codes.
    # 
    # * <tt>Gateway.supported_countries</tt>: sets the countries of _merchants_ the gateway supports.
    # 
    # * <tt>Gateway.supported_cardtypes</tt>: sets the card types supported by the gateway.
    # 
    # * <tt>Gateway.homepage_url</tt>: sets the URL at which the gateway may be found.
    # 
    # * <tt>Gateway.display_name</tt>: sets the name of the gateway for display purposes, such as generating documentation.
    # 
    # * <tt>Gateway.application_id</tt>: This is the application making calls to the gateway. This 
    #   is useful for things like the Paypal build notation (BN) id fields.
    # 
    # * <tt>Gateway.money_format</tt>: this attribute may be set to <tt>:dollars</tt> or 
    #   <tt>:cents</tt>. Use this to set the expected money format you'll be inputting.
    #
    # 
    #     Gateway.money_format = :dollars # => 12.50
    #     Gateway.money_format = :cents   # => 1250
    # 
    # 
    # == Testing Your Code
    # There are two kinds of tests performed with your code: local and remote.
    # 
    # === Local Tests
    # Before running any remote tests, it's best to ensure that your code covers the basics 
    # locally. Local tests run on your own machine and will run faster than remote tests.
    # 
    # To run a local test, first ensure that your gateway is in test mode: 
    # 
    #   ActiveMerchant::Base.mode = :test
    # 
    # (See ActiveMerchant::Base for more details.) This is often best set in your test's +setup+ 
    # or +teardown+ methods, if you are using Test::Unit.
    # 
    # The next step is to use one of three test credit card numbers: 
    # 
    # <tt>1</tt>:: Result will be successful
    # <tt>2</tt>:: Result will be a failure
    # <tt>3</tt>:: Result will raise a miscellaneous error
    # 
    # For examples of test requests, please see your gateway of interest's unit test code.
    # 
    # === Remote Tests
    # Remote tests aren't mandatory, but it's not a bad idea to write them to ensure everything 
    # works as expected. You'll first need authorization parameters from the gateway you'll be 
    # working with. Once you have these values you'll be able to use ActiveMerchant to run test 
    # requests.
    # 
    # As with local tests, first ensure that you are in test mode: 
    # 
    #   ActiveMerchant::Base.mode = :test
    # 
    # (See ActiveMerchant::Base for more details.) 
    # 
    # Test requests may then be made using appropriate parameters provided by your gateway of 
    # choice. For instance, the Moneris gateway provides a test MasterCard and Visa number that 
    # one may use to process test purchases and authorization requests.
    # 
    # Given that these remote tests will take longer to run than local tests, it is recommended 
    # that you comment them out, or disable them when not required.
    class Gateway
      include PostsData
      include RequiresParameters
      include CreditCardFormatting
      
      ## Constants
      
      DEBIT_CARDS = [ :switch, :solo ]
      
      ## Attributes
      
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
      
      attr_reader :options
      
      # Use this method to check if your gateway of interest supports a credit card of some type
      def self.supports?(card_type)
        supported_cardtypes.include?(card_type.to_sym)
      end       
    
      ## Instance Methods
    
      # Initialize a new gateway.
      # 
      # See the documentation for the gateway you will be using to make sure there are no other 
      # required options.
      def initialize(options = {})
      end
                                     
      # Are we running in test mode?
      def test?
        Base.gateway_mode == :test
      end
            
      private # :nodoc: all

      def name 
        self.class.name.scan(/\:\:(\w+)Gateway/).flatten.first
      end
      
      # This is used to check if our credit card number implies that we are seeking a test 
      # Response. Of course, this returns false if we are not in test mode.
      # 
      # Recognized values: 
      # <tt>1</tt>:: Result will be successful
      # <tt>2</tt>:: Result will be a failure
      # <tt>3</tt>:: Result will raise a miscellaneous error
      # 
      # All other values will not be recognized.
      #--
      # TODO Refactor this method. It's kind of on the ugly side of things.
      def test_result_from_cc_number(card_number)
        return false unless test?
        
        case card_number.to_s
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
      
      # Return a String with the amount in the appropriate format
      #--
      # TODO Refactor this method. It's a tad on the ugly side.
      def amount(money)
        return nil if money.nil?
        cents = money.respond_to?(:cents) ? money.cents : money 

        if money.is_a?(String) or cents.to_i < 0
          raise ArgumentError, 'money amount must be either a Money object or a positive integer in cents.' 
        end

        if self.money_format == :cents
          cents.to_s
        else
          sprintf("%.2f", cents.to_f / 100)
        end
      end
      
      # Ascertains the currency to be used on the money supplied.
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
