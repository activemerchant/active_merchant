require 'time'
require 'date'
require "active_merchant/billing/model"

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
    #     :first_name         => 'Steve',
    #     :last_name          => 'Smith',
    #     :month              => '9',
    #     :year               => '2017',
    #     :brand              => 'visa',
    #     :number             => '4242424242424242',
    #     :verification_value => '424'
    #   )
    #
    #   cc.validate # => {}
    #   cc.display_number # => XXXX-XXXX-XXXX-4242
    #
    class CreditCard < Model
      include CreditCardMethods

      class << self
        # Inherited, but can be overridden w/o changing parent's value
        attr_accessor :require_verification_value
        attr_accessor :require_name
      end

      self.require_name = true
      self.require_verification_value = true

      # Returns or sets the credit card number.
      #
      # @return [String]
      attr_reader :number

      def number=(value)
        @number = (empty?(value) ? value : value.to_s.gsub(/[^\d]/, ""))
      end

      # Returns or sets the expiry month for the card.
      #
      # @return [Integer]
      attr_reader :month

      # Returns or sets the expiry year for the card.
      #
      # @return [Integer]
      attr_reader :year

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
      def brand
        if !defined?(@brand) || empty?(@brand)
          self.class.brand?(number)
        else
          @brand
        end
      end

      def brand=(value)
        value = value && value.to_s.dup
        @brand = (value.respond_to?(:downcase) ? value.downcase : value)
      end

      # Returns or sets the first name of the card holder.
      #
      # @return [String]
      attr_accessor :first_name

      # Returns or sets the last name of the card holder.
      #
      # @return [String]
      attr_accessor :last_name

      # Required for Switch / Solo cards
      attr_reader :start_month, :start_year
      attr_accessor :issue_number

      # Returns or sets the card verification value.
      #
      # This attribute is optional but recommended. The verification value is
      # a {card security code}[http://en.wikipedia.org/wiki/Card_security_code]. If provided,
      # the gateway will attempt to validate the value.
      #
      # @return [String] the verification value
      attr_accessor :verification_value

      # Sets if the credit card requires a verification value.
      #
      # @return [Boolean]
      def require_verification_value=(value)
        @require_verification_value_set = true
        @require_verification_value = value
      end

      # Returns if this credit card needs a verification value.
      #
      # By default this returns the configured value from `CreditCard.require_verification_value`,
      # but one can set a per instance requirement with `credit_card.require_verification_value = false`.
      #
      # @return [Boolean]
      def requires_verification_value?
        @require_verification_value_set ||= false
        if @require_verification_value_set
          @require_verification_value
        else
          self.class.requires_verification_value?
        end
      end

      # Returns or sets the track data for the card
      #
      # @return [String]
      attr_accessor :track_data

      # Returns or sets whether a card has been processed using manual entry.
      #
      # This attribute is optional and is only used by gateways who use this information in their transaction risk
      # calculations. See {this page on 'card not present' transactions}[http://en.wikipedia.org/wiki/Card_not_present_transaction]
      # for further explanation and examples of this kind of transaction.
      #
      # @return [true, false]
      attr_accessor :manual_entry

      # Returns or sets the ICC/ASN1 credit card data for a EMV transaction, typically this is a BER-encoded TLV string.
      #
      # @return [String]
      attr_accessor :icc_data

      # Returns or sets a fallback reason for a EMV transaction whereby the customer's card entered a fallback scenario.
      # This can be an arbitrary string.
      #
      # @return [String]
      attr_accessor :fallback_reason

      # Returns or sets whether card-present EMV data has been read contactlessly.
      #
      # @return [true, false]
      attr_accessor :contactless_emv

      # Returns or sets whether card-present magstripe data has been read contactlessly.
      #
      # @return [true, false]
      attr_accessor :contactless_magstripe

      # Returns the ciphertext of the card's encrypted PIN.
      #
      # @return [String]
      attr_accessor :encrypted_pin_cryptogram

      # Returns the Key Serial Number (KSN) of the card's encrypted PIN.
      #
      # @return [String]
      attr_accessor :encrypted_pin_ksn

      def type
        ActiveMerchant.deprecated "CreditCard#type is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand instead."
        brand
      end

      def type=(value)
        ActiveMerchant.deprecated "CreditCard#type is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand instead."
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
        first_name.present?
      end

      # Returns whether the +last_name+ attribute has been set.
      def last_name?
        last_name.present?
      end

      # Returns the full name of the card holder.
      #
      # @return [String] the full name of the card holder
      def name
        "#{first_name} #{last_name}".strip
      end

      def name=(full_name)
        names = full_name.split
        self.last_name  = names.pop
        self.first_name = names.join(" ")
      end

      %w(month year start_month start_year).each do |m|
        class_eval %(
          def #{m}=(v)
            @#{m} = case v
            when "", nil, 0
              nil
            else
              v.to_i
            end
          end
        )
      end

      def verification_value?
        !verification_value.blank?
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
        errors = validate_essential_attributes + validate_verification_value

        # Bogus card is pretty much for testing purposes. Lets just skip these extra tests if its used
        return errors_hash(errors) if brand == 'bogus'

        errors_hash(
          errors +
          validate_card_brand_and_number +
          validate_switch_or_solo_attributes
        )
      end

      def self.requires_verification_value?
        require_verification_value
      end

      def self.requires_name?
        require_name
      end

      def emv?
        icc_data.present?
      end

      private

      def validate_essential_attributes #:nodoc:
        errors = []

        if self.class.requires_name?
          errors << [:first_name, "cannot be empty"] if first_name.blank?
          errors << [:last_name,  "cannot be empty"] if last_name.blank?
        end

        if(empty?(month) || empty?(year))
          errors << [:month, "is required"] if empty?(month)
          errors << [:year,  "is required"] if empty?(year)
        else
          errors << [:month, "is not a valid month"] if !valid_month?(month)

          if expired?
            errors << [:year,  "expired"]
          else
            errors << [:year,  "is not a valid year"]  if !valid_expiry_year?(year)
          end
        end

        errors
      end

      def validate_card_brand_and_number #:nodoc:
        errors = []

        if !empty?(brand)
          errors << [:brand, "is invalid"]  if !CreditCard.card_companies.keys.include?(brand)
        end

        if empty?(number)
          errors << [:number, "is required"]
        elsif !CreditCard.valid_number?(number)
          errors << [:number, "is not a valid credit card number"]
        end

        if errors.empty?
          errors << [:brand, "does not match the card number"] if !CreditCard.matching_brand?(number, brand)
        end

        errors
      end

      def validate_verification_value #:nodoc:
        errors = []

        if verification_value?
          unless valid_card_verification_value?(verification_value, brand)
            errors << [:verification_value, "should be #{card_verification_value_length(brand)} digits"]
          end
        elsif requires_verification_value?
          errors << [:verification_value, "is required"]
        end
        errors
      end

      def validate_switch_or_solo_attributes #:nodoc:
        errors = []

        if %w[switch solo].include?(brand)
          valid_start_month = valid_month?(start_month)
          valid_start_year = valid_start_year?(start_year)

          if((!valid_start_month || !valid_start_year) && !valid_issue_number?(issue_number))
            if empty?(issue_number)
              errors << [:issue_number, "cannot be empty"]
              errors << [:start_month, "is invalid"] if !valid_start_month
              errors << [:start_year,  "is invalid"] if !valid_start_year
            else
              errors << [:issue_number, "is invalid"] if !valid_issue_number?(issue_number)
            end
          end
        end

        errors
      end

      class ExpiryDate #:nodoc:
        attr_reader :month, :year
        def initialize(month, year)
          @month = month.to_i
          @year = year.to_i
        end

        def expired? #:nodoc:
          Time.now.utc > expiration
        end

        def expiration #:nodoc:
          begin
            Time.utc(year, month, month_days, 23, 59, 59)
          rescue ArgumentError
            Time.at(0).utc
          end
        end

        private
        def month_days
          mdays = [nil,31,28,31,30,31,30,31,31,30,31,30,31]
          mdays[2] = 29 if Date.leap?(year)
          mdays[month]
        end
      end
    end
  end
end
