# encoding: utf-8

module ActiveMerchant #:nodoc:
  class InvalidCountryCodeError < StandardError
  end

  class CountryCodeFormatError < StandardError
  end

  class CountryCode
    attr_reader :value, :format
    def initialize(value)
      @value = value.to_s.upcase
      detect_format
    end

    def to_s
      value
    end

    private

    def detect_format
      case @value
      when /^[[:alpha:]]{2}$/
        @format = :alpha2
      when /^[[:alpha:]]{3}$/
        @format = :alpha3
      when /^[[:digit:]]{3}$/
        @format = :numeric
      else
        raise CountryCodeFormatError, "The country code is not formatted correctly #{@value}"
      end
    end
  end

  class Country
    attr_reader :name

    def initialize(options = {})
      @name = options.delete(:name)
      @codes = options.collect{|k,v| CountryCode.new(v)}
    end

    def code(format)
      @codes.detect{|c| c.format == format}
    end

    def ==(other)
      if other.class == ActiveMerchant::Country
        (@name == other.name)
      else
        super
      end
    end

    alias eql? ==

    def hash
      @name.hash
    end

    def to_s
      @name
    end

    COUNTRIES = [
      { alpha2: 'AF', name: 'Afghanistan', alpha3: 'AFG', numeric: '004' },
      { alpha2: 'AL', name: 'Albania', alpha3: 'ALB', numeric: '008' },
      { alpha2: 'DZ', name: 'Algeria', alpha3: 'DZA', numeric: '012' },
      { alpha2: 'AS', name: 'American Samoa', alpha3: 'ASM', numeric: '016' },
      { alpha2: 'AD', name: 'Andorra', alpha3: 'AND', numeric: '020' },
      { alpha2: 'AO', name: 'Angola', alpha3: 'AGO', numeric: '024' },
      { alpha2: 'AI', name: 'Anguilla', alpha3: 'AIA', numeric: '660' },
      { alpha2: 'AG', name: 'Antigua and Barbuda', alpha3: 'ATG', numeric: '028' },
      { alpha2: 'AR', name: 'Argentina', alpha3: 'ARG', numeric: '032' },
      { alpha2: 'AM', name: 'Armenia', alpha3: 'ARM', numeric: '051' },
      { alpha2: 'AW', name: 'Aruba', alpha3: 'ABW', numeric: '533' },
      { alpha2: 'AU', name: 'Australia', alpha3: 'AUS', numeric: '036' },
      { alpha2: 'AT', name: 'Austria', alpha3: 'AUT', numeric: '040' },
      { alpha2: 'AZ', name: 'Azerbaijan', alpha3: 'AZE', numeric: '031' },
      { alpha2: 'BS', name: 'Bahamas', alpha3: 'BHS', numeric: '044' },
      { alpha2: 'BH', name: 'Bahrain', alpha3: 'BHR', numeric: '048' },
      { alpha2: 'BD', name: 'Bangladesh', alpha3: 'BGD', numeric: '050' },
      { alpha2: 'BB', name: 'Barbados', alpha3: 'BRB', numeric: '052' },
      { alpha2: 'BY', name: 'Belarus', alpha3: 'BLR', numeric: '112' },
      { alpha2: 'BE', name: 'Belgium', alpha3: 'BEL', numeric: '056' },
      { alpha2: 'BZ', name: 'Belize', alpha3: 'BLZ', numeric: '084' },
      { alpha2: 'BJ', name: 'Benin', alpha3: 'BEN', numeric: '204' },
      { alpha2: 'BM', name: 'Bermuda', alpha3: 'BMU', numeric: '060' },
      { alpha2: 'BT', name: 'Bhutan', alpha3: 'BTN', numeric: '064' },
      { alpha2: 'BO', name: 'Bolivia', alpha3: 'BOL', numeric: '068' },
      { alpha2: 'BA', name: 'Bosnia and Herzegovina', alpha3: 'BIH', numeric: '070' },
      { alpha2: 'BW', name: 'Botswana', alpha3: 'BWA', numeric: '072' },
      { alpha2: 'BV', name: 'Bouvet Island', alpha3: 'BVD', numeric: '074' },
      { alpha2: 'BR', name: 'Brazil', alpha3: 'BRA', numeric: '076' },
      { alpha2: 'IO', name: 'British Indian Ocean Territory', alpha3: 'IOT', numeric: '086' },
      { alpha2: 'BN', name: 'Brunei Darussalam', alpha3: 'BRN', numeric: '096' },
      { alpha2: 'BG', name: 'Bulgaria', alpha3: 'BGR', numeric: '100' },
      { alpha2: 'BF', name: 'Burkina Faso', alpha3: 'BFA', numeric: '854' },
      { alpha2: 'BI', name: 'Burundi', alpha3: 'BDI', numeric: '108' },
      { alpha2: 'KH', name: 'Cambodia', alpha3: 'KHM', numeric: '116' },
      { alpha2: 'CM', name: 'Cameroon', alpha3: 'CMR', numeric: '120' },
      { alpha2: 'CA', name: 'Canada', alpha3: 'CAN', numeric: '124' },
      { alpha2: 'CV', name: 'Cape Verde', alpha3: 'CPV', numeric: '132' },
      { alpha2: 'KY', name: 'Cayman Islands', alpha3: 'CYM', numeric: '136' },
      { alpha2: 'CF', name: 'Central African Republic', alpha3: 'CAF', numeric: '140' },
      { alpha2: 'TD', name: 'Chad', alpha3: 'TCD', numeric: '148' },
      { alpha2: 'CL', name: 'Chile', alpha3: 'CHL', numeric: '152' },
      { alpha2: 'CN', name: 'China', alpha3: 'CHN', numeric: '156' },
      { alpha2: 'CX', name: 'Christmas Island', alpha3: 'CXR', numeric: '162' },
      { alpha2: 'CC', name: 'Cocos (Keeling) Islands', alpha3: 'CCK', numeric: '166' },
      { alpha2: 'CO', name: 'Colombia', alpha3: 'COL', numeric: '170' },
      { alpha2: 'KM', name: 'Comoros', alpha3: 'COM', numeric: '174' },
      { alpha2: 'CG', name: 'Congo', alpha3: 'COG', numeric: '178' },
      { alpha2: 'CD', name: 'Congo, the Democratic Republic of the', alpha3: 'COD', numeric: '180' },
      { alpha2: 'CK', name: 'Cook Islands', alpha3: 'COK', numeric: '184' },
      { alpha2: 'CR', name: 'Costa Rica', alpha3: 'CRI', numeric: '188' },
      { alpha2: 'CI', name: 'Cote D\'Ivoire', alpha3: 'CIV', numeric: '384' },
      { alpha2: 'HR', name: 'Croatia', alpha3: 'HRV', numeric: '191' },
      { alpha2: 'CU', name: 'Cuba', alpha3: 'CUB', numeric: '192' },
      { alpha2: 'CW', name: 'Curaçao', alpha3: 'CUW', numeric: '531' },
      { alpha2: 'CY', name: 'Cyprus', alpha3: 'CYP', numeric: '196' },
      { alpha2: 'CZ', name: 'Czech Republic', alpha3: 'CZE', numeric: '203' },
      { alpha2: 'DK', name: 'Denmark', alpha3: 'DNK', numeric: '208' },
      { alpha2: 'DJ', name: 'Djibouti', alpha3: 'DJI', numeric: '262' },
      { alpha2: 'DM', name: 'Dominica', alpha3: 'DMA', numeric: '212' },
      { alpha2: 'DO', name: 'Dominican Republic', alpha3: 'DOM', numeric: '214' },
      { alpha2: 'EC', name: 'Ecuador', alpha3: 'ECU', numeric: '218' },
      { alpha2: 'EG', name: 'Egypt', alpha3: 'EGY', numeric: '818' },
      { alpha2: 'SV', name: 'El Salvador', alpha3: 'SLV', numeric: '222' },
      { alpha2: 'GQ', name: 'Equatorial Guinea', alpha3: 'GNQ', numeric: '226' },
      { alpha2: 'ER', name: 'Eritrea', alpha3: 'ERI', numeric: '232' },
      { alpha2: 'EE', name: 'Estonia', alpha3: 'EST', numeric: '233' },
      { alpha2: 'ET', name: 'Ethiopia', alpha3: 'ETH', numeric: '231' },
      { alpha2: 'FK', name: 'Falkland Islands (Malvinas)', alpha3: 'FLK', numeric: '238' },
      { alpha2: 'FO', name: 'Faroe Islands', alpha3: 'FRO', numeric: '234' },
      { alpha2: 'FJ', name: 'Fiji', alpha3: 'FJI', numeric: '242' },
      { alpha2: 'FI', name: 'Finland', alpha3: 'FIN', numeric: '246' },
      { alpha2: 'FR', name: 'France', alpha3: 'FRA', numeric: '250' },
      { alpha2: 'GF', name: 'French Guiana', alpha3: 'GUF', numeric: '254' },
      { alpha2: 'PF', name: 'French Polynesia', alpha3: 'PYF', numeric: '258' },
      { alpha2: 'TF', name: 'French Southern Territories', alpha3: 'ATF', numeric: '260' },
      { alpha2: 'GA', name: 'Gabon', alpha3: 'GAB', numeric: '266' },
      { alpha2: 'GM', name: 'Gambia', alpha3: 'GMB', numeric: '270' },
      { alpha2: 'GE', name: 'Georgia', alpha3: 'GEO', numeric: '268' },
      { alpha2: 'DE', name: 'Germany', alpha3: 'DEU', numeric: '276' },
      { alpha2: 'GH', name: 'Ghana', alpha3: 'GHA', numeric: '288' },
      { alpha2: 'GI', name: 'Gibraltar', alpha3: 'GIB', numeric: '292' },
      { alpha2: 'GR', name: 'Greece', alpha3: 'GRC', numeric: '300' },
      { alpha2: 'GL', name: 'Greenland', alpha3: 'GRL', numeric: '304' },
      { alpha2: 'GD', name: 'Grenada', alpha3: 'GRD', numeric: '308' },
      { alpha2: 'GP', name: 'Guadeloupe', alpha3: 'GLP', numeric: '312' },
      { alpha2: 'GU', name: 'Guam', alpha3: 'GUM', numeric: '316' },
      { alpha2: 'GT', name: 'Guatemala', alpha3: 'GTM', numeric: '320' },
      { alpha2: 'GG', name: 'Guernsey', alpha3: 'GGY', numeric: '831' },
      { alpha2: 'GN', name: 'Guinea', alpha3: 'GIN', numeric: '324' },
      { alpha2: 'GW', name: 'Guinea-Bissau', alpha3: 'GNB', numeric: '624' },
      { alpha2: 'GY', name: 'Guyana', alpha3: 'GUY', numeric: '328' },
      { alpha2: 'HT', name: 'Haiti', alpha3: 'HTI', numeric: '332' },
      { alpha2: 'HM', name: 'Heard Island And Mcdonald Islands', alpha3: 'HMD', numeric: '334' },
      { alpha2: 'VA', name: 'Holy See (Vatican City State)', alpha3: 'VAT', numeric: '336' },
      { alpha2: 'HN', name: 'Honduras', alpha3: 'HND', numeric: '340' },
      { alpha2: 'HK', name: 'Hong Kong', alpha3: 'HKG', numeric: '344' },
      { alpha2: 'HU', name: 'Hungary', alpha3: 'HUN', numeric: '348' },
      { alpha2: 'IS', name: 'Iceland', alpha3: 'ISL', numeric: '352' },
      { alpha2: 'IN', name: 'India', alpha3: 'IND', numeric: '356' },
      { alpha2: 'ID', name: 'Indonesia', alpha3: 'IDN', numeric: '360' },
      { alpha2: 'IR', name: 'Iran, Islamic Republic of', alpha3: 'IRN', numeric: '364' },
      { alpha2: 'IQ', name: 'Iraq', alpha3: 'IRQ', numeric: '368' },
      { alpha2: 'IE', name: 'Ireland', alpha3: 'IRL', numeric: '372' },
      { alpha2: 'IM', name: 'Isle Of Man', alpha3: 'IMN', numeric: '833' },
      { alpha2: 'IL', name: 'Israel', alpha3: 'ISR', numeric: '376' },
      { alpha2: 'IT', name: 'Italy', alpha3: 'ITA', numeric: '380' },
      { alpha2: 'JM', name: 'Jamaica', alpha3: 'JAM', numeric: '388' },
      { alpha2: 'JP', name: 'Japan', alpha3: 'JPN', numeric: '392' },
      { alpha2: 'JE', name: 'Jersey', alpha3: 'JEY', numeric: '832' },
      { alpha2: 'JO', name: 'Jordan', alpha3: 'JOR', numeric: '400' },
      { alpha2: 'KZ', name: 'Kazakhstan', alpha3: 'KAZ', numeric: '398' },
      { alpha2: 'KE', name: 'Kenya', alpha3: 'KEN', numeric: '404' },
      { alpha2: 'KI', name: 'Kiribati', alpha3: 'KIR', numeric: '296' },
      { alpha2: 'KP', name: 'Korea, Democratic People\'s Republic of', alpha3: 'PRK', numeric: '408' },
      { alpha2: 'KR', name: 'Korea, Republic of', alpha3: 'KOR', numeric: '410' },
      { alpha2: 'KV', name: 'Kosovo', alpha3: 'KSV', numeric: '377' },
      { alpha2: 'KW', name: 'Kuwait', alpha3: 'KWT', numeric: '414' },
      { alpha2: 'KG', name: 'Kyrgyzstan', alpha3: 'KGZ', numeric: '417' },
      { alpha2: 'LA', name: 'Lao People\'s Democratic Republic', alpha3: 'LAO', numeric: '418' },
      { alpha2: 'LV', name: 'Latvia', alpha3: 'LVA', numeric: '428' },
      { alpha2: 'LB', name: 'Lebanon', alpha3: 'LBN', numeric: '422' },
      { alpha2: 'LS', name: 'Lesotho', alpha3: 'LSO', numeric: '426' },
      { alpha2: 'LR', name: 'Liberia', alpha3: 'LBR', numeric: '430' },
      { alpha2: 'LY', name: 'Libyan Arab Jamahiriya', alpha3: 'LBY', numeric: '434' },
      { alpha2: 'LI', name: 'Liechtenstein', alpha3: 'LIE', numeric: '438' },
      { alpha2: 'LT', name: 'Lithuania', alpha3: 'LTU', numeric: '440' },
      { alpha2: 'LU', name: 'Luxembourg', alpha3: 'LUX', numeric: '442' },
      { alpha2: 'MO', name: 'Macao', alpha3: 'MAC', numeric: '446' },
      { alpha2: 'MK', name: 'Macedonia, the Former Yugoslav Republic of', alpha3: 'MKD', numeric: '807' },
      { alpha2: 'MG', name: 'Madagascar', alpha3: 'MDG', numeric: '450' },
      { alpha2: 'MW', name: 'Malawi', alpha3: 'MWI', numeric: '454' },
      { alpha2: 'MY', name: 'Malaysia', alpha3: 'MYS', numeric: '458' },
      { alpha2: 'MV', name: 'Maldives', alpha3: 'MDV', numeric: '462' },
      { alpha2: 'ML', name: 'Mali', alpha3: 'MLI', numeric: '466' },
      { alpha2: 'MT', name: 'Malta', alpha3: 'MLT', numeric: '470' },
      { alpha2: 'MH', name: 'Marshall Islands', alpha3: 'MHL', numeric: '584' },
      { alpha2: 'MQ', name: 'Martinique', alpha3: 'MTQ', numeric: '474' },
      { alpha2: 'MR', name: 'Mauritania', alpha3: 'MRT', numeric: '478' },
      { alpha2: 'MU', name: 'Mauritius', alpha3: 'MUS', numeric: '480' },
      { alpha2: 'YT', name: 'Mayotte', alpha3: 'MYT', numeric: '175' },
      { alpha2: 'MX', name: 'Mexico', alpha3: 'MEX', numeric: '484' },
      { alpha2: 'FM', name: 'Micronesia, Federated States of', alpha3: 'FSM', numeric: '583' },
      { alpha2: 'MD', name: 'Moldova, Republic of', alpha3: 'MDA', numeric: '498' },
      { alpha2: 'MC', name: 'Monaco', alpha3: 'MCO', numeric: '492' },
      { alpha2: 'MN', name: 'Mongolia', alpha3: 'MNG', numeric: '496' },
      { alpha2: 'ME', name: 'Montenegro', alpha3: 'MNE', numeric: '499' },
      { alpha2: 'MS', name: 'Montserrat', alpha3: 'MSR', numeric: '500' },
      { alpha2: 'MA', name: 'Morocco', alpha3: 'MAR', numeric: '504' },
      { alpha2: 'MZ', name: 'Mozambique', alpha3: 'MOZ', numeric: '508' },
      { alpha2: 'MM', name: 'Myanmar', alpha3: 'MMR', numeric: '104' },
      { alpha2: 'NA', name: 'Namibia', alpha3: 'NAM', numeric: '516' },
      { alpha2: 'NR', name: 'Nauru', alpha3: 'NRU', numeric: '520' },
      { alpha2: 'NP', name: 'Nepal', alpha3: 'NPL', numeric: '524' },
      { alpha2: 'NL', name: 'Netherlands', alpha3: 'NLD', numeric: '528' },
      { alpha2: 'AN', name: 'Netherlands Antilles', alpha3: 'ANT', numeric: '530' },
      { alpha2: 'NC', name: 'New Caledonia', alpha3: 'NCL', numeric: '540' },
      { alpha2: 'NZ', name: 'New Zealand', alpha3: 'NZL', numeric: '554' },
      { alpha2: 'NI', name: 'Nicaragua', alpha3: 'NIC', numeric: '558' },
      { alpha2: 'NE', name: 'Niger', alpha3: 'NER', numeric: '562' },
      { alpha2: 'NG', name: 'Nigeria', alpha3: 'NGA', numeric: '566' },
      { alpha2: 'NU', name: 'Niue', alpha3: 'NIU', numeric: '570' },
      { alpha2: 'NF', name: 'Norfolk Island', alpha3: 'NFK', numeric: '574' },
      { alpha2: 'MP', name: 'Northern Mariana Islands', alpha3: 'MNP', numeric: '580' },
      { alpha2: 'NO', name: 'Norway', alpha3: 'NOR', numeric: '578' },
      { alpha2: 'OM', name: 'Oman', alpha3: 'OMN', numeric: '512' },
      { alpha2: 'PK', name: 'Pakistan', alpha3: 'PAK', numeric: '586' },
      { alpha2: 'PW', name: 'Palau', alpha3: 'PLW', numeric: '585' },
      { alpha2: 'PS', name: 'Palestinian Territory, Occupied', alpha3: 'PSE', numeric: '275' },
      { alpha2: 'PA', name: 'Panama', alpha3: 'PAN', numeric: '591' },
      { alpha2: 'PG', name: 'Papua New Guinea', alpha3: 'PNG', numeric: '598' },
      { alpha2: 'PY', name: 'Paraguay', alpha3: 'PRY', numeric: '600' },
      { alpha2: 'PE', name: 'Peru', alpha3: 'PER', numeric: '604' },
      { alpha2: 'PH', name: 'Philippines', alpha3: 'PHL', numeric: '608' },
      { alpha2: 'PN', name: 'Pitcairn', alpha3: 'PCN', numeric: '612' },
      { alpha2: 'PL', name: 'Poland', alpha3: 'POL', numeric: '616' },
      { alpha2: 'PT', name: 'Portugal', alpha3: 'PRT', numeric: '620' },
      { alpha2: 'PR', name: 'Puerto Rico', alpha3: 'PRI', numeric: '630' },
      { alpha2: 'QA', name: 'Qatar', alpha3: 'QAT', numeric: '634' },
      { alpha2: 'RE', name: 'Reunion', alpha3: 'REU', numeric: '638' },
      { alpha2: 'RO', name: 'Romania', alpha3: 'ROM', numeric: '642' },
      { alpha2: 'RU', name: 'Russian Federation', alpha3: 'RUS', numeric: '643' },
      { alpha2: 'RW', name: 'Rwanda', alpha3: 'RWA', numeric: '646' },
      { alpha2: 'BL', name: 'Saint Barthélemy', alpha3: 'BLM', numeric: '652' },
      { alpha2: 'SH', name: 'Saint Helena', alpha3: 'SHN', numeric: '654' },
      { alpha2: 'KN', name: 'Saint Kitts and Nevis', alpha3: 'KNA', numeric: '659' },
      { alpha2: 'LC', name: 'Saint Lucia', alpha3: 'LCA', numeric: '662' },
      { alpha2: 'MF', name: 'Saint Martin (French part)', alpha3: 'MAF', numeric: '663' },
      { alpha2: 'PM', name: 'Saint Pierre and Miquelon', alpha3: 'SPM', numeric: '666' },
      { alpha2: 'VC', name: 'Saint Vincent and the Grenadines', alpha3: 'VCT', numeric: '670' },
      { alpha2: 'WS', name: 'Samoa', alpha3: 'WSM', numeric: '882' },
      { alpha2: 'SM', name: 'San Marino', alpha3: 'SMR', numeric: '674' },
      { alpha2: 'ST', name: 'Sao Tome and Principe', alpha3: 'STP', numeric: '678' },
      { alpha2: 'SA', name: 'Saudi Arabia', alpha3: 'SAU', numeric: '682' },
      { alpha2: 'SN', name: 'Senegal', alpha3: 'SEN', numeric: '686' },
      { alpha2: 'RS', name: 'Serbia', alpha3: 'SRB', numeric: '688' },
      { alpha2: 'SC', name: 'Seychelles', alpha3: 'SYC', numeric: '690' },
      { alpha2: 'SL', name: 'Sierra Leone', alpha3: 'SLE', numeric: '694' },
      { alpha2: 'SG', name: 'Singapore', alpha3: 'SGP', numeric: '702' },
      { alpha2: 'SK', name: 'Slovakia', alpha3: 'SVK', numeric: '703' },
      { alpha2: 'SI', name: 'Slovenia', alpha3: 'SVN', numeric: '705' },
      { alpha2: 'SB', name: 'Solomon Islands', alpha3: 'SLB', numeric: '090' },
      { alpha2: 'SO', name: 'Somalia', alpha3: 'SOM', numeric: '706' },
      { alpha2: 'ZA', name: 'South Africa', alpha3: 'ZAF', numeric: '710' },
      { alpha2: 'GS', name: 'South Georgia and the South Sandwich Islands', alpha3: 'SGS', numeric: '239' },
      { alpha2: 'ES', name: 'Spain', alpha3: 'ESP', numeric: '724' },
      { alpha2: 'LK', name: 'Sri Lanka', alpha3: 'LKA', numeric: '144' },
      { alpha2: 'SD', name: 'Sudan', alpha3: 'SDN', numeric: '736' },
      { alpha2: 'SR', name: 'Suriname', alpha3: 'SUR', numeric: '740' },
      { alpha2: 'SJ', name: 'Svalbard and Jan Mayen', alpha3: 'SJM', numeric: '744' },
      { alpha2: 'SZ', name: 'Swaziland', alpha3: 'SWZ', numeric: '748' },
      { alpha2: 'SE', name: 'Sweden', alpha3: 'SWE', numeric: '752' },
      { alpha2: 'CH', name: 'Switzerland', alpha3: 'CHE', numeric: '756' },
      { alpha2: 'SY', name: 'Syrian Arab Republic', alpha3: 'SYR', numeric: '760' },
      { alpha2: 'TW', name: 'Taiwan, Province of China', alpha3: 'TWN', numeric: '158' },
      { alpha2: 'TJ', name: 'Tajikistan', alpha3: 'TJK', numeric: '762' },
      { alpha2: 'TZ', name: 'Tanzania, United Republic of', alpha3: 'TZA', numeric: '834' },
      { alpha2: 'TH', name: 'Thailand', alpha3: 'THA', numeric: '764' },
      { alpha2: 'TL', name: 'Timor Leste', alpha3: 'TLS', numeric: '626' },
      { alpha2: 'TG', name: 'Togo', alpha3: 'TGO', numeric: '768' },
      { alpha2: 'TK', name: 'Tokelau', alpha3: 'TKL', numeric: '772' },
      { alpha2: 'TO', name: 'Tonga', alpha3: 'TON', numeric: '776' },
      { alpha2: 'TT', name: 'Trinidad and Tobago', alpha3: 'TTO', numeric: '780' },
      { alpha2: 'TN', name: 'Tunisia', alpha3: 'TUN', numeric: '788' },
      { alpha2: 'TR', name: 'Turkey', alpha3: 'TUR', numeric: '792' },
      { alpha2: 'TM', name: 'Turkmenistan', alpha3: 'TKM', numeric: '795' },
      { alpha2: 'TC', name: 'Turks and Caicos Islands', alpha3: 'TCA', numeric: '796' },
      { alpha2: 'TV', name: 'Tuvalu', alpha3: 'TUV', numeric: '798' },
      { alpha2: 'UG', name: 'Uganda', alpha3: 'UGA', numeric: '800' },
      { alpha2: 'UA', name: 'Ukraine', alpha3: 'UKR', numeric: '804' },
      { alpha2: 'AE', name: 'United Arab Emirates', alpha3: 'ARE', numeric: '784' },
      { alpha2: 'GB', name: 'United Kingdom', alpha3: 'GBR', numeric: '826' },
      { alpha2: 'US', name: 'United States', alpha3: 'USA', numeric: '840' },
      { alpha2: 'UM', name: 'United States Minor Outlying Islands', alpha3: 'UMI', numeric: '581' },
      { alpha2: 'UY', name: 'Uruguay', alpha3: 'URY', numeric: '858' },
      { alpha2: 'UZ', name: 'Uzbekistan', alpha3: 'UZB', numeric: '860' },
      { alpha2: 'VU', name: 'Vanuatu', alpha3: 'VUT', numeric: '548' },
      { alpha2: 'VE', name: 'Venezuela', alpha3: 'VEN', numeric: '862' },
      { alpha2: 'VN', name: 'Viet Nam', alpha3: 'VNM', numeric: '704' },
      { alpha2: 'VG', name: 'Virgin Islands, British', alpha3: 'VGB', numeric: '092' },
      { alpha2: 'VI', name: 'Virgin Islands, U.S.', alpha3: 'VIR', numeric: '850' },
      { alpha2: 'WF', name: 'Wallis and Futuna', alpha3: 'WLF', numeric: '876' },
      { alpha2: 'EH', name: 'Western Sahara', alpha3: 'ESH', numeric: '732' },
      { alpha2: 'YE', name: 'Yemen', alpha3: 'YEM', numeric: '887' },
      { alpha2: 'ZM', name: 'Zambia', alpha3: 'ZMB', numeric: '894' },
      { alpha2: 'ZW', name: 'Zimbabwe', alpha3: 'ZWE', numeric: '716' },
      { alpha2: 'AX', name: 'Åland Islands', alpha3: 'ALA', numeric: '248' }
    ]

    def self.find(name)
      raise InvalidCountryCodeError, "Cannot lookup country for an empty name" if name.blank?

      case name.length
      when 2, 3
        upcase_name = name.upcase
        country_code = CountryCode.new(name)
        country = COUNTRIES.detect{|c| c[country_code.format] == upcase_name }
      else
        country = COUNTRIES.detect{|c| c[:name] == name }
      end
      raise InvalidCountryCodeError, "No country could be found for the country #{name}" if country.nil?
      Country.new(country.dup)
    end
  end
end
