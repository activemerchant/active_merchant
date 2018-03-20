# frozen-string-literal: true

module ActiveMerchant  #:nodoc: ALL
  module Billing
    class AurusGateway < Gateway
      self.test_url = 'https://localhost:8080/auruspay/aesdk'
      self.live_url = 'https://%<server>s:%<port>s/auruspay/aesdk'

      self.default_currency     = 'USD'
      self.display_name         = 'Aurus Payment Gateway'
      self.homepage_url         = 'http://aurusinc.com'
      self.money_format         = :dollars
      self.supported_countries  = %w[CA US]
      self.supported_cardtypes  = %i[visa master american_express jcb discover]

      # Actions
      CLOSE_TRANSACTION_REQ = :CloseTransactionRequest
      GET_STATUS_REQ        = :GetStatusRequest
      TRANSACTION_REQ       = :TransRequest

      # Endpoints
      INIT_ENDPOINT              = 'initaesdk'
      TRANSACTION_ENDPOINT       = 'authtransaction'
      CLOSE_TRANSACTION_ENDPOINT = 'closeTransaction'

      # Transaction codes
      PURCHASE  = '01'
      REFUND    = '02'
      AUTHORIZE = '04' # Pre-Auth
      CAPTURE   = '05' # Post-Auth
      VOID      = '06'

      STANDARD_ERROR_CODE_MAPPING = {}.freeze

      def initialize(options = {})
        requires!(options, :server_dns, :server_port)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit(TRANSACTION_REQ, TRANSACTION_ENDPOINT, post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit(TRANSACTION_REQ, TRANSACTION_ENDPOINT, post)
      end

      def capture(_money, _authorization, _options = {})
        post = {}
        commit(TRANSACTION_REQ, TRANSACTION_ENDPOINT, post)
      end

      def refund(_money, _authorization, _options = {})
        post = {}
        commit(TRANSACTION_REQ, TRANSACTION_ENDPOINT, post)
      end

      def void(_authorization, _options = {})
        post = {}
        commit(TRANSACTION_REQ, TRANSACTION_ENDPOINT, post)
      end

      def verify(credit_card, options = {})
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

      def add_customer_data(_post, _options); end

      def add_address(_post, _creditcard, _options); end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(_post, _payment); end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body)
      end

      def api_request(endpoint, action, parameters = nil)
        raw_response = response = nil
        begin
          endpoint = '/' + endpoint if endpoint&.size&.positive?
          raw_response = ssl_post(target_url + endpoint, post_data(action, parameters), headers(parameters))
          response = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        response
      end

      def commit(endpoint, action, parameters)
        response = api_request(endpoint, action, parameters)

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

      def success_from(_response); end

      def message_from(_response); end

      def authorization_from(_response); end

      def post_data(action, parameters = {}); end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

      def headers(_options = {})
        {
          'Content-Type': 'application/json',
          'User-Agent':   "Aurus/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end

      def post_data(action, parameters = {})
        post = {}
        post[action] = parameters

        JSON.generate(post)
      end

      def target_url
        format(live_url, server: @options[:server_dns], port: @options[:server_port])
      end

    end
  end
end
