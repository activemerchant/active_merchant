module ActiveMerchant
  module Billing
    module PaypalCommercePlatformCommon

      URLS = {
          :test_url     => "https://api.sandbox.paypal.com",
          :live_url     => "https://api.paypal.com"
      }

      def initialize(options = { })
        super
      end

      def base_url
        test? ? URLS[:test_url] : URLS[:live_url]
      end

      def commit(method, url, parameters = nil, options = {})
        response               = api_request(method, "#{ base_url }/#{ url }", parameters, options)
        response['webhook_id'] = options[:webhook_id] if options[:webhook_id]
        success                = success_from(response, options)

        Response.new(
            success,
            message_from(success, response),
            response
        )
      end

      def skip_empty(obj_hsh, key)
        obj_hsh.delete(key) if obj_hsh[key].empty?
      end

      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, endpoint, parameters.to_json, opt_headers)
          response     = parse(raw_response)
        rescue ResponseError => e
          raw_response = e.response.body
          response     = response_error(raw_response)
        rescue JSON::ParserError
          response     = json_error(raw_response)
        end
        response
      end

      def headers(params)
        params[:headers]
      end

      def prepare_request_for_get_access_token(options)
        @options = options
        "basic #{ encoded_credentials }"
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

      def message_from(success, response)
        success ? 'Transaction Successfully Completed' : response['message']
      end

      def json_error(raw_response)
        msg = 'Invalid response received from the PayPal API. '
        msg += "  (The raw response returned by the API was #{raw_response.inspect})"
        {
            'error' => {
                'message' => msg
            }
        }
      end

      def success_from(response, options)
        !response.key?('name') && response['debug_id'].nil?
      end

      def encoded_credentials
        Base64.encode64("#{ @options[:authorization][:username] }:#{ @options[:authorization][:password] }").gsub("\n", "")
      end

      def get_update_type(path)
        path.split("/").last
      end

    end
  end
end