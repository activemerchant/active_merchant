require 'active_merchant/billing/card_company'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Convenience methods that can be included into a custom Credit Card object, such as an ActiveRecord based Credit Card object.
    module CreditCardMethods
      CARD_COMPANY_DETECTORS = {
        'visa'               => 'Visa',
        'master'             => 'Master',
        'elo'                => 'Elo',
        'alelo'              => 'Alelo',
        'discover'           => 'Discover',
        'american_express'   => 'AmericanExpress',
        'naranja'            => 'Naranja',
        'diners_club'        => 'DinersClub',
        'jcb'                => 'Jcb',
        'dankort'            => 'Dankort',
        'maestro'            => 'Maestro',
        'maestro_no_luhn'    => 'MaestroNoLuhn',
        'forbrugsforeningen' => 'Forbrugsforeningen',
        'sodexo'             => 'Sodexo',
        'alia'               => 'Alia',
        'vr'                 => 'Vr',
        'cabal'              => 'Cabal',
        'unionpay'           => 'Unionpay',
        'carnet'             => 'Carnet',
        'cartes_bancaires'   => 'CarnetBancaries',
        'olimpica'           => 'Olimpica',
        'creditel'           => 'Creditel',
        'confiable'          => 'Confiable',
        'synchrony'          => 'Synchrony',
        'routex'             => 'Routex',
        'mada'               => 'Mada'
      }

      # http://www.barclaycard.co.uk/business/files/bin_rules.pdf
      ELECTRON_RANGES = [
        [400115],
        (400837..400839),
        (412921..412923),
        [417935],
        (419740..419741),
        (419773..419775),
        [424519],
        (424962..424963),
        [437860],
        [444000],
        [459472],
        (484406..484411),
        (484413..484414),
        (484418..484418),
        (484428..484455),
        (491730..491759),
      ]

      def self.included(base)
        base.extend(ClassMethods)
      end

      def valid_month?(month)
        (1..12).cover?(month.to_i)
      end

      def credit_card?
        true
      end

      def valid_expiry_year?(year)
        (Time.now.year..Time.now.year + 20).cover?(year.to_i)
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
        case brand
        when 'american_express'
          4
        when 'maestro'
          0
        else
          3
        end
      end

      def valid_issue_number?(number)
        (number.to_s =~ /^\d{1,2}$/)
      end

      # Returns if the card matches known Electron BINs
      def electron?
        self.class.electron?(number)
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
              valid_card_number_characters?(number) &&
              valid_by_algorithm?(brand?(number), number)
        end

        def card_companies
          CARD_COMPANY_DETECTORS.keys
        end

        # Returns a string containing the brand of card from the list of known information below.
        def brand?(number)
          return 'bogus' if valid_test_mode_card_number?(number)

          CARD_COMPANY_DETECTORS.each do |company, class_name|
            return company.dup if Billing.const_get(class_name).valid_card_number?(number)
          end
          nil
        end

        def electron?(number)
          return false unless [16, 19].include?(number&.length)

          # don't recalculate for each range
          bank_identification_number = first_digits(number).to_i

          ELECTRON_RANGES.any? do |range|
            range.include?(bank_identification_number)
          end
        end

        def type?(number)
          ActiveMerchant.deprecated 'CreditCard#type? is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#brand? instead.'
          brand?(number)
        end

        def first_digits(number)
          number&.slice(0, 6) || ''
        end

        def last_digits(number)
          return '' if number.nil?

          number.length <= 4 ? number : number.slice(-4..-1)
        end

        def mask(number)
          "XXXX-XXXX-XXXX-#{last_digits(number)}"
        end

        # Checks to see if the calculated brand matches the specified brand
        def matching_brand?(number, brand)
          brand?(number) == brand
        end

        def matching_type?(number, brand)
          ActiveMerchant.deprecated 'CreditCard#matching_type? is deprecated and will be removed from a future release of ActiveMerchant. Please use CreditCard#matching_brand? instead.'
          matching_brand?(number, brand)
        end

        private

        def valid_card_number_length?(number) #:nodoc:
          return false if number.nil?

          number.length >= 12
        end

        def valid_card_number_characters?(number) #:nodoc:
          return false if number.nil?

          !number.match(/\D/)
        end

        def valid_test_mode_card_number?(number) #:nodoc:
          ActiveMerchant::Billing::Base.test? &&
            %w[1 2 3 success failure error].include?(number)
        end

        def valid_by_algorithm?(brand, numbers) #:nodoc:
          case brand
          when 'naranja'
            valid_naranja_algo?(numbers)
          when 'creditel'
            valid_creditel_algo?(numbers)
          when 'alia', 'confiable', 'maestro_no_luhn'
            true
          else
            valid_luhn?(numbers)
          end
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
          57 => 9
        }.freeze

        # Checks the validity of a card number by use of the Luhn Algorithm.
        # Please see http://en.wikipedia.org/wiki/Luhn_algorithm for details.
        # This implementation is from the luhn_checksum gem, https://github.com/zendesk/luhn_checksum.
        def valid_luhn?(numbers) #:nodoc:
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

        # Checks the validity of a card number by use of specific algorithms
        def valid_naranja_algo?(numbers) #:nodoc:
          num_array = numbers.to_s.chars.map(&:to_i)
          multipliers = [4, 3, 2, 7, 6, 5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
          num_sum = num_array[0..14].zip(multipliers).map { |a, b| a * b }.reduce(:+)
          intermediate = 11 - (num_sum % 11)
          final_num = intermediate > 9 ? 0 : intermediate
          final_num == num_array[15]
        end

        def valid_creditel_algo?(numbers) #:nodoc:
          num_array = numbers.to_s.chars.map(&:to_i)
          multipliers = [5, 4, 3, 2, 1, 9, 8, 7, 6, 5, 4, 3, 2, 1, 9]
          num_sum = num_array[0..14].zip(multipliers).map { |a, b| a * b }.reduce(:+)
          final_num = num_sum % 10
          final_num == num_array[15]
        end
      end
    end
  end
end
