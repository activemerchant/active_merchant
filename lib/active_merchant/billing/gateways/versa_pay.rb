module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class VersaPayGateway < Gateway
      self.test_url = 'https://uat.versapay.com'
      self.live_url = 'https://secure.versapay.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.versapay.com/'
      self.display_name = 'VersaPay'

      def initialize(options = {})
        requires!(options, :api_token, :api_key)
        @api_token = options[:api_token]
        @api_key = options[:api_key]
        super
      end

      def purchase(money, payment, options = {})
        transact(money, payment, options)
      end

      def authorize(money, payment, options = {})
        transact(money, payment, options, 'auth')
      end

      def capture(money, authorization, options = {})
        post = {
          amount_cents: money,
          transaction: authorization
        }
        commit('capture', post)
      end

      def verify(credit_card, options = {})
        transact(0, credit_card, options, 'verify')
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("card_number\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def transact(money, payment, options = {}, type = 'sale')
        post = {
          contact: { email: options[:email] }
        }
        add_invoice(post, money, options)
        add_order(post, money, options)
        add_payment_method(post, payment, options)
        commit(type, post)
      end

      def add_customer_data(post, options)
        post[:customer_identifier] = options[:customer_identifier] if options[:customer_identifier]
      end

      def add_invoice(post, money, options)
        post[:amount_cents] = amount(money)
        post[:currency] = options[:currency] || currency(money)
      end

      def add_order(post, money, options = {})
        order = {
          identifier: options[:order_id],
          number: options[:order_number],
          date: options[:order_date] || Time.now.strftime('%Y-%m-%d'),
          draft: false,
          settlement_token: options[:settlement_token] # A settlement token reference (see whoami response structure) representing the merchant/bank processor configuration that should be used for transaction settlement.
        }.compact

        add_invoice(order, money, options)
        add_address(order, options, 'shipping')
        add_address(order, options)
        post[:order] = order
      end

      def add_address(post, options, address_key = 'billing', hash = 'order')
        address = options["#{address_key}_address".to_sym]
        return unless address

        address_data = {
          address_1: address[:address1],
          city: address[:city],
          province: address[:state],
          postal_code: address[:zip],
          country: Country.find(address[:country]).code(:alpha3).value
        }

        if hash == 'payment_method'
          post[:address] = address_data
        else
          post.merge!({
            "#{address_key}_name": address[:company],
            "#{address_key}_address": address[:address1],
            "#{address_key}_address2": address[:address2],
            "#{address_key}_city": address[:city],
            "#{address_key}_country": address_data[:country],
            "#{address_key}_email": options[:email],
            "#{address_key}_telephone": address[:phone] || address[:phone_number],
            "#{address_key}_postalcode": address[:zip],
            "#{address_key}_state_province": address[:state]
          }.compact)
        end
      end

      def add_payment_method(post, payment_method, options)
        if payment_method.is_a?(CreditCard)
          post[:credit_card] = {
            name: payment_method.name,
            expiry_month: format(payment_method.month, :two_digits),
            expiry_year: payment_method.year,
            card_number: payment_method.number,
            cvv: payment_method.verification_value
          }
          add_address(post[:credit_card], options, 'billing', 'payment_method')
        end
      end

      def parse(body)
        JSON.parse(body).with_indifferent_access
      rescue JSON::ParserError => e
        {
          errors: body,
          status: 'Unable to parse JSON response',
          message: e.message
        }.with_indifferent_access
      end

      def commit(action, post)
        raw_response = ssl_post(url(action), post.to_json, request_headers)
        response = parse(raw_response)
        first_transaction = response['transactions']&.first

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: dig_avs_code(first_transaction)),
          cvv_result: CVVResult.new(dig_cvv_code(first_transaction)),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response['success'] || false
      end

      def message_from(response)
        return 'Succeeded' if success_from(response)

        first_transaction = response['transactions']&.first
        gateway_response_errors = gateway_errors_message(response)

        response_message = {
          errors: response['errors']&.join(', ').presence,
          gateway_error_message: first_transaction&.dig('gateway_error_message').presence,
          gateway_response_errors: gateway_response_errors.presence
        }.compact

        response_message.map { |key, value| "#{key}: #{value}" }.join(' | ')
      end

      def authorization_from(response)
        response['transaction']
      end

      def error_code_from(response)
        return if success_from(response)

        first_transaction = response['transactions']&.first
        error_info = {
          gateway_error_code: first_transaction&.dig('gateway_error_code'),
          response_code: response['response_code']
        }.compact

        error_info.map { |key, value| "#{key}: #{value}" }.join(' | ')
      end

      def gateway_errors_message(response)
        errors = response.dig('transactions', 0, 'gateway_response', 'errors')
        return unless errors.is_a?(Hash)

        errors.flat_map do |field, error_details|
          error_details.flat_map do |error|
            if error.is_a?(Hash)
              error.map { |key, messages| "[#{field} - #{key}: #{messages.join(', ')}]" }
            else
              "[#{field} - #{error}]"
            end
          end
        end.join(' , ')
      end

      def url(endpoint)
        "#{test? ? test_url : live_url}/api/gateway/v1/orders/#{endpoint}"
      end

      def basic_auth
        Base64.strict_encode64("#{@api_token}:#{@api_key}")
      end

      def request_headers
        {
          'Content-Type' => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
      end

      def dig_cvv_code(first_transaction)
        return unless first_transaction

        first_transaction.dig('cvv_response') ||
          first_transaction.dig('gateway_response', 'cvv_response') ||
          find_cvv_avs_code(first_transaction, 'cvvresponse')
      end

      def dig_avs_code(first_transaction)
        return unless first_transaction

        first_transaction.dig('avs_response') ||
          first_transaction.dig('gateway_response', 'avs_response') ||
          find_cvv_avs_code(first_transaction, 'avsresponse')
      end

      def find_cvv_avs_code(first_transaction, to_find)
        neasted_response = first_transaction.dig(
          'gateway_response',
          'gateway_response',
          'response', 'content',
          'create'
        )
        return nil unless neasted_response.is_a?(Array)

        neasted_response.find { |x| x.dig('transaction', to_find) }&.dig('transaction', to_find)
      end

      def handle_response(response)
        case response.code.to_i
        when 200..412
          response.body
        else
          raise ResponseError.new(response)
        end
      end
    end
  end
end
