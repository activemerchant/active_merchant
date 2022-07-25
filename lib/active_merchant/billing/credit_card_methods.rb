require 'set'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Convenience methods that can be included into a custom Credit Card object, such as an ActiveRecord based Credit Card object.
    module CreditCardMethods
      CARD_COMPANY_DETECTORS = {
        'visa'               => ->(num) { num =~ /^4\d{12}(\d{3})?(\d{3})?$/ },
        'master'             => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), MASTERCARD_RANGES) },
        'elo'                => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), ELO_RANGES) },
        'alelo'              => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), ALELO_RANGES) },
        'discover'           => ->(num) { num =~ /^(6011|65\d{2}|64[4-9]\d)\d{12,15}$/ },
        'american_express'   => ->(num) { num =~ /^3[47]\d{13}$/ },
        'naranja'            => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), NARANJA_RANGES) },
        'diners_club'        => ->(num) { num =~ /^3(0[0-5]|[68]\d)\d{11,16}$/ },
        'jcb'                => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 4), JCB_RANGES) },
        'dankort'            => ->(num) { num =~ /^5019\d{12}$/ },
        'maestro'            => lambda { |num|
          (12..19).cover?(num&.size) && (
            in_bin_range?(num.slice(0, 6), MAESTRO_RANGES) ||
            MAESTRO_BINS.any? { |bin| num.slice(0, bin.size) == bin }
          )
        },
        'maestro_no_luhn'    => ->(num) { num =~ /^(501080|501081|501082)\d{6,13}$/ },
        'forbrugsforeningen' => ->(num) { num =~ /^600722\d{10}$/ },
        'sodexo'             => ->(num) { num =~ /^(606071|603389|606070|606069|606068|600818)\d{10}$/ },
        'alia'               => ->(num) { num =~ /^(504997|505878|601030|601073|505874)\d{10}$/ },
        'vr'                 => ->(num) { num =~ /^(627416|637036)\d{10}$/ },
        'cabal'              => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 8), CABAL_RANGES) },
        'unionpay'           => ->(num) { (16..19).cover?(num&.size) && in_bin_range?(num.slice(0, 8), UNIONPAY_RANGES) },
        'carnet'             => lambda { |num|
          num&.size == 16 && (
            in_bin_range?(num.slice(0, 6), CARNET_RANGES) ||
            CARNET_BINS.any? { |bin| num.slice(0, bin.size) == bin }
          )
        },
        'cartes_bancaires' => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), CARTES_BANCAIRES_RANGES) },
        'olimpica' => ->(num) { num =~ /^636853\d{10}$/ },
        'creditel' => ->(num) { num =~ /^601933\d{10}$/ },
        'confiable' => ->(num) { num =~ /^560718\d{10}$/ },
        'synchrony' => ->(num) { num =~ /^700600\d{10}$/ },
        'routex' => ->(num) { num =~ /^(700676|700678)\d{13}$/ },
        'mada' => ->(num) { num&.size == 16 && in_bin_range?(num.slice(0, 6), MADA_RANGES) }
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
        %w[
          286900 502275 606333 627535 636318 636379 639388
          639484 639559 50633601 50633606 58877274 62753500
          60462203 60462204 588772
        ]
      )

      CARTES_BANCAIRES_RANGES = [
        (507589..507590),
        (507593..507595),
        [507597],
        [560408],
        [581752],
        (585402..585405),
        (585501..585505),
        (585577..585582)
      ]

      # https://www.mastercard.us/content/dam/mccom/global/documents/mastercard-rules.pdf, page 73
      MASTERCARD_RANGES = [
        (222100..272099),
        (510000..559999),
        [605272],
        [606282],
        [637095],
        [637568],
        (637599..637600),
        [637609],
      ]

      MAESTRO_BINS = Set.new(
        %w[ 500057
            501018 501043 501045 501047 501049 501051 501072 501075 501083 501087 501089 501095
            501500
            501879 502113 502120 502121 502301
            503175 503337 503645 503670
            504310 504338 504363 504533 504587 504620 504639 504656 504738 504781 504910
            507001 507002 507004 507082 507090
            560014 560565 561033
            572402 572610 572626
            576904
            578614
            581149
            585274 585697
            586509
            588729 588792
            589244 589407 589471 589605 589633 589647 589671 589916
            590043 590206 590263 590265 590278 590361 590362 590379 590393 590590
            591235 591420 591481 591620 591770 591948 591994
            592024 592161 592184 592186 592201 592384 592393 592528 592566 592704 592735 592879 592884
            593074 593264 593272 593355 593496 593556 593589 593666 593709 593825 593963 593994
            594184 594409 594468 594475 594581 594665 594691 594710 594874 594968
            595355 595364 595532 595547 595561 595568 595743 595929
            596245 596289 596399 596405 596590 596608 596645 596646 596791 596808 596815 596846
            597077 597094 597143 597370 597410 597765 597855 597862
            598053 598054 598395 598585 598793 598794 598815 598835 598838 598880 598889
            599000 599069 599089 599148 599191 599310 599741 599742 599867
            601070 601452 601628 601638
            602648
            603326 603450 603689
            604983
            606126
            608710
            627339 627453 627454 627973
            636117 636380 636422 636502 636639
            637046 637529 637568 637600 637756
            639130 639229 639350
            690032]
      )

      # https://www.mastercard.us/content/dam/mccom/global/documents/mastercard-rules.pdf, page 79
      MAESTRO_RANGES = [
        (500032..500033),
        (501015..501016),
        (501020..501021),
        (501023..501029),
        (501038..501041),
        (501053..501058),
        (501060..501063),
        (501066..501067),
        (501091..501092),
        (501104..501105),
        (501107..501108),
        (501104..501105),
        (501107..501108),
        (501800..501899),
        (502000..502099),
        (503800..503899),
        (561200..561269),
        (561271..561299),
        (561320..561356),
        (581700..581751),
        (581753..581800),
        (589300..589399),
        (589998..591259),
        (591261..596770),
        (596772..598744),
        (598746..599999),
        (600297..600314),
        (600316..600335),
        (600337..600362),
        (600364..600382),
        (601232..601254),
        (601256..601276),
        (601640..601652),
        (601689..601700),
        (602011..602050),
        (630400..630499),
        (639000..639099),
        (670000..679999),
      ]

      # https://dev.elo.com.br/apis/tabela-de-bins, download csv from left sidebar
      ELO_RANGES = [
        506707..506708, 506715..506715, 506717..506722, 506724..506736, 506739..506743,
        506745..506747, 506753..506753, 506774..506778, 509000..509007, 509009..509014,
        509020..509030, 509035..509042, 509044..509089, 509091..509101, 509104..509807,
        509831..509877, 509897..509900, 509918..509964, 509971..509986, 509995..509999,
        627780..627780, 636368..636368, 650031..650033, 650035..650051, 650057..650081,
        650406..650439, 650485..650504, 650506..650538, 650552..650598, 650720..650727,
        650901..650922, 650928..650928, 650938..650939, 650946..650978, 651652..651704,
        655000..655019, 655021..655057
      ]

      # Alelo provides BIN ranges by e-mailing them out periodically.
      # The BINs beginning with the digit 4 overlap with Visa's range of valid card numbers.
      # By placing the 'alelo' entry in CARD_COMPANY_DETECTORS below the 'visa' entry, we
      # identify these cards as Visa. This works because transactions with such cards will
      # run on Visa rails.
      ALELO_RANGES = [
        402588..402588, 404347..404347, 405876..405876, 405882..405882, 405884..405884,
        405886..405886, 430471..430471, 438061..438061, 438064..438064, 470063..470066,
        496067..496067, 506699..506704, 506706..506706, 506713..506714, 506716..506716,
        506749..506750, 506752..506752, 506754..506756, 506758..506767, 506770..506771,
        506773..506773, 509015..509019, 509880..509882, 509884..509885, 509887..509887,
        509987..509992
      ]

      CABAL_RANGES = [
        60420100..60440099,
        58965700..58965799,
        60352200..60352299
      ]

      MADA_RANGES = [
        504300..504300, 506968..506968, 508160..508160, 585265..585265, 588848..588848,
        588850..588850, 588982..588983, 589005..589005, 589206..589206, 604906..604906,
        605141..605141, 636120..636120, 968201..968209, 968211..968211
      ]

      NARANJA_RANGES = [
        589562..589562
      ]

      # https://www.discoverglobalnetwork.com/content/dam/discover/en_us/dgn/pdfs/IPP-VAR-Enabler-Compliance.pdf
      UNIONPAY_RANGES = [
        62000000..62000000, 62212600..62379699, 62400000..62699999, 62820000..62889999,
        81000000..81099999, 81100000..81319999, 81320000..81519999, 81520000..81639999, 81640000..81719999
      ]

      JCB_RANGES = [
        3528..3589, 3088..3094, 3096..3102, 3112..3120, 3158..3159, 3337..3349
      ]

      def self.included(base)
        base.extend(ClassMethods)
      end

      def self.in_bin_range?(number, ranges)
        bin = number.to_i
        ranges.any? do |range|
          range.include?(bin)
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
              valid_by_algorithm?(brand?(number), number)
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
