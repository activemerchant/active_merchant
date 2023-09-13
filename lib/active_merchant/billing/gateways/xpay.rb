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
        post = {}
        add_auth_purchase(post, money, payment, options)
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

      def add_invoice(post, money, options) end

      def add_payment_method(post, payment_method) end

      def add_reference(post, authorization) end

      def add_auth_purchase(post, money, payment, options) end

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
          authorization: authorization_from,
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
        response == 'SUCCESS'
      end

      def message_from(succeeded, response)
        if succeeded
          'Succeeded'
        else
          response[:some_key]
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
