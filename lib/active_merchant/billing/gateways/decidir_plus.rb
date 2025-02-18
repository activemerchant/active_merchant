module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class DecidirPlusGateway < Gateway
      self.test_url = 'https://developers.decidir.com/api/v2'
      self.live_url = 'https://live.decidir.com/api/v2'

      self.supported_countries = ['AR']
      self.default_currency = 'ARS'
      self.supported_cardtypes = %i[visa master american_express discover diners_club naranja cabal patagonia_365 tarjeta_sol]

      self.homepage_url = 'http://decidir.com.ar/home'
      self.display_name = 'Decidir Plus'

      def initialize(options = {})
        requires!(options, :public_key, :private_key)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        build_purchase_authorize_request(post, money, payment, options)

        commit(:post, 'payments', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        build_purchase_authorize_request(post, money, payment, options)

        commit(:post, 'payments', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        post[:amount] = money

        commit(:put, "payments/#{add_reference(authorization)}", post)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:amount] = money

        commit(:post, "payments/#{add_reference(authorization)}/refunds", post)
      end

      def void(authorization, options = {})
        commit(:post, "payments/#{add_reference(authorization)}/refunds")
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { store(credit_card, options) }
          r.process { authorize(100, r.authorization, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def store(payment, options = {})
        post = {}
        add_payment(post, payment, options)

        commit(:post, 'tokens', post)
      end

      def unstore(customer_token)
        commit(:delete, "cardtokens/#{customer_token}")
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Apikey: )\w+), '\1[FILTERED]').
          gsub(%r(("card_number\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("security_code\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def build_purchase_authorize_request(post, money, payment, options)
        add_customer_data(post, options)
        add_payment(post, payment, options)
        add_purchase_data(post, money, payment, options)
        add_fraud_detection(post, options)
      end

      def add_reference(authorization)
        return unless authorization

        authorization.split('|')[0]
      end

      def add_wallet_id(post, options)
        return unless options[:wallet_id]

        post[:wallet_id] = options[:wallet_id]
      end

      def add_payment(post, payment, options = {})
        if payment.is_a?(String)
          token, bin = payment.split('|')
          post[:token] = token
          post[:bin] = bin
        else
          post[:card_number] = payment.number
          post[:card_expiration_month] = format(payment.month, :two_digits)
          post[:card_expiration_year] = format(payment.year, :two_digits)
          post[:security_code] = payment.verification_value.to_s
          post[:card_holder_name] = payment.name.empty? ? options[:name_override] : payment.name
          post[:card_holder_identification] = {}
          post[:card_holder_identification][:type] = options[:card_holder_identification_type] if options[:card_holder_identification_type]
          post[:card_holder_identification][:number] = options[:card_holder_identification_number] if options[:card_holder_identification_number]

          # additional data used for Visa transactions
          post[:card_holder_door_number] = options[:card_holder_door_number].to_i if options[:card_holder_door_number]
          post[:card_holder_birthday] = options[:card_holder_birthday] if options[:card_holder_birthday]
        end
      end

      def add_customer_data(post, options = {})
        return unless customer = options[:customer]

        post[:customer] = {}
        post[:customer][:id] = customer[:id] if customer[:id]
        post[:customer][:email] = customer[:email] if customer[:email]
      end

      def add_purchase_data(post, money, payment, options = {})
        post[:site_transaction_id] = options[:site_transaction_id] || SecureRandom.hex
        post[:payment_method_id] = add_payment_method_id(options)
        post[:amount] = money
        post[:currency] = options[:currency] || self.default_currency
        post[:installments] = options[:installments] || 1
        post[:payment_type] = options[:payment_type] || 'single'
        post[:establishment_name] = options[:establishment_name] if options[:establishment_name]

        add_aggregate_data(post, options) if options[:aggregate_data]
        add_sub_payments(post, options)
        add_wallet_id(post, options)
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

      def add_sub_payments(post, options)
        # sub_payments field is required for purchase transactions, even if empty
        post[:sub_payments] = []

        return unless sub_payments = options[:sub_payments]

        sub_payments.each do |sub_payment|
          sub_payment_hash = {
            site_id: sub_payment[:site_id],
            installments: sub_payment[:installments].to_i,
            amount: sub_payment[:amount].to_i
          }
          post[:sub_payments] << sub_payment_hash
        end
      end

      def add_payment_method_id(options)
        return options[:payment_method_id].to_i if options[:payment_method_id]

        if options[:debit]
          case options[:card_brand]
          when 'visa'
            31
          when 'master'
            105
          when 'maestro'
            106
          when 'cabal'
            108
          else
            31
          end
        else
          case options[:card_brand]
          when 'visa'
            1
          when 'master'
            104
          when 'american_express'
            65
          when 'american_express_prisma'
            111
          when 'cabal'
            63
          when 'diners_club'
            8
          when 'patagonia_365'
            55
          else
            1
          end
        end
      end

      def add_fraud_detection(post, options)
        return unless fraud_detection = options[:fraud_detection]

        {}.tap do |hsh|
          hsh[:send_to_cs] = fraud_detection[:send_to_cs] == 'true' # true/false
          hsh[:channel] = fraud_detection[:channel] if fraud_detection[:channel]
          hsh[:dispatch_method] = fraud_detection[:dispatch_method] if fraud_detection[:dispatch_method]
          add_csmdds(hsh, fraud_detection)

          post[:fraud_detection] = hsh
        end
      end

      def add_csmdds(hsh, fraud_detection)
        return unless fraud_detection[:csmdds]

        csmdds_arr = []
        fraud_detection[:csmdds].each do |csmdds|
          csmdds_hsh = {}
          csmdds_hsh[:code] = csmdds[:code].to_i
          csmdds_hsh[:description] = csmdds[:description]
          csmdds_arr.append(csmdds_hsh)
        end
        hsh[:csmdds] = csmdds_arr unless csmdds_arr.empty?
      end

      def parse(body)
        return {} if body.nil?

        JSON.parse(body)
      end

      def commit(method, endpoint, parameters = {}, options = {})
        begin
          raw_response = ssl_request(method, url(endpoint), post_data(parameters), headers(endpoint))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = parse(raw_response)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers(endpoint)
        {
          'Content-Type' => 'application/json',
          'apikey' => endpoint == 'tokens' ? @options[:public_key] : @options[:private_key]
        }
      end

      def url(action, options = {})
        base_url = (test? ? test_url : live_url)

        return "#{base_url}/#{action}"
      end

      def success_from(response)
        response.dig('status') == 'approved' || response.dig('status') == 'active' || response.dig('status') == 'pre_approved' || response.empty?
      end

      def message_from(response)
        return '' if response.empty?

        rejected?(response) ? message_from_status_details(response) : response.dig('status') || error_message(response) || response.dig('message')
      end

      def authorization_from(response)
        return nil unless response.dig('id') || response.dig('bin')

        "#{response.dig('id')}|#{response.dig('bin')}"
      end

      def post_data(parameters = {})
        parameters.to_json
      end

      def error_code_from(response)
        return if success_from(response)

        error_code = nil
        if error = response.dig('status_details', 'error')
          error_code = error.dig('reason', 'id') || error['type']
        elsif response['error_type']
          error_code = response['error_type']
        elsif response.dig('error', 'validation_errors')
          error = response.dig('error')
          validation_errors = error.dig('validation_errors', 0)
          code = validation_errors['code'] if validation_errors && validation_errors['code']
          param = validation_errors['param'] if validation_errors && validation_errors['param']
          error_code = "#{error['error_type']} | #{code} | #{param}" if error['error_type']
        elsif error = response.dig('error')
          error_code = error.dig('reason', 'id')
        end

        error_code
      end

      def error_message(response)
        return error_code_from(response) unless validation_errors = response.dig('validation_errors')

        validation_errors = validation_errors[0]
        message = "#{validation_errors&.dig('code')}: #{validation_errors&.dig('param')}"
        return message unless message == ': '

        errors = response['validation_errors'].map { |k, v| "#{k}: #{v}" }.join(', ')
        "#{response['error_type']} - #{errors}"
      end

      def rejected?(response)
        return response.dig('status') == 'rejected'
      end

      def message_from_status_details(response)
        return unless error = response.dig('status_details', 'error')
        return message_from_fraud_detection(response) if error.dig('type') == 'cybersource_error'

        "#{error.dig('type')}: #{error.dig('reason', 'description')}"
      end

      def message_from_fraud_detection(response)
        return error_message(response.dig('fraud_detection', 'status', 'details'))
      end
    end
  end
end
