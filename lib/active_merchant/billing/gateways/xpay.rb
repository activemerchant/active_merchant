module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class XpayGateway < Gateway
      self.display_name = 'XPay Gateway'
      self.homepage_url = 'https://developer.nexi.it/en'

      self.test_url = 'https://stg-ta.nexigroup.com/api/phoenix-0.0/psp/api/v1/'
      self.live_url = 'https://xpay.nexigroup.com/api/phoenix-0.0/psp/api/v1/'

      self.supported_countries = %w(AT BE CY EE FI FR DE GR IE IT LV LT LU MT PT SK SI ES BG HR DK NO PL RO RO SE CH HU)
      self.default_currency = 'EUR'
      self.currencies_without_fractions = %w(BGN HRK DKK NOK GBP PLN CZK RON SEK CHF HUF)
      self.money_format = :cents
      self.supported_cardtypes = %i[visa master maestro american_express jcb]

      ENDPOINTS_MAPPING = {
        purchase: 'orders/2steps/payment',
        preauth: 'orders/2steps/init',
        capture: 'operations/{%s}/captures',
        verify: 'orders/card_verification',
        void: 'operations/{%s}/cancels',
        refund: 'operations/{%s}/refunds'
      }

      def initialize(options = {})
        requires!(options, :api_key)
        @api_key = options[:api_key]
        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_auth_purchase_params(post, amount, payment_method, options)
        action = options[:operation_id] ? :purchase : :preauth
        commit(action, post, options)
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        add_auth_purchase_params(post, amount, payment_method, options)
        commit(:preauth, post, options)
      end

      def capture(amount, authorization, options = {})
        post = {}
        commit(:capture, post, options)
      end

      def void(authorization, options = {})
        post = {}
        commit(:void, post, options)
      end

      def refund(amount, authorization, options = {})
        post = {}
        commit(:refund, post, options)
      end

      def verify(credit_card, options = {})
        post = {}
        add_invoice(post, 0, options)
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

      def add_invoice(post, amount, options)
        currency = options[:currency] || currency(amount)
        post[:order] = {
          orderId: options[:order_id],
          amount: localized_amount(amount, currency),
          currency: currency
        }.compact
      end

      def add_credit_card(post, payment_method)
        post[:card] = {
          pan: payment_method.number,
          expiryDate: expdate(payment_method),
          cvv: payment_method.verification_value
        }
      end

      def add_payment_method(post, payment_method)
        add_credit_card(post, payment_method) if payment_method.is_a?(CreditCard)
      end

      def add_customer_data(post, payment_method, options)
        post[:order][:customerInfo] = {
          cardHolderName: payment_method.name,
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

      def add_3ds_params(post, options)
        post[:threeDSAuthData] = { threeDSAuthResponse: options[:three_ds_auth_response] }.compact
        post[:operationId] = options[:operation_id] if options[:operation_id]
      end

      def add_auth_purchase_params(post, amount, payment_method, options)
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, payment_method, options)
        add_address(post, options)
        add_recurrence(post, options) unless options[:operation_id]
        add_exemptions(post, options)
        add_3ds_params(post, options)
      end

      def add_reference(post, authorization) end

      def add_auth_purchase(post, money, payment, options) end

      def parse(body = {})
        JSON.parse(body)
      end

      def commit(action, params, options)
        transaction_id = params.dig(:operation_id) unless action != 'capture'
        begin
          url = build_request_url(action, transaction_id)
          raw_response = ssl_post(url, params.to_json, request_headers(options))
          response = parse(raw_response)
        rescue ResponseError => e
          response = e.response.body
          response = parse(response)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def request_headers(options)
        {
          'Content-Type' => 'application/json',
          'X-Api-Key' => @api_key,
          'Correlation-Id' => options[:order_id] || SecureRandom.uuid
        }
      end

      def build_request_url(action, id = nil)
        base_url = test? ? test_url : live_url
        endpoint = ENDPOINTS_MAPPING[action.to_sym] % id
        base_url + endpoint
      end

      def success_from(response)
        response.dig('operation', 'operationResult') == 'PENDING' || response.dig('operation', 'operationResult') == 'FAILED' || response.dig('operation', 'operationResult') == 'AUTHORIZED'
      end

      def message_from(response)
        response['errors'] || response.dig('operation', 'operationResult')
      end

      def authorization_from(response)
        response.dig('operation', 'operationId') unless response
      end

      def error_code_from(response)
        response.dig('errors', 0, 'code')
      end
    end
  end
end
