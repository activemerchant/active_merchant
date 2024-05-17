module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RapydGateway < Gateway
      class_attribute :payment_redirect_test, :payment_redirect_live

      self.test_url = 'https://sandboxapi.rapyd.net/v1/'
      self.live_url = 'https://api.rapyd.net/v1/'

      self.payment_redirect_test = 'https://sandboxpayment-redirect.rapyd.net/v1/'
      self.payment_redirect_live = 'https://payment-redirect.rapyd.net/v1/'

      self.supported_countries = %w(CA CL CO DO SV PE PT VI AU HK IN ID JP MY NZ PH SG KR TW TH VN AD AT BE BA BG HR CY CZ DK EE FI FR GE DE GI GR GL HU IS IE IL IT LV LI LT LU MK MT MD MC ME NL GB NO PL RO RU SM SK SI ZA ES SE CH TR VA)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover verve]

      self.homepage_url = 'https://www.rapyd.net/'
      self.display_name = 'Rapyd Gateway'

      USA_PAYMENT_METHODS = %w[us_debit_discover_card us_debit_mastercard_card us_debit_visa_card us_ach_bank]

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :secret_key, :access_key)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_auth_purchase(post, money, payment, options)
        post[:capture] = true unless payment.is_a?(Check)

        commit(:post, 'payments', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_auth_purchase(post, money, payment, options)
        post[:capture] = false unless payment.is_a?(Check)

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
        add_customer_data(post, payment, options, 'store')
        add_metadata(post, options)
        add_ewallet(post, options)
        add_payment_fields(post, options)
        add_payment_urls(post, options, 'store')
        add_address(post, payment, options)
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

      def add_auth_purchase(post, money, payment, options)
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_customer_data(post, payment, options)
        add_3ds(post, payment, options)
        add_address(post, payment, options)
        add_metadata(post, options)
        add_ewallet(post, options)
        add_payment_fields(post, options)
        add_payment_urls(post, options)
        add_idempotency(options)
      end

      def add_idempotency(options)
        @options[:idempotency] = options[:idempotency_key] if options[:idempotency_key]
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
        post[:merchant_reference_id] = options[:merchant_reference_id] || options[:order_id]
        post[:requested_currency] = options[:requested_currency] if options[:requested_currency].present?
        post[:fixed_side] = options[:fixed_side] if options[:fixed_side].present?
        post[:expiration] = (options[:expiration_days] || 7).to_i.days.from_now.to_i if options[:fixed_side].present?
      end

      def add_payment(post, payment, options)
        if payment.is_a?(CreditCard)
          add_creditcard(post, payment, options)
        elsif payment.is_a?(Check)
          add_ach(post, payment, options)
        else
          add_tokens(post, payment, options)
        end
      end

      def add_stored_credential(post, options)
        add_network_reference_id(post, options)
        add_initiation_type(post, options)
      end

      def add_network_reference_id(post, options)
        return unless (options[:stored_credential] && options[:stored_credential][:reason_type] == 'recurring') || options[:network_transaction_id]

        network_transaction_id = options[:network_transaction_id] || options[:stored_credential][:network_transaction_id]
        post[:payment_method][:fields][:network_reference_id] = network_transaction_id unless network_transaction_id&.empty?
      end

      def add_initiation_type(post, options)
        return unless options[:stored_credential] || options[:initiation_type]

        initiation_type = options[:initiation_type] || options[:stored_credential][:reason_type]
        post[:initiation_type] = initiation_type if initiation_type
      end

      def add_creditcard(post, payment, options)
        post[:payment_method] = {}
        post[:payment_method][:fields] = {}
        pm_fields = post[:payment_method][:fields]

        post[:payment_method][:type] = options[:pm_type]
        pm_fields[:number] = payment.number
        pm_fields[:expiration_month] = format(payment.month, :two_digits).to_s
        pm_fields[:expiration_year] = format(payment.year, :two_digits).to_s
        pm_fields[:name] = "#{payment.first_name} #{payment.last_name}"
        pm_fields[:cvv] = payment.verification_value.to_s unless valid_network_transaction_id?(options) || payment.verification_value.blank?
        pm_fields[:recurrence_type] = options[:recurrence_type] if options[:recurrence_type]
        add_stored_credential(post, options)
      end

      def send_customer_object?(options)
        options[:stored_credential] && options[:stored_credential][:reason_type] == 'recurring'
      end

      def valid_network_transaction_id?(options)
        network_transaction_id = options[:network_tansaction_id] || options.dig(:stored_credential_options, :network_transaction_id) || options.dig(:stored_credential, :network_transaction_id)
        return network_transaction_id.present?
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

      def add_tokens(post, payment, options)
        return unless payment.respond_to?(:split)

        customer_id, card_id = payment.split('|')

        post[:customer] = customer_id unless send_customer_object?(options)
        post[:payment_method] = card_id
      end

      def add_3ds(post, payment, options)
        if options[:execute_threed] == true
          post[:payment_method_options] = { '3d_required' => true } if options[:force_3d_secure].to_s == 'true'
        elsif three_d_secure = options[:three_d_secure]
          post[:payment_method_options] = {}
          post[:payment_method_options]['3d_required'] = three_d_secure[:required]
          post[:payment_method_options]['3d_version'] = three_d_secure[:version]
          post[:payment_method_options][:cavv] = three_d_secure[:cavv]
          post[:payment_method_options][:eci] = three_d_secure[:eci]
          post[:payment_method_options][:xid] = three_d_secure[:xid]
          post[:payment_method_options][:ds_trans_id] = three_d_secure[:ds_transaction_id]
        end
      end

      def add_metadata(post, options)
        post[:metadata] = options[:metadata] if options[:metadata]
      end

      def add_ewallet(post, options)
        post[:ewallet] = options[:ewallet_id] if options[:ewallet_id]
      end

      def add_payment_fields(post, options)
        post[:description] = options[:description] if options[:description]
        post[:statement_descriptor] = options[:statement_descriptor] if options[:statement_descriptor]
      end

      def add_payment_urls(post, options, action = '')
        if action == 'store'
          url_location = post[:payment_method]
        else
          url_location = post
        end

        url_location[:complete_payment_url] = options[:complete_payment_url] if options[:complete_payment_url]
        url_location[:error_payment_url] = options[:error_payment_url] if options[:error_payment_url]
      end

      def add_customer_data(post, payment, options, action = '')
        phone_number = options.dig(:billing_address, :phone) || options.dig(:billing_address, :phone_number)
        post[:phone_number] = phone_number.gsub(/\D/, '') unless phone_number.nil?
        post[:receipt_email] = options[:email] if payment.is_a?(String) && options[:customer_id].present? && !send_customer_object?(options)

        return if payment.is_a?(String)
        return add_customer_id(post, options) if options[:customer_id]

        if action == 'store'
          post.merge!(customer_fields(payment, options))
        else
          post[:customer] = customer_fields(payment, options) unless send_customer_object?(options)
        end
      end

      def customer_fields(payment, options)
        return if options[:customer_id]

        customer_address = address(options)
        customer_data = {}
        customer_data[:name] = "#{payment.first_name} #{payment.last_name}" unless payment.is_a?(String)
        customer_data[:email] = options[:email] unless payment.is_a?(String) && options[:customer_id].blank?
        customer_data[:addresses] = [customer_address] if customer_address
        customer_data
      end

      def address(options)
        return unless address = options[:billing_address]

        formatted_address = {}

        formatted_address[:name] = address[:name] if address[:name]
        formatted_address[:line_1] = address[:address1] if address[:address1]
        formatted_address[:line_2] = address[:address2] if address[:address2]
        formatted_address[:city] = address[:city] if address[:city]
        formatted_address[:state] = address[:state] if address[:state]
        formatted_address[:country] = address[:country] if address[:country]
        formatted_address[:zip] = address[:zip] if address[:zip]
        formatted_address[:phone_number] = address[:phone].gsub(/\D/, '') if address[:phone]

        formatted_address
      end

      def add_customer_id(post, options)
        post[:customer] = options[:customer_id] if options[:customer_id]
      end

      def parse(body)
        return {} if body.empty? || body.nil?

        parsed = JSON.parse(body)
        parsed.is_a?(Hash) ? parsed : { 'status' => { 'status' => parsed } }
      end

      def url(action, url_override = nil)
        if url_override.to_s == 'payment_redirect' && action == 'payments'
          (self.test? ? self.payment_redirect_test : self.payment_redirect_live) + action.to_s
        else
          (self.test? ? self.test_url : self.live_url) + action.to_s
        end
      end

      def commit(method, action, parameters)
        rel_path = "#{method}/v1/#{action}"
        response = api_request(method, url(action, @options[:url_override]), rel_path, parameters)

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
      rescue ActiveMerchant::ResponseError => e
        response = e.response.body.present? ? parse(e.response.body) : { 'status' => { 'response_code' => e.response.msg } }
        message = response['status'].slice('message', 'response_code').values.compact_blank.first || ''
        Response.new(false, message, response, test: test?, error_code: error_code_from(response))
      end

      # We need to revert the work of ActiveSupport JSON encoder to prevent discrepancies
      # Between the signature and the actual request body
      def revert_json_html_encoding!(string)
        {
          '\\u003e' => '>',
          '\\u003c' => '<',
          '\\u0026' => '&'
        }.each { |k, v| string.gsub! k, v }
      end

      def api_request(method, url, rel_path, params)
        params == {} ? body = '' : body = params.to_json
        revert_json_html_encoding!(body) if defined?(ActiveSupport::JSON::Encoding) && ActiveSupport::JSON::Encoding.escape_html_entities_in_json
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
          'signature' => generate_hmac(rel_path, salt, timestamp, payload),
          'idempotency' => @options[:idempotency]
        }.delete_if { |_, value| value.nil? }
      end

      def generate_hmac(rel_path, salt, timestamp, payload)
        signature = "#{rel_path}#{salt}#{timestamp}#{@options[:access_key]}#{@options[:secret_key]}#{payload}"
        Base64.urlsafe_encode64(OpenSSL::HMAC.hexdigest('sha256', @options[:secret_key], signature))
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
        response.dig('status', 'error_code') || response.dig('status', 'response_code') || ''
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
