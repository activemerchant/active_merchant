module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Convenience methods that can be included into a custom Credit Card object, such as an ActiveRecord based Credit Card object.
    module CreditCardMethods
      CARD_COMPANIES = { 
        'visa'               => /^4\d{12}(\d{3})?$/,
        'master'             => /^(5[1-5]\d{4}|677189)\d{10}$/,
        'discover'           => /^(6011|65\d{2}|64[4-9]\d)\d{12}|(62\d{14})$/,
        'american_express'   => /^3[47]\d{13}$/,
        'diners_club'        => /^3(0[0-5]|[68]\d)\d{11}$/,
        'jcb'                => /^35(28|29|[3-8]\d)\d{12}$/,
        'switch'             => /^6759\d{12}(\d{2,3})?$/,
        'solo'               => /^6767\d{12}(\d{2,3})?$/,
        'dankort'            => /^5019\d{12}$/,
        'maestro'            => /^(5[06-8]|6\d)\d{10,17}$/,
        'forbrugsforeningen' => /^600722\d{10}$/,
        'laser'              => /^(6304|6706|6709|6771(?!89))\d{8}(\d{4}|\d{6,7})?$/
      }
    
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      def valid_month?(month)
        (1..12).include?(month.to_i)
      end
      
      def valid_expiry_year?(year)
        (Time.now.year..Time.now.year + 20).include?(year.to_i)
      end
      
      def valid_start_year?(year)
        year.to_s =~ /^\d{4}$/ && year.to_i > 1987
      end
      
      def valid_issue_number?(number)
        number.to_s =~ /^\d{1,2}$/
      end
      
      module ClassMethods
        # Returns true if it validates. Optionally, you can pass a card brand as an argument and 
        # make sure it is of the correct brand.
        #
        # References:
        # - http://perl.about.com/compute/perl/library/nosearch/P073000.htm
        # - http://www.beachnet.com/~hstiles/cardtype.html
        def valid_number?(number)
          valid_test_mode_card_number?(number) || 
            valid_card_number_length?(number) && 
            valid_checksum?(number)
        end
        
        # Regular expressions for the known card companies.
        # 
        # References: 
        # - http://en.wikipedia.org/wiki/Credit_card_number 
        # - http://www.barclaycardbusiness.co.uk/information_zone/processing/bin_rules.html 
        def card_companies
          CARD_COMPANIES
        end
        
        # Returns a string containing the brand of card from the list of known information below.
        # Need to check the cards in a particular order, as there is some overlap of the allowable ranges
        #--
        # TODO Refactor this method. We basically need to tighten up the Maestro Regexp. 
        # 
        # Right now the Maestro regexp overlaps with the MasterCard regexp (IIRC). If we can tighten 
        # things up, we can boil this whole thing down to something like... 
        # 
        #   def brand?(number)
        #     return 'visa' if valid_test_mode_card_number?(number)
        #     card_companies.find([nil]) { |brand, regexp| number =~ regexp }.first.dup
        #   end
        # 
        def brand?(number)
          return 'bogus' if valid_test_mode_card_number?(number)

          card_companies.reject { |c,p| c == 'maestro' }.each do |company, pattern|
            return company.dup if number =~ pattern 
          end
          
          return 'maestro' if number =~ card_companies['maestro']

          return nil
        end

        def type?(number)
          deprecated "CreditCard#type? is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand? instead."
          brand?(number)
        end
        
        def first_digits(number)
          number.to_s.slice(0,6) 
        end
        
        def last_digits(number)     
          number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1) 
        end
        
        def mask(number)
          "XXXX-XXXX-XXXX-#{last_digits(number)}"
        end
        
        # Checks to see if the calculated brand matches the specified brand
        def matching_brand?(number, brand)
          brand?(number) == brand
        end

        def matching_type?(number, brand)
          deprecated "CreditCard#matching_type? is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#matching_brand? instead."
          matching_brand?(number, brand)
        end

        def deprecated(message)
          warn(Kernel.caller[1] + message)
        end
        
        private
        
        def valid_card_number_length?(number) #:nodoc:
          number.to_s.length >= 12
        end
        
        def valid_test_mode_card_number?(number) #:nodoc:
          ActiveMerchant::Billing::Base.test? && 
            %w[1 2 3 success failure error].include?(number.to_s)
        end
        
        # Checks the validity of a card number by use of the Luhn Algorithm.
        # Please see http://en.wikipedia.org/wiki/Luhn_algorithm for details.
        def valid_checksum?(number) #:nodoc:
          sum = 0
          for i in 0..number.length
            weight = number[-1 * (i + 2), 1].to_i * (2 - (i % 2))
            sum += (weight < 10) ? weight : weight - 9
          end
          
          (number[-1,1].to_i == (10 - sum % 10) % 10)
        end
      end
    end
  end
end
