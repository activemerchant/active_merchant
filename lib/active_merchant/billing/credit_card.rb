require 'time'
require 'date'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This credit card object can be used as a stand alone object. It acts just like a active record object
    # but doesn't support the .save method as its not backed by a database.
    class CreditCard
      include CreditCardMethods
      
      cattr_accessor :require_verification_value
      self.require_verification_value = false
      
      def self.requires_verification_value?
        require_verification_value
      end
        
      include Validateable

      class ExpiryDate #:nodoc:
        attr_reader :month, :year
        def initialize(month, year)
          @month = month
          @year = year
        end

        def expired? #:nodoc:
          Time.now > expiration rescue true
        end

        def expiration #:nodoc:
          Time.parse("#{month}/#{month_days}/#{year} 23:59:59") rescue Time.at(0)
        end

        private
        def month_days
          mdays = [nil,31,28,31,30,31,30,31,31,30,31,30,31]
          mdays[2] = 29 if Date.leap?(year)
          mdays[month]
        end
      end 

      # required
      attr_accessor :number, :month, :year, :type, :first_name, :last_name
      
      # required for Switch / Solo
      attr_accessor :start_month, :start_year, :issue_number

      # Optional verification_value (CVV, CVV2 etc)
      #
      # Gateways will try their best to run validation on the passed in value if it is supplied
      #
      attr_accessor :verification_value

      def before_validate
        self.type.downcase! if type.respond_to?(:downcase)
        self.month = month.to_i
        self.year = year.to_i
        self.number.to_s.gsub!(/[^\d]/, "")
      end

      def validate
        errors.add "year", "expired"                             if expired?
            
        errors.add "first_name", "cannot be empty"               if @first_name.blank?
        errors.add "last_name", "cannot be empty"                if @last_name.blank?
        errors.add "month", "cannot be empty"                    unless valid_month?(@month)
        errors.add "year", "cannot be empty"                     unless valid_expiry_year?(@year)

        # Bogus card is pretty much for testing purposes. Lets just skip these extra tests if its used
        
        return if type == 'bogus'

        errors.add "number", "is not a valid credit card number" unless CreditCard.valid_number?(number)                     
        errors.add "type", "is invalid"                          unless CreditCard.card_companies.keys.include?(type)
        errors.add "type", "is not the correct card type"        unless CreditCard.type?(number) == type
        
        if CreditCard.requires_verification_value?
          errors.add "verification_value", "is required" unless verification_value?
        end
        
        if [ 'switch', 'solo' ].include?(type)
          unless valid_month?(@start_month) && valid_start_year?(@start_year) || valid_issue_number?(@issue_number)
            errors.add "start_month", "is invalid"                    unless valid_month?(@start_month)
            errors.add "start_year", "is invalid"                     unless valid_start_year?(@start_year)
            errors.add "issue_number", "cannot be empty"              unless valid_issue_number?(@issue_number)
          end
        end
      end  
      
      def expired?
        expiry_date.expired?
      end
      
      def name?
        @first_name != nil and @last_name != nil
      end
      
      def first_name?
        @first_name != nil
      end
      
      def last_name?
        @last_name != nil
      end
            
      def name
        "#{@first_name} #{@last_name}"
      end
            
      def verification_value?
        !@verification_value.blank?
      end

      # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
      def display_number
        "XXXX-XXXX-XXXX-#{last_digits}"
      end
      
      def last_digits
        number.nil? ? "" : number.last(4)
      end

      def expiry_date
        ExpiryDate.new(@month, @year)
      end
    end
  end
end
