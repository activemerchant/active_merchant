require 'set'

module ActiveMerchant
  module Billing
    class CardCompany
      def self.in_bin_range?(number, ranges)
        bin = number.to_i
        ranges.any? do |range|
          range.include?(bin)
        end
      end
    end

    class Visa < CardCompany
      def self.valid_card_number?(number)
        number =~ /^4\d{12}(\d{3})?(\d{3})?$/
      end
    end

    class Master < CardCompany
      # https://www.mastercard.us/content/dam/mccom/global/documents/mastercard-rules.pdf, page 73
      RANGES = [
        (222100..272099),
        (510000..559999),
        [605272],
        [606282],
        [637095],
        [637568],
        (637599..637600),
        [637609]
      ]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 6), RANGES)
      end
    end

    class Elo < CardCompany
      # https://dev.elo.com.br/apis/tabela-de-bins, download csv from left sidebar
      RANGES = [
        506707..506708, 506715..506715, 506717..506722, 506724..506736, 506739..506743,
        506745..506747, 506753..506753, 506774..506778, 509000..509007, 509009..509014,
        509020..509030, 509035..509042, 509044..509089, 509091..509101, 509104..509807,
        509831..509877, 509897..509900, 509918..509964, 509971..509986, 509995..509999,
        627780..627780, 636368..636368, 650031..650033, 650035..650051, 650057..650081,
        650406..650439, 650485..650504, 650506..650538, 650552..650598, 650720..650727,
        650901..650922, 650928..650928, 650938..650939, 650946..650978, 651652..651704,
        655000..655019, 655021..655057
      ]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 6), RANGES)
      end
    end

    class Alelo < CardCompany
      # Alelo provides BIN ranges by e-mailing them out periodically.
      # The BINs beginning with the digit 4 overlap with Visa's range of valid card numbers.
      # By placing the 'alelo' entry in CARD_COMPANY_DETECTORS below the 'visa' entry, we
      # identify these cards as Visa. This works because transactions with such cards will
      # run on Visa rails.
      RANGES = [
        402588..402588, 404347..404347, 405876..405876, 405882..405882, 405884..405884,
        405886..405886, 430471..430471, 438061..438061, 438064..438064, 470063..470066,
        496067..496067, 506699..506704, 506706..506706, 506713..506714, 506716..506716,
        506749..506750, 506752..506752, 506754..506756, 506758..506767, 506770..506771,
        506773..506773, 509015..509019, 509880..509882, 509884..509885, 509887..509887,
        509987..509992
      ]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 6), RANGES)
      end
    end

    class Discover < CardCompany
      def self.valid_card_number?(number)
        number =~ /^(6011|65\d{2}|64[4-9]\d)\d{12,15}$/
      end
    end

    class AmericanExpress < CardCompany
      def self.valid_card_number?(number)
        number =~ /^3[47]\d{13}$/
      end
    end

    class Naranja < CardCompany
      RANGES = [589562..589562]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 6), RANGES)
      end
    end

    class DinersClub < CardCompany
      def self.valid_card_number?(number)
        number =~ /^3(0[0-5]|[68]\d)\d{11,16}$/
      end
    end

    class Jcb < CardCompany
      RANGES = [3528..3589, 3088..3094, 3096..3102, 3112..3120, 3158..3159, 3337..3349]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 4), RANGES)
      end
    end

    class Dankort < CardCompany
      def self.valid_card_number?(number)
        number =~ /^5019\d{12}$/
      end
    end

    class Maestro < CardCompany
      # https://www.mastercard.us/content/dam/mccom/global/documents/mastercard-rules.pdf, page 79
      RANGES = [
        (500032..500033), (501015..501016), (501020..501021),
        (501023..501029), (501038..501041), (501053..501058),
        (501060..501063), (501066..501067), (501091..501092),
        (501104..501105), (501107..501108), (501104..501105),
        (501107..501108), (501800..501899), (502000..502099),
        (503800..503899), (561200..561269), (561271..561299),
        (561320..561356), (581700..581751), (581753..581800),
        (589300..589399), (589998..591259), (591261..596770),
        (596772..598744), (598746..599999), (600297..600314),
        (600316..600335), (600337..600362), (600364..600382),
        (601232..601254), (601256..601276), (601640..601652),
        (601689..601700), (602011..602050), (630400..630499),
        (639000..639099), (670000..679999)
      ]
      BINS = Set.new(
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

      def self.valid_card_number?(number)
        (12..19).cover?(number&.size) && (
          in_bin_range?(number.slice(0, 6), RANGES) ||
          BINS.any? { |bin| number.slice(0, bin.size) == bin }
        )
      end
    end

    class MaestroNoLuhn < CardCompany
      def self.valid_card_number?(number)
        number =~ /^(501080|501081|501082)\d{6,13}$/
      end
    end

    class Forbrugsforeningen < CardCompany
      def self.valid_card_number?(number)
        number =~ /^600722\d{10}$/
      end
    end

    class Sodexo < CardCompany
      def self.valid_card_number?(number)
        number =~ /^(606071|603389|606070|606069|606068|600818)\d{10}$/
      end
    end

    class Alia < CardCompany
      def self.valid_card_number?(number)
        number =~ /^(504997|505878|601030|601073|505874)\d{10}$/
      end
    end

    class Vr < CardCompany
      def self.valid_card_number?(number)
        number =~ /^(627416|637036)\d{10}$/
      end
    end

    class Cabal < CardCompany
      RANGES = [60420100..60440099, 58965700..58965799, 60352200..60352299]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 8), RANGES)
      end
    end

    class Unionpay < CardCompany
      # https://www.discoverglobalnetwork.com/content/dam/discover/en_us/dgn/pdfs/IPP-VAR-Enabler-Compliance.pdf
      RANGES = [
        62000000..62000000, 62212600..62379699, 62400000..62699999, 62820000..62889999,
        81000000..81099999, 81100000..81319999, 81320000..81519999, 81520000..81639999, 81640000..81719999
      ]

      def self.valid_card_number?(number)
        (16..19).cover?(number&.size) && in_bin_range?(number.slice(0, 8), RANGES)
      end
    end

    class Carnet < CardCompany
      RANGES = [506199..506499]
      BINS = Set.new(
        %w[
          286900 502275 606333 627535 636318 636379 639388
          639484 639559 50633601 50633606 58877274 62753500
          60462203 60462204 588772
        ]
      )

      def self.valid_card_number?(number)
        number&.size == 16 && (
          in_bin_range?(number.slice(0, 6), RANGES) ||
          BINS.any? { |bin| number.slice(0, bin.size) == bin }
        )
      end
    end

    class CarnetBancaries < CardCompany
      RANGES = [
        (507589..507590),
        (507593..507595),
        [507597],
        [560408],
        [581752],
        (585402..585405),
        (585501..585505),
        (585577..585582)
      ]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 6), RANGES)
      end
    end

    class Olimpica < CardCompany
      def self.valid_card_number?(number)
        number =~ /^636853\d{10}$/
      end
    end

    class Creditel < CardCompany
      def self.valid_card_number?(number)
        number =~ /^601933\d{10}$/
      end
    end

    class Confiable < CardCompany
      def self.valid_card_number?(number)
        number =~ /^560718\d{10}$/
      end
    end

    class Synchrony < CardCompany
      def self.valid_card_number?(number)
        number =~ /^700600\d{10}$/
      end
    end

    class Routex < CardCompany
      def self.valid_card_number?(number)
        number =~ /^(700676|700678)\d{13}$/
      end
    end

    class Mada < CardCompany
      RANGES = [
        504300..504300, 506968..506968, 508160..508160, 585265..585265, 588848..588848,
        588850..588850, 588982..588983, 589005..589005, 589206..589206, 604906..604906,
        605141..605141, 636120..636120, 968201..968209, 968211..968211
      ]

      def self.valid_card_number?(number)
        number&.size == 16 && in_bin_range?(number.slice(0, 6), RANGES)
      end
    end
  end
end
