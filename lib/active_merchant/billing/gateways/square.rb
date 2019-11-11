module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SquareGateway < Gateway
      self.test_url = 'https://connect.squareupsandbox.com/v2'
      self.live_url = 'https://connect.squareup.com/v2'

      self.supported_countries = ['US', 'CA', 'GB', 'AU', 'JP']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :union_pay]
      self.money_format = :cents

      self.homepage_url = 'https://squareup.com/'
      self.display_name = 'Square Payments Gateway'

      DEFAULT_API_VERSION = '2019-10-23'

      STANDARD_ERROR_CODE_MAPPING = {
        'BAD_EXPIRATION' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'INVALID_ACCOUNT' => STANDARD_ERROR_CODE[:config_error],
        'CARDHOLDER_INSUFFICIENT_PERMISSIONS' => STANDARD_ERROR_CODE[:card_declined],
        'INSUFFICIENT_PERMISSIONS' => STANDARD_ERROR_CODE[:config_error],
        'INSUFFICIENT_FUNDS' => STANDARD_ERROR_CODE[:card_declined],
        'INVALID_LOCATION' => STANDARD_ERROR_CODE[:processing_error],
        'TRANSACTION_LIMIT' => STANDARD_ERROR_CODE[:card_declined],
        'CARD_EXPIRED' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'CVV_FAILURE' => STANDARD_ERROR_CODE[:card_declined],
        'ADDRESS_VERIFICATION_FAILURE' => STANDARD_ERROR_CODE[:processing_error],
        'VOICE_FAILURE' => STANDARD_ERROR_CODE[:card_declined],
        'PAN_FAILURE' => STANDARD_ERROR_CODE[:incorrect_number],
        'EXPIRATION_FAILURE' => STANDARD_ERROR_CODE[:invalid_expiry_date],
        'CARD_NOT_SUPPORTED' => STANDARD_ERROR_CODE[:processing_error],
        'INVALID_PIN' => STANDARD_ERROR_CODE[:incorrect_pin],
        'INVALID_POSTAL_CODE' => STANDARD_ERROR_CODE[:incorrect_zip],
        'CHIP_INSERTION_REQUIRED' => STANDARD_ERROR_CODE[:processing_error],
        'ALLOWABLE_PIN_TRIES_EXCEEDED' => STANDARD_ERROR_CODE[:card_declined],
        'MANUALLY_ENTERED_PAYMENT_NOT_SUPPORTED' => STANDARD_ERROR_CODE[:unsupported_feature],
        'PAYMENT_LIMIT_EXCEEDED' => STANDARD_ERROR_CODE[:processing_error],
        'GENERIC_DECLINE' => STANDARD_ERROR_CODE[:card_declined],
        'INVALID_FEES' => STANDARD_ERROR_CODE[:config_error],
        'GIFT_CARD_AVAILABLE_AMOUNT' => STANDARD_ERROR_CODE[:card_declined]
      }

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

      # To create a charge on a card or a token, call
      #
      #   purchase(money, card_hash_or_token, { ... })
      #
      # To create a charge on a customer, call
      #
      #   purchase(money, nil, { :customer => id, ... })
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

        commit(:post, "refunds", post, options)
      end

      def store(payment, options = {})
        customer_post = options[:customer]

        add_idempotency_key(customer_post, options)

        response = {}

        MultiResponse.run do |r|
          r.process { commit(:post, "customers", customer_post, options) }
          customer_id = r.params['customer']['id']

          response[:customer] = r.params['customer']

          customer_card_post = create_post_for_customer_card(options[:customer], payment)
          add_customer(customer_card_post, customer_id)

          r.process { commit(:post, "customers/#{customer_id}/cards", customer_card_post, options) }

          response[:card] = r.params['card']
        end

        return Response.new(true, nil, response)
      end

      def unstore(identification, options = {})
        commit(:delete, "customers/#{identification}", {}, options)
      end

      def update_customer(customer_id, options = {})
        # commit(:post, "customers/#{CGI.escape(customer_id)}", options, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_idempotency_key(post, options)
        post[:idempotency_key] = options[:idempotency_key]
      end

      def add_amount(post, money, options)
        currency = options[:currency] || currency(money)
        post[:amount_money] = {
          amount: localized_amount(money, currency).to_i,
          currency: currency.upcase
        }
      end

      def add_application_fee(post, options)
        post[:app_fee_money] = localized_amount(options[:application_fee], @fee_currency).to_i if options[:application_fee]
      end

      def add_nonce_source(post, nonce)
        post[:source_id] = nonce
      end

      def add_customer_source(post, options = {})
        post[:source_id] = options[:customer][:source_id]
        post[:customer_id] = options[:customer][:id]
      end

      def add_charge_details(post, money, payment, options)

        add_idempotency_key(post, options)
        add_amount(post, money, options)
        add_application_fee(post, options)

        return post
      end

      def add_customer(post, identification)
        post[:customer_id] = identification
      end

      def create_post_for_auth_or_purchase(money, payment, options)
        post = {}

        if options[:customer]
          add_customer_source(post, options[:customer])
        else
          add_nonce_source(post, payment)
        end

        add_charge_details(post, money, payment, options)

        return post
      end

      def create_post_for_customer_card(customer, payment)
        post = {
          card_nonce: payment,
          billing_address: customer[:address] ? customer[:address] : {},
          cardholder_name: "#{customer[:given_name]} #{customer[:family_name]}"
        }

        return post
      end

      def api_request(method, endpoint, parameters = nil, options = {})
        url = (test? ? test_url : live_url)
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, "#{url}/#{endpoint}", parameters.to_json, headers(options))
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
        avs_code = card['avs_status']
        cvc_code = card['cvv_status']

        Response.new(
          success,
          message_from(success, response),
          response,
          authorization: authorization_from(success, url, method, response),
          avs_result: success ? { :code => avs_code } : nil,
          cvv_result: success ? cvc_code : nil,

          test: test?,
          error_code: error_code_from(response)
        )
      end

      def card_from_response(response)
        return {} unless response['payment']

        return response['payment']['card_details'] || {}
      end

      def success_from(response)
        return true unless response['errors']
      end

      def message_from(success, response)
        return success ? 'Transaction approved' : response['errors'][0]['detail']
      end

      def authorization_from(success, url, method, response)
        return response.fetch('errors', [])[0]['detail'] unless success

        if method == :post && (url == 'payments' || url.match(/payments\/.*\/complete/) || url.match(/payments\/.*\/cancel/))
          return response['payment']['id']
        elsif method == :post && url == 'refunds'
          return response['refund']['id']
        elsif method == :post && url == 'customers'
          return response['customer']['id']
        elsif method == :post && (url.match(/customers\/.*\/cards/))
          return response['card']['id']
        elsif method == :delete && (url.match(/customers/))
          return {}
        else
          return nil
        end
      end

      def error_code_from(response)
        return nil unless response['errors']

        code = response['errors'][0]['code']
        return STANDARD_ERROR_CODE_MAPPING[code]
      end

      def api_version(options)
        return options[:version] || self.class::DEFAULT_API_VERSION
      end

      def headers(options = {})
        key = options[:access_token] || @access_token

        return {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{key}",
          'Square-Version' => api_version(options),
        }
      end

      def parse(body)
        return JSON.parse(body)
      end

      def response_error(raw_response)
        return parse(raw_response)
      rescue JSON::ParserError
        return json_error(raw_response)
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Square API.  Please visit https://squareup.com/help if you continue to receive this message.'
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"

        return {
          'errors' => [ { 'message' => msg } ]
        }
      end
    end
  end
end
