module ActiveMerchant
  module Billing
    module PaypalCheckoutCommon

      URLS = {
        :test_url     => "https://api.sandbox.paypal.com",
        :live_url     => "https://api.paypal.com"
      }

      ALLOWED_INTENT              = %w(CAPTURE AUTHORIZE).freeze
      ALLOWED_TOKEN_TYPE          = %w(BILLING_AGREEMENT).freeze
      ALLOWED_ITEM_CATEGORY       = %w(DIGITAL_GOODS PHYSICAL_GOODS).freeze
      ALLOWED_PHONE_TYPE          = %w(FAX HOME MOBILE OTHER PAGER).freeze
      ALLOWED_TAX_TYPE            = %w(BR_CPF BR_CNPJ).freeze


      def initialize(options = {})
        requires!(options, :client_id, :client_secret)
        super
      end

      def base_url
        test? ? URLS[:test_url] : URLS[:live_url]
      end

      def commit(method, url, parameters = nil, options = {})
        options = {} unless !options.nil?
        response               = api_request(method, "#{ base_url }/#{ url }", parameters, options)
        success                = success_from(response)

        Response.new(
            success,
            message_from(success, response),
            response,
            authorization: authorization_from(response),
            avs_result: nil,
            cvv_result: nil,
            test: test?,
            error_code: error_code_from(response)
        )
      end

      # Prepare API request to hit remote endpoint \
      # to appropriate method(POST, GET, PUT, PATCH).
      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        parameters = parameters.nil? ? nil : parameters.to_json
        opt_headers.update(default_headers)
        if !opt_headers.key?("Content-Type")
            opt_headers["Content-Type"] = "application/json"
        end
        begin
        raw_response = ssl_request(method, endpoint, parameters, opt_headers)
        response     = parse(raw_response)
        rescue ResponseError => e
        raw_response = e.response.body
        response     = response_error(raw_response)
        rescue JSON::ParserError
        response     = json_error(raw_response)
        end
        response
      end

      def encoded_credentials
        Base64.encode64("#{ @options[:client_id] }:#{ @options[:client_secret] }").gsub("\n", "")
      end

      def default_headers
        return {
          "Authorization" => "Basic #{ encoded_credentials }"
        }
      end

      def parse(raw_response)
        raw_response = (raw_response.nil? || raw_response.empty?) ? "{}": raw_response
        JSON.parse(raw_response)
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end

      def authorization_from(response)
        response['id']
      end

      def error_code_from(response)
        return if success_from(response)
        code = response['name'] || response['error']
        code&.to_s
      end

      def message_from(success, response)
        success ? response['status'] : (response['message'] || response['error_description'])
      end

      def json_error(raw_response)
        {
            'error' => {
                'message' => "#{ raw_response.inspect }"
            }
        }
      end

      def success_from(response)
        !response.key?('name') && response['debug_id'].nil? && !response.key?('error')
      end

      def supports_scrubbing?
        false
      end
    end
  end
end
