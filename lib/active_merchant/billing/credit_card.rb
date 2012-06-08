require 'time'
require 'date'
require 'active_merchant/billing/expiry_date'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # A +CreditCard+ object represents a physical credit card, and is capable of validating the various
    # data associated with these.
    #
    # At the moment, the following credit card types are supported:
    #
    # * Visa
    # * MasterCard
    # * Discover
    # * American Express
    # * Diner's Club
    # * JCB
    # * Switch
    # * Solo
    # * Dankort
    # * Maestro
    # * Forbrugsforeningen
    # * Laser
    #
    # For testing purposes, use the 'bogus' credit card brand. This skips the vast majority of
    # validations, allowing you to focus on your core concerns until you're ready to be more concerned
    # with the details of particular credit cards or your gateway.
    #
    # == Testing With CreditCard
    # Often when testing we don't care about the particulars of a given card brand. When using the 'test'
    # mode in your {Gateway}, there are six different valid card numbers: 1, 2, 3, 'success', 'fail',
    # and 'error'.
    #
    # For details, see {CreditCardMethods::ClassMethods#valid_number?}
    #
    # == Example Usage
    #   cc = CreditCard.new(
    #     :first_name => 'Steve',
    #     :last_name  => 'Smith',
    #     :month      => '9',
    #     :year       => '2010',
    #     :brand      => 'visa',
    #     :number     => '4242424242424242'
    #   )
    #
    #   cc.valid? # => true
    #   cc.display_number # => XXXX-XXXX-XXXX-4242
    #
    class CreditCard
      include CreditCardMethods
      include Validateable

      cattr_accessor :require_verification_value
      self.require_verification_value = true

      # Returns or sets the credit card number.
      #
      # @return [String]
      attr_accessor :number

      # Returns or sets the expiry month for the card.
      #
      # @return [Integer]
      attr_accessor :month

      # Returns or sets the expiry year for the card.
      #
      # @return [Integer]
      attr_accessor :year

      # Returns or sets the credit card brand.
      #
      # Valid card types are
      #
      # * +'visa'+
      # * +'master'+
      # * +'discover'+
      # * +'american_express'+
      # * +'diners_club'+
      # * +'jcb'+
      # * +'switch'+
      # * +'solo'+
      # * +'dankort'+
      # * +'maestro'+
      # * +'forbrugsforeningen'+
      # * +'laser'+
      #
      # Or, if you wish to test your implementation, +'bogus'+.
      #
      # @return (String) the credit card brand
      attr_accessor :brand

      # Returns or sets the first name of the card holder.
      #
      # @return [String]
      attr_accessor :first_name

      # Returns or sets the last name of the card holder.
      #
      # @return [String]
      attr_accessor :last_name

      # Required for Switch / Solo cards
      attr_accessor :start_month, :start_year, :issue_number

      # Returns or sets the card verification value.
      #
      # This attribute is optional but recommended. The verification value is
      # a {card security code}[http://en.wikipedia.org/wiki/Card_security_code]. If provided,
      # the gateway will attempt to validate the value.
      #
      # @return [String] the verification value
      attr_accessor :verification_value

      def type
        self.class.deprecated "CreditCard#type is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand instead."
        brand
      end

      def type=(value)
        self.class.deprecated "CreditCard#type is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand instead."
        self.brand = value
      end

      # Provides proxy access to an expiry date object
      #
      # @return [ExpiryDate]
      def expiry_date
        ExpiryDate.new(@month, @year)
      end

      # Returns whether the credit card has expired.
      #
      # @return +true+ if the card has expired, +false+ otherwise
      def expired?
        expiry_date.expired?
      end

      # Returns whether either the +first_name+ or the +last_name+ attributes has been set.
      def name?
        first_name? || last_name?
      end

      # Returns whether the +first_name+ attribute has been set.
      def first_name?
        @first_name.present?
      end

      # Returns whether the +last_name+ attribute has been set.
      def last_name?
        @last_name.present?
      end

      # Returns the full name of the card holder.
      #
      # @return [String] the full name of the card holder
      def name
        [@first_name, @last_name].compact.join(' ')
      end

      def name=(full_name)
        names = full_name.split
        self.last_name  = names.pop
        self.first_name = names.join(" ")
      end

      def verification_value?
        !@verification_value.blank?
      end

      # Returns a display-friendly version of the card number.
      #
      # All but the last 4 numbers are replaced with an "X", and hyphens are
      # inserted in order to improve legibility.
      #
      # @example
      #   credit_card = CreditCard.new(:number => "2132542376824338")
      #   credit_card.display_number  # "XXXX-XXXX-XXXX-4338"
      #
      # @return [String] a display-friendly version of the card number
      def display_number
        self.class.mask(number)
      end
      
      def first_digits
        self.class.first_digits(number)
      end

      def last_digits
        self.class.last_digits(number)
      end

      # Validates the credit card details.
      #
      # Any validation errors are added to the {#errors} attribute.
      def validate
        validate_essential_attributes

        # Bogus card is pretty much for testing purposes. Lets just skip these extra tests if its used
        return if brand == 'bogus'

        validate_card_brand
        validate_card_number
        validate_verification_value
        validate_switch_or_solo_attributes
      end

      def self.requires_verification_value?
        require_verification_value
      end

      private

      def before_validate #:nodoc:
        self.month = month.to_i
        self.year  = year.to_i
        self.start_month = start_month.to_i unless start_month.nil?
        self.start_year = start_year.to_i unless start_year.nil?
        self.number = number.to_s.gsub(/[^\d]/, "")
        self.brand.downcase! if brand.respond_to?(:downcase)
        self.brand = self.class.brand?(number) if brand.blank?
      end

      def validate_card_number #:nodoc:
        if number.blank?
          errors.add :number, "is required"
        elsif !CreditCard.valid_number?(number)
          errors.add :number, "is not a valid credit card number"
        end

        unless errors.on(:number) || errors.on(:brand)
          errors.add :brand, "is not the correct card brand" unless CreditCard.matching_brand?(number, brand)
        end
      end

      def validate_card_brand #:nodoc:
        errors.add :brand, "is required" if brand.blank? && number.present?
        errors.add :brand, "is invalid"  unless brand.blank? || CreditCard.card_companies.keys.include?(brand)
      end

      alias_method :validate_card_type, :validate_card_brand

      def validate_essential_attributes #:nodoc:
        errors.add :first_name, "cannot be empty"      if @first_name.blank?
        errors.add :last_name,  "cannot be empty"      if @last_name.blank?

        if @month.to_i.zero? || @year.to_i.zero?
          errors.add :month, "is required"  if @month.to_i.zero?
          errors.add :year,  "is required"  if @year.to_i.zero?
        else
          errors.add :month,      "is not a valid month" unless valid_month?(@month)
          errors.add :year,       "expired"              if expired?
          errors.add :year,       "is not a valid year"  unless expired? || valid_expiry_year?(@year)
        end
      end

      def validate_switch_or_solo_attributes #:nodoc:
        if %w[switch solo].include?(brand)
          unless valid_month?(@start_month) && valid_start_year?(@start_year) || valid_issue_number?(@issue_number)
            errors.add :start_month,  "is invalid"      unless valid_month?(@start_month)
            errors.add :start_year,   "is invalid"      unless valid_start_year?(@start_year)
            errors.add :issue_number, "cannot be empty" unless valid_issue_number?(@issue_number)
          end
        end
      end

      def validate_verification_value #:nodoc:
        if CreditCard.requires_verification_value?
          errors.add :verification_value, "is required" unless verification_value?
        end
      end
    end
  end
end
