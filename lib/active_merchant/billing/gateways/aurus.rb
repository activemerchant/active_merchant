# frozen-string-literal: true

module ActiveMerchant  #:nodoc: ALL
  module Billing
    class AurusGateway < Gateway
      self.test_url = 'http://localhost:8080/auruspay/aesdk'
      self.live_url = 'http://live.auruspay.com/auruspay/aesdk'

      self.default_currency     = 'USD'
      self.display_name         = 'Aurus Payment Gateway'
      self.homepage_url         = 'http://aurusinc.com'
      self.money_format         = :dollars
      self.supported_countries  = %w[CA US]
      self.supported_cardtypes  = %i[visa master american_express jcb discover]

      # Actions
      CLOSE_TRANSACTION_REQ = :CloseTransaction
      GET_STATUS_REQ        = :GetStatus
      INIT_AESDK_REQ        = :InitAesdk
      TRANSACTION_REQ       = :Trans

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

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :merchant_id, :terminal_id)
        Gateway.logger = Logger.new(STDOUT)
        Gateway.logger.level = Logger::DEBUG
        super
      end

      def purchase(money, payment, options = {}); end

      def authorize(money, payment, options = {}); end

      def capture(_money, _authorization, _options = {}); end

      def refund(_money, _authorization, _options = {}); end

      def void(_authorization, _options = {}); end

      def verify(credit_card, options = {}); end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def action_request(action)
        (action.to_s + 'Request').to_sym
      end

      def action_response(action)
        action.to_s + 'Response'
      end

      def add_customer_data(_post, _options); end

      def add_address(_post, _creditcard, _options); end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(_post, _payment); end

      def parse(body, action)
        return {} if body.blank?
        response = JSON.parse(body)
        raise ResponseError.new(body) unless response[action_response(action)].present?
        response[action_response(action)]
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the Aurus API.'
        msg + "  (The raw response returned by the API was #{raw_response.inspect})"
        {
          'Status'       => STATUS_FAIL,
          'ResponseCode' => STANDARD_ERROR_CODE[:processing_error],
          'ResponseText' => msg
        }
      end

      def response_error(raw_response, action)
        parse(raw_response, action)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def api_request(endpoint, action, parameters = nil)
        raw_response = response = nil
        begin
          endpoint = '/' + endpoint if endpoint&.size&.positive?
          raw_response = ssl_post(target_url + endpoint, post_data(action, parameters), headers(parameters))
          response = parse(raw_response, action)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response, action)
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
          authorization: authorization_from(action, response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(_response)
        true # TODO: fix this!
      end

      def message_from(_response); end

      def authorization_from(action, response)
        case action
        when TRANSACTION_REQ
          response['TransactionIdentifier']
        else
          'OK' # TODO: flesh out for other calls
        end
      end

      def post_data(action, parameters = {}); end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end

      def headers(_options = {})
        {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'User-Agent':   "Aurus/v1 ActiveMerchantBindings/#{ActiveMerchant::VERSION}"
        }
      end

      def post_data(action, parameters = {})
        post = {}
        post[action_request(action)] = parameters

        JSON.generate(post)
      end

      def target_url
        test? ? self.test_url : self.live_url
      end

    end
  end
end
