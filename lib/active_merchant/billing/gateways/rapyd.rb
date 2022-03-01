module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RapydGateway < Gateway
      self.test_url = 'https://sandboxapi.rapyd.net/v1/'
      self.live_url = 'https://api.rapyd.net/v1/'

      self.supported_countries = %w(US BR CA CL CO DO SV MX PE PT VI AU HK IN ID JP MY NZ PH SG KR TW TH VN AD AT BE BA BG HR CY CZ DK EE FI FR GE DE GI GR GL HU IS IE IL IT LV LI LT LU MK MT MD MC ME NL GB NO PL RO RU SM SK SI ZA ES SE CH TR VA)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.rapyd.net/'
      self.display_name = 'Rapyd Gateway'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :secret_key, :access_key)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)
        post[:capture] = true if payment_is_card?(options)

        if payment_is_ach?(options)
          MultiResponse.run do |r|
            r.process { commit(:post, 'payments', post) }
            post = {}
            post[:token] = r.authorization
            post[:param2] = r.params.dig('data', 'original_amount').to_s
            r.process { commit(:post, 'payments/completePayment', post) }
          end
        else
          commit(:post, 'payments', post)
        end
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)
        post[:capture] = false
        commit(:post, 'payments', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        commit(:post, "payments/#{authorization}/capture", post)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:payment] = authorization
        add_invoice(post, money, options)
        commit(:post, 'refunds', post)
      end

      def void(authorization, options = {})
        post = {}
        commit(:delete, "payments/#{authorization}", post)
      end

      # Gateway returns an error if trying to run a $0 auth as invalid payment amount
      # Gateway does not support void on a card transaction and refunds can only be done on completed transactions
      # (such as a purchase). Authorize transactions are considered 'active' and not 'complete' until they are captured.
      def verify(credit_card, options = {})
        MultiResponse.run do |r|
          r.process { purchase(100, credit_card, options) }
          r.process { refund(100, r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Access_key: )\w+), '\1[FILTERED]').
          gsub(%r(("number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def payment_is_ach?(options)
        return true if options[:type].include?('_bank')
      end

      def payment_is_card?(options)
        return true if options[:type].include?('_card')
      end

      def add_address(post, creditcard, options)
        return unless address = options[:address]

        post[:address] = {}
        # name and line_1 are required at the gateway
        post[:address][:name] = address[:name] if address[:name]
        post[:address][:line_1] = address[:address1] if address[:address1]
        post[:address][:line_2] = address[:address2] if address[:address2]
        post[:address][:city] = address[:city] if address[:city]
        post[:address][:state] = address[:state] if address[:state]
        post[:address][:country] = address[:country] if address[:country]
        post[:address][:zip] = address[:zip] if address[:zip]
        post[:address][:phone_number] = address[:phone] if address[:phone]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money).to_f.to_s
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment, options)
        if payment_is_card?(options)
          add_creditcard(post, payment, options)
        elsif payment_is_ach?(options)
          add_ach(post, payment, options)
        end
      end

      def add_creditcard(post, payment, options)
        post[:payment_method] = {}
        post[:payment_method][:fields] = {}
        pm_fields = post[:payment_method][:fields]

        post[:payment_method][:type] = options[:type]
        pm_fields[:number] = payment.number
        pm_fields[:expiration_month] = payment.month.to_s
        pm_fields[:expiration_year] = payment.year.to_s
        pm_fields[:cvv] = payment.verification_value.to_s
        pm_fields[:name] = "#{payment.first_name} #{payment.last_name}"
      end

      def add_ach(post, payment, options)
        post[:payment_method] = {}
        post[:payment_method][:fields] = {}

        post[:payment_method][:type] = options[:type]
        post[:payment_method][:fields][:proof_of_authorization] = options[:proof_of_authorization]
        post[:payment_method][:fields][:first_name] = payment.first_name if payment.first_name
        post[:payment_method][:fields][:last_name] = payment.last_name if payment.last_name
        post[:payment_method][:fields][:routing_number] = payment.routing_number
        post[:payment_method][:fields][:account_number] = payment.account_number
        post[:payment_method][:fields][:payment_purpose] = options[:payment_purpose] if options[:payment_purpose]
      end

      def parse(body)
        return {} if body.empty? || body.nil?

        JSON.parse(body)
      end

      def commit(method, action, parameters)
        url = (test? ? test_url : live_url) + action.to_s
        rel_path = "#{method}/v1/#{action}"
        response = api_request(method, url, rel_path, parameters)

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: avs_result(response),
          cvv_result: cvv_result(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def api_request(method, url, rel_path, params)
        params == {} ? body = '' : body = params.to_json
        parse(ssl_request(method, url, body, headers(rel_path, body)))
      end

      def headers(rel_path, payload)
        salt = SecureRandom.base64(12)
        timestamp = Time.new.to_i.to_s
        {
          'Content-Type' => 'application/json',
          'access_key' => @options[:access_key],
          'salt' => salt,
          'timestamp' => timestamp,
          'signature' => generate_hmac(rel_path, salt, timestamp, payload)
        }
      end

      def generate_hmac(rel_path, salt, timestamp, payload)
        signature = "#{rel_path}#{salt}#{timestamp}#{@options[:access_key]}#{@options[:secret_key]}#{payload}"
        hash = Base64.urlsafe_encode64(OpenSSL::HMAC.hexdigest('sha256', @options[:secret_key], signature))
        hash
      end

      def avs_result(response)
        return nil unless (code = response.dig('data', 'payment_method_data', 'acs_check'))

        AVSResult.new(code: code)
      end

      def cvv_result(response)
        return nil unless (code = response.dig('data', 'payment_method_data', 'cvv_check'))

        CVVResult.new(code)
      end

      def success_from(response)
        response.dig('status', 'status') == 'SUCCESS' && response.dig('status', 'error') != 'ERR'
      end

      def message_from(response)
        case response.dig('status', 'status')
        when 'ERROR'
          response.dig('status', 'message') == '' ? response.dig('status', 'error_code') : response.dig('status', 'message')
        else
          response.dig('status', 'status')
        end
      end

      def authorization_from(response)
        response.dig('data') ? response.dig('data', 'id') : response.dig('status', 'operation_id')
      end

      def error_code_from(response)
        response.dig('status', 'error_code') unless success_from(response)
      end

      def handle_response(response)
        case response.code.to_i
        when 200...300, 400, 401, 404
          response.body
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
