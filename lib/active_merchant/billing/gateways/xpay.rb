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
        authorize: 'orders/2steps/payment',
        preauth: 'orders/2steps/init',
        capture: 'operations/%s/captures',
        verify: 'orders/card_verification',
        void: 'operations/%s/cancels',
        refund: 'operations/%s/refunds'
      }

      def initialize(options = {})
        requires!(options, :api_key)
        @api_key = options[:api_key]
        super
      end

      def preauth(amount, payment_method, options = {})
        post = {}
        add_transaction_params_commit(:preauth, amount, post, payment_method, options)
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_transaction_params_commit(:purchase, amount, post, payment_method, options)
      end

      def authorize(amount, payment_method, options = {})
        post = {}
        add_transaction_params_commit(:authorize, amount, post, payment_method, options)
      end

      def capture(amount, authorization, options = {})
        post = {}
        add_refund_capture_params(amount, post, options)
        commit(:capture, post, options)
      end

      def void(authorization, options = {})
        post = { description: options[:description] }
        commit(:void, post, options)
      end

      def refund(amount, authorization, options = {})
        post = {}
        add_refund_capture_params(amount, post, options)
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

      def add_transaction_params_commit(action, amount, post, payment_method, options = {})
        add_capture_type(post, options, action)
        add_auth_purchase_params(post, amount, payment_method, options)
        commit(action, post, options)
      end

      def add_capture_type(post, options, action)
        case action
        when :purchase
          post[:captureType] = 'IMPLICIT'
        when :authorize
          post[:captureType] = 'EXPLICIT'
        end
      end

      def add_refund_capture_params(amount, post, options)
        post[:amount] = amount
        post[:currency] = options[:order][:currency]
        post[:description] = options[:order][:description]
      end

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

      def parse(body = {})
        JSON.parse(body)
      end

      def commit(action, params, options)
        transaction_id = transaction_id_from(params, options, action)
        begin
          url = build_request_url(action, transaction_id)
          raw_response = ssl_post(url, params.to_json, request_headers(options, action))
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

      def request_headers(options, action = nil)
        headers = {
          'X-Api-Key' => @api_key,
          'Correlation-Id' => options.dig(:order_id) || SecureRandom.uuid,
          'Content-Type' => 'application/json'
        }
        case action
        when :refund, :capture
          headers.merge!('Idempotency-Key' => SecureRandom.uuid)
        end
        headers
      end

      def transaction_id_from(params, options, action = nil)
        case action
        when :refund, :capture, :void
          return options[:operation_id]
        else
          return params[:operation_id]
        end
      end

      def build_request_url(action, id = nil)
        base_url = test? ? test_url : live_url
        endpoint = ENDPOINTS_MAPPING[action.to_sym] % id
        base_url + endpoint
      end

      def success_from(response)
        response.dig('operation', 'operationResult') == 'PENDING' || response.dig('operation', 'operationResult') == 'AUTHORIZED'
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
