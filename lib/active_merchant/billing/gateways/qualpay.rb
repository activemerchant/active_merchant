module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class QualpayGateway < Gateway
      self.test_url = 'https://api-test.qualpay.com/pg'
      self.live_url = 'https://api.qualpay.com/pg'

      self.supported_countries = [
          "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AZ", "BA", "BB",
          "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BM", "BN", "BO", "BQ", "BR", "BS", "BT", "BV", "BW", "BY", "BZ",
          "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CW", "CX", "CY",
          "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE", "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM",
          "FO", "FR", "GA", "GB", "GD", "GE", "GF", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT",
          "GU", "GW", "GY", "HK", "HM", "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IN", "IO", "IQ", "IR", "IS", "IT",
          "JM", "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC", "LI",
          "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MG", "MH", "MK", "ML", "MM", "MN", "MO",
          "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI", "NL",
          "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT",
          "PW", "PY", "QA", "RE", "RS", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ",
          "SK", "SL", "SM", "SN", "SO", "SR", "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK",
          "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE",
          "VG", "VI", "VN", "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"]

      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.money_format = :dollars

      self.homepage_url = 'https://www.qualpay.com/index'
      self.display_name = 'Qualpay'

      CURRENCY_CODES = {
          'AED' => '784', 'AFN' => '971', 'ALL' => '008', 'AMD' => '051', 'ANG' => '532', 'AOA' => '973', 'ARS' => '032',
          'AUD' => '036', 'AWG' => '533', 'BAM' => '977', 'BBD' => '052', 'BDT' => '050', 'BGN' => '975', 'BHD' => '048',
          'BIF' => '108', 'BMD' => '060', 'BND' => '096', 'BOB' => '068', 'BRL' => '986', 'BSD' => '044', 'BTN' => '064',
          'BWP' => '072', 'BZD' => '084', 'CAD' => '124', 'CDF' => '976', 'CHF' => '756', 'CLP' => '152', 'CNY' => '156',
          'COP' => '170', 'CRC' => '188', 'CUP' => '192', 'CVE' => '132', 'CZK' => '203', 'DJF' => '262', 'DKK' => '208',
          'DOP' => '214', 'DZD' => '012', 'EGP' => '818', 'ERN' => '232', 'ETB' => '230', 'EUR' => '978', 'FJD' => '242',
          'FKP' => '238', 'GBP' => '826', 'GEL' => '981', 'GHS' => '936', 'GIP' => '292', 'GMD' => '270', 'GNF' => '324',
          'GTQ' => '320', 'GYD' => '328', 'HKD' => '344', 'HNL' => '340', 'HRK' => '191', 'HTG' => '332', 'HUF' => '348',
          'IDR' => '360', 'ILS' => '376', 'INR' => '356', 'IQD' => '368', 'IRR' => '364', 'ISK' => '352', 'JMD' => '388',
          'JOD' => '400', 'JPY' => '392', 'KES' => '404', 'KGS' => '417', 'KHR' => '116', 'KMF' => '174', 'KPW' => '408',
          'KRW' => '410', 'KWD' => '414', 'KYD' => '136', 'KZT' => '398', 'LAK' => '418', 'LBP' => '422', 'LKR' => '144',
          'LRD' => '430', 'LSL' => '426', 'LYD' => '434', 'MAD' => '504', 'MDL' => '498', 'MGA' => '969', 'MKD' => '807',
          'MMK' => '104', 'MNT' => '496', 'MOP' => '446', 'MRO' => '478', 'MUR' => '480', 'MVR' => '462', 'MWK' => '454',
          'MXN' => '484', 'MYR' => '458', 'MZN' => '943', 'NAD' => '516', 'NGN' => '566', 'NIO' => '558', 'NOK' => '578',
          'NPR' => '524', 'NZD' => '554', 'OMR' => '512', 'PAB' => '590', 'PEN' => '604', 'PGK' => '598', 'PHP' => '608',
          'PKR' => '586', 'PLN' => '985', 'PYG' => '600', 'QAR' => '634', 'RON' => '946', 'RSD' => '941', 'RUB' => '643',
          'RWF' => '646', 'SAR' => '682', 'SBD' => '090', 'SCR' => '690', 'SEK' => '752', 'SGD' => '702', 'SHP' => '654',
          'SLL' => '694', 'SOS' => '706', 'SRD' => '968', 'STD' => '678', 'SVC' => '222', 'SYP' => '760', 'SZL' => '748',
          'THB' => '764', 'TJS' => '972', 'TMT' => '934', 'TND' => '788', 'TOP' => '776', 'TRY' => '949', 'TTD' => '780',
          'TWD' => '901', 'TZS' => '834', 'UAH' => '980', 'UGX' => '800', 'USD' => '840', 'UYU' => '858', 'UZS' => '860',
          'VEF' => '937', 'VND' => '704', 'VUV' => '548', 'WST' => '882', 'XAF' => '950', 'XCD' => '951', 'XOF' => '952',
          'XPF' => '953', 'YER' => '886', 'ZAR' => '710', 'ZMW' => '967'
      }

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :merchant_id, :security_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit('sale', post, "Approved")
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit('auth', post, "Approved")
      end

      def capture(money, authorization, options={})
        post = { pg_id: authorization }
        add_invoice(post, money, options)
        commit("capture", post, "Capture request accepted")
      end

      def refund(money, authorization, options={})
        post = { pg_id: authorization }
        add_invoice(post, money, options)
        commit("refund", post, "Refund request accepted")
      end

      def void(authorization, options={})
        post = { pg_id: authorization }
        commit("void", post, "Transaction voided")
      end

      def verify(payment, options={})
        post = {}
        add_payment(post, payment)
        add_customer_data(post, options)
        commit('verify', post, "No reason to decline")
      end

      def credit(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)
        commit('credit', post, "Credit transaction accepted")
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
            gsub(%r((card_number\\":\\")\d+), '\1[FILTERED]\2').
            gsub(%r((security_key\\":\\")[\w]+), '\1[FILTERED]\2').
            gsub(%r((cvv2\\":\\")\d+), '\1[FILTERED]\2')
      end

      private

      def add_customer_data(post, options)
        if(billing_address = options[:billing_address] || options[:address])
          post[:avs_address] = billing_address[:address1]
          post[:avs_zip]    = billing_address[:zip]
        end
      end

      def add_invoice(post, money, options)
        post[:amt_tran] = amount(money)
        post[:amt_tax] = options[:tax] if options[:tax].present?
        currency = (options[:currency] || currency(money))
        post[:tran_currency] = CURRENCY_CODES[currency] if currency.present?
        post[:purchase_id] = options[:order_id] if options[:order_id].present?
        cust_id = options[:customer_id] || options[:customer]
        post[:customer_code] = cust_id if cust_id.present?
        post[:merch_ref_num] = options[:description] if options[:description].present?
      end

      def add_payment(post, payment)
        post[:card_number] = payment.number
        post[:exp_date] = exp_date(payment)
        post[:cardholder_name] = payment.name
        post[:cvv2] = payment.verification_value unless payment.verification_value.blank?
      end

      def exp_date(payment)
        "#{format(payment.month, :two_digits)}#{format(payment.year, :two_digits)}"
      end

      def parse(body)
        begin
          response = JSON.parse(body)
        rescue
          response = {}
        end

        response
      end

      def commit(action, parameters, successful_text)
        url = "#{(test? ? test_url : live_url)}/#{action}#{parameters[:pg_id].present? ? "/#{parameters[:pg_id]}" : '' }"
        parameters = parameters.merge(@options)

        begin
          raw_response = ssl_post(url, post_data(action, parameters), headers)
          response = parse(raw_response)
        rescue ResponseError => e
          raise unless(e.response.code.to_s =~ /4\d\d/)
          response = parse(e.response.body)
        end

        succeeded = success_from(response, successful_text)

        Response.new(
          succeeded,
          message_from(succeeded, response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["auth_avs_result"]),
          cvv_result: CVVResult.new(response["auth_cvv2_result"]),
          test: test?,
          error_code: error_code_from(response, successful_text)
        )
      end

      def headers
        { "Content-Type"  => "application/json" }
      end

      def success_from(response, successful_text)
        response["rmsg"].present? && response["rmsg"].include?(successful_text)
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          response["rmsg"]
        end
      end

      def authorization_from(response)
        response["pg_id"]
      end

      def post_data(action, parameters = {})
        parameters[:developer_id] = "ActiveMerchant"
        parameters.to_json
      end

      def error_code_from(response, successful_text)
        unless success_from(response, successful_text)
          response["rcode"]
        end
      end
    end
  end
end
