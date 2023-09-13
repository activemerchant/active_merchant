require 'nokogiri'

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
        authorize: 'orders/2steps/init',
        capture: 'captures',
        verify: 'orders/card_verification',
        void: 'cancels',
        refund: 'refunds'
      }

      def initialize(options = {})
        requires!(options, :api_key)
        @api_key = options[:api_key]
        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        commit('purchase', post, options)
      end

      def authorize(amount, payment_method, options = {})
        requires!(options, :order_id)
        post = {}
        add_auth_purchase_params(post, amount, payment_method, options)
        commit('authorize', post, options)
      end

      def capture(amount, authorization, options = {})
        post = {}
        commit('capture', post, options)
      end

      def void(authorization, options = {})
        post = {}
        commit('void', post, options)
      end

      def refund(amount, authorization, options = {})
        post = {}
        commit('refund', post, options)
      end

      def verify(credit_card, options = {})
        post = {}
        commit('verify', post, options)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript) end

      private

      def add_invoice(post, amount, options)
        post[:order] = {}
        post[:order][:orderId] = options[:order_id]
        post[:order][:amount] = amount(amount)
        post[:order][:currency] = (options[:currency] || currency(amount))
      end

      def add_customer_data(post, payment_method, options)
        post[:customerInfo] = {}
        card_holder_name = "#{payment_method.try(:first_name)} #{payment_method.try(:last_name)}"
        post[:customerInfo][:cardHolderName] = card_holder_name
        post[:customerInfo][:cardHolderEmail] = options[:email]
      end

      def add_address(post, options)
        if address = options[:billing_address] || options[:address]
          post[:billingAddress] = {}
          post[:billingAddress][:name] = address[:name] if address[:name]
          post[:billingAddress][:street] = address[:address1] if address[:address1]
          post[:billingAddress][:additionalInfo] = address[:address2] if address[:address2]
          post[:billingAddress][:city] = address[:city] if address[:city]
          post[:billingAddress][:postCode] = address[:zip] if address[:zip]
          post[:billingAddress][:country] = address[:country] if address[:country]
        end

        if address = options[:shipping_address]
          post[:shippingAddress] = {}          
          post[:shippingAddress][:name] = address[:name] if address[:name]
          post[:shippingAddress][:street] = address[:address1] if address[:address1]
          post[:shippingAddress][:additionalInfo] = address[:address2] if address[:address2]
          post[:shippingAddress][:city] = address[:city] if address[:city]
          post[:shippingAddress][:postCode] = address[:zip] if address[:zip]
          post[:shippingAddress][:country] = address[:country] if address[:country]
        end
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

      def add_reference(post, authorization) end

      def add_auth_purchase_params(post, amount, payment_method, options)
        add_invoice(post, amount, options)        
        add_address(post, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, payment_method, options)
      end

      def commit(action, params, options)        
        begin
          url = build_request_url(action)
          response = ssl_post(url, params.to_json, request_headers(params))
        rescue ResponseError => e
          response = e.response.body
          response = JSON.parse(response)
        end        

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_result_key']),
          cvv_result: CVVResult.new(response['some_cvv_result_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def request_headers(post)
        timestamp = Time.now.utc.iso8601.gsub(':', '-')
        headers = {
          'Content-Type' => 'application/json',
          'X-Api-Key' => @api_key,
          'Correlation-Id' => @api_key + timestamp
        }
        headers
      end

      def build_request_url(action, id = nil)
        base_url = (test? ? test_url : live_url)
        endpoint = ENDPOINTS_MAPPING[action.to_sym].to_s
        endpoint = id.present? ? '/operations/' + endpoint % { id: id } : endpoint
        base_url + endpoint
      end

      def success_from(response)
        response.include? 'errors' ? false : true
      end

      def message_from(response)
        if response.include? 'errors'
          response['errors']
        else
          'Succeeded'
        end
      end

      def authorization_from(response)
        response.dig('latest_payment_attempt', 'payment_intent_id')
      end

      def error_code_from(response)
        response['provider_original_response_code'] || response['code'] unless success_from(response)
      end
    end
  end
end
