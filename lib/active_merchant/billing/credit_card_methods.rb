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
        ((year.to_s =~ /^\d{4}$/) && (year.to_i > 1987))
      end

      # Credit card providers have 3 digit verification values
      # This isn't standardised, these are called various names such as
      # CVC, CVV, CID, CSC and more
      # See: http://en.wikipedia.org/wiki/Card_security_code
      # American Express is the exception with 4 digits
      #
      # Below are links from the card providers with their requirements
      # visa:             http://usa.visa.com/personal/security/3-digit-security-code.jsp
      # master:           http://www.mastercard.com/ca/merchant/en/getstarted/Anatomy_MasterCard.html
      # jcb:              http://www.jcbcard.com/security/info.html
      # diners_club:      http://www.dinersclub.com/assets/DinersClub_card_ID_features.pdf
      # discover:         https://www.discover.com/credit-cards/help-center/glossary.html
      # american_express: https://online.americanexpress.com/myca/fuidfyp/us/action?request_type=un_fuid&Face=en_US
      def valid_card_verification_value?(cvv, brand)
        cvv.to_s =~ /^\d{#{card_verification_value_length(brand)}}$/
      end
      
      def card_verification_value_length(brand)
        brand == 'american_express' ? 4 : 3
      end
      
      def valid_issue_number?(number)
        (number.to_s =~ /^\d{1,2}$/)
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
          ActiveMerchant.deprecated "CreditCard#type? is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand? instead."
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
          ActiveMerchant.deprecated "CreditCard#matching_type? is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#matching_brand? instead."
          matching_brand?(number, brand)
        end

        private

        def valid_card_number_length?(number) #:nodoc:
          number.to_s.length >= 12
        end

        def valid_test_mode_card_number?(number) #:nodoc:
          ActiveMerchant::Billing::Base.test? &&
            %w[1 2 3 success failure error].include?(number.to_s)
        end

        ODD_LUHN_VALUE = {
          48 => 0,
          49 => 1,
          50 => 2,
          51 => 3,
          52 => 4,
          53 => 5,
          54 => 6,
          55 => 7,
          56 => 8,
          57 => 9,
          nil => 0
        }.freeze

        EVEN_LUHN_VALUE = {
          48 => 0, # 0 * 2
          49 => 2, # 1 * 2
          50 => 4, # 2 * 2
          51 => 6, # 3 * 2
          52 => 8, # 4 * 2
          53 => 1, # 5 * 2 - 9
          54 => 3, # 6 * 2 - 9
          55 => 5, # etc ...
          56 => 7,
          57 => 9,
        }.freeze

        # Checks the validity of a card number by use of the Luhn Algorithm.
        # Please see http://en.wikipedia.org/wiki/Luhn_algorithm for details.
        # This implementation is from the luhn_checksum gem, https://github.com/zendesk/luhn_checksum.
        def valid_checksum?(numbers) #:nodoc:
          sum = 0

          odd = true
          numbers.reverse.bytes.each do |number|
            if odd
              odd = false
              sum += ODD_LUHN_VALUE[number]
            else
              odd = true
              sum += EVEN_LUHN_VALUE[number]
            end
          end

          sum % 10 == 0
        end
      end
    end
  end
end
