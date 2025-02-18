module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class DeepstackGateway < Gateway
      self.test_url = 'https://api.sandbox.deepstack.io'
      self.live_url = 'https://api.deepstack.io'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover]
      self.money_format = :cents

      self.homepage_url = 'https://deepstack.io/'
      self.display_name = 'Deepstack Gateway'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :publishable_api_key, :app_id, :shared_secret)
        @publishable_api_key, @app_id, @shared_secret = options.values_at(:publishable_api_key, :app_id, :shared_secret)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_payment(post, payment, options)
        add_order(post, money, options)
        add_purchase_capture(post)
        add_address(post, payment, options)
        add_customer_data(post, options)
        commit('sale', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_payment(post, payment, options)
        add_order(post, money, options)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('auth', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_invoice(post, money, authorization, options)

        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_invoice(post, money, authorization, options)
        commit('refund', post)
      end

      def void(money, authorization, options = {})
        post = {}
        add_invoice(post, money, authorization, options)
        commit('void', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(0, r.authorization, options) }
        end
      end

      def get_token(credit_card, options = {})
        post = {}
        add_payment_instrument(post, credit_card, options)
        add_address_payment_instrument(post, credit_card, options)
        commit('gettoken', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer )\w+), '\1[FILTERED]').
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r((Hmac: )[\w=]+), '\1[FILTERED]').
          gsub(%r((\\"account_number\\":\\")[\w*]+), '\1[FILTERED]').
          gsub(%r((\\"cvv\\":\\")\w+), '\1[FILTERED]').
          gsub(%r((\\"expiration\\":\\")\w+), '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:meta] ||= {}

        add_shipping(post, options) if options.key?(:shipping_address)
        post[:meta][:client_customer_id] = options[:customer] if options[:customer]
        post[:meta][:client_transaction_id] = options[:order_id] if options[:order_id]
        post[:meta][:client_transaction_description] = options[:description] if options[:description]
        post[:meta][:client_invoice_id] = options[:invoice] if options[:invoice]
        post[:meta][:card_holder_ip_address] = options[:ip] if options[:ip]
      end

      def add_address(post, creditcard, options)
        return post unless options.key?(:address) || options.key?(:billing_address)

        billing_address = options[:address] || options[:billing_address]
        post[:source] ||= {}

        post[:source][:billing_contact] = {}
        post[:source][:billing_contact][:first_name] = billing_address[:first_name] if billing_address[:first_name]
        post[:source][:billing_contact][:last_name] = billing_address[:last_name] if billing_address[:last_name]
        post[:source][:billing_contact][:phone] = billing_address[:phone] if billing_address[:phone]
        post[:source][:billing_contact][:email] = options[:email] if options[:email]
        post[:source][:billing_contact][:address] = {}
        post[:source][:billing_contact][:address][:line_1] = billing_address[:address1] if billing_address[:address1]
        post[:source][:billing_contact][:address][:line_2] = billing_address[:address2] if billing_address[:address2]
        post[:source][:billing_contact][:address][:city] = billing_address[:city] if billing_address[:city]
        post[:source][:billing_contact][:address][:state] = billing_address[:state] if billing_address[:state]
        post[:source][:billing_contact][:address][:postal_code] = billing_address[:zip] if billing_address[:zip]
        post[:source][:billing_contact][:address][:country_code] = billing_address[:country] if billing_address[:country]
      end

      def add_address_payment_instrument(post, creditcard, options)
        return post unless options.key?(:address) || options.key?(:billing_address)

        billing_address = options[:address] || options[:billing_address]
        post[:source] = {} unless post.key?(:payment_instrument)

        post[:payment_instrument][:billing_contact] = {}
        post[:payment_instrument][:billing_contact][:first_name] = billing_address[:first_name] if billing_address[:first_name]
        post[:payment_instrument][:billing_contact][:last_name] = billing_address[:last_name] if billing_address[:last_name]
        post[:payment_instrument][:billing_contact][:phone] = billing_address[:phone] if billing_address[:phone]
        post[:payment_instrument][:billing_contact][:email] = billing_address[:email] if billing_address[:email]
        post[:payment_instrument][:billing_contact][:address] = {}
        post[:payment_instrument][:billing_contact][:address][:line_1] = billing_address[:address1] if billing_address[:address1]
        post[:payment_instrument][:billing_contact][:address][:line_2] = billing_address[:address2] if billing_address[:address2]
        post[:payment_instrument][:billing_contact][:address][:city] = billing_address[:city] if billing_address[:city]
        post[:payment_instrument][:billing_contact][:address][:state] = billing_address[:state] if billing_address[:state]
        post[:payment_instrument][:billing_contact][:address][:postal_code] = billing_address[:zip] if billing_address[:zip]
        post[:payment_instrument][:billing_contact][:address][:country_code] = billing_address[:country] if billing_address[:country]
      end

      def add_shipping(post, options = {})
        return post unless options.key?(:shipping_address)

        shipping = options[:shipping_address]
        post[:meta][:shipping_info] = {}
        post[:meta][:shipping_info][:first_name] = shipping[:first_name] if shipping[:first_name]
        post[:meta][:shipping_info][:last_name] = shipping[:last_name] if shipping[:last_name]
        post[:meta][:shipping_info][:phone] = shipping[:phone] if shipping[:phone]
        post[:meta][:shipping_info][:email] = shipping[:email] if shipping[:email]
        post[:meta][:shipping_info][:address] = {}
        post[:meta][:shipping_info][:address][:line_1] = shipping[:address1] if shipping[:address1]
        post[:meta][:shipping_info][:address][:line_2] = shipping[:address2] if shipping[:address2]
        post[:meta][:shipping_info][:address][:city] = shipping[:city] if shipping[:city]
        post[:meta][:shipping_info][:address][:state] = shipping[:state] if shipping[:state]
        post[:meta][:shipping_info][:address][:postal_code] = shipping[:zip] if shipping[:zip]
        post[:meta][:shipping_info][:address][:country_code] = shipping[:country] if shipping[:country]
      end

      def add_invoice(post, money, authorization, options)
        post[:amount] = amount(money)
        post[:charge] = authorization
      end

      def add_payment(post, payment, options)
        if payment.kind_of?(String)
          post[:source] = {}
          post[:source][:type] = 'card_on_file'
          post[:source][:card_on_file] = {}
          post[:source][:card_on_file][:id] = payment
          post[:source][:card_on_file][:cvv] = options[:verification_value] || ''
          post[:source][:card_on_file][:customer_id] = options[:customer_id] || ''
        # credit card object
        elsif payment.respond_to?(:number)
          post[:source] = {}
          post[:source][:type] = 'credit_card'
          post[:source][:credit_card] = {}
          post[:source][:credit_card][:account_number] = payment.number
          post[:source][:credit_card][:cvv] = payment.verification_value || ''
          post[:source][:credit_card][:expiration] = '%02d%02d' % [payment.month, payment.year % 100]
          post[:source][:credit_card][:customer_id] = options[:customer_id] || ''
        end
      end

      def add_payment_instrument(post, creditcard, options)
        if creditcard.kind_of?(String)
          post[:source] = creditcard
          return post
        end
        return post unless creditcard.respond_to?(:number)

        post[:payment_instrument] = {}
        post[:payment_instrument][:type] = 'credit_card'
        post[:payment_instrument][:credit_card] = {}
        post[:payment_instrument][:credit_card][:account_number] = creditcard.number
        post[:payment_instrument][:credit_card][:expiration] = '%02d%02d' % [creditcard.month, creditcard.year % 100]
        post[:payment_instrument][:credit_card][:cvv] = creditcard.verification_value
      end

      def add_order(post, amount, options)
        post[:transaction] ||= {}

        post[:transaction][:amount] = amount
        post[:transaction][:cof_type] = options.key?(:cof_type) ? options[:cof_type].upcase : 'UNSCHEDULED_CARDHOLDER'
        post[:transaction][:capture] = false # Change this in the request (auth/charge)
        post[:transaction][:currency_code] = (options[:currency] || currency(amount).upcase)
        post[:transaction][:avs] = options[:avs] || true # default avs to true unless told otherwise
        post[:transaction][:save_payment_instrument] = options[:save_payment_instrument] || false
      end

      def add_purchase_capture(post)
        post[:transaction] ||= {}
        post[:transaction][:capture] = true
      end

      def parse(body)
        return {} if !body || body.empty?

        JSON.parse(body)
      end

      def commit(action, parameters, method = 'POST')
        url = (test? ? test_url : live_url)
        if no_hmac(action)
          request_headers = headers.merge(create_basic(parameters, action))
        else
          request_headers = headers.merge(create_hmac(parameters, method))
        end
        request_url = url + get_url(action)
        begin
          response = parse(ssl_post(request_url, post_data(action, parameters), request_headers))
          Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            avs_result: AVSResult.new(code: response['avs_result']),
            cvv_result: CVVResult.new(response['cvv_result']),
            test: test?,
            error_code: error_code_from(response)
          )
        rescue ResponseError => e
          Response.new(
            false,
            message_from_error(e.response.body),
            response_error(e.response.body)
          )
        rescue JSON::ParserError
          Response.new(
            false,
            message_from(response),
            json_error(response)
          )
        end
      end

      def headers
        {
          'Accept' => 'text/plain',
          'Content-Type' => 'application/json'
        }
      end

      def response_error(response)
        parse(response)
      rescue JSON::ParserError
        json_error(response)
      end

      def json_error(response)
        msg = 'Invalid response received from the Conekta API.'
        msg += "  (The raw response returned by the API was #{response.inspect})"
        {
          'message' => msg
        }
      end

      def success_from(response)
        success = false
        if response.key?('response_code')
          success = response['response_code'] == '00'
        # Hack because token/payment instrument methods do not return a response_code
        elsif response.key?('id')
          success = true if response['id'].start_with?('tok', 'card')
        end

        return success
      end

      def message_from(response)
        response = JSON.parse(response) if response.is_a?(String)
        if response.key?('message')
          return response['message']
        elsif response.key?('detail')
          return response['detail']
        end
      end

      def message_from_error(response)
        if response.is_a?(String)
          response.gsub!('\\"', '"')
          response = JSON.parse(response)
        end

        if response.key?('detail')
          return response['detail']
        elsif response.key?('message')
          return response['message']
        end
      end

      def authorization_from(response)
        response['id']
      end

      def post_data(action, parameters = {})
        return JSON.generate(parameters)
      end

      def error_code_from(response)
        error_code = nil
        error_code = response['response_code'] unless success_from(response)
        if error = response.dig('detail')
          error_code = error
        elsif error = response.dig('error')
          error_code = error.dig('reason', 'id')
        end
        error_code
      end

      def get_url(action)
        base = '/api/v1/'
        case action
        when 'sale'
          return base + 'payments/charge'
        when 'auth'
          return base + 'payments/charge'
        when 'capture'
          return base + 'payments/capture'
        when 'void'
          return base + 'payments/refund'
        when 'refund'
          return base + 'payments/refund'
        when 'gettoken'
          return base + 'vault/token'
        when 'vault'
          return base + 'vault/payment-instrument/token'
        else
          return base + 'noaction'
        end
      end

      def no_hmac(action)
        case action
        when 'gettoken'
          return true
        else
          return false
        end
      end

      def create_basic(post, method)
        return { 'Authorization' => "Bearer #{@publishable_api_key}" }
      end

      def create_hmac(post, method)
        # Need requestDate, requestMethod, Nonce, AppIDKey
        app_id_key = @app_id
        request_method = method.upcase
        uuid = SecureRandom.uuid
        request_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ')

        string_to_hash = "#{app_id_key}|#{request_method}|#{request_time}|#{uuid}|#{JSON.generate(post)}"
        signature = OpenSSL::HMAC.digest(OpenSSL::Digest.new('SHA256'), Base64.strict_decode64(@shared_secret), string_to_hash)
        base64_signature = Base64.strict_encode64(signature)
        hmac_header = Base64.strict_encode64("#{app_id_key}|#{request_method}|#{request_time}|#{uuid}|#{base64_signature}")
        return { 'hmac' => hmac_header }
      end
    end
  end
end
