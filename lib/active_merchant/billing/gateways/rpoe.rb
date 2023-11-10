module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class RpoeGateway < Gateway
      self.test_url = 'https://example.com/test'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ["US", "CA"]
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club, :jcb]

      self.homepage_url = 'http://www.example.net/'
      self.display_name = 'RPOE Gateway'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :merchant_id)
        requires!(options, :login, :password) unless options[:ip_authentication]
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize_params(options={})
        RPOE::TokenizationRequest.new(
          full_name: options[:given_family],
          card_number: options[:credit_card_account_number],
          cvv: options[:verification_value],
          expiry_date: options[:expiry_date],
          payment_method: 'CC',
          retain_card: false,
          eligible_for_card_updater: false,
          billing_address: {
            address_line_1: options[:street_address],
            address_line_2: options[:extended_addresses],
            city: options[:locality],
            state: options[:region],
            zip_code: options[:postal_code],
            country: options[:country_code],
            phone_number: options[:billing_phone]
          }
        ).as_json
      end

      def authorize(money, payment, options={})
        post = {}
        post.merge(authorize_params(options[:rpoe_auth] || {}))

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        post = {}
        post.merge(authorize_params(options[:rpoe_capture] || {}))

        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      def parse(body)
        JSON.parse(body)
      end

      def one_of_test_url(action)
        if action == 'authonly'
          URI("https://guse4-pmtmidtiergw-qaa.dqs.pcln.com/paymenttransactionalapi/pay")
        elsif action == 'capture'
          URI("https://guse4-pmtmidtiergw-qaa.dqs.pcln.com/paymenttransactionalapi/capture")
        end
      end

      def one_of_live_url(action)

      end

      def commit(action, parameters)
        url = (test? ? one_of_test_url(action) : one_of_live_url(action))
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response.dig('payment_details', 'avs_code')),
          cvv_result: CVVResult.new('M'),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response.dig('summary', 'response_code') == "100" || response["status"] == "SUCCESS"
      end

      def message_from(response)
        response["error_messages"]
      end

      def authorization_from(response)
        response.dig('summary', 'payment_details', 'payment_method_token')
      end

      def post_data(action, parameters = {})
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
