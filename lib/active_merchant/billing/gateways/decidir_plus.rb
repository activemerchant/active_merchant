module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class DecidirPlusGateway < Gateway
      self.test_url = 'https://developers.decidir.com/api/v2'
      self.live_url = 'https://live.decidir.com/api/v2'

      self.supported_countries = ['AR']
      self.default_currency = 'ARS'
      self.supported_cardtypes = %i[visa master american_express discover]

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
          post[:card_holder_name] = payment.name
          post[:card_holder_identification] = {}
          post[:card_holder_identification][:type] = options[:dni]
          post[:card_holder_identification][:number] = options[:card_holder_identification_number]
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
        post[:payment_method_id] = 1
        post[:amount] = money
        post[:currency] = options[:currency] || self.default_currency
        post[:installments] = options[:installments] || 1
        post[:payment_type] = options[:payment_type] || 'single'
        add_sub_payments(post, options)
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
        response.dig('error_type') unless success_from(response)
      end

      def error_message(response)
        return error_code_from(response) unless validation_errors = response.dig('validation_errors')

        validation_errors = validation_errors[0]

        "#{validation_errors.dig('code')}: #{validation_errors.dig('param')}"
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
