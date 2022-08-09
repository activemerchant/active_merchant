module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AleloGateway < Gateway
      self.test_url = 'https://sandbox-desenvolvedor.alelo.com.br'
      self.live_url = 'https://desenvolvedor.alelo.com.br'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.alelo.com.br'
      self.display_name = 'Alelo'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :access_token)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options = {})
        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        commit('refund', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options); end

      def add_address(post, creditcard, options); end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment); end

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
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response); end

      def message_from(response); end

      def authorization_from(response); end

      def post_data(action, parameters = {}); end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
