module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CamsGateway < Gateway
      self.live_url = "https://secure.centralams.com/gw/api/transact.php"

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://www.centralams.com/'
      self.display_name = 'CAMS: Central Account Management System'

      STANDARD_ERROR_CODE_MAPPING = {
        '200' => STANDARD_ERROR_CODE[:card_declined],
        '201' => STANDARD_ERROR_CODE[:card_declined],
        '202' => STANDARD_ERROR_CODE[:card_declined],
        '203' => STANDARD_ERROR_CODE[:card_declined],
        '204' => STANDARD_ERROR_CODE[:card_declined],
        '220' => STANDARD_ERROR_CODE[:card_declined],
        '221' => STANDARD_ERROR_CODE[:card_declined],
        '222' => STANDARD_ERROR_CODE[:incorrect_number],
        '223' => STANDARD_ERROR_CODE[:expired_card],
        '224' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        '225' => STANDARD_ERROR_CODE[:invalid_cvc],
        '240' => STANDARD_ERROR_CODE[:call_issuer],
        '250' => STANDARD_ERROR_CODE[:pickup_card],
        '251' => STANDARD_ERROR_CODE[:pickup_card],
        '252' => STANDARD_ERROR_CODE[:pickup_card],
        '253' => STANDARD_ERROR_CODE[:pickup_card],
        '260' => STANDARD_ERROR_CODE[:card_declined],
        '261' => STANDARD_ERROR_CODE[:card_declined],
        '262' => STANDARD_ERROR_CODE[:card_declined],
        '263' => STANDARD_ERROR_CODE[:processing_error],
        '264' => STANDARD_ERROR_CODE[:card_declined],
        '300' => STANDARD_ERROR_CODE[:card_declined],
        '400' => STANDARD_ERROR_CODE[:processing_error],
        '410' => STANDARD_ERROR_CODE[:processing_error],
        '411' => STANDARD_ERROR_CODE[:processing_error],
        '420' => STANDARD_ERROR_CODE[:processing_error],
        '421' => STANDARD_ERROR_CODE[:processing_error],
        '430' => STANDARD_ERROR_CODE[:processing_error],
        '440' => STANDARD_ERROR_CODE[:processing_error],
        '441' => STANDARD_ERROR_CODE[:processing_error],
        '460' => STANDARD_ERROR_CODE[:invalid_number],
        '461' => STANDARD_ERROR_CODE[:processing_error],
        '801' => STANDARD_ERROR_CODE[:processing_error],
        '811' => STANDARD_ERROR_CODE[:processing_error],
        '812' => STANDARD_ERROR_CODE[:processing_error],
        '813' => STANDARD_ERROR_CODE[:processing_error],
        '814' => STANDARD_ERROR_CODE[:processing_error],
        '815' => STANDARD_ERROR_CODE[:processing_error],
        '823' => STANDARD_ERROR_CODE[:processing_error],
        '824' => STANDARD_ERROR_CODE[:processing_error],
        '881' => STANDARD_ERROR_CODE[:processing_error],
        '882' => STANDARD_ERROR_CODE[:processing_error],
        '883' => STANDARD_ERROR_CODE[:processing_error],
        '884' => STANDARD_ERROR_CODE[:card_declined],
        '885' => STANDARD_ERROR_CODE[:card_declined],
        '886' => STANDARD_ERROR_CODE[:card_declined],
        '887' => STANDARD_ERROR_CODE[:processing_error],
        '888' => STANDARD_ERROR_CODE[:processing_error],
        '889' => STANDARD_ERROR_CODE[:processing_error],
        '890' => STANDARD_ERROR_CODE[:processing_error],
        '891' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '892' => STANDARD_ERROR_CODE[:incorrect_cvc],
        '893' => STANDARD_ERROR_CODE[:processing_error],
        '894' => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options={})
        requires!(options, :username, :password)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)

        if payment.respond_to?(:number)
          add_payment(post, payment)
          add_address(post, payment, options)
        elsif payment.kind_of?(String)
          post[:transactionid] = split_authorization(payment)[0]
        end

        commit("sale", post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)

        commit('auth', post)
      end

      def capture(money, authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_invoice(post, money, options)

        commit('capture', post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_reference(post, authorization)
        add_invoice(post, money, options)
        commit('refund', post)
      end

      def void(authorization, options={})
        post = {}
        add_reference(post, authorization)
        commit('void', post)
      end

      def verify(credit_card, options={})
        post = {}
        add_invoice(post, 0, options)
        add_payment(post, credit_card)
        add_address(post, credit_card, options)
        commit('verify', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        %w(ccnumber cvv password).each do |field|
          transcript = transcript.gsub(%r((#{field}=)[^&]+), '\1[FILTERED]\2')
        end

        transcript
      end

      private

      def add_address(post, creditcard, options={})
        post[:firstname] = creditcard.first_name
        post[:lastname ] = creditcard.last_name

        return unless options[:billing_address]

        address = options[:billing_address]
        post[:address1 ] = address[:address1]
        post[:address2 ] = address[:address2]
        post[:city     ] = address[:city]
        post[:state    ] = address[:state]
        post[:zip      ] = address[:zip]
        post[:country  ] = address[:country]
        post[:phone    ] = address[:phone]
      end

      def add_reference(post, authorization)
        transaction_id, authcode = split_authorization(authorization)
        post["transactionid"] = transaction_id
        post["authcode"]      = authcode
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || default_currency)
      end

      def add_payment(post, payment)
        post[:ccnumber] = payment.number
        post[:ccexp   ] = "#{payment.month.to_s.rjust(2,"0")}#{payment.year.to_s[-2..-1]}"
        post[:cvv     ] = payment.verification_value
      end

      def parse(body)
        kvs = body.split("&")

        kvs.inject({}) { |h, kv|
          k,v = kv.split("=")
          h[k] = v
          h
        }
      end

      def commit(action, parameters)
        url = live_url
        parameters[:type] = action

        response_body = ssl_post(url, post_data(parameters))
        response = parse(response_body)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response["response_code"] == "100"
      end

      def message_from(response)
        response["responsetext"]
      end

      def authorization_from(response)
        [response["transactionid"], response["authcode"]].join("#")
      end

      def split_authorization(authorization)
        transaction_id, authcode = authorization.split("#")
        [transaction_id, authcode]
      end

      def post_data(parameters = {})
        parameters[:password] = @options[:password]
        parameters[:username] = @options[:username]

        parameters.collect{|k,v| "#{k}=#{v}" }.join("&")
      end

      def error_code_from(response)
        STANDARD_ERROR_CODE_MAPPING[response["response_code"]]
      end
    end
  end
end
