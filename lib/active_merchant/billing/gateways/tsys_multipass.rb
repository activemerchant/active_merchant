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
      BLANK = ""
      CONTENT_TYPE = "application/json"
      WHITELISTED_RESPONSE_ROOT_KEYS = %w(AuthResponse CaptureResponse VoidResponse ReturnResponse)

      attr_reader :parsed_body

      def initialize(options={})
        super
      end

      def authorize(money, credit_card, options = {})
        call(
          request_body: { "Auth": options }.to_json
        )
      end

      def capture(money, authorization_id, options = {})
        call(
          request_body: { "Capture": options }.to_json
        )
      end

      def void(authorization_id, options = {})
        call(
          request_body: { "Void": options }.to_json
        )
      end

      def refund(money, authorization_id, options = {})
        call(
          request_body: { "Return": options }.to_json
        )
      end

      private

      def call(request_body: )
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |https|
          request      = Net::HTTP::Post.new(uri, {'Content-Type' => CONTENT_TYPE })
          request.body = request_body
          response     = https.request(request)
          @parsed_body = parse(response.body)
        end

        Response.new(
          success?,
          message,
          parsed_body,
          amount: amount,
          error_code: error_code,
          authorization: authorization,
          test: test?
        )
      end

      def success?
        return false unless recognized_response_root_key?

        parsed_body_root_value["status"] == "PASS"
      end

      def message
        return BLANK unless recognized_response_root_key?

        parsed_body_root_value["responseMessage"]
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

        parsed_body_root_value["responseCode"]
      end

      def authorization
        return BLANK unless recognized_response_root_key?

        parsed_body_root_value["transactionID"]
      end

      def amount
        return BLANK unless recognized_response_root_key?

        parsed_body_root_value[ amount_key_mapping[parsed_body_root_key] ]
      end

      # This method gives us mapping of which amount field to 
      # fetch based on the transaction response types.
      def amount_key_mapping
        {
          "AuthResponse": "processedAmount",
          "CaptureResponse": "transactionAmount",
          "VoidResponse": "voidedAmount",
          "ReturnResponse": "returnAmount"
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
        @parsed_body_root_value ||= (parsed_body.first&.second || EMPTY_OBJ)
      end

      def parse(body)
        JSON.parse(body)
      rescue JSON::ParseError
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
