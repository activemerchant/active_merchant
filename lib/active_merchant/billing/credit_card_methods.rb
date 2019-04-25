module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Convenience methods that can be included into a custom Credit Card object, such as an ActiveRecord based Credit Card object.
    module CreditCardMethods
      CARD_COMPANY_DETECTORS = {
        'visa'               => ->(num) { num =~ /^4\d{12}(\d{3})?(\d{3})?$/ },
        'master'             => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), MASTERCARD_RANGES) },
        'elo'                => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), ELO_RANGES) },
        'discover'           => ->(num) { num =~ /^(6011|65\d{2}|64[4-9]\d)\d{12,15}|(62\d{14,17})$/ },
        'american_express'   => ->(num) { num =~ /^3[47]\d{13}$/ },
        'diners_club'        => ->(num) { num =~ /^3(0[0-5]|[68]\d)\d{11}$/ },
        'jcb'                => ->(num) { num =~ /^35(28|29|[3-8]\d)\d{12}$/ },
        'dankort'            => ->(num) { num =~ /^5019\d{12}$/ },
        'maestro'            => ->(num) { (12..19).cover?(num&.size) && in_bin_range?(num.slice(0, 6), MAESTRO_RANGES) },
        'forbrugsforeningen' => ->(num) { num =~ /^600722\d{10}$/ },
        'sodexo'             => ->(num) { num =~ /^(606071|603389|606070|606069|606068|600818)\d{10}$/ },
        'vr'                 => ->(num) { num =~ /^(627416|637036)\d{10}$/ },
        'carnet'             => lambda { |num|
          num&.size == 16 && (
            in_bin_range?(num.slice(0, 6), CARNET_RANGES) ||
            CARNET_BINS.any? { |bin| num.slice(0, bin.size) == bin }
          )
        }
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

      CARNET_RANGES = [
        (506199..506499),
      ]

      CARNET_BINS = Set.new(
        [
          '286900', '502275', '606333', '627535', '636318', '636379', '639388',
          '639484', '639559', '50633601', '50633606', '58877274', '62753500',
          '60462203', '60462204', '588772'
        ]
      )

      # https://www.mastercard.us/content/dam/mccom/global/documents/mastercard-rules.pdf, page 73
      MASTERCARD_RANGES = [
        (222100..272099),
        (510000..559999),
      ]

      # https://www.mastercard.us/content/dam/mccom/global/documents/mastercard-rules.pdf, page 73
      MAESTRO_RANGES = [
        (639000..639099),
        (670000..679999),
      ]

      # https://dev.elo.com.br/apis/tabela-de-bins, download csv from left sidebar
      ELO_RANGES = [
        506707..506708, 506715..506715, 506718..506722, 506724..506724, 506726..506736, 506739..506739, 506741..506743,
        506745..506747, 506753..506753, 506774..506776, 506778..506778, 509000..509001, 509003..509003, 509007..509007,
        509020..509022, 509035..509035, 509039..509042, 509045..509045, 509048..509048, 509051..509071, 509073..509074,
        509077..509080, 509084..509084, 509091..509094, 509098..509098, 509100..509100, 509104..509104, 509106..509109,
        627780..627780, 636368..636368, 650031..650033, 650035..650045, 650047..650047, 650406..650410, 650434..650436,
        650439..650439, 650485..650504, 650506..650530, 650577..650580, 650582..650591, 650721..650727, 650901..650922,
        650928..650928, 650938..650939, 650946..650948, 650954..650955, 650962..650963, 650967..650967, 650971..650971,
        651652..651667, 651675..651678, 655000..655010, 655012..655015, 655051..655052, 655056..655057
      ]

      def self.included(base)
        base.extend(ClassMethods)
      end

      def self.in_bin_range?(number, ranges)
        bin = number.to_i
        ranges.any? do |range|
          range.cover?(bin)
        end
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
            valid_checksum?(number)
        end

        def card_companies
          CARD_COMPANY_DETECTORS.keys
        end

        # Returns a string containing the brand of card from the list of known information below.
        def brand?(number)
          return 'bogus' if valid_test_mode_card_number?(number)

          CARD_COMPANY_DETECTORS.each do |company, func|
            return company.dup if func.call(number)
          end

          return nil
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
