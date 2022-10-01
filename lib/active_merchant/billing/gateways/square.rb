module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SquareGateway < Gateway
      self.test_url = 'https://connect.squareupsandbox.com/v2'
      self.live_url = 'https://connect.squareup.com/v2'

      self.supported_countries = %w[US CA GB AU JP]
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express discover jcb union_pay]
      self.money_format = :cents

      self.homepage_url = 'https://squareup.com/'
      self.display_name = 'Square Payments Gateway'

      CVC_CODE_TRANSLATOR = {
        'CVV_ACCEPTED' => 'M',
        'CVV_REJECTED' => 'N',
        'CVV_NOT_CHECKED' => 'P'
      }.freeze

      AVS_CODE_TRANSLATOR = {
        # TODO: unsure if Square does street or only postal AVS matches
        'AVS_ACCEPTED' => 'P', # 'P' => 'Postal code matches, but street address not verified.',
        'AVS_REJECTED' => 'N', # 'N' => 'Street address and postal code do not match. For American Express: Card member\'s name, street address and postal code do not match.',
        'AVS_NOT_CHECKED' => 'I' # 'I' => 'Address not verified.',
      }.freeze

      DEFAULT_API_VERSION = '2020-06-25'.freeze

      STANDARD_ERROR_CODE_MAPPING = {
        'BAD_EXPIRATION' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'INVALID_ACCOUNT' => STANDARD_ERROR_CODE[:config_error],
        'CARDHOLDER_INSUFFICIENT_PERMISSIONS' => STANDARD_ERROR_CODE[:card_declined],
        'INSUFFICIENT_PERMISSIONS' => STANDARD_ERROR_CODE[:config_error],
        'INSUFFICIENT_FUNDS' => STANDARD_ERROR_CODE[:card_declined],
        'INVALID_LOCATION' => STANDARD_ERROR_CODE[:processing_error],
        'TRANSACTION_LIMIT' => STANDARD_ERROR_CODE[:card_declined],
        'CARD_EXPIRED' => STANDARD_ERROR_CODE[:expired_card],
        'CVV_FAILURE' => STANDARD_ERROR_CODE[:incorrect_cvc],
        'ADDRESS_VERIFICATION_FAILURE' => STANDARD_ERROR_CODE[:incorrect_address],
        'VOICE_FAILURE' => STANDARD_ERROR_CODE[:card_declined],
        'PAN_FAILURE' => STANDARD_ERROR_CODE[:incorrect_number],
        'EXPIRATION_FAILURE' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'INVALID_EXPIRATION' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'CARD_NOT_SUPPORTED' => STANDARD_ERROR_CODE[:processing_error],
        'INVALID_PIN' => STANDARD_ERROR_CODE[:incorrect_pin],
        'INVALID_POSTAL_CODE' => STANDARD_ERROR_CODE[:incorrect_zip],
        'CHIP_INSERTION_REQUIRED' => STANDARD_ERROR_CODE[:processing_error],
        'ALLOWABLE_PIN_TRIES_EXCEEDED' => STANDARD_ERROR_CODE[:card_declined],
        'MANUALLY_ENTERED_PAYMENT_NOT_SUPPORTED' => STANDARD_ERROR_CODE[:unsupported_feature],
        'PAYMENT_LIMIT_EXCEEDED' => STANDARD_ERROR_CODE[:processing_error],
        'GENERIC_DECLINE' => STANDARD_ERROR_CODE[:card_declined],
        'INVALID_FEES' => STANDARD_ERROR_CODE[:config_error],
        'GIFT_CARD_AVAILABLE_AMOUNT' => STANDARD_ERROR_CODE[:card_declined],
        'BAD_REQUEST' => STANDARD_ERROR_CODE[:processing_error]
      }.freeze

      def initialize(options={})
        requires!(options, :access_token)
        @access_token = options[:access_token]
        @fee_currency = options[:fee_currency] || default_currency
        super
      end

      def authorize(money, payment, options={})
        post = create_post_for_auth_or_purchase(money, payment, options)
        post[:autocomplete] = false

        commit(:post, 'payments', post, options)
      end

      def purchase(money, payment, options={})
        post = create_post_for_auth_or_purchase(money, payment, options)
        post[:autocomplete] = true

        commit(:post, 'payments', post, options)
      end

      def capture(authorization)
        commit(:post, "payments/#{authorization}/complete", {}, {})
      end

      def void(authorization, options = {})
        post = {}

        post[:reason] = options[:reason] if options[:reason]

        commit(:post, "payments/#{authorization}/cancel", post, {})
      end

      def refund(money, identification, options={})
        post = { payment_id: identification }

        add_idempotency_key(post, options)
        add_amount(post, money, options)

        post[:reason] = options[:reason] if options[:reason]

        commit(:post, 'refunds', post, options)
      end

      def show_payment(payment_id, options)
        commit(:get, "payments/#{payment_id}", nil, options)
      end

      def store(payment, options = {})
        requires!(options, :idempotency_key)

        post = {}

        add_customer(post, options)
        add_idempotency_key(post, options)

        MultiResponse.run(:first) do |r|
          r.process { commit(:post, 'customers', post, options) }

          r.process { commit(:post, "customers/#{r.params['customer']['id']}/cards", { card_nonce: payment }, options) } if r.success? && r.params && r.params['customer'] && r.params['customer']['id']
        end
      end

      def unstore(identification, options = {})
        commit(:delete, "customers/#{identification}", {}, options)
      end

      def update_customer(identification, options = {})
        post = {}
        add_customer(post, options)
        commit(:put, "customers/#{identification}", post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Bearer )\w+), '\1[FILTERED]').
          gsub(/(\\\"source_id\\\":)(\\\".*?")/, '\1[FILTERED]')
      end

      private

      def add_idempotency_key(post, options)
        post[:idempotency_key] = options[:idempotency_key] unless options.nil? || options[:idempotency_key].nil? || options[:idempotency_key].blank?
      end

      def add_amount(post, money, options)
        currency = options[:currency] || currency(money)
        post[:amount_money] = {
          amount: localized_amount(money, currency).to_i,
          currency: currency.upcase
        }
      end

      def add_application_fee(post, money, options)
        currency = options[:currency] || currency(money)
        if options[:application_fee]
          post[:app_fee_money] = {
            amount: localized_amount(money, currency).to_i,
            currency: currency.upcase
          }
        end
      end

      def add_details(post, options)
        post[:note] = options[:note] if options[:note].present?
        post[:reference_id] = options[:reference_id] if options[:reference_id].present?
        post[:location_id] = options[:location_id] if options[:location_id].present?
      end

      def create_post_for_auth_or_purchase(money, payment, options)
        post = {}

        post[:source_id] = payment
        post[:customer_id] = options[:customer] unless options[:customer].nil? || options[:customer].blank?

        add_idempotency_key(post, options)
        add_amount(post, money, options)
        add_application_fee(post, options[:application_fee], options)
        add_details(post, options)

        post
      end

      def add_customer(post, options)
        first_name = options[:billing_address][:name].split(' ')[0]
        last_name = options[:billing_address][:name].split(' ')[1] if options[:billing_address][:name].split(' ').length > 1

        post[:email_address] = options[:email] || nil
        post[:phone_number] = options[:billing_address] ? options[:billing_address][:phone] : nil
        post[:given_name] = first_name
        post[:family_name] = last_name

        post[:address] = {}
        post[:address][:address_line_1] = options[:billing_address] ? options[:billing_address][:address1] : nil
        post[:address][:address_line_2] = options[:billing_address] ? options[:billing_address][:address2] : nil
        post[:address][:locality] = options[:billing_address] ? options[:billing_address][:city] : nil
        post[:address][:administrative_district_level_1] = options[:billing_address] ? options[:billing_address][:state] : nil
        post[:address][:administrative_district_level_2] = options[:billing_address] ? options[:billing_address][:country] : nil
        post[:address][:country] = options[:billing_address] ? options[:billing_address][:country] : nil
        post[:address][:postal_code] = options[:billing_address] ? options[:billing_address][:zip] : nil
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        url = (test? ? test_url : live_url)
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, "#{url}/#{endpoint}", parameters.presence&.to_json, headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end

        return response
      end

      def commit(method, url, parameters = nil, options = {})
        response = api_request(method, url, parameters, options)
        success = success_from(response)

        card = card_from_response(response)

        avs_code = AVS_CODE_TRANSLATOR[card['avs_status']]
        cvc_code = CVC_CODE_TRANSLATOR[card['cvv_status']]

        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(success, url, method, response),
          avs_result: success ? AVSResult.new(code: avs_code) : nil,
          cvv_result: success ? CVVResult.new(cvc_code) : nil,
          error_code: success ? nil : error_code_from(response),
          test: test?
        )
      end

      def card_from_response(response)
        return {} unless response['payment']

        response['payment']['card_details'] || {}
      end

      def success_from(response)
        !response.key?('errors')
      end

      def message_from(success, response)
        success ? 'Transaction approved' : response['errors'][0]['detail']
      end

      def authorization_from(success, url, method, response)
        # errors.detail is a vague string -- returning the actual transaction ID here makes more sense
        # return response.fetch('errors', [])[0]['detail'] unless success

        return nil unless success

        if method == :post && (url == 'payments' || url.match(/payments\/.*\/complete/) || url.match(/payments\/.*\/cancel/))
          return response['payment']['id']
        elsif method == :post && url == 'refunds'
          return response['refund']['id']
        elsif method == :post && url == 'customers'
          return response['customer']['id']
        elsif method == :post && url.match(/customers\/.*\/cards/)
          return response['card']['id']
        elsif method == :put && url.match(/customers/)
          return response['customer']['id']
        elsif method == :delete && url.match(/customers/)
          return {}
        else
          return nil
        end
      end

      def error_code_from(response)
        return nil unless response['errors']

        code = response['errors'][0]['code']
        STANDARD_ERROR_CODE_MAPPING[code] || STANDARD_ERROR_CODE[:processing_error]
      end

      def api_version(options)
        options[:version] || self.class::DEFAULT_API_VERSION
      end

      def headers(options = {})
        key = options[:access_token] || @access_token

        {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{key}",
          'Square-Version' => api_version(options),
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Square API.  Please visit https://squareup.com/help if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"

        {
          'errors' => [{ 'message' => msg }]
        }
      end
    end
  end
end
