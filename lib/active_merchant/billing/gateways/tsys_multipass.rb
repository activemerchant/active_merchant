require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class TsysMultipassGateway < Gateway
      self.display_name = 'TSYS Multipass'
      self.homepage_url = 'https://www.tsys.com'
      self.test_url     = 'https://stagegw.transnox.com/servlets/TransNox_API_Server'
      self.live_url     = 'https://gateway.transit-pass.com/servlets/TransNox_API_Server/'

      self.supported_countries = ['US']
      self.default_currency    = 'USD'
      self.money_format        = :cents
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :diners_club]

      EMPTY_OBJ = {}
      BLANK = ''
      CONTENT_TYPE = 'application/json'

      WHITELISTED_RESPONSE_ROOT_KEYS = %w(
        SaleResponse
        AuthResponse
        CaptureResponse
        VoidResponse
        ReturnResponse
        CardAuthenticationResponse
      )

      attr_reader :response, :parsed_body

      def initialize(options={})
        requires!(options, :multipass_device_id, :transaction_key)
        super
      end

      def purchase(money, credit_card, options = {})
        commit(
          request_body: { "Sale": request_params(options) }.to_json
        )
      end

      def authorize(money, credit_card, options = {})
        req_body = { "Auth": request_params(options) }.to_json
        commit(
          request_body: req_body 
        )
      end

      def capture(money, tx_reference, options = {})
        req_body = { "Capture": request_params(options) }.to_json
        commit(
          request_body: req_body 
        )
      end

      def void(tx_reference, options = {})
        req_body = { "Void": request_params(options) }.to_json
        commit(
          request_body: req_body
        )
      end

      def refund(money, tx_reference, options = {})
        req_body = { "Return": request_params(options) }.to_json
        commit(
          request_body: req_body
        )
      end

      def avs_check(options = {})
        req_body = { "CardAuthentication": request_params(options) }.to_json
        commit(
          request_body: req_body
        )
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/\"deviceID\":\K(?:(?!,).)*/, '[FILTERED]').
          gsub(/\"transactionKey\":\K(?:(?!,).)*/, '[FILTERED]').
          gsub(/\"cardNumber\":\K(?:(?!,).)*/, '[FILTERED]').
          gsub(/\"expirationDate\":\K(?:(?!,).)*/, '[FILTERED]').
          gsub(/\"token\":\K(?:(?!,).)*/, '[FILTERED]')
      end

      private

      def request_params(options)
        {
          "deviceID": @options[:multipass_device_id],
          "transactionKey": @options[:transaction_key]
        }.merge!(options)
      end

      def commit(request_body:)
        @response =
          Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |https|
            request      = Net::HTTP::Post.new(uri, {'Content-Type' => CONTENT_TYPE })
            request.body = request_body
            # Making the call
            https.request(request)
          end
        
        # Parsing the response body
        @parsed_body = parse(response.body)

        Response.new(
          success?,
          message,
          parsed_body,
          amount: amount,
          error_code: error_code,
          authorization: authorization,
          avs_result: avs_result_code,
          test: test?
        )
      end

      def success?
        return false unless recognized_response_root_key?

        parsed_body_root_value['status'] == 'PASS'
      end

      def message
        return BLANK unless recognized_response_root_key?

        parsed_body_root_value['responseMessage']
      end

      def avs_result_code
        return BLANK unless recognized_response_root_key?

        AVSResult.new(code: (parsed_body_root_value['addressVerificationCode'] || BLANK))
      end

      def error_code
        return BLANK unless error?

        response_code
      end

      def error?
        !response_code.start_with?('A')
      end

      def response_code
        return BLANK unless recognized_response_root_key?

        parsed_body_root_value['responseCode']
      end

      def authorization
        return BLANK unless recognized_response_root_key?

        parsed_body_root_value['transactionID']
      end

      def amount
        return BLANK unless recognized_response_root_key?

        parsed_body_root_value[amount_key_mapping[parsed_body_root_key]]
      end

      # This method gives us mapping of which amount field to
      # fetch based on the transaction response types.
      def amount_key_mapping
        {
          'SaleResponse' => 'processedAmount',
          'AuthResponse' => 'processedAmount',
          'CaptureResponse' => 'transactionAmount',
          'VoidResponse' => 'voidedAmount',
          'ReturnResponse' => 'returnedAmount'
        }
      end

      def recognized_response_root_key?
        @recognized_response_root_key ||=
          WHITELISTED_RESPONSE_ROOT_KEYS.include?(parsed_body_root_key)
      end

      def parsed_body_root_key
        parsed_body.first&.first
      end

      def parsed_body_root_value
        (parsed_body.present? && parsed_body.first[1]) || EMPTY_OBJ
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParserError
        EMPTY_OBJ
      end

      def url
        test? ? test_url : live_url
      end

      def uri
        @uri ||= URI(url)
      end
    end
  end
end
