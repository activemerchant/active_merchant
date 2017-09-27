module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardStreamGateway < Gateway

      THREEDSECURE_REQUIRED_DEPRECATION_MESSAGE = "Specifying the :threeDSRequired initialization option is deprecated. Please use the `:threeds_required => true` *transaction* option instead."

      self.test_url = self.live_url = 'https://gateway.cardstream.com/direct/'
      self.money_format = :cents
      self.default_currency = 'GBP'
      self.supported_countries = ['GB', 'US', 'CH', 'SE', 'SG', 'NO', 'JP', 'IS', 'HK', 'NL', 'CZ', 'CA', 'AU']
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club, :discover, :jcb, :maestro, :solo, :switch]
      self.homepage_url = 'http://www.cardstream.com/'
      self.display_name = 'CardStream'

      CURRENCY_CODES = {
        "AED" => "784",
        "ALL" => "008",
        "AMD" => "051",
        "ANG" => "532",
        "ARS" => "032",
        "AUD" => "036",
        "AWG" => "533",
        "BAM" => "977",
        "BBD" => "052",
        "BGN" => "975",
        "BMD" => "060",
        "BOB" => "068",
        "BRL" => "986",
        "BSD" => "044",
        "BWP" => "072",
        "BZD" => "084",
        "CAD" => "124",
        "CHF" => "756",
        "CLP" => "152",
        "CNY" => "156",
        "COP" => "170",
        "CRC" => "188",
        "CZK" => "203",
        "DKK" => "208",
        "DOP" => "214",
        "EGP" => "818",
        "EUR" => "978",
        "GBP" => "826",
        "GEL" => "981",
        "GIP" => "292",
        "GTQ" => "320",
        "GYD" => "328",
        "HKD" => "344",
        "HNL" => "340",
        "HRK" => "191",
        "HUF" => "348",
        "ISK" => "352",
        "IDR" => "360",
        "ILS" => "376",
        "INR" => "356",
        "JPY" => "392",
        "JMD" => "388",
        "KES" => "404",
        "KRW" => "410",
        "KYD" => "136",
        "LBP" => "422",
        "LKR" => "144",
        "MAD" => "504",
        "MVR" => "462",
        "MWK" => "454",
        "MXN" => "484",
        "MYR" => "458",
        "NAD" => "516",
        "NGN" => "566",
        "NIO" => "558",
        "NOK" => "578",
        "NPR" => "524",
        "NZD" => "554",
        "PAB" => "590",
        "PEN" => "604",
        "PGK" => "598",
        "PHP" => "608",
        "PKR" => "586",
        "PLN" => "985",
        "PYG" => "600",
        "QAR" => "634",
        "RON" => "946",
        "RSD" => "941",
        "RUB" => "643",
        "RWF" => "646",
        "SAR" => "682",
        "SEK" => "752",
        "SGD" => "702",
        "SRD" => "968",
        "THB" => "764",
        "TND" => "788",
        "TRY" => "949",
        "TTD" => "780",
        "TWD" => "901",
        "TZS" => "834",
        "UAH" => "980",
        "UGX" => "800",
        "USD" => "840",
        "UYU" => "858",
        "VND" => "704",
        "WST" => "882",
        "XAF" => "950",
        "XCD" => "951",
        "XOF" => "952",
        "ZAR" => "710"
      }

      CVV_CODE = {
        '0' => 'U',
        '1' => 'P',
        '2' => 'M',
        '4' => 'N'
      }

      # 0 - No additional information available.
      # 1 - Postcode not checked.
      # 2 - Postcode matched.
      # 4 - Postcode not matched.
      # 8 - Postcode partially matched.
      AVS_POSTAL_MATCH = {
        "0" => nil,
        "1" => nil,
        "2" => "Y",
        "4" => "N",
        "8" => "N"
      }

      # 0 - No additional information available.
      # 1 - Address numeric not checked.
      # 2 - Address numeric matched.
      # 4 - Address numeric not matched.
      # 8 - Address numeric partially matched.
      AVS_STREET_MATCH = {
        "0" => nil,
        "1" => nil,
        "2" => "Y",
        "4" => "N",
        "8" => "N"
      }

      def initialize(options = {})
        requires!(options, :login, :shared_secret)
        @threeds_required = false
        if (options[:threeDSRequired])
          ActiveMerchant.deprecated(THREEDSECURE_REQUIRED_DEPRECATION_MESSAGE)
          @threeds_required = options[:threeDSRequired]
        end
        super
      end

      def authorize(money, credit_card_or_reference, options = {})
        post = {}
        add_pair(post, :captureDelay, -1)
        add_amount(post, money, options)
        add_invoice(post, credit_card_or_reference, money, options)
        add_credit_card_or_reference(post, credit_card_or_reference)
        add_customer_data(post, options)
        commit('SALE', post)
      end

      def purchase(money, credit_card_or_reference, options = {})
        post = {}
        add_pair(post, :captureDelay, 0)
        add_amount(post, money, options)
        add_invoice(post, credit_card_or_reference, money, options)
        add_credit_card_or_reference(post, credit_card_or_reference)
        add_customer_data(post, options)
        commit('SALE', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_pair(post, :xref, authorization)
        add_pair(post, :amount, amount(money), :required => true)

        commit('CAPTURE', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_pair(post, :xref, authorization)
        add_amount(post, money, options)
        commit('REFUND', post)
      end

      def void(authorization, options = {})
        post = {}
        add_pair(post, :xref, authorization)
        commit('CANCEL', post)
      end

      def verify(creditcard, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, creditcard, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((cardNumber=)\d+), '\1[FILTERED]').
          gsub(%r((CVV=)\d+), '\1[FILTERED]')
      end

      private

      def add_amount(post, money, options)
        add_pair(post, :amount, amount(money), :required => true)
        add_pair(post, :currencyCode, currency_code(options[:currency] || currency(money)))
      end

      def add_customer_data(post, options)
        add_pair(post, :customerEmail, options[:email])
        if (address = options[:billing_address] || options[:address])
          add_pair(post, :customerAddress, "#{address[:address1]} #{address[:address2]}".strip)
          add_pair(post, :customerPostCode, address[:zip])
          add_pair(post, :customerPhone, options[:phone])
        end
      end

      def add_invoice(post, credit_card_or_reference, money, options)
        add_pair(post, :transactionUnique, options[:order_id], :required => true)
        add_pair(post, :orderRef, options[:description] || options[:order_id], :required => true)
        add_pair(post, :statementNarrative1, options[:merchant_name]) if options[:merchant_name]
        add_pair(post, :statementNarrative2, options[:dynamic_descriptor]) if options[:dynamic_descriptor]
        if credit_card_or_reference.respond_to?(:number)
          if ['american_express', 'diners_club'].include?(card_brand(credit_card_or_reference).to_s)
            add_pair(post, :item1Quantity, 1)
            add_pair(post, :item1Description, (options[:description] || options[:order_id]).slice(0, 15))
            add_pair(post, :item1GrossValue, amount(money))
          end
        end

        add_pair(post, :type, options[:type] || '1')
        add_threeds_required(post, options)
      end

      def add_credit_card_or_reference(post, credit_card_or_reference)
        if credit_card_or_reference.respond_to?(:number)
          add_credit_card(post, credit_card_or_reference)
        else
          add_reference(post, credit_card_or_reference.to_s)
        end
      end

      def add_reference(post, reference)
        add_pair(post, :xref, reference, :required => true)
      end

      def add_credit_card(post, credit_card)
        add_pair(post, :customerName, credit_card.name, :required => true)
        add_pair(post, :cardNumber, credit_card.number, :required => true)

        add_pair(post, :cardExpiryMonth, format(credit_card.month, :two_digits), :required => true)
        add_pair(post, :cardExpiryYear, format(credit_card.year, :two_digits), :required => true)

        if requires_start_date_or_issue_number?(credit_card)
          add_pair(post, :cardStartMonth, format(credit_card.start_month, :two_digits))
          add_pair(post, :cardStartYear, format(credit_card.start_year, :two_digits))

          add_pair(post, :cardIssueNumber, credit_card.issue_number)
        end

        add_pair(post, :cardCVV, credit_card.verification_value)
      end

      def add_threeds_required(post, options)
        add_pair(post, :threeDSRequired, (options[:threeds_required] || @threeds_required) ? 'Y' : 'N')
      end

      def normalize_line_endings(str)
        str.gsub(/%0D%0A|%0A%0D|%0D/, "%0A")
      end

      def add_hmac(post)
        result = post.sort.collect { |key, value| "#{key}=#{normalize_line_endings(CGI.escape(value.to_s))}" }.join("&")
        result = Digest::SHA512.hexdigest("#{result}#{@options[:shared_secret]}")

        add_pair(post, :signature, result)
      end

      def parse(body)
        result = {}
        pairs = body.split("&")
        pairs.each do |pair|
          a = pair.split("=")
          # because some value pairs don't have a value
          result[a[0].to_sym] = a[1] == nil ? '' : CGI.unescape(a[1])
        end
        result
      end

      def commit(action, parameters)
        parameters.update(:countryCode => self.supported_countries[0]) unless ['CAPTURE', 'CANCEL'].include?(action)
        parameters.update(
          :merchantID => @options[:login],
          :action => action
        )
        # adds a signature to the post hash/array
        add_hmac(parameters)

        response = parse(ssl_post(self.live_url, post_data(action, parameters)))

        Response.new(response[:responseCode] == "0",
                     response[:responseCode] == "0" ? "APPROVED" : response[:responseMessage],
                     response,
                     :test => test?,
                     :authorization => response[:xref],
                     :cvv_result => CVV_CODE[response[:avscv2ResponseCode].to_s[0, 1]],
                     :avs_result => avs_from(response)
        )
      end

      def avs_from(response)
        postal_match = AVS_POSTAL_MATCH[response[:avscv2ResponseCode].to_s[1, 1]]
        street_match = AVS_STREET_MATCH[response[:avscv2ResponseCode].to_s[2, 1]]

        code = if postal_match == "Y" && street_match == "Y"
          "M"
        elsif postal_match == "Y"
          "P"
        elsif street_match == "Y"
          "A"
        else
          "I"
        end

        AVSResult.new({
          :code => code,
          :postal_match => postal_match,
          :street_match => street_match
        })
      end


      def currency_code(currency)
        CURRENCY_CODES[currency]
      end

      def post_data(action, parameters = {})
        parameters.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      def add_pair(post, key, value, options = {})
        post[key] = value if !value.blank? || options[:required]
      end

    end
  end
end
