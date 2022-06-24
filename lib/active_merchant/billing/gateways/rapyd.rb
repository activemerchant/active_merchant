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
        add_3ds(post, payment, options)
        add_address(post, payment, options)
        add_metadata(post, options)
        add_ewallet(post, options)
        add_payment_fields(post, options)
        add_payment_urls(post, options)
        post[:capture] = true if payment.is_a?(CreditCard)

        if payment.is_a?(Check)
          MultiResponse.run do |r|
            r.process { commit(:post, 'payments', post) }
            post = {}
            post[:token] = add_reference(r.authorization)
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
        add_3ds(post, payment, options)
        add_address(post, payment, options)
        add_metadata(post, options)
        add_ewallet(post, options)
        add_payment_fields(post, options)
        add_payment_urls(post, options)
        post[:capture] = false

        commit(:post, 'payments', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        commit(:post, "payments/#{add_reference(authorization)}/capture", post)
      end

      def refund(money, authorization, options = {})
        post = {}
        post[:payment] = add_reference(authorization)
        add_invoice(post, money, options)
        add_metadata(post, options)
        add_ewallet(post, options)

        commit(:post, 'refunds', post)
      end

      def void(authorization, options = {})
        post = {}
        commit(:delete, "payments/#{add_reference(authorization)}", post)
      end

      def verify(credit_card, options = {})
        authorize(0, credit_card, options)
      end

      def store(payment, options = {})
        post = {}
        add_payment(post, payment, options)
        add_customer_object(post, payment)
        add_metadata(post, options)
        add_ewallet(post, options)
        add_payment_fields(post, options)
        add_payment_urls(post, options)
        commit(:post, 'customers', post)
      end

      def unstore(customer)
        commit(:delete, "customers/#{add_reference(customer)}", {})
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Access_key: )\w+), '\1[FILTERED]').
          gsub(%r(("number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("account_number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("routing_number\\?":\\?")\d+), '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def add_reference(authorization)
        return unless authorization

        authorization.split('|')[0]
      end

      def add_address(post, creditcard, options)
        return unless address = options[:billing_address]

        post[:address] = {}
        # name and line_1 are required at the gateway
        post[:address][:name] = address[:name] if address[:name]
        post[:address][:line_1] = address[:address1] if address[:address1]
        post[:address][:line_2] = address[:address2] if address[:address2]
        post[:address][:city] = address[:city] if address[:city]
        post[:address][:state] = address[:state] if address[:state]
        post[:address][:country] = address[:country] if address[:country]
        post[:address][:zip] = address[:zip] if address[:zip]
        post[:address][:phone_number] = address[:phone].gsub(/\D/, '') if address[:phone]
      end

      def add_invoice(post, money, options)
        post[:amount] = money.zero? ? 0 : amount(money).to_f.to_s
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment, options)
        if payment.is_a?(CreditCard)
          add_creditcard(post, payment, options)
        elsif payment.is_a?(Check)
          add_ach(post, payment, options)
        else
          add_token(post, payment, options)
        end
      end

      def add_creditcard(post, payment, options)
        post[:payment_method] = {}
        post[:payment_method][:fields] = {}
        pm_fields = post[:payment_method][:fields]

        post[:payment_method][:type] = options[:pm_type]
        pm_fields[:number] = payment.number
        pm_fields[:expiration_month] = payment.month.to_s
        pm_fields[:expiration_year] = payment.year.to_s
        pm_fields[:cvv] = payment.verification_value.to_s
        pm_fields[:name] = "#{payment.first_name} #{payment.last_name}"
      end

      def add_ach(post, payment, options)
        post[:payment_method] = {}
        post[:payment_method][:fields] = {}

        post[:payment_method][:type] = options[:pm_type]
        post[:payment_method][:fields][:proof_of_authorization] = options[:proof_of_authorization]
        post[:payment_method][:fields][:first_name] = payment.first_name if payment.first_name
        post[:payment_method][:fields][:last_name] = payment.last_name if payment.last_name
        post[:payment_method][:fields][:routing_number] = payment.routing_number
        post[:payment_method][:fields][:account_number] = payment.account_number
        post[:payment_method][:fields][:payment_purpose] = options[:payment_purpose] if options[:payment_purpose]
      end

      def add_token(post, payment, options)
        post[:payment_method] = payment
      end

      def add_3ds(post, payment, options)
        return unless three_d_secure = options[:three_d_secure]

        post[:payment_method_options] = {}
        post[:payment_method_options]['3d_required'] = three_d_secure[:required]
        post[:payment_method_options]['3d_version'] = three_d_secure[:version]
        post[:payment_method_options][:cavv] = three_d_secure[:cavv]
        post[:payment_method_options][:eci] = three_d_secure[:eci]
        post[:payment_method_options][:xid] = three_d_secure[:xid]
        post[:payment_method_options][:ds_trans_id] = three_d_secure[:ds_transaction_id]
      end

      def add_metadata(post, options)
        post[:metadata] = options[:metadata] if options[:metadata]
      end

      def add_ewallet(post, options)
        post[:ewallet_id] = options[:ewallet_id] if options[:ewallet_id]
      end

      def add_payment_fields(post, options)
        post[:payment] = {}

        post[:payment][:description] = options[:description] if options[:description]
        post[:payment][:statement_descriptor] = options[:statement_descriptor] if options[:statement_descriptor]
      end

      def add_payment_urls(post, options)
        post[:complete_payment_url] = options[:complete_payment_url] if options[:complete_payment_url]
        post[:error_payment_url] = options[:error_payment_url] if options[:error_payment_url]
      end

      def add_customer_object(post, payment)
        post[:name] = "#{payment.first_name} #{payment.last_name}"
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
        id = response.dig('data') ? response.dig('data', 'id') : response.dig('status', 'operation_id')

        "#{id}|#{response.dig('data', 'default_payment_method')}"
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
