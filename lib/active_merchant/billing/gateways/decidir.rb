module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DecidirGateway < Gateway
      self.test_url = 'https://developers.decidir.com/api/v2'
      self.live_url = 'https://live.decidir.com/api/v2'

      self.supported_countries = ['AR']
      self.money_format = :cents
      self.default_currency = 'ARS'
      self.supported_cardtypes = %i[visa master american_express diners_club naranja cabal]

      self.homepage_url = 'http://www.decidir.com'
      self.display_name = 'Decidir'

      STANDARD_ERROR_CODE_MAPPING = {
        1 => STANDARD_ERROR_CODE[:call_issuer],
        2 => STANDARD_ERROR_CODE[:call_issuer],
        3 => STANDARD_ERROR_CODE[:config_error],
        4 => STANDARD_ERROR_CODE[:pickup_card],
        5 => STANDARD_ERROR_CODE[:card_declined],
        7 => STANDARD_ERROR_CODE[:pickup_card],
        12 => STANDARD_ERROR_CODE[:processing_error],
        14 => STANDARD_ERROR_CODE[:invalid_number],
        28 => STANDARD_ERROR_CODE[:processing_error],
        38 => STANDARD_ERROR_CODE[:incorrect_pin],
        39 => STANDARD_ERROR_CODE[:invalid_number],
        43 => STANDARD_ERROR_CODE[:pickup_card],
        45 => STANDARD_ERROR_CODE[:card_declined],
        46 => STANDARD_ERROR_CODE[:invalid_number],
        47 => STANDARD_ERROR_CODE[:card_declined],
        48 => STANDARD_ERROR_CODE[:card_declined],
        49 => STANDARD_ERROR_CODE[:invalid_expiry_date],
        51 => STANDARD_ERROR_CODE[:card_declined],
        53 => STANDARD_ERROR_CODE[:card_declined],
        54 => STANDARD_ERROR_CODE[:expired_card],
        55 => STANDARD_ERROR_CODE[:incorrect_pin],
        56 => STANDARD_ERROR_CODE[:card_declined],
        57 => STANDARD_ERROR_CODE[:card_declined],
        76 => STANDARD_ERROR_CODE[:call_issuer],
        91 => STANDARD_ERROR_CODE[:call_issuer],
        96 => STANDARD_ERROR_CODE[:processing_error],
        97 => STANDARD_ERROR_CODE[:processing_error]
      }

      def initialize(options={})
        requires!(options, :api_key)
        super
        @options[:preauth_mode] ||= false
      end

      def purchase(money, payment, options={})
        raise ArgumentError, 'Purchase is not supported on Decidir gateways configured with the preauth_mode option' if @options[:preauth_mode]

        post = {}
        add_auth_purchase_params(post, money, payment, options)
        commit(:post, 'payments', post)
      end

      def authorize(money, payment, options={})
        raise ArgumentError, 'Authorize is not supported on Decidir gateways unless the preauth_mode option is enabled' unless @options[:preauth_mode]

        post = {}
        add_auth_purchase_params(post, money, payment, options)
        commit(:post, 'payments', post)
      end

      def capture(money, authorization, options={})
        raise ArgumentError, 'Capture is not supported on Decidir gateways unless the preauth_mode option is enabled' unless @options[:preauth_mode]

        post = {}
        add_amount(post, money, options)
        commit(:put, "payments/#{authorization}", post)
      end

      def refund(money, authorization, options={})
        post = {}
        add_amount(post, money, options)
        commit(:post, "payments/#{authorization}/refunds", post)
      end

      def void(authorization, options={})
        post = {}
        commit(:post, "payments/#{authorization}/refunds", post)
      end

      def verify(credit_card, options={})
        raise ArgumentError, 'Verify is not supported on Decidir gateways unless the preauth_mode option is enabled' unless @options[:preauth_mode]

        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((apikey: )\w+)i, '\1[FILTERED]').
          gsub(%r((\"card_number\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"security_code\\\":\\\")\d+), '\1[FILTERED]').
          gsub(%r((\"emv_issuer_data\\\":\\\")\d+), '\1[FILTERED]')
      end

      private

      def add_auth_purchase_params(post, money, credit_card, options)
        post[:payment_method_id] = add_payment_method_id(credit_card, options)
        post[:site_transaction_id] = options[:order_id]
        post[:bin] = credit_card.number[0..5]
        post[:payment_type] = options[:payment_type] || 'single'
        post[:installments] = options[:installments] ? options[:installments].to_i : 1
        post[:description] = options[:description] if options[:description]
        post[:email] = options[:email] if options[:email]
        post[:establishment_name] = options[:establishment_name] if options[:establishment_name]
        post[:fraud_detection] = add_fraud_detection(options[:fraud_detection]) if options[:fraud_detection].present?
        post[:site_id] = options[:site_id] if options[:site_id]
        post[:sub_payments] = []

        add_invoice(post, money, options)
        add_payment(post, credit_card, options)
        add_aggregate_data(post, options) if options[:aggregate_data]
      end

      def add_payment_method_id(credit_card, options)
        if options[:payment_method_id]
          options[:payment_method_id].to_i
        elsif options[:debit]
          if CreditCard.brand?(credit_card.number) == 'visa'
            31
          elsif CreditCard.brand?(credit_card.number) == 'master'
            105
          elsif CreditCard.brand?(credit_card.number) == 'maestro'
            106
          elsif CreditCard.brand?(credit_card.number) == 'cabal'
            108
          end
        elsif CreditCard.brand?(credit_card.number) == 'master'
          104
        elsif CreditCard.brand?(credit_card.number) == 'american_express'
          65
        elsif CreditCard.brand?(credit_card.number) == 'diners_club'
          8
        elsif CreditCard.brand?(credit_card.number) == 'cabal'
          63
        elsif CreditCard.brand?(credit_card.number) == 'naranja'
          24
        else
          1
        end
      end

      def add_invoice(post, money, options)
        add_amount(post, money, options)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_amount(post, money, options)
        currency = (options[:currency] || currency(money))
        post[:amount] = localized_amount(money, currency).to_i
      end

      def add_payment(post, credit_card, options)
        card_data = {}
        card_data[:card_number] = credit_card.number
        card_data[:card_expiration_month] = format(credit_card.month, :two_digits)
        card_data[:card_expiration_year] = format(credit_card.year, :two_digits)
        card_data[:security_code] = credit_card.verification_value if credit_card.verification_value?
        card_data[:card_holder_name] = credit_card.name if credit_card.name

        # additional data used for Visa transactions
        card_data[:card_holder_door_number] = options[:card_holder_door_number].to_i if options[:card_holder_door_number]
        card_data[:card_holder_birthday] = options[:card_holder_birthday] if options[:card_holder_birthday]

        card_data[:card_holder_identification] = {}
        card_data[:card_holder_identification][:type] = options[:card_holder_identification_type] if options[:card_holder_identification_type]
        card_data[:card_holder_identification][:number] = options[:card_holder_identification_number] if options[:card_holder_identification_number]

        post[:card_data] = card_data
      end

      def add_aggregate_data(post, options)
        aggregate_data = {}
        data = options[:aggregate_data]
        aggregate_data[:indicator] = data[:indicator] if data[:indicator]
        aggregate_data[:identification_number] = data[:identification_number] if data[:identification_number]
        aggregate_data[:bill_to_pay] = data[:bill_to_pay] if data[:bill_to_pay]
        aggregate_data[:bill_to_refund] = data[:bill_to_refund] if data[:bill_to_refund]
        aggregate_data[:merchant_name] = data[:merchant_name] if data[:merchant_name]
        aggregate_data[:street] = data[:street] if data[:street]
        aggregate_data[:number] = data[:number] if data[:number]
        aggregate_data[:postal_code] = data[:postal_code] if data[:postal_code]
        aggregate_data[:category] = data[:category] if data[:category]
        aggregate_data[:channel] = data[:channel] if data[:channel]
        aggregate_data[:geographic_code] = data[:geographic_code] if data[:geographic_code]
        aggregate_data[:city] = data[:city] if data[:city]
        aggregate_data[:merchant_id] = data[:merchant_id] if data[:merchant_id]
        aggregate_data[:province] = data[:province] if data[:province]
        aggregate_data[:country] = data[:country] if data[:country]
        aggregate_data[:merchant_email] = data[:merchant_email] if data[:merchant_email]
        aggregate_data[:merchant_phone] = data[:merchant_phone] if data[:merchant_phone]
        post[:aggregate_data] = aggregate_data
      end

      def add_fraud_detection(options = {})
        {}.tap do |hsh|
          hsh[:send_to_cs] = options[:send_to_cs] if valid_fraud_detection_option?(options[:send_to_cs]) # true/false
          hsh[:channel] = options[:channel] if valid_fraud_detection_option?(options[:channel])
          hsh[:dispatch_method] = options[:dispatch_method] if valid_fraud_detection_option?(options[:dispatch_method])
        end
      end

      # Avoid sending fields with empty or null when not populated.
      def valid_fraud_detection_option?(val)
        !val.nil? && val != ''
      end

      def headers(options = {})
        {
          'apikey' => @options[:api_key],
          'Content-type'  => 'application/json',
          'Cache-Control' => 'no-cache'
        }
      end

      def commit(method, endpoint, parameters, options={})
        url = "#{(test? ? test_url : live_url)}/#{endpoint}"

        begin
          raw_response = ssl_request(method, url, post_data(parameters), headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        success = success_from(response)
        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: success ? nil : error_code_from(response)
        )
      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        {
          'message' => "A non-JSON response was received from Decidir where one was expected. The raw response was:\n\n#{body}"
        }
      end

      def message_from(success, response)
        return response['status'] if success
        return response['message'] if response['message']

        message = nil
        if error = response.dig('status_details', 'error')
          message = "#{error.dig('reason', 'description')} | #{error['type']}"
        elsif response['error_type']
          message = response['validation_errors'].map { |errors| "#{errors['code']}: #{errors['param']}" }.join(', ') if response['validation_errors']
          message ||= response['error_type']
        end

        message
      end

      def success_from(response)
        response['status'] == 'approved' || response['status'] == 'pre_approved'
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(response)
        error_code = nil
        if error = response.dig('status_details', 'error')
          code = error.dig('reason', 'id')
          error_code = STANDARD_ERROR_CODE_MAPPING[code]
          error_code ||= error['type']
        elsif response['error_type']
          error_code = response['error_type'] if response['validation_errors']
        elsif error = response.dig('error')
          validation_errors = error.dig('validation_errors', 0)
          code = validation_errors['code'] if validation_errors && validation_errors['code']
          param = validation_errors['param'] if validation_errors && validation_errors['param']
          error_code = "#{error['error_type']} | #{code} | #{param}" if error['error_type']
        end

        error_code || STANDARD_ERROR_CODE[:processing_error]
      end
    end
  end
end
