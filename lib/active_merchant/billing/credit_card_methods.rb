module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Convenience methods that can be included into a custom Credit Card object, such as an ActiveRecord based Credit Card object.
    module CreditCardMethods
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      def valid_month?(month)
        (1..12).include?(month)
      end
      
      def valid_expiry_year?(year)
        (Time.now.year..Time.now.year + 20).include?(year)
      end
      
      def valid_start_year?(year)
        year.to_s =~ /^\d{4}$/ && year.to_i > 1987
      end
      
      def valid_issue_number?(number)
        number.to_s =~ /^\d{1,2}$/
      end
      
      module ClassMethods
        # Returns true if it validates. Optionally, you can pass a card type as an argument and 
        # make sure it is of the correct type.
        #
        # References:
        # - http://perl.about.com/compute/perl/library/nosearch/P073000.htm
        # - http://www.beachnet.com/~hstiles/cardtype.html
        def valid_number?(number)
          valid_test_mode_card_number?(number) || 
            valid_card_number_length?(number) && 
            valid_card_number_digits?(number)
        end
        
        # Regular expressions for the known card companies.
        # 
        # References: 
        # - http://en.wikipedia.org/wiki/Credit_card_number 
        # - http://www.barclaycardbusiness.co.uk/information_zone/processing/bin_rules.html 
        def card_companies
          { 
            'visa'               => /^4\d{12}(\d{3})?$/,
            'master'             => /^(5[1-5]\d{4}|677189)\d{10}$/,
            'discover'           => /^6011\d{12}$/,
            'american_express'   => /^3[47]\d{13}$/,
            'diners_club'        => /^3(0[0-5]|[68]\d)\d{11}$/,
            'jcb'                => /^3528\d{12}$/,
            'switch'             => /^6759\d{12}(\d{2,3})?$/,  
            'solo'               => /^6767\d{12}(\d{2,3})?$/,
            'dankort'            => /^5019\d{12}$/,
            'maestro'            => /^(5[06-8]|6\d)\d{14}$/,
            'forbrugsforeningen' => /^600722\d{10}$/,
            'laser'              => /^(6304[89]\d{11}(\d{2,3})?|670695\d{12})$/
          }
        end
        
        # Returns a string containing the type of card from the list of known information below.
        # Need to check the cards in a particular order, as there is some overlap of the allowable ranges
        #--
        # TODO Refactor this method. We basically need to tighten up the Maestro Regexp. 
        # 
        # Right now the Maestro regexp overlaps with the MasterCard regexp (IIRC). If we can tighten 
        # things up, we can boil this whole thing down to something like... 
        # 
        #   def type?(number)
        #     return 'visa' if valid_test_mode_card_number?(number)
        #     card_companies.find([nil]) { |type, regexp| number =~ regexp }.first.dup
        #   end
        # 
        def type?(number)
          return 'visa' if valid_test_mode_card_number?(number)

          card_companies.reject { |c,p| c == 'maestro' }.each do |company, pattern|
            return company.dup if number =~ pattern 
          end
          
          return 'maestro' if number =~ card_companies['maestro']

          return nil
        end
        
        # Checks to see if the calculated type matches the specified type
        def matching_type?(number, type)
          type?(number) == type
        end
        
        private
        
          def valid_card_number_length?(number) #:nodoc:
            number.to_s.length >= 13
          end
        
          def valid_test_mode_card_number?(number) #:nodoc:
            ActiveMerchant::Billing::Base.test? && 
              %w[1 2 3 success failure error].include?(number.to_s)
          end
          
          # Checks the validity of a card number by use of the the Luhn Algorithm. 
          # Please see http://en.wikipedia.org/wiki/Luhn_algorithm for details.
          def valid_card_number_digits?(number) #:nodoc:
            number[-1, 1].to_i == (10 - sum_and_weigh_digits(number) % 10) % 10
          end
          
          # This is an implementation of the Luhn algorithm, refactored for readability.
          def sum_and_weigh_digits(number) #:nodoc:
            sum = 0
            number = number.to_s
            for position in 0..number.length
              weight = calculate_weight(number, position)
              sum += (weight < 10) ? weight : weight - 9
            end
            return sum
          end
          
          # To save time on the Luhn algorithm, we caculate the weight of a digit in the series by 
          # multiplying by 2 if it's position is even, and 1 if it's index is odd.
          def calculate_weight(number, position) #:nodoc:
            select_digit(number, position) * (2 - (position % 2))
          end
          
          # Plucks a digit from the card number to perform operations on
          def select_digit(number, position) #:nodoc:
            number[-1 * (position + 2), 1].to_i
          end
      end
    end
  end
end