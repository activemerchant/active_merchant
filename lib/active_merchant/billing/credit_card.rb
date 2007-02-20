require 'time'
require 'delegate'
require 'date'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
  
    # This credit card object can be used as a stand alone object. It acts just like a active record object
    # but doesn't support the .save method as its not backed by a database.
    class CreditCard
      cattr_accessor :require_verification_value
      self.require_verification_value = false
      
      def self.requires_verification_value?
        require_verification_value
      end
        
      include Validateable

      class ExpiryMonth < DelegateClass(Fixnum)#:nodoc:
        def to_s(format = :default) #:nodoc:
          case format
          when :default
            __getobj__.to_s
          when :two_digit
            sprintf("%.2i", self)[-2..-1]
          else
            super
          end  
        end

        def valid? #:nodoc:
          (1..12).include?(self)
        end
      end

      class ExpiryYear < DelegateClass(Fixnum)#:nodoc:
        def to_s(format = :default) #:nodoc:
          case format
          when :default
            __getobj__.to_s
          when :two_digit
            sprintf("%.2i", self)[-2..-1]
          when :four_digit
            sprintf("%.4i", self)
          else
            super
          end  
        end

        def valid? #:nodoc:
          (Time.now.year..Time.now.year + 20).include?(self)
        end
      end

      class ExpiryDate #:nodoc:
        attr_reader :month, :year
        def initialize(month, year)
          @month = ExpiryMonth.new(month)
          @year = ExpiryYear.new(year)
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
        @errors.add "year", "expired"                             if expired?
             
        @errors.add "first_name", "cannot be empty"               if @first_name.blank?
        @errors.add "last_name", "cannot be empty"                if @last_name.blank?
        @errors.add "month", "cannot be empty"                    unless month.valid?
        @errors.add "year", "cannot be empty"                     unless year.valid?

        # Bogus card is pretty much for testing purposes. Lets just skip these extra tests if its used
        
        return if type == 'bogus'

        @errors.add "number", "is not a valid credit card number" unless CreditCard.valid_number?(number)                     
        @errors.add "type", "is invalid"                         unless CreditCard.card_companies.keys.include?(type)
        @errors.add "type", "is not the correct card type"        unless CreditCard.type?(number) == type
        
        if CreditCard.requires_verification_value?
          @errors.add "verification_value", "is required" unless verification_value?
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

      # Regular expressions for the known card companies
      # == Known card types
      #	 Card Type                         Prefix                           Length
      #  --------------------------------------------------------------------------
      #	 master                            51-55                            16
      #	 visa                              4                                13, 16
      #	 american_express                  34, 37                           15
      #	 diners_club                       300-305, 36, 38                  14
      #	 discover                          6011                             16
      #	 jcb                               3                                16
      #	 jcb                               2131, 1800                       15
      #	 switch                            various                          16,18,19
      #	 solo                              63, 6767                         16,18,19
      def self.card_companies
        { 
          'visa' =>  /^4\d{12}(\d{3})?$/,
          'master' =>  /^5[1-5]\d{14}$/,
          'discover' =>  /^6011\d{12}$/,
          'american_express' =>  /^3[47]\d{13}$/,
          'diners_club' =>  /^3(0[0-5]|[68]\d)\d{11}$/,
          'jcb' =>  /^(3\d{4}|2131|1800)\d{11}$/,
          'switch' =>  [/^49(03(0[2-9]|3[5-9])|11(0[1-2]|7[4-9]|8[1-2])|36[0-9]{2})\d{10}(\d{2,3})?$/, /^564182\d{10}(\d{2,3})?$/, /^6(3(33[0-4][0-9])|759[0-9]{2})\d{10}(\d{2,3})?$/],
          'solo' =>  /^6(3(34[5-9][0-9])|767[0-9]{2})\d{10}(\d{2,3})?$/ 
        }
      end

      # Returns a string containing the type of card from the list of known information below.
      def self.type?(number)
        return 'visa' if Base.gateway_mode == :test and ['1','2','3','success','failure','error'].include?(number.to_s)
        
        card_companies.each do |company, patterns|
          return company if [patterns].flatten.any? { |pattern| number =~ pattern  } 
        end

        return nil
      end

      # Returns true if it validates. Optionally, you can pass a card type as an argument and make sure it is of the correct type.
      # == References
      # - http://perl.about.com/compute/perl/library/nosearch/P073000.htm
      # - http://www.beachnet.com/~hstiles/cardtype.html
      def self.valid_number?(number)
        return true if Base.gateway_mode == :test and ['1','2','3','success','failure','error'].include?(number.to_s)
        
        return false unless number.to_s.length >= 13

        sum = 0
        for i in 0..number.length
          weight = number[-1 * (i + 2), 1].to_i * (2 - (i % 2))
          sum += (weight < 10) ? weight : weight - 9
        end

        (number[-1,1].to_i == (10 - sum % 10) % 10)
      end

      # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
      def display_number
        "XXXX-XXXX-XXXX-#{last_digits}"
      end
      
      def last_digits
        number.nil? ? "" : number.last(4)
      end

      def month
        expiry_date.month
      end

      def year
        expiry_date.year
      end

      def expiry_date
        ExpiryDate.new(@month, @year)
      end
    end
  end
end
