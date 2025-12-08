module ActiveMerchant # :nodoc:
  module Billing # :nodoc:
    class XpayGateway < Gateway
      self.display_name = 'XPay Gateway'
      self.homepage_url = 'https://developer.nexi.it/en'

      version 'v1'

      self.test_url = "https://xpaysandbox.nexigroup.com/api/phoenix-0.0/psp/api/#{fetch_version}/"
      self.live_url = "https://xpay.nexigroup.com/api/phoenix-0.0/psp/api/#{fetch_version}/"

      self.supported_countries = %w(AT BE CY EE FI FR DE GR IE IT LV LT LU MT PT SK SI ES BG HR DK NO PL RO RO SE CH HU)
      self.default_currency = 'EUR'
      self.currencies_without_fractions = %w(BGN HRK DKK NOK GBP PLN CZK RON SEK CHF HUF)
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master maestro american_express jcb]

      ENDPOINTS_MAPPING = {
        validation: 'orders/3steps/validation',
        purchase: 'orders/3steps/payment',
        authorize: 'orders/3steps/payment',
        preauth: 'orders/3steps/init',
        capture: 'operations/%s/captures',
        verify: 'orders/card_verification',
        refund: 'operations/%s/refunds'
      }

      SUCCESS_MESSAGES = %w(PENDING AUTHORIZED THREEDS_VALIDATED EXECUTED).freeze

      def initialize(options = {})
        requires!(options, :api_key)
        @api_key = options[:api_key]
        super
      end

      def preauth(amount, credit_card, options = {})
        order_request(:preauth, amount, {}, credit_card, options)
      end

      def purchase(amount, credit_card, options = {})
        complete_order_request(:purchase, amount, credit_card, options)
      end

      def authorize(amount, credit_card, options = {})
        complete_order_request(:authorize, amount, credit_card, options)
      end

      def capture(amount, authorization, options = {})
        operation_request(:capture, amount, authorization, options)
      end

      def refund(amount, authorization, options = {})
        operation_request(:refund, amount, authorization, options)
      end

      def verify(credit_card, options = {})
        post = {}
        add_invoice(post, 0, options)
        add_customer_data(post, credit_card, options)
        add_credit_card(post, credit_card)
        commit(:verify, post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((X-Api-Key: )(\w|-)+), '\1[FILTERED]').
          gsub(%r(("pan\\?"\s*:\s*\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")\d+), '\1[FILTERED]')
      end

      private

      def validation(options = {})
        post = {}
        add_3ds_validation_params(post, options)
        commit(:validation, post, options)
      end

      def complete_order_request(action, amount, credit_card, options = {})
        MultiResponse.run do |r|
          r.process { validation(options) }
          r.process { order_request(action, amount, { captureType: (action == :authorize ? 'EXPLICIT' : 'IMPLICIT') }, credit_card, options.merge!(validation: r.params)) }
        end
      end

      def order_request(action, amount, post, credit_card, options = {})
        add_invoice(post, amount, options)
        add_credit_card(post, credit_card)
        add_customer_data(post, credit_card, options)
        add_address(post, options)
        add_recurrence(post, options) unless options[:operation_id]
        add_exemptions(post, options)
        add_3ds_params(post, options[:validation]) if options[:validation]

        commit(action, post, options)
      end

      def operation_request(action, amount, authorization, options)
        options[:correlation_id], options[:reference] = authorization.split('#')
        commit(action, { amount:, currency: options[:currency] }, options)
      end

      def add_invoice(post, amount, options)
        currency = options[:currency] || currency(amount)
        post[:order] = {
          orderId: options[:order_id],
          amount: localized_amount(amount, currency),
          currency:
        }.compact
      end

      def add_credit_card(post, credit_card)
        post[:card] = {
          pan: credit_card.number,
          expiryDate: expdate(credit_card),
          cvv: credit_card.verification_value
        }
      end

      def add_customer_data(post, credit_card, options)
        post[:order][:customerInfo] = {
          cardHolderName: credit_card.name,
          cardHolderEmail: options[:email]
        }.compact
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:order][:customerInfo][:billingAddress] = {
            name: address[:name],
            street: address[:address1],
            additionalInfo: address[:address2],
            city: address[:city],
            postCode: address[:zip],
            country: address[:country]
          }.compact
        end

        if address = options[:shipping_address]
          post[:order][:customerInfo][:shippingAddress] = {
            name: address[:name],
            street: address[:address1],
            additionalInfo: address[:address2],
            city: address[:city],
            postCode: address[:zip],
            country: address[:country]
          }.compact
        end
      end

      def add_recurrence(post, options)
        post[:recurrence] = { action: options[:recurrence] || 'NO_RECURRING' }
      end

      def add_exemptions(post, options)
        post[:exemptions] = options[:exemptions] || 'NO_PREFERENCE'
      end

      def add_3ds_params(post, validation)
        post[:threeDSAuthData] = {
          authenticationValue: validation['threeDSAuthResult']['authenticationValue'],
          eci: validation['threeDSAuthResult']['eci'],
          xid: validation['threeDSAuthResult']['xid']
        }
        post[:operationId] = validation['operation']['operationId']
      end

      def add_3ds_validation_params(post, options)
        post[:operationId] = options[:operation_id]
        post[:threeDSAuthResponse] = options[:three_ds_auth_response]
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, params, options)
        options[:correlation_id] ||= SecureRandom.uuid
        transaction_id = transaction_id_from(params, options, action)
        raw_response =
          begin
            url = build_request_url(action, transaction_id)
            ssl_post(url, params.to_json, request_headers(options, action))
          rescue ResponseError => e
            { errors: [code: e.response.code, description: e.response.body] }.to_json
          end
        response = parse(raw_response)

        Response.new(
          success_from(action, response),
          message_from(response),
          response,
          authorization: authorization_from(options[:correlation_id], response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def request_headers(options, action = nil)
        headers = { 'X-Api-Key' => @api_key, 'Content-Type' => 'application/json', 'Correlation-Id' => options[:correlation_id] }
        headers.merge!('Idempotency-Key' => options[:idempotency_key] || SecureRandom.uuid) if %i[capture refund].include?(action)
        headers
      end

      def transaction_id_from(params, options, action = nil)
        case action
        when :refund, :capture
          return options[:reference]
        else
          return params[:operation_id]
        end
      end

      def build_request_url(action, id = nil)
        "#{test? ? test_url : live_url}#{ENDPOINTS_MAPPING[action.to_sym] % id}"
      end

      def success_from(action, response)
        case action
        when :capture, :refund
          response.include?('operationId') && response.include?('operationTime')
        else
          SUCCESS_MESSAGES.include?(response.dig('operation', 'operationResult'))
        end
      end

      def message_from(response)
        response['operationId'] || response.dig('operation', 'operationResult') || response.dig('errors', 0, 'description')
      end

      def authorization_from(correlation_id, response = {})
        [correlation_id, (response['operationId'] || response.dig('operation', 'operationId'))].join('#')
      end

      def error_code_from(response)
        response.dig('errors', 0, 'code')
      end
    end
  end
end
