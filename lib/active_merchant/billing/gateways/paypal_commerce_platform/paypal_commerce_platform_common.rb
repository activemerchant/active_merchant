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
        response = api_request(method, "#{ base_url }/#{ url }", parameters, options)
        response
      end


      def skip_empty(obj_hsh, key)
        obj_hsh.delete(key) if obj_hsh[key].empty?
      end


      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, endpoint, parameters.to_json, opt_headers)
          raw_response = raw_response.nil? ? "{}": raw_response
          raw_response = eval(raw_response)
          response     = ActiveMerchant::Billing::PPCPResponse.new(raw_response).process
        rescue ResponseError => e
          raw_response = e.response.body
          response     = ActiveMerchant::Billing::PPCPResponse.new(raw_response).process
        rescue JSON::ParserError
          response     = ActiveMerchant::Billing::PPCPResponse.new(raw_response).process
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


      def encoded_credentials
        Base64.encode64("#{ @options[:authorization][:username] }:#{ @options[:authorization][:password] }").gsub("\n", "")
      end

      def get_update_type(path)
        path.split("/").last
      end


    end
  end
end