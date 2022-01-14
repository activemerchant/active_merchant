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

        add_payment(post, payment, options)
        add_purchase_data(post, money, payment, options)

        commit(:post, 'payments', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:amount] = money

        commit(:post, "payments/#{add_reference(authorization)}/refunds")
      end

      def store(payment, options = {})
        post = {}
        add_payment(post, payment, options)

        commit(:post, 'tokens', post)
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
          post[:card_expiration_month] = payment.month.to_s.rjust(2, '0')
          post[:card_expiration_year] = payment.year.to_s[-2..-1]
          post[:security_code] = payment.verification_value.to_s
          post[:card_holder_name] = payment.name
          post[:card_holder_identification] = {}
          post[:card_holder_identification][:type] = options[:dni]
          post[:card_holder_identification][:number] = options[:card_holder_identification_number]
        end
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
            installments: sub_payment[:installments],
            amount: sub_payment[:amount]
          }
          post[:sub_payments] << sub_payment_hash
        end
      end

      def parse(body)
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
        response.dig('status') == 'approved' || response.dig('status') == 'active'
      end

      def message_from(response)
        response.dig('status') || error_message(response) || response.dig('message')
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
    end
  end
end
