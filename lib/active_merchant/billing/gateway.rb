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
    # The standard list of gateway functions that most concrete gateway subclasses implement is:
    # 
    # * <tt>purchase(money, creditcard, options = {})</tt>
    # * <tt>authorize(money, creditcard, options = {})</tt>
    # * <tt>capture(money, authorization, options = {})</tt>
    # * <tt>void(identification, options = {})</tt>
    # * <tt>credit(money, identification, options = {})</tt>
    #
    # Some gateways include features for recurring billing
    #
    # * <tt>recurring(money, creditcard, options = {})</tt>
    #
    # Some gateways also support features for storing credit cards:
    #
    # * <tt>store(creditcard, options = {})</tt>
    # * <tt>unstore(identification, options = {})</tt>
    # 
    # === Gateway Options
    # The options hash consists of the following options:
    #
    # * <tt>:order_id</tt> - The order number
    # * <tt>:ip</tt> - The IP address of the customer making the purchase
    # * <tt>:customer</tt> - The name, customer number, or other information that identifies the customer
    # * <tt>:invoice</tt> - The invoice number
    # * <tt>:merchant</tt> - The name or description of the merchant offering the product
    # * <tt>:description</tt> - A description of the transaction
    # * <tt>:email</tt> - The email address of the customer
    # * <tt>:currency</tt> - The currency of the transaction.  Only important when you are using a currency that is not the default with a gateway that supports multiple currencies.
    # * <tt>:billing_address</tt> - A hash containing the billing address of the customer.
    # * <tt>:shipping_address</tt> - A hash containing the shipping address of the customer.
    # 
    # The <tt>:billing_address</tt>, and <tt>:shipping_address</tt> hashes can have the following keys:
    # 
    # * <tt>:name</tt> - The full name of the customer.
    # * <tt>:company</tt> - The company name of the customer.
    # * <tt>:address1</tt> - The primary street address of the customer.
    # * <tt>:address2</tt> - Additional line of address information.
    # * <tt>:city</tt> - The city of the customer.
    # * <tt>:state</tt> - The state of the customer.  The 2 digit code for US and Canadian addresses. The full name of the state or province for foreign addresses.
    # * <tt>:country</tt> - The [ISO 3166-1-alpha-2 code](http://www.iso.org/iso/country_codes/iso_3166_code_lists/english_country_names_and_code_elements.htm) for the customer.
    # * <tt>:zip</tt> - The zip or postal code of the customer.
    # * <tt>:phone</tt> - The phone number of the customer.
    #
    # == Implmenting new gateways
    #
    # See the {ActiveMerchant Guide to Contributing}[http://code.google.com/p/activemerchant/wiki/Contributing]
    #
    class Gateway
      include PostsData
      include RequiresParameters
      include CreditCardFormatting
      
      DEBIT_CARDS = [ :switch, :solo ]
      
      cattr_reader :implementations
      @@implementations = []
      
      def self.inherited(subclass)
        super
        @@implementations << subclass
      end
    
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
      
      attr_reader :url, :response, :options
      
      # Use this method to check if your gateway of interest supports a credit card of some type
      def self.supports?(card_type)
        supported_cardtypes.include?(card_type.to_sym)
      end       
    
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
