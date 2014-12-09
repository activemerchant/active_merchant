require 'net/http'
require 'net/https'
require 'active_merchant/billing/response'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    #
    # == Description
    # The Gateway class is the base class for all ActiveMerchant gateway implementations.
    #
    # The standard list of gateway functions that most concrete gateway subclasses implement is:
    #
    # * <tt>purchase(money, credit_card, options = {})</tt>
    # * <tt>authorize(money, credit_card, options = {})</tt>
    # * <tt>capture(money, authorization, options = {})</tt>
    # * <tt>void(identification, options = {})</tt>
    # * <tt>refund(money, identification, options = {})</tt>
    # * <tt>verify(credit_card, options = {})</tt>
    #
    # Some gateways also support features for storing credit cards:
    #
    # * <tt>store(credit_card, options = {})</tt>
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
    # See the {ActiveMerchant Guide to Contributing}[https://github.com/Shopify/active_merchant/wiki/Contributing]
    #
    class Gateway
      include PostsData
      include CreditCardFormatting

      DEBIT_CARDS = [ :switch, :solo ]
      CURRENCIES_WITHOUT_FRACTIONS = [ 'BIF', 'BYR', 'CLP', 'CVE', 'DJF', 'GNF', 'HUF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF', 'TWD', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF' ]

      CREDIT_DEPRECATION_MESSAGE = "Support for using credit to refund existing transactions is deprecated and will be removed from a future release of ActiveMerchant. Please use the refund method instead."
      RECURRING_DEPRECATION_MESSAGE = "Recurring functionality in ActiveMerchant is deprecated and will be removed in a future version. Please contact the ActiveMerchant maintainers if you have an interest in taking ownership of a separate gem that continues support for it."

      # == Standardized Error Codes
      #
      # :incorrect_number - Card number does not comply with ISO/IEC 7812 numbering standard
      # :invalid_number - Card number was not matched by processor
      # :invalid_expiry_date - Expiry date deos not match correct formatting
      # :invalid_cvc - Security codes does not match correct format (3-4 digits)
      # :expired_card - Card number is expired
      # :incorrect_cvc - Secerity code was not matched by the processor
      # :incorrect_zip - Zip code is not in correct format
      # :incorrect_address - Billing address info was not matched by the processor
      # :card_declined - Card number declined by processor
      # :processing_error - Processor error
      # :call_issuer - Transaction requires voice authentication, call issuer
      # :pickup_card - Issuer requests that you pickup the card from merchant

      STANDARD_ERROR_CODE = {
        :incorrect_number => 'incorrect_number',
        :invalid_number => 'invalid_number',
        :invalid_expiry_date => 'invalid_expiry_date',
        :invalid_cvc => 'invalid_cvc',
        :expired_card => 'expired_card',
        :incorrect_cvc => 'incorrect_cvc',
        :incorrect_zip => 'incorrect_zip',
        :incorrect_address => 'incorrect_address',
        :card_declined => 'card_declined',
        :processing_error => 'processing_error',
        :call_issuer => 'call_issuer',
        :pickup_card => 'pick_up_card'
      }

      cattr_reader :implementations
      @@implementations = []

      def self.inherited(subclass)
        super
        @@implementations << subclass
      end

      def generate_unique_id
        SecureRandom.hex(16)
      end

      # The format of the amounts used by the gateway
      # :dollars => '12.50'
      # :cents => '1250'
      class_attribute :money_format
      self.money_format = :dollars

      # The default currency for the transactions if no currency is provided
      class_attribute :default_currency

      # The supported card types for the gateway
      class_attribute :supported_cardtypes
      self.supported_cardtypes = []

      class_attribute :homepage_url
      class_attribute :display_name

      class_attribute :test_url, :live_url

      class_attribute :abstract_class

      self.abstract_class = false

      # The application making the calls to the gateway
      # Useful for things like the PayPal build notation (BN) id fields
      class_attribute :application_id, instance_writer: false
      self.application_id = 'ActiveMerchant'

      attr_reader :options

      # Use this method to check if your gateway of interest supports a credit card of some type
      def self.supports?(card_type)
        supported_cardtypes.include?(card_type.to_sym)
      end

      def self.card_brand(source)
        result = source.respond_to?(:brand) ? source.brand : source.type
        result.to_s.downcase
      end

      def self.non_fractional_currency?(currency)
        CURRENCIES_WITHOUT_FRACTIONS.include?(currency.to_s)
      end

      def self.supported_countries=(country_codes)
        country_codes.each do |country_code|
          unless ActiveMerchant::Country.find(country_code)
            raise ActiveMerchant::InvalidCountryCodeError, "No country could be found for the country #{country_code}"
          end
        end
        @supported_countries = country_codes.dup
      end

      def self.supported_countries
        @supported_countries ||= []
      end

      def supported_countries
        self.class.supported_countries
      end

      def card_brand(source)
        self.class.card_brand(source)
      end

      # Initialize a new gateway.
      #
      # See the documentation for the gateway you will be using to make sure there are no other
      # required options.
      def initialize(options = {})
        @options = options
      end

      # Are we running in test mode?
      def test?
        (@options.has_key?(:test) ? @options[:test] : Base.test?)
      end

      # Does this gateway know how to scrub sensitive information out of HTTP transcripts?
      def supports_scrubbing?
        false
      end

      def scrub(transcript)
        raise RuntimeError.new("This gateway does not support scrubbing.")
      end

      protected # :nodoc: all

      def normalize(field)
        case field
          when "true"   then true
          when "false"  then false
          when ""       then nil
          when "null"   then nil
          else field
        end
      end

      def user_agent
        @@ua ||= JSON.dump({
          :bindings_version => ActiveMerchant::VERSION,
          :lang => 'ruby',
          :lang_version => "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})",
          :platform => RUBY_PLATFORM,
          :publisher => 'active_merchant'
        })
      end

      private # :nodoc: all

      def name
        self.class.name.scan(/\:\:(\w+)Gateway/).flatten.first
      end

      def amount(money)
        return nil if money.nil?
        cents = if money.respond_to?(:cents)
          ActiveMerchant.deprecated "Support for Money objects is deprecated and will be removed from a future release of ActiveMerchant. Please use an Integer value in cents"
          money.cents
        else
          money
        end

        if money.is_a?(String)
          raise ArgumentError, 'money amount must be a positive Integer in cents.'
        end

        if self.money_format == :cents
          cents.to_s
        else
          sprintf("%.2f", cents.to_f / 100)
        end
      end

      def localized_amount(money, currency)
        amount = amount(money)

        return amount unless Gateway.non_fractional_currency?(currency)

        if self.money_format == :cents
          sprintf("%.0f", amount.to_f / 100)
        else
          amount.split('.').first
        end
      end


      def currency(money)
        money.respond_to?(:currency) ? money.currency : self.default_currency
      end

      def requires_start_date_or_issue_number?(credit_card)
        return false if card_brand(credit_card).blank?
        DEBIT_CARDS.include?(card_brand(credit_card).to_sym)
      end

      def requires!(hash, *params)
        params.each do |param|
          if param.is_a?(Array)
            raise ArgumentError.new("Missing required parameter: #{param.first}") unless hash.has_key?(param.first)

            valid_options = param[1..-1]
            raise ArgumentError.new("Parameter: #{param.first} must be one of #{valid_options.to_sentence(:words_connector => 'or')}") unless valid_options.include?(hash[param.first])
          else
            raise ArgumentError.new("Missing required parameter: #{param}") unless hash.has_key?(param)
          end
        end
      end
    end
  end
end
