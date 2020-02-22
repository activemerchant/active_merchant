module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AwesomesauceGateway < Gateway
      self.test_url = 'https://awesomesauce-staging.herokuapp.com'
      self.live_url = 'https://awesomesauce-prod.herokuapp.com'

      self.supported_countries = ['US', 'GB']
      self.default_currency = 'USD'
      self.money_format = :dollars 
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'https://awesomesauce-staging.herokuapp.com/'
      self.display_name = 'Awesomesauce'

      STANDARD_ERROR_CODE_MAPPING = {
        '01' => STANDARD_ERROR_CODE_MAPPING[:card_declined]
        '02' => STANDARD_ERROR_CODE_MAPPING[:invalid_number]
        '03' => STANDARD_ERROR_CODE_MAPPING[:expired_card]
        '10' => STANDARD_ERROR_CODE_MAPPING[:processing_error]
      }

      def initialize(options={})
        requires!(options, :merchant, :secret)
        super
      end

      def purchase(amount, payment, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(amount, payment, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(amount, authorization, options={})
        commit('capture', post)
      end

      def refund(amount, authorization, options={})
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

      def add_invoice(post, amount, options)
        post[:amount] = amount(amount)
        post[:currency] = (options[:currency] || currency(amount))
      end

      def add_payment(post, payment)
      end

      def parse(body)
        {}
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
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
