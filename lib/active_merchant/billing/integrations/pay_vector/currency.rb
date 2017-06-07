# encoding: UTF-8

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayVector
        class ISOCurrencies

          @@currencies = Array.new
          @@currencies << {:iso_code => 634, :currency => "Qatari Rial", :currency_short => "QAR", :exponent => 2}
          @@currencies << {:iso_code => 566, :currency => "Naira", :currency_short => "NGN", :exponent => 2}
          @@currencies << {:iso_code => 678, :currency => "Dobra", :currency_short => "STD", :exponent => 2}
          @@currencies << {:iso_code => 943, :currency => "Metical", :currency_short => "MZN", :exponent => 2}
          @@currencies << {:iso_code => 826, :currency => "Pound Sterling", :currency_short => "GBP", :exponent => 2}
          @@currencies << {:iso_code => 654, :currency => "Saint Helena Pound", :currency_short => "SHP", :exponent => 2}
          @@currencies << {:iso_code => 704, :currency => "Vietnamese ??ng", :currency_short => "VND", :exponent => 2}
          @@currencies << {:iso_code => 952, :currency => "CFA Franc BCEAO", :currency_short => "XOF", :exponent => 0}
          @@currencies << {:iso_code => 356, :currency => "Indian Rupee", :currency_short => "INR", :exponent => 2}
          @@currencies << {:iso_code => 807, :currency => "Denar", :currency_short => "MKD", :exponent => 2}
          @@currencies << {:iso_code => 959, :currency => "Gold (one Troy ounce)", :currency_short => "XAU", :exponent => 0}
          @@currencies << {:iso_code => 410, :currency => "South Korean Won", :currency_short => "KRW", :exponent => 0}
          @@currencies << {:iso_code => 946, :currency => "Romanian New Leu", :currency_short => "RON", :exponent => 2}
          @@currencies << {:iso_code => 949, :currency => "New Turkish Lira", :currency_short => "TRY", :exponent => 2}
          @@currencies << {:iso_code => 532, :currency => "Netherlands Antillian Guilder", :currency_short => "ANG", :exponent => 2}
          @@currencies << {:iso_code => 788, :currency => "Tunisian Dinar", :currency_short => "TND", :exponent => 3}
          @@currencies << {:iso_code => 646, :currency => "Rwanda Franc", :currency_short => "RWF", :exponent => 0}
          @@currencies << {:iso_code => 504, :currency => "Moroccan Dirham", :currency_short => "MAD", :exponent => 2}
          @@currencies << {:iso_code => 174, :currency => "Comoro Franc", :currency_short => "KMF", :exponent => 0}
          @@currencies << {:iso_code => 484, :currency => "Mexican Peso", :currency_short => "MXN", :exponent => 2}
          @@currencies << {:iso_code => 478, :currency => "Ouguiya", :currency_short => "MRO", :exponent => 2}
          @@currencies << {:iso_code => 233, :currency => "Kroon", :currency_short => "EEK", :exponent => 2}
          @@currencies << {:iso_code => 400, :currency => "Jordanian Dinar", :currency_short => "JOD", :exponent => 3}
          @@currencies << {:iso_code => 292, :currency => "Gibraltar pound", :currency_short => "GIP", :exponent => 2}
          @@currencies << {:iso_code => 690, :currency => "Seychelles Rupee", :currency_short => "SCR", :exponent => 2}
          @@currencies << {:iso_code => 422, :currency => "Lebanese Pound", :currency_short => "LBP", :exponent => 2}
          @@currencies << {:iso_code => 232, :currency => "Nakfa", :currency_short => "ERN", :exponent => 2}
          @@currencies << {:iso_code => 496, :currency => "Tugrik", :currency_short => "MNT", :exponent => 2}
          @@currencies << {:iso_code => 328, :currency => "Guyana Dollar", :currency_short => "GYD", :exponent => 2}
          @@currencies << {:iso_code => 970, :currency => "Unidad de Valor Real", :currency_short => "COU", :exponent => 2}
          @@currencies << {:iso_code => 974, :currency => "Belarusian Ruble", :currency_short => "BYR", :exponent => 0}
          @@currencies << {:iso_code => 608, :currency => "Philippine Peso", :currency_short => "PHP", :exponent => 2}
          @@currencies << {:iso_code => 598, :currency => "Kina", :currency_short => "PGK", :exponent => 2}
          @@currencies << {:iso_code => 951, :currency => "East Caribbean Dollar", :currency_short => "XCD", :exponent => 2}
          @@currencies << {:iso_code => 52, :currency => "Barbados Dollar", :currency_short => "BBD", :exponent => 2}
          @@currencies << {:iso_code => 944, :currency => "Azerbaijanian Manat", :currency_short => "AZN", :exponent => 2}
          @@currencies << {:iso_code => 434, :currency => "Libyan Dinar", :currency_short => "LYD", :exponent => 3}
          @@currencies << {:iso_code => 706, :currency => "Somali Shilling", :currency_short => "SOS", :exponent => 2}
          @@currencies << {:iso_code => 950, :currency => "CFA Franc BEAC", :currency_short => "XAF", :exponent => 0}
          @@currencies << {:iso_code => 840, :currency => "US Dollar", :currency_short => "USD", :exponent => 2}
          @@currencies << {:iso_code => 68, :currency => "Boliviano", :currency_short => "BOB", :exponent => 2}
          @@currencies << {:iso_code => 214, :currency => "Dominican Peso", :currency_short => "DOP", :exponent => 2}
          @@currencies << {:iso_code => 818, :currency => "Egyptian Pound", :currency_short => "EGP", :exponent => 2}
          @@currencies << {:iso_code => 170, :currency => "Colombian Peso", :currency_short => "COP", :exponent => 2}
          @@currencies << {:iso_code => 986, :currency => "Brazilian Real", :currency_short => "BRL", :exponent => 2}
          @@currencies << {:iso_code => 961, :currency => "Silver (one Troy ounce)", :currency_short => "XAG", :exponent => 0}
          @@currencies << {:iso_code => 973, :currency => "Kwanza", :currency_short => "AOA", :exponent => 2}
          @@currencies << {:iso_code => 962, :currency => "Platinum (one Troy ounce)", :currency_short => "XPT", :exponent => 0}
          @@currencies << {:iso_code => 414, :currency => "Kuwaiti Dinar", :currency_short => "KWD", :exponent => 3}
          @@currencies << {:iso_code => 604, :currency => "Nuevo Sol", :currency_short => "PEN", :exponent => 2}
          @@currencies << {:iso_code => 702, :currency => "Singapore Dollar", :currency_short => "SGD", :exponent => 2}
          @@currencies << {:iso_code => 862, :currency => "Venezuelan bol�var", :currency_short => "VEB", :exponent => 2}
          @@currencies << {:iso_code => 953, :currency => "CFP franc", :currency_short => "XPF", :exponent => 0}
          @@currencies << {:iso_code => 558, :currency => "Cordoba Oro", :currency_short => "NIO", :exponent => 2}
          @@currencies << {:iso_code => 348, :currency => "Forint", :currency_short => "HUF", :exponent => 2}
          @@currencies << {:iso_code => 948, :currency => "WIR Franc ", :currency_short => "CHW", :exponent => 2}
          @@currencies << {:iso_code => 116, :currency => "Riel", :currency_short => "KHR", :exponent => 2}
          @@currencies << {:iso_code => 956, :currency => "European Monetary Unit", :currency_short => "XBB", :exponent => 0}
          @@currencies << {:iso_code => 156, :currency => "Yuan Renminbi", :currency_short => "CNY", :exponent => 2}
          @@currencies << {:iso_code => 834, :currency => "Tanzanian Shilling", :currency_short => "TZS", :exponent => 2}
          @@currencies << {:iso_code => 997, :currency => "", :currency_short => "USN", :exponent => 2}
          @@currencies << {:iso_code => 981, :currency => "Lari", :currency_short => "GEL", :exponent => 2}
          @@currencies << {:iso_code => 242, :currency => "Fiji Dollar", :currency_short => "FJD", :exponent => 2}
          @@currencies << {:iso_code => 941, :currency => "Serbian Dinar", :currency_short => "RSD", :exponent => 2}
          @@currencies << {:iso_code => 104, :currency => "Kyat", :currency_short => "MMK", :exponent => 2}
          @@currencies << {:iso_code => 84, :currency => " Belize Dollar", :currency_short => "BZD", :exponent => 2}
          @@currencies << {:iso_code => 710, :currency => "South African Rand", :currency_short => "ZAR", :exponent => 2}
          @@currencies << {:iso_code => 760, :currency => "Syrian Pound", :currency_short => "SYP", :exponent => 2}
          @@currencies << {:iso_code => 512, :currency => "Rial Omani", :currency_short => "OMR", :exponent => 3}
          @@currencies << {:iso_code => 324, :currency => "Guinea Franc", :currency_short => "GNF", :exponent => 0}
          @@currencies << {:iso_code => 196, :currency => "Cyprus Pound", :currency_short => "CYP", :exponent => 2}
          @@currencies << {:iso_code => 960, :currency => "Special Drawing Rights", :currency_short => "XDR", :exponent => 0}
          @@currencies << {:iso_code => 716, :currency => "Zimbabwe Dollar", :currency_short => "ZWD", :exponent => 2}
          @@currencies << {:iso_code => 972, :currency => "Somoni", :currency_short => "TJS", :exponent => 2}
          @@currencies << {:iso_code => 462, :currency => "Rufiyaa", :currency_short => "MVR", :exponent => 2}
          @@currencies << {:iso_code => 979, :currency => "Mexican Unidad de Inversion (UDI)", :currency_short => "MXV", :exponent => 2}
          @@currencies << {:iso_code => 860, :currency => "Uzbekistan Som", :currency_short => "UZS", :exponent => 2}
          @@currencies << {:iso_code => 12, :currency => "Algerian Dinar", :currency_short => "DZD", :exponent => 2}
          @@currencies << {:iso_code => 332, :currency => "Haiti Gourde", :currency_short => "HTG", :exponent => 2}
          @@currencies << {:iso_code => 963, :currency => "Code reserved for testing purposes", :currency_short => "XTS", :exponent => 0}
          @@currencies << {:iso_code => 32, :currency => "Argentine Peso", :currency_short => "ARS", :exponent => 2}
          @@currencies << {:iso_code => 642, :currency => "Romanian Leu", :currency_short => "ROL", :exponent => 2}
          @@currencies << {:iso_code => 984, :currency => "Bolivian Mvdol (Funds code)", :currency_short => "BOV", :exponent => 2}
          @@currencies << {:iso_code => 440, :currency => "Lithuanian Litas", :currency_short => "LTL", :exponent => 2}
          @@currencies << {:iso_code => 480, :currency => "Mauritius Rupee", :currency_short => "MUR", :exponent => 2}
          @@currencies << {:iso_code => 426, :currency => "Loti", :currency_short => "LSL", :exponent => 2}
          @@currencies << {:iso_code => 262, :currency => "Djibouti Franc", :currency_short => "DJF", :exponent => 0}
          @@currencies << {:iso_code => 886, :currency => "Yemeni Rial", :currency_short => "YER", :exponent => 2}
          @@currencies << {:iso_code => 748, :currency => "Lilangeni", :currency_short => "SZL", :exponent => 2}
          @@currencies << {:iso_code => 192, :currency => "Cuban Peso", :currency_short => "CUP", :exponent => 2}
          @@currencies << {:iso_code => 548, :currency => "Vatu", :currency_short => "VUV", :exponent => 0}
          @@currencies << {:iso_code => 360, :currency => "Rupiah", :currency_short => "IDR", :exponent => 2}
          @@currencies << {:iso_code => 51, :currency => "Armenian Dram", :currency_short => "AMD", :exponent => 2}
          @@currencies << {:iso_code => 894, :currency => "Kwacha", :currency_short => "ZMK", :exponent => 2}
          @@currencies << {:iso_code => 90, :currency => "Solomon Islands Dollar", :currency_short => "SBD", :exponent => 2}
          @@currencies << {:iso_code => 132, :currency => "Cape Verde Escudo", :currency_short => "CVE", :exponent => 2}
          @@currencies << {:iso_code => 999, :currency => "No currency", :currency_short => "XXX", :exponent => 0}
          @@currencies << {:iso_code => 524, :currency => "Nepalese Rupee", :currency_short => "NPR", :exponent => 2}
          @@currencies << {:iso_code => 203, :currency => "Czech Koruna", :currency_short => "CZK", :exponent => 2}
          @@currencies << {:iso_code => 44, :currency => "Bahamian Dollar", :currency_short => "BSD", :exponent => 2}
          @@currencies << {:iso_code => 96, :currency => "Brunei Dollar", :currency_short => "BND", :exponent => 2}
          @@currencies << {:iso_code => 50, :currency => "Bangladeshi Taka", :currency_short => "BDT", :exponent => 2}
          @@currencies << {:iso_code => 404, :currency => "Kenyan Shilling", :currency_short => "KES", :exponent => 2}
          @@currencies << {:iso_code => 947, :currency => "WIR Euro ", :currency_short => "CHE", :exponent => 2}
          @@currencies << {:iso_code => 964, :currency => "Palladium (one Troy ounce)", :currency_short => "XPD", :exponent => 0}
          @@currencies << {:iso_code => 398, :currency => "Tenge", :currency_short => "KZT", :exponent => 2}
          @@currencies << {:iso_code => 352, :currency => "Iceland Krona", :currency_short => "ISK", :exponent => 2}
          @@currencies << {:iso_code => 64, :currency => "Ngultrum", :currency_short => "BTN", :exponent => 2}
          @@currencies << {:iso_code => 533, :currency => "Aruban Guilder", :currency_short => "AWG", :exponent => 2}
          @@currencies << {:iso_code => 230, :currency => "Ethiopian Birr", :currency_short => "ETB", :exponent => 2}
          @@currencies << {:iso_code => 800, :currency => "Uganda Shilling", :currency_short => "UGX", :exponent => 2}
          @@currencies << {:iso_code => 968, :currency => "Surinam Dollar", :currency_short => "SRD", :exponent => 2}
          @@currencies << {:iso_code => 882, :currency => "Samoan Tala", :currency_short => "WST", :exponent => 2}
          @@currencies << {:iso_code => 454, :currency => "Kwacha", :currency_short => "MWK", :exponent => 2}
          @@currencies << {:iso_code => 985, :currency => "Zloty", :currency_short => "PLN", :exponent => 2}
          @@currencies << {:iso_code => 124, :currency => "Canadian Dollar", :currency_short => "CAD", :exponent => 2}
          @@currencies << {:iso_code => 776, :currency => "Pa'anga", :currency_short => "TOP", :exponent => 2}
          @@currencies << {:iso_code => 208, :currency => "Danish Krone", :currency_short => "DKK", :exponent => 2}
          @@currencies << {:iso_code => 108, :currency => "Burundian Franc", :currency_short => "BIF", :exponent => 0}
          @@currencies << {:iso_code => 764, :currency => "Baht", :currency_short => "THB", :exponent => 2}
          @@currencies << {:iso_code => 458, :currency => "Malaysian Ringgit", :currency_short => "MYR", :exponent => 2}
          @@currencies << {:iso_code => 364, :currency => "Iranian Rial", :currency_short => "IRR", :exponent => 2}
          @@currencies << {:iso_code => 600, :currency => "Guarani", :currency_short => "PYG", :exponent => 0}
          @@currencies << {:iso_code => 977, :currency => "Convertible Marks", :currency_short => "BAM", :exponent => 2}
          @@currencies << {:iso_code => 446, :currency => "Pataca", :currency_short => "MOP", :exponent => 2}
          @@currencies << {:iso_code => 780, :currency => "Trinidad and Tobago Dollar", :currency_short => "TTD", :exponent => 2}
          @@currencies << {:iso_code => 703, :currency => "Slovak Koruna", :currency_short => "SKK", :exponent => 2}
          @@currencies << {:iso_code => 958, :currency => "European Unit of Account 17 (E.U.A.-17)", :currency_short => "XBD", :exponent => 0}
          @@currencies << {:iso_code => 430, :currency => "Liberian Dollar", :currency_short => "LRD", :exponent => 2}
          @@currencies << {:iso_code => 191, :currency => "Croatian Kuna", :currency_short => "HRK", :exponent => 2}
          @@currencies << {:iso_code => 694, :currency => "Leone", :currency_short => "SLL", :exponent => 2}
          @@currencies << {:iso_code => 756, :currency => "Swiss Franc", :currency_short => "CHF", :exponent => 2}
          @@currencies << {:iso_code => 969, :currency => "Malagasy Ariary", :currency_short => "MGA", :exponent => 0}
          @@currencies << {:iso_code => 270, :currency => "Dalasi", :currency_short => "GMD", :exponent => 2}
          @@currencies << {:iso_code => 418, :currency => "Kip", :currency_short => "LAK", :exponent => 2}
          @@currencies << {:iso_code => 516, :currency => "Namibian Dollar", :currency_short => "NAD", :exponent => 2}
          @@currencies << {:iso_code => 392, :currency => "Japanese yen", :currency_short => "JPY", :exponent => 0}
          @@currencies << {:iso_code => 320, :currency => "Quetzal", :currency_short => "GTQ", :exponent => 2}
          @@currencies << {:iso_code => 554, :currency => "New Zealand Dollar", :currency_short => "NZD", :exponent => 2}
          @@currencies << {:iso_code => 578, :currency => "Norwegian Krone", :currency_short => "NOK", :exponent => 2}
          @@currencies << {:iso_code => 376, :currency => "New Israeli Shekel", :currency_short => "ILS", :exponent => 2}
          @@currencies << {:iso_code => 957, :currency => "European Unit of Account 9 (E.U.A.-9)", :currency_short => "XBC", :exponent => 0}
          @@currencies << {:iso_code => 498, :currency => "Moldovan Leu", :currency_short => "MDL", :exponent => 2}
          @@currencies << {:iso_code => 998, :currency => "", :currency_short => "USS", :exponent => 2}
          @@currencies << {:iso_code => 955, :currency => "European Composite Unit (EURCO)", :currency_short => "XBA", :exponent => 0}
          @@currencies << {:iso_code => 344, :currency => "Hong Kong Dollar", :currency_short => "HKD", :exponent => 2}
          @@currencies << {:iso_code => 417, :currency => "Som", :currency_short => "KGS", :exponent => 2}
          @@currencies << {:iso_code => 858, :currency => "Peso Uruguayo", :currency_short => "UYU", :exponent => 2}
          @@currencies << {:iso_code => 60, :currency => "Bermudian Dollar ", :currency_short => "BMD", :exponent => 2}
          @@currencies << {:iso_code => 682, :currency => "Saudi Riyal", :currency_short => "SAR", :exponent => 2}
          @@currencies << {:iso_code => 643, :currency => "Russian Ruble", :currency_short => "RUB", :exponent => 2}
          @@currencies << {:iso_code => 470, :currency => "Maltese Lira", :currency_short => "MTL", :exponent => 2}
          @@currencies << {:iso_code => 340, :currency => "Lempira", :currency_short => "HNL", :exponent => 2}
          @@currencies << {:iso_code => 72, :currency => "Pula", :currency_short => "BWP", :exponent => 2}
          @@currencies << {:iso_code => 368, :currency => "Iraqi Dinar", :currency_short => "IQD", :exponent => 3}
          @@currencies << {:iso_code => 188, :currency => "Costa Rican Colon", :currency_short => "CRC", :exponent => 2}
          @@currencies << {:iso_code => 144, :currency => "Sri Lanka Rupee", :currency_short => "LKR", :exponent => 2}
          @@currencies << {:iso_code => 752, :currency => "Swedish Krona", :currency_short => "SEK", :exponent => 2}
          @@currencies << {:iso_code => 136, :currency => "Cayman Islands Dollar", :currency_short => "KYD", :exponent => 2}
          @@currencies << {:iso_code => 8, :currency => "Lek", :currency_short => "ALL", :exponent => 2}
          @@currencies << {:iso_code => 48, :currency => "Bahraini Dinar", :currency_short => "BHD", :exponent => 3}
          @@currencies << {:iso_code => 795, :currency => "Manat", :currency_short => "TMM", :exponent => 2}
          @@currencies << {:iso_code => 938, :currency => "Sudanese Pound", :currency_short => "SDG", :exponent => 2}
          @@currencies << {:iso_code => 590, :currency => "Balboa", :currency_short => "PAB", :exponent => 2}
          @@currencies << {:iso_code => 152, :currency => "Chilean Peso", :currency_short => "CLP", :exponent => 0}
          @@currencies << {:iso_code => 980, :currency => "Hryvnia", :currency_short => "UAH", :exponent => 2}
          @@currencies << {:iso_code => 428, :currency => "Latvian Lats", :currency_short => "LVL", :exponent => 2}
          @@currencies << {:iso_code => 288, :currency => "Cedi", :currency_short => "GHS", :exponent => 2}
          @@currencies << {:iso_code => 978, :currency => "Euro", :currency_short => "EUR", :exponent => 2}
          @@currencies << {:iso_code => 976, :currency => "Franc Congolais", :currency_short => "CDF", :exponent => 2}
          @@currencies << {:iso_code => 586, :currency => "Pakistan Rupee", :currency_short => "PKR", :exponent => 2}
          @@currencies << {:iso_code => 408, :currency => "North Korean Won", :currency_short => "KPW", :exponent => 2}
          @@currencies << {:iso_code => 388, :currency => "Jamaican Dollar", :currency_short => "JMD", :exponent => 2}
          @@currencies << {:iso_code => 990, :currency => "Unidades de formento", :currency_short => "CLF", :exponent => 0}
          @@currencies << {:iso_code => 971, :currency => "Afghani", :currency_short => "AFN", :exponent => 2}
          @@currencies << {:iso_code => 975, :currency => "Bulgarian Lev", :currency_short => "BGN", :exponent => 2}
          @@currencies << {:iso_code => 36, :currency => "Australian Dollar", :currency_short => "AUD", :exponent => 2}
          @@currencies << {:iso_code => 238, :currency => "Falkland Islands Pound", :currency_short => "FKP", :exponent => 2}
          @@currencies << {:iso_code => 901, :currency => "New Taiwan Dollar", :currency_short => "TWD", :exponent => 2}
          @@currencies << {:iso_code => 784, :currency => "United Arab Emirates dirham", :currency_short => "AED", :exponent => 2}
          
          def self.get_ISO_code_from_short(currency_short)
            @@currencies.each do |currency|
              if(currency[:currency_short] == currency_short)
                return currency[:iso_code]
              end
            end
            #if no currency found with that shortcode then return default
            return 826
          end
          
          def self.get_exponent_from_ISO_code(iso_code)
            @@currencies.each do |currency|
              if(currency[iso_code] == iso_code)
                return currency[:exponent]
              end
            end
            #if no currency found with that ISO code then return default
            return 2
          end
          
          def self.get_short_from_ISO_code(iso_code)
            @@currencies.each do |currency|
              if(currency[:iso_code] == iso_code)
                return currency[:currency_short]
              end
            end
            #if no currency found with that ISO code then return default
            return "GBP"
          end
          
        end
      end
    end
  end
end
