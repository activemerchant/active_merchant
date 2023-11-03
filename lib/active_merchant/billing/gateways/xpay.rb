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

      def capture(amount, authorization, options = {})
        commit('capture', options)
      end

      def void(authorization, options = {})
        post = {}
        commit('void', post)
      end

      def refund(amount, authorization, options = {})
        post = {}
        commit('refund', post)
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_auth_purchase_params(post, amount, payment_method, options)
        commit('preauth', post)
      end

      def verify(credit_card, options = {})
        post = {}
        add_invoice(post, 0, options)
        add_credit_card(post, credit_card)
        commit('verify', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript) end

      private

      def add_invoice(post, amount, options)
        currency = options[:currency] || currency(amount)
        post[:order] = {}
        post[:order][:orderId] = options[:order][:order_id]
        post[:order][:amount] = localized_amount(amount, currency)
        post[:order][:currency] = currency
      end

      def add_credit_card(post, payment_method)
        post[:card] = {}
        post[:card][:pan] = payment_method.number
        post[:card][:expiryDate] = "#{format(payment_method.month, :two_digits)}#{format(payment_method.year, :two_digits)}"
        post[:card][:cvv] = payment_method.verification_value
      end

      def add_payment_method(post, payment_method)
        add_credit_card(post, payment_method) if payment_method.is_a?(CreditCard)
      end

      def add_customer_data(post, payment_method, options)
        post[:order][:customerInfo] = {}
        card_holder_name = "#{payment_method.try(:first_name)} #{payment_method.try(:last_name)}"
        post[:order][:customerInfo][:cardHolderName] = card_holder_name
        post[:order][:customerInfo][:cardHolderEmail] = options[:email] if options[:email]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:order][:customerInfo][:billingAddress] = {}
          post[:order][:customerInfo][:billingAddress][:name] = address[:name] if address[:name]
          post[:order][:customerInfo][:billingAddress][:street] = address[:address1] if address[:address1]
          post[:order][:customerInfo][:billingAddress][:additionalInfo] = address[:address2] if address[:address2]
          post[:order][:customerInfo][:billingAddress][:city] = address[:city] if address[:city]
          post[:order][:customerInfo][:billingAddress][:postCode] = address[:zip] if address[:zip]
          post[:order][:customerInfo][:billingAddress][:country] = address[:country] if address[:country]
        end

        if address = options[:shipping_address]
          post[:order][:customerInfo][:shippingAddress] = {}
          post[:order][:customerInfo][:shippingAddress][:name] = address[:name] if address[:name]
          post[:order][:customerInfo][:shippingAddress][:street] = address[:address1] if address[:address1]
          post[:order][:customerInfo][:shippingAddress][:additionalInfo] = address[:address2] if address[:address2]
          post[:order][:customerInfo][:shippingAddress][:city] = address[:city] if address[:city]
          post[:order][:customerInfo][:shippingAddress][:postCode] = address[:zip] if address[:zip]
          post[:order][:customerInfo][:shippingAddress][:country] = address[:country] if address[:country]
        end
        post
      end

      def add_recurrence(post, options)
        post[:recurrence] = { action: options[:recurrence] || 'NO_RECURRING' }
      end

      def add_excemptions(post, options)
        post[:exemptions] = options[:exemptions] || 'NO_PREFERENCE'
      end

      def add_3ds(post, payment, options)
        post[:threeDSAuthResponse] = ''
        post[:authenticationValue] = ''
        post[:eci] = ''
        post[:xid] = ''
      end

      def add_auth_purchase_params(post, amount, payment_method, options)
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, payment_method, options)
        add_address(post, options)
        add_recurrence(post, options)
        add_excemptions(post, options)
      end

      def commit(action, params)
        transaction_id = params.dig(:operation_id) unless action != 'capture'
        begin
          url = build_request_url(action, transaction_id)
          response = JSON.parse(ssl_post(url, params.to_json, request_headers(params)))
        rescue ResponseError => e
          response = e.response.body
          response = JSON.parse(response)
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

      def request_headers(params)
        headers = {
          'Content-Type' => 'application/json',
          'X-Api-Key' => @api_key,
          'Correlation-Id' => SecureRandom.uuid
        }
        headers
      end

      def build_request_url(action, id = nil)
        base_url = test? ? test_url : live_url
        endpoint = ENDPOINTS_MAPPING[action.to_sym] % id
        base_url + endpoint
      end

      def success_from(response)
        response.dig('operation', 'operationResult') == 'PENDING'
      end

      def message_from(response)
        if response.include? 'errors'
          response['errors']
        else
          response.dig('operation', 'operationResult')
        end
      end

      def authorization_from(response)
        response.dig('operation', 'operationId') unless response
      end

      def error_code_from(response)
        response['errors'].first.dig('code') unless success_from(response)
      end
    end
  end
end
