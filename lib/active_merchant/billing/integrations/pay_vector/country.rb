# encoding: UTF-8

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module PayVector
        class ISOCountries

          @@countries = Array.new
          @@countries << {:iso_code => 826, :country_short_2 => "GB", :country_short_3 =>  "GBR", :country_name => "United Kingdom", :list_priority => 3}
          @@countries << {:iso_code => 840, :country_short_2 => "US", :country_short_3 =>"USA", :country_name => "United States", :list_priority => 2}
          @@countries << {:iso_code => 36, :country_short_2 => "AU", :country_short_3 =>"AUS", :country_name => "Australia", :list_priority => 1}
          @@countries << {:iso_code => 124, :country_short_2 => "CA", :country_short_3 =>"CAN", :country_name => "Canada", :list_priority => 1}
          @@countries << {:iso_code => 276, :country_short_2 => "DE", :country_short_3 =>"DEU", :country_name => "Germany", :list_priority => 1}
          @@countries << {:iso_code => 250, :country_short_2 => "FR", :country_short_3 =>"FRA", :country_name => "France", :list_priority => 1}
          @@countries << {:iso_code => 533, :country_short_2 => "AW", :country_short_3 =>"ABW", :country_name => "Aruba", :list_priority => 0}
          @@countries << {:iso_code => 4, :country_short_2 => "AF", :country_short_3 =>"AFG", :country_name => "Afghanistan", :list_priority => 0}
          @@countries << {:iso_code => 24, :country_short_2 => "AO", :country_short_3 =>"AGO", :country_name => "Angola", :list_priority => 0}
          @@countries << {:iso_code => 660, :country_short_2 => "AI", :country_short_3 =>"AIA", :country_name => "Anguilla", :list_priority => 0}
          @@countries << {:iso_code => 248, :country_short_2 => "AX", :country_short_3 => "ALA", :country_name => "Åland Islands", :list_priority => 0}
          @@countries << {:iso_code => 8, :country_short_2 => "AL", :country_short_3 =>"ALB", :country_name => "Albania", :list_priority => 0}
          @@countries << {:iso_code => 20, :country_short_2 => "AD", :country_short_3 =>"AND", :country_name => "Andorra", :list_priority => 0}
          @@countries << {:iso_code => 530, :country_short_2 => "AN", :country_short_3 =>"ANT", :country_name => "Netherlands Antilles", :list_priority => 0}
          @@countries << {:iso_code => 784, :country_short_2 => "AE", :country_short_3 =>"ARE", :country_name => "United Arab Emirates", :list_priority => 0}
          @@countries << {:iso_code => 32, :country_short_2 => "AR", :country_short_3 =>"ARG", :country_name => "Argentina", :list_priority => 0}
          @@countries << {:iso_code => 51, :country_short_2 => "AM", :country_short_3 =>"ARM", :country_name => "Armenia", :list_priority => 0}
          @@countries << {:iso_code => 16, :country_short_2 => "AS", :country_short_3 =>"ASM", :country_name => "American Samoa", :list_priority => 0}
          @@countries << {:iso_code => 10, :country_short_2 => "AQ", :country_short_3 =>"ATA", :country_name => "Antarctica", :list_priority => 0}
          @@countries << {:iso_code => 260, :country_short_2 => "TF", :country_short_3 =>"ATF", :country_name => "French Southern Territories", :list_priority => 0}
          @@countries << {:iso_code => 28, :country_short_2 => "AG", :country_short_3 =>"ATG", :country_name => "Antigua and Barbuda", :list_priority => 0}
          @@countries << {:iso_code => 40, :country_short_2 => "AT", :country_short_3 =>"AUT", :country_name => "Austria", :list_priority => 0}
          @@countries << {:iso_code => 31, :country_short_2 => "AZ", :country_short_3 =>"AZE", :country_name => "Azerbaijan", :list_priority => 0}
          @@countries << {:iso_code => 108, :country_short_2 => "BI", :country_short_3 =>"BDI", :country_name => "Burundi", :list_priority => 0}
          @@countries << {:iso_code => 56, :country_short_2 => "BE", :country_short_3 =>"BEL", :country_name => "Belgium", :list_priority => 0}
          @@countries << {:iso_code => 204, :country_short_2 => "BJ", :country_short_3 =>"BEN", :country_name => "Benin", :list_priority => 0}
          @@countries << {:iso_code => 854, :country_short_2 => "BF", :country_short_3 =>"BFA", :country_name => "Burkina Faso", :list_priority => 0}
          @@countries << {:iso_code => 50, :country_short_2 => "BD", :country_short_3 =>"BGD", :country_name => "Bangladesh", :list_priority => 0}
          @@countries << {:iso_code => 100, :country_short_2 => "BG", :country_short_3 =>"BGR", :country_name => "Bulgaria", :list_priority => 0}
          @@countries << {:iso_code => 48, :country_short_2 => "BH", :country_short_3 =>"BHR", :country_name => "Bahrain", :list_priority => 0}
          @@countries << {:iso_code => 44, :country_short_2 => "BS", :country_short_3 =>"BHS", :country_name => "Bahamas", :list_priority => 0}
          @@countries << {:iso_code => 70, :country_short_2 => "BA", :country_short_3 =>"BIH", :country_name => "Bosnia and Herzegovina", :list_priority => 0}
          @@countries << {:iso_code => 652, :country_short_2 => "BL", :country_short_3 => "BLM", :country_name => "Saint Barthélemy", :list_priority => 0}
          @@countries << {:iso_code => 112, :country_short_2 => "BY", :country_short_3 =>"BLR", :country_name => "Belarus", :list_priority => 0}
          @@countries << {:iso_code => 84, :country_short_2 => "BZ", :country_short_3 =>"BLZ", :country_name => "Belize", :list_priority => 0}
          @@countries << {:iso_code => 60, :country_short_2 => "BM", :country_short_3 =>"BMU", :country_name => "Bermuda", :list_priority => 0}
          @@countries << {:iso_code => 68, :country_short_2 => "BO", :country_short_3 =>"BOL", :country_name => "Bolivia", :list_priority => 0}
          @@countries << {:iso_code => 76, :country_short_2 => "BR", :country_short_3 =>"BRA", :country_name => "Brazil", :list_priority => 0}
          @@countries << {:iso_code => 52, :country_short_2 => "BB", :country_short_3 =>"BRB", :country_name => "Barbados", :list_priority => 0}
          @@countries << {:iso_code => 96, :country_short_2 => "BN", :country_short_3 =>"BRN", :country_name => "Brunei Darussalam", :list_priority => 0}
          @@countries << {:iso_code => 64, :country_short_2 => "BT", :country_short_3 =>"BTN", :country_name => "Bhutan", :list_priority => 0}
          @@countries << {:iso_code => 74, :country_short_2 => "BV", :country_short_3 =>"BVT", :country_name => "Bouvet Island", :list_priority => 0}
          @@countries << {:iso_code => 72, :country_short_2 => "BW", :country_short_3 =>"BWA", :country_name => "Botswana", :list_priority => 0}
          @@countries << {:iso_code => 140, :country_short_2 => "CF", :country_short_3 =>"CAF", :country_name => "Central African Republic", :list_priority => 0}
          @@countries << {:iso_code => 166, :country_short_2 => "CC", :country_short_3 => "CCK", :country_name => "Cocos (Keeling}) Islands", :list_priority => 0}
          @@countries << {:iso_code => 756, :country_short_2 => "CH", :country_short_3 =>"CHE", :country_name => "Switzerland", :list_priority => 0}
          @@countries << {:iso_code => 152, :country_short_2 => "CL", :country_short_3 =>"CHL", :country_name => "Chile", :list_priority => 0}
          @@countries << {:iso_code => 156, :country_short_2 => "CN", :country_short_3 =>"CHN", :country_name => "China", :list_priority => 0}
          @@countries << {:iso_code => 384, :country_short_2 => "CI", :country_short_3 => "CIV", :country_name => "Côte d'Ivoire", :list_priority => 0}
          @@countries << {:iso_code => 120, :country_short_2 => "CM", :country_short_3 =>"CMR", :country_name => "Cameroon", :list_priority => 0}
          @@countries << {:iso_code => 180, :country_short_2 => "CD", :country_short_3 => "COD", :country_name => "Congo,  the Democratic Republic of the", :list_priority => 0}
          @@countries << {:iso_code => 178, :country_short_2 => "CG", :country_short_3 =>"COG", :country_name => "Congo", :list_priority => 0}
          @@countries << {:iso_code => 184, :country_short_2 => "CK", :country_short_3 =>"COK", :country_name => "Cook Islands", :list_priority => 0}
          @@countries << {:iso_code => 170, :country_short_2 => "CO", :country_short_3 =>"COL", :country_name => "Colombia", :list_priority => 0}
          @@countries << {:iso_code => 174, :country_short_2 => "KM", :country_short_3 =>"COM", :country_name => "Comoros", :list_priority => 0}
          @@countries << {:iso_code => 132, :country_short_2 => "CV", :country_short_3 =>"CPV", :country_name => "Cape Verde", :list_priority => 0}
          @@countries << {:iso_code => 188, :country_short_2 => "CR", :country_short_3 =>"CRI", :country_name => "Costa Rica", :list_priority => 0}
          @@countries << {:iso_code => 192, :country_short_2 => "CU", :country_short_3 =>"CUB", :country_name => "Cuba", :list_priority => 0}
          @@countries << {:iso_code => 162, :country_short_2 => "CX", :country_short_3 =>"CXR", :country_name => "Christmas Island", :list_priority => 0}
          @@countries << {:iso_code => 136, :country_short_2 => "KY", :country_short_3 =>"CYM", :country_name => "Cayman Islands", :list_priority => 0}
          @@countries << {:iso_code => 196, :country_short_2 => "CY", :country_short_3 =>"CYP", :country_name => "Cyprus", :list_priority => 0}
          @@countries << {:iso_code => 203, :country_short_2 => "CZ", :country_short_3 =>"CZE", :country_name => "Czech Republic", :list_priority => 0}
          @@countries << {:iso_code => 262, :country_short_2 => "DJ", :country_short_3 =>"DJI", :country_name => "Djibouti", :list_priority => 0}
          @@countries << {:iso_code => 212, :country_short_2 => "DM", :country_short_3 =>"DMA", :country_name => "Dominica", :list_priority => 0}
          @@countries << {:iso_code => 208, :country_short_2 => "DK", :country_short_3 =>"DNK", :country_name => "Denmark", :list_priority => 0}
          @@countries << {:iso_code => 214, :country_short_2 => "DO", :country_short_3 =>"DOM", :country_name => "Dominican Republic", :list_priority => 0}
          @@countries << {:iso_code => 12, :country_short_2 => "DZ", :country_short_3 =>"DZA", :country_name => "Algeria", :list_priority => 0}
          @@countries << {:iso_code => 218, :country_short_2 => "EC", :country_short_3 =>"ECU", :country_name => "Ecuador", :list_priority => 0}
          @@countries << {:iso_code => 818, :country_short_2 => "EG", :country_short_3 =>"EGY", :country_name => "Egypt", :list_priority => 0}
          @@countries << {:iso_code => 232, :country_short_2 => "ER", :country_short_3 =>"ERI", :country_name => "Eritrea", :list_priority => 0}
          @@countries << {:iso_code => 732, :country_short_2 => "EH", :country_short_3 =>"ESH", :country_name => "Western Sahara", :list_priority => 0}
          @@countries << {:iso_code => 724, :country_short_2 => "ES", :country_short_3 =>"ESP", :country_name => "Spain", :list_priority => 0}
          @@countries << {:iso_code => 233, :country_short_2 => "EE", :country_short_3 =>"EST", :country_name => "Estonia", :list_priority => 0}
          @@countries << {:iso_code => 231, :country_short_2 => "ET", :country_short_3 =>"ETH", :country_name => "Ethiopia", :list_priority => 0}
          @@countries << {:iso_code => 246, :country_short_2 => "FI", :country_short_3 =>"FIN", :country_name => "Finland", :list_priority => 0}
          @@countries << {:iso_code => 242, :country_short_2 => "FJ", :country_short_3 =>"FJI", :country_name => "Fiji", :list_priority => 0}
          @@countries << {:iso_code => 238, :country_short_2 => "FK", :country_short_3 => "FLK", :country_name => "Falkland Islands (Malvinas})", :list_priority => 0}
          @@countries << {:iso_code => 234, :country_short_2 => "FO", :country_short_3 =>"FRO", :country_name => "Faroe Islands", :list_priority => 0}
          @@countries << {:iso_code => 583, :country_short_2 => "FM", :country_short_3 =>"FSM", :country_name => "Micronesia Federated States of", :list_priority => 0}
          @@countries << {:iso_code => 266, :country_short_2 => "GA", :country_short_3 =>"GAB", :country_name => "Gabon", :list_priority => 0}
          @@countries << {:iso_code => 268, :country_short_2 => "GE", :country_short_3 =>"GEO", :country_name => "Georgia", :list_priority => 0}
          @@countries << {:iso_code => 831, :country_short_2 => "GG", :country_short_3 =>"GGY", :country_name => "Guernsey", :list_priority => 0}
          @@countries << {:iso_code => 288, :country_short_2 => "GH", :country_short_3 =>"GHA", :country_name => "Ghana", :list_priority => 0}
          @@countries << {:iso_code => 292, :country_short_2 => "GI", :country_short_3 =>"GIB", :country_name => "Gibraltar", :list_priority => 0}
          @@countries << {:iso_code => 324, :country_short_2 => "GN", :country_short_3 =>"GIN", :country_name => "Guinea", :list_priority => 0}
          @@countries << {:iso_code => 312, :country_short_2 => "GP", :country_short_3 =>"GLP", :country_name => "Guadeloupe", :list_priority => 0}
          @@countries << {:iso_code => 270, :country_short_2 => "GM", :country_short_3 =>"GMB", :country_name => "Gambia", :list_priority => 0}
          @@countries << {:iso_code => 624, :country_short_2 => "GW", :country_short_3 => "GNB", :country_name => "Guinea-Bissau", :list_priority => 0}
          @@countries << {:iso_code => 226, :country_short_2 => "GQ", :country_short_3 =>"GNQ", :country_name => "Equatorial Guinea", :list_priority => 0}
          @@countries << {:iso_code => 300, :country_short_2 => "GR", :country_short_3 =>"GRC", :country_name => "Greece", :list_priority => 0}
          @@countries << {:iso_code => 308, :country_short_2 => "GD", :country_short_3 =>"GRD", :country_name => "Grenada", :list_priority => 0}
          @@countries << {:iso_code => 304, :country_short_2 => "GL", :country_short_3 =>"GRL", :country_name => "Greenland", :list_priority => 0}
          @@countries << {:iso_code => 320, :country_short_2 => "GT", :country_short_3 =>"GTM", :country_name => "Guatemala", :list_priority => 0}
          @@countries << {:iso_code => 254, :country_short_2 => "GF", :country_short_3 =>"GUF", :country_name => "French Guiana", :list_priority => 0}
          @@countries << {:iso_code => 316, :country_short_2 => "GU", :country_short_3 =>"GUM", :country_name => "Guam", :list_priority => 0}
          @@countries << {:iso_code => 328, :country_short_2 => "GY", :country_short_3 =>"GUY", :country_name => "Guyana", :list_priority => 0}
          @@countries << {:iso_code => 344, :country_short_2 => "HK", :country_short_3 =>"HKG", :country_name => "Hong Kong", :list_priority => 0}
          @@countries << {:iso_code => 334, :country_short_2 => "HM", :country_short_3 =>"HMD", :country_name => "Heard Island and McDonald Islands", :list_priority => 0}
          @@countries << {:iso_code => 340, :country_short_2 => "HN", :country_short_3 =>"HND", :country_name => "Honduras", :list_priority => 0}
          @@countries << {:iso_code => 191, :country_short_2 => "HR", :country_short_3 =>"HRV", :country_name => "Croatia", :list_priority => 0}
          @@countries << {:iso_code => 332, :country_short_2 => "HT", :country_short_3 =>"HTI", :country_name => "Haiti", :list_priority => 0}
          @@countries << {:iso_code => 348, :country_short_2 => "HU", :country_short_3 =>"HUN", :country_name => "Hungary", :list_priority => 0}
          @@countries << {:iso_code => 360, :country_short_2 => "ID", :country_short_3 =>"IDN", :country_name => "Indonesia", :list_priority => 0}
          @@countries << {:iso_code => 833, :country_short_2 => "IM", :country_short_3 =>"IMN", :country_name => "Isle of Man", :list_priority => 0}
          @@countries << {:iso_code => 356, :country_short_2 => "IN", :country_short_3 =>"IND", :country_name => "India", :list_priority => 0}
          @@countries << {:iso_code => 86, :country_short_2 => "IO", :country_short_3 =>"IOT", :country_name => "British Indian Ocean Territory", :list_priority => 0}
          @@countries << {:iso_code => 372, :country_short_2 => "IE", :country_short_3 =>"IRL", :country_name => "Ireland", :list_priority => 0}
          @@countries << {:iso_code => 364, :country_short_2 => "IR", :country_short_3 =>"IRN", :country_name => "Iran Islamic Republic of", :list_priority => 0}
          @@countries << {:iso_code => 368, :country_short_2 => "IQ", :country_short_3 =>"IRQ", :country_name => "Iraq", :list_priority => 0}
          @@countries << {:iso_code => 352, :country_short_2 => "IS", :country_short_3 =>"ISL", :country_name => "Iceland", :list_priority => 0}
          @@countries << {:iso_code => 376, :country_short_2 => "IL", :country_short_3 =>"ISR", :country_name => "Israel", :list_priority => 0}
          @@countries << {:iso_code => 380, :country_short_2 => "IT", :country_short_3 =>"ITA", :country_name => "Italy", :list_priority => 0}
          @@countries << {:iso_code => 388, :country_short_2 => "JM", :country_short_3 =>"JAM", :country_name => "Jamaica", :list_priority => 0}
          @@countries << {:iso_code => 832, :country_short_2 => "JE", :country_short_3 =>"JEY", :country_name => "Jersey", :list_priority => 0}
          @@countries << {:iso_code => 400, :country_short_2 => "JO", :country_short_3 =>"JOR", :country_name => "Jordan", :list_priority => 0}
          @@countries << {:iso_code => 392, :country_short_2 => "JP", :country_short_3 =>"JPN", :country_name => "Japan", :list_priority => 0}
          @@countries << {:iso_code => 398, :country_short_2 => "KZ", :country_short_3 =>"KAZ", :country_name => "Kazakhstan", :list_priority => 0}
          @@countries << {:iso_code => 404, :country_short_2 => "KE", :country_short_3 =>"KEN", :country_name => "Kenya", :list_priority => 0}
          @@countries << {:iso_code => 417, :country_short_2 => "KG", :country_short_3 =>"KGZ", :country_name => "Kyrgyzstan", :list_priority => 0}
          @@countries << {:iso_code => 116, :country_short_2 => "KH", :country_short_3 =>"KHM", :country_name => "Cambodia", :list_priority => 0}
          @@countries << {:iso_code => 296, :country_short_2 => "KI", :country_short_3 =>"KIR", :country_name => "Kiribati", :list_priority => 0}
          @@countries << {:iso_code => 659, :country_short_2 => "KN", :country_short_3 =>"KNA", :country_name => "Saint Kitts and Nevis", :list_priority => 0}
          @@countries << {:iso_code => 410, :country_short_2 => "KR", :country_short_3 => "KOR", :country_name => "Korea, Republic of", :list_priority => 0}
          @@countries << {:iso_code => 414, :country_short_2 => "KW", :country_short_3 =>"KWT", :country_name => "Kuwait", :list_priority => 0}
          @@countries << {:iso_code => 418, :country_short_2 => "LA", :country_short_3 => "LAO", :country_name => "Lao People's Democratic Republic", :list_priority => 0}
          @@countries << {:iso_code => 422, :country_short_2 => "LB", :country_short_3 =>"LBN", :country_name => "Lebanon", :list_priority => 0}
          @@countries << {:iso_code => 430, :country_short_2 => "LR", :country_short_3 =>"LBR", :country_name => "Liberia", :list_priority => 0}
          @@countries << {:iso_code => 434, :country_short_2 => "LY", :country_short_3 =>"LBY", :country_name => "Libyan Arab Jamahiriya", :list_priority => 0}
          @@countries << {:iso_code => 662, :country_short_2 => "LC", :country_short_3 =>"LCA", :country_name => "Saint Lucia", :list_priority => 0}
          @@countries << {:iso_code => 438, :country_short_2 => "LI", :country_short_3 =>"LIE", :country_name => "Liechtenstein", :list_priority => 0}
          @@countries << {:iso_code => 144, :country_short_2 => "LK", :country_short_3 =>"LKA", :country_name => "Sri Lanka", :list_priority => 0}
          @@countries << {:iso_code => 426, :country_short_2 => "LS", :country_short_3 =>"LSO", :country_name => "Lesotho", :list_priority => 0}
          @@countries << {:iso_code => 440, :country_short_2 => "LT", :country_short_3 =>"LTU", :country_name => "Lithuania", :list_priority => 0}
          @@countries << {:iso_code => 442, :country_short_2 => "LU", :country_short_3 =>"LUX", :country_name => "Luxembourg", :list_priority => 0}
          @@countries << {:iso_code => 428, :country_short_2 => "LV", :country_short_3 =>"LVA", :country_name => "Latvia", :list_priority => 0}
          @@countries << {:iso_code => 446, :country_short_2 => "MO", :country_short_3 =>"MAC", :country_name => "Macao", :list_priority => 0}
          @@countries << {:iso_code => 663, :country_short_2 => "MF", :country_short_3 => "MAF", :country_name => "Saint Martin (French part})", :list_priority => 0}
          @@countries << {:iso_code => 504, :country_short_2 => "MA", :country_short_3 =>"MAR", :country_name => "Morocco", :list_priority => 0}
          @@countries << {:iso_code => 492, :country_short_2 => "MC", :country_short_3 =>"MCO", :country_name => "Monaco", :list_priority => 0}
          @@countries << {:iso_code => 498, :country_short_2 => "MD", :country_short_3 =>"MDA", :country_name => "Moldova", :list_priority => 0}
          @@countries << {:iso_code => 450, :country_short_2 => "MG", :country_short_3 =>"MDG", :country_name => "Madagascar", :list_priority => 0}
          @@countries << {:iso_code => 462, :country_short_2 => "MV", :country_short_3 =>"MDV", :country_name => "Maldives", :list_priority => 0}
          @@countries << {:iso_code => 484, :country_short_2 => "MX", :country_short_3 =>"MEX", :country_name => "Mexico", :list_priority => 0}
          @@countries << {:iso_code => 584, :country_short_2 => "MH", :country_short_3 =>"MHL", :country_name => "Marshall Islands", :list_priority => 0}
          @@countries << {:iso_code => 807, :country_short_2 => "MK", :country_short_3 => "MKD", :country_name => "Macedonia, the former Yugoslav Republic of", :list_priority => 0}
          @@countries << {:iso_code => 466, :country_short_2 => "ML", :country_short_3 =>"MLI", :country_name => "Mali", :list_priority => 0}
          @@countries << {:iso_code => 470, :country_short_2 => "MT", :country_short_3 =>"MLT", :country_name => "Malta", :list_priority => 0}
          @@countries << {:iso_code => 104, :country_short_2 => "MM", :country_short_3 =>"MMR", :country_name => "Myanmar", :list_priority => 0}
          @@countries << {:iso_code => 499, :country_short_2 => "ME", :country_short_3 =>"MNE", :country_name => "Montenegro", :list_priority => 0}
          @@countries << {:iso_code => 496, :country_short_2 => "MN", :country_short_3 =>"MNG", :country_name => "Mongolia", :list_priority => 0}
          @@countries << {:iso_code => 580, :country_short_2 => "MP", :country_short_3 =>"MNP", :country_name => "Northern Mariana Islands", :list_priority => 0}
          @@countries << {:iso_code => 508, :country_short_2 => "MZ", :country_short_3 =>"MOZ", :country_name => "Mozambique", :list_priority => 0}
          @@countries << {:iso_code => 478, :country_short_2 => "MR", :country_short_3 =>"MRT", :country_name => "Mauritania", :list_priority => 0}
          @@countries << {:iso_code => 500, :country_short_2 => "MS", :country_short_3 =>"MSR", :country_name => "Montserrat", :list_priority => 0}
          @@countries << {:iso_code => 474, :country_short_2 => "MQ", :country_short_3 =>"MTQ", :country_name => "Martinique", :list_priority => 0}
          @@countries << {:iso_code => 480, :country_short_2 => "MU", :country_short_3 =>"MUS", :country_name => "Mauritius", :list_priority => 0}
          @@countries << {:iso_code => 454, :country_short_2 => "MW", :country_short_3 =>"MWI", :country_name => "Malawi", :list_priority => 0}
          @@countries << {:iso_code => 458, :country_short_2 => "MY", :country_short_3 =>"MYS", :country_name => "Malaysia", :list_priority => 0}
          @@countries << {:iso_code => 175, :country_short_2 => "YT", :country_short_3 =>"MYT", :country_name => "Mayotte", :list_priority => 0}
          @@countries << {:iso_code => 516, :country_short_2 => "NA", :country_short_3 =>"NAM", :country_name => "Namibia", :list_priority => 0}
          @@countries << {:iso_code => 540, :country_short_2 => "NC", :country_short_3 =>"NCL", :country_name => "New Caledonia", :list_priority => 0}
          @@countries << {:iso_code => 562, :country_short_2 => "NE", :country_short_3 =>"NER", :country_name => "Niger", :list_priority => 0}
          @@countries << {:iso_code => 574, :country_short_2 => "NF", :country_short_3 =>"NFK", :country_name => "Norfolk Island", :list_priority => 0}
          @@countries << {:iso_code => 566, :country_short_2 => "NG", :country_short_3 =>"NGA", :country_name => "Nigeria", :list_priority => 0}
          @@countries << {:iso_code => 558, :country_short_2 => "NI", :country_short_3 =>"NIC", :country_name => "Nicaragua", :list_priority => 0}
          @@countries << {:iso_code => 570, :country_short_2 => "NU", :country_short_3 =>"NIU", :country_name => "Niue", :list_priority => 0}
          @@countries << {:iso_code => 528, :country_short_2 => "NL", :country_short_3 =>"NLD", :country_name => "Netherlands", :list_priority => 0}
          @@countries << {:iso_code => 578, :country_short_2 => "NO", :country_short_3 =>"NOR", :country_name => "Norway", :list_priority => 0}
          @@countries << {:iso_code => 524, :country_short_2 => "NP", :country_short_3 =>"NPL", :country_name => "Nepal", :list_priority => 0}
          @@countries << {:iso_code => 520, :country_short_2 => "NR", :country_short_3 =>"NRU", :country_name => "Nauru", :list_priority => 0}
          @@countries << {:iso_code => 554, :country_short_2 => "NZ", :country_short_3 =>"NZL", :country_name => "New Zealand", :list_priority => 0}
          @@countries << {:iso_code => 512, :country_short_2 => "OM", :country_short_3 =>"OMN", :country_name => "Oman", :list_priority => 0}
          @@countries << {:iso_code => 586, :country_short_2 => "PK", :country_short_3 =>"PAK", :country_name => "Pakistan", :list_priority => 0}
          @@countries << {:iso_code => 591, :country_short_2 => "PA", :country_short_3 =>"PAN", :country_name => "Panama", :list_priority => 0}
          @@countries << {:iso_code => 612, :country_short_2 => "PN", :country_short_3 =>"PCN", :country_name => "Pitcairn", :list_priority => 0}
          @@countries << {:iso_code => 604, :country_short_2 => "PE", :country_short_3 =>"PER", :country_name => "Peru", :list_priority => 0}
          @@countries << {:iso_code => 608, :country_short_2 => "PH", :country_short_3 =>"PHL", :country_name => "Philippines", :list_priority => 0}
          @@countries << {:iso_code => 585, :country_short_2 => "PW", :country_short_3 =>"PLW", :country_name => "Palau", :list_priority => 0}
          @@countries << {:iso_code => 598, :country_short_2 => "PG", :country_short_3 =>"PNG", :country_name => "Papua New Guinea", :list_priority => 0}
          @@countries << {:iso_code => 616, :country_short_2 => "PL", :country_short_3 =>"POL", :country_name => "Poland", :list_priority => 0}
          @@countries << {:iso_code => 630, :country_short_2 => "PR", :country_short_3 =>"PRI", :country_name => "Puerto Rico", :list_priority => 0}
          @@countries << {:iso_code => 408, :country_short_2 => "KP", :country_short_3 => "PRK", :country_name => "Korea, Democratic People's Republic of", :list_priority => 0}
          @@countries << {:iso_code => 620, :country_short_2 => "PT", :country_short_3 =>"PRT", :country_name => "Portugal", :list_priority => 0}
          @@countries << {:iso_code => 600, :country_short_2 => "PY", :country_short_3 =>"PRY", :country_name => "Paraguay", :list_priority => 0}
          @@countries << {:iso_code => 275, :country_short_2 => "PS", :country_short_3 => "PSE", :country_name => "Palestinian Territory,  Occupied", :list_priority => 0}
          @@countries << {:iso_code => 258, :country_short_2 => "PF", :country_short_3 =>"PYF", :country_name => "French Polynesia", :list_priority => 0}
          @@countries << {:iso_code => 634, :country_short_2 => "QA", :country_short_3 =>"QAT", :country_name => "Qatar", :list_priority => 0}
          @@countries << {:iso_code => 638, :country_short_2 => "RE", :country_short_3 => "REU", :country_name => "Réunion", :list_priority => 0}
          @@countries << {:iso_code => 642, :country_short_2 => "RO", :country_short_3 =>"ROU", :country_name => "Romania", :list_priority => 0}
          @@countries << {:iso_code => 643, :country_short_2 => "RU", :country_short_3 =>"RUS", :country_name => "Russian Federation", :list_priority => 0}
          @@countries << {:iso_code => 646, :country_short_2 => "RW", :country_short_3 =>"RWA", :country_name => "Rwanda", :list_priority => 0}
          @@countries << {:iso_code => 682, :country_short_2 => "SA", :country_short_3 =>"SAU", :country_name => "Saudi Arabia", :list_priority => 0}
          @@countries << {:iso_code => 736, :country_short_2 => "SD", :country_short_3 =>"SDN", :country_name => "Sudan", :list_priority => 0}
          @@countries << {:iso_code => 686, :country_short_2 => "SN", :country_short_3 =>"SEN", :country_name => "Senegal", :list_priority => 0}
          @@countries << {:iso_code => 702, :country_short_2 => "SG", :country_short_3 =>"SGP", :country_name => "Singapore", :list_priority => 0}
          @@countries << {:iso_code => 239, :country_short_2 => "GS", :country_short_3 =>"SGS", :country_name => "South Georgia and the South Sandwich Islands", :list_priority => 0}
          @@countries << {:iso_code => 654, :country_short_2 => "SH", :country_short_3 =>"SHN", :country_name => "Saint Helena", :list_priority => 0}
          @@countries << {:iso_code => 744, :country_short_2 => "SJ", :country_short_3 =>"SJM", :country_name => "Svalbard and Jan Mayen", :list_priority => 0}
          @@countries << {:iso_code => 90, :country_short_2 => "SB", :country_short_3 =>"SLB", :country_name => "Solomon Islands", :list_priority => 0}
          @@countries << {:iso_code => 694, :country_short_2 => "SL", :country_short_3 =>"SLE", :country_name => "Sierra Leone", :list_priority => 0}
          @@countries << {:iso_code => 222, :country_short_2 => "SV", :country_short_3 =>"SLV", :country_name => "El Salvador", :list_priority => 0}
          @@countries << {:iso_code => 674, :country_short_2 => "SM", :country_short_3 =>"SMR", :country_name => "San Marino", :list_priority => 0}
          @@countries << {:iso_code => 706, :country_short_2 => "SO", :country_short_3 =>"SOM", :country_name => "Somalia", :list_priority => 0}
          @@countries << {:iso_code => 666, :country_short_2 => "PM", :country_short_3 =>"SPM", :country_name => "Saint Pierre and Miquelon", :list_priority => 0}
          @@countries << {:iso_code => 688, :country_short_2 => "RS", :country_short_3 =>"SRB", :country_name => "Serbia", :list_priority => 0}
          @@countries << {:iso_code => 678, :country_short_2 => "ST", :country_short_3 =>"STP", :country_name => "Sao Tome and Principe", :list_priority => 0}
          @@countries << {:iso_code => 740, :country_short_2 => "SR", :country_short_3 =>"SUR", :country_name => "Suriname", :list_priority => 0}
          @@countries << {:iso_code => 703, :country_short_2 => "SK", :country_short_3 =>"SVK", :country_name => "Slovakia", :list_priority => 0}
          @@countries << {:iso_code => 705, :country_short_2 => "SI", :country_short_3 =>"SVN", :country_name => "Slovenia", :list_priority => 0}
          @@countries << {:iso_code => 752, :country_short_2 => "SE", :country_short_3 =>"SWE", :country_name => "Sweden", :list_priority => 0}
          @@countries << {:iso_code => 748, :country_short_2 => "SZ", :country_short_3 =>"SWZ", :country_name => "Swaziland", :list_priority => 0}
          @@countries << {:iso_code => 690, :country_short_2 => "SC", :country_short_3 =>"SYC", :country_name => "Seychelles", :list_priority => 0}
          @@countries << {:iso_code => 760, :country_short_2 => "SY", :country_short_3 =>"SYR", :country_name => "Syrian Arab Republic", :list_priority => 0}
          @@countries << {:iso_code => 796, :country_short_2 => "TC", :country_short_3 =>"TCA", :country_name => "Turks and Caicos Islands", :list_priority => 0}
          @@countries << {:iso_code => 148, :country_short_2 => "TD", :country_short_3 =>"TCD", :country_name => "Chad", :list_priority => 0}
          @@countries << {:iso_code => 768, :country_short_2 => "TG", :country_short_3 =>"TGO", :country_name => "Togo", :list_priority => 0}
          @@countries << {:iso_code => 764, :country_short_2 => "TH", :country_short_3 =>"THA", :country_name => "Thailand", :list_priority => 0}
          @@countries << {:iso_code => 762, :country_short_2 => "TJ", :country_short_3 =>"TJK", :country_name => "Tajikistan", :list_priority => 0}
          @@countries << {:iso_code => 772, :country_short_2 => "TK", :country_short_3 =>"TKL", :country_name => "Tokelau", :list_priority => 0}
          @@countries << {:iso_code => 795, :country_short_2 => "TM", :country_short_3 =>"TKM", :country_name => "Turkmenistan", :list_priority => 0}
          @@countries << {:iso_code => 626, :country_short_2 => "TL", :country_short_3 => "TLS", :country_name => "Timor-Leste", :list_priority => 0}
          @@countries << {:iso_code => 776, :country_short_2 => "TO", :country_short_3 =>"TON", :country_name => "Tonga", :list_priority => 0}
          @@countries << {:iso_code => 780, :country_short_2 => "TT", :country_short_3 =>"TTO", :country_name => "Trinidad and Tobago", :list_priority => 0}
          @@countries << {:iso_code => 788, :country_short_2 => "TN", :country_short_3 =>"TUN", :country_name => "Tunisia", :list_priority => 0}
          @@countries << {:iso_code => 792, :country_short_2 => "TR", :country_short_3 =>"TUR", :country_name => "Turkey", :list_priority => 0}
          @@countries << {:iso_code => 798, :country_short_2 => "TV", :country_short_3 =>"TUV", :country_name => "Tuvalu", :list_priority => 0}
          @@countries << {:iso_code => 158, :country_short_2 => "TW", :country_short_3 => "TWN", :country_name => "Taiwan, Province of China", :list_priority => 0}
          @@countries << {:iso_code => 834, :country_short_2 => "TZ", :country_short_3 => "TZA", :country_name => "Tanzania, United Republic of", :list_priority => 0}
          @@countries << {:iso_code => 800, :country_short_2 => "UG", :country_short_3 =>"UGA", :country_name => "Uganda", :list_priority => 0}
          @@countries << {:iso_code => 804, :country_short_2 => "UA", :country_short_3 =>"UKR", :country_name => "Ukraine", :list_priority => 0}
          @@countries << {:iso_code => 581, :country_short_2 => "UM", :country_short_3 =>"UMI", :country_name => "United States Minor Outlying Islands", :list_priority => 0}
          @@countries << {:iso_code => 858, :country_short_2 => "UY", :country_short_3 =>"URY", :country_name => "Uruguay", :list_priority => 0}
          @@countries << {:iso_code => 860, :country_short_2 => "UZ", :country_short_3 =>"UZB", :country_name => "Uzbekistan", :list_priority => 0}
          @@countries << {:iso_code => 336, :country_short_2 => "VA", :country_short_3 => "VAT", :country_name => "Holy See (Vatican City State})", :list_priority => 0}
          @@countries << {:iso_code => 670, :country_short_2 => "VC", :country_short_3 =>"VCT", :country_name => "Saint Vincent and the Grenadines", :list_priority => 0}
          @@countries << {:iso_code => 862, :country_short_2 => "VE", :country_short_3 =>"VEN", :country_name => "Venezuela", :list_priority => 0}
          @@countries << {:iso_code => 92, :country_short_2 => "VG", :country_short_3 => "VGB", :country_name => "Virgin Islands, British", :list_priority => 0}
          @@countries << {:iso_code => 850, :country_short_2 => "VI", :country_short_3 => "VIR", :country_name => "Virgin Islands, U.S.", :list_priority => 0}
          @@countries << {:iso_code => 704, :country_short_2 => "VN", :country_short_3 =>"VNM", :country_name => "Viet Nam", :list_priority => 0}
          @@countries << {:iso_code => 548, :country_short_2 => "VU", :country_short_3 =>"VUT", :country_name => "Vanuatu", :list_priority => 0}
          @@countries << {:iso_code => 876, :country_short_2 => "WF", :country_short_3 =>"WLF", :country_name => "Wallis And Futuna", :list_priority => 0}
          @@countries << {:iso_code => 882, :country_short_2 => "WS", :country_short_3 =>"WSM", :country_name => "Samoa", :list_priority => 0}
          @@countries << {:iso_code => 887, :country_short_2 => "YE", :country_short_3 =>"YEM", :country_name => "Yemen", :list_priority => 0}
          @@countries << {:iso_code => 710, :country_short_2 => "ZA", :country_short_3 =>"ZAF", :country_name => "South Africa", :list_priority => 0}
          @@countries << {:iso_code => 894, :country_short_2 => "ZM", :country_short_3 =>"ZMB", :country_name => "Zambia", :list_priority => 0}
          @@countries << {:iso_code => 826, :country_short_2 => "ZW", :country_short_3 =>"ZWE", :country_name => "Zimbabwe", :list_priority => 0}
          @@countries << {:iso_code => 535, :country_short_2 => "BQ", :country_short_3 => "BES", :country_name => "Bonaire, Sint Eustatius and Saba", :list_priority => 0}
          @@countries << {:iso_code => 531, :country_short_2 => "CW", :country_short_3 => "CUW", :country_name => "Curaçao", :list_priority => 0}
          @@countries << {:iso_code => 534, :country_short_2 => "SX", :country_short_3 => "SXM", :country_name => "Sint Maarten (Dutch part})", :list_priority => 0}
          @@countries << {:iso_code => 728, :country_short_2 => "SS", :country_short_3 =>"SSD", :country_name => "South Sudan", :list_priority => 0}
          
          
          def self.get_ISO_code_from_2_digit_short(country_short_2)
            @@countries.each do |country|
              if(country[:country_short_2] == country_short_2)
                return country[:iso_code]
              end
            end
            return 826
          end
        end
      end
    end
  end
end
