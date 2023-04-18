module ActiveMerchant
  module Billing
    module EbanxV2
      attr_accessor :gateway_version

      @test_url = 'https://sandbox.ebanxpay.com/channels/spreedly/'
      @live_url = 'https://api.ebanxpay.com/channels/spreedly/'

      def get_gateway_version(parameters)
        return unless test?

        headers = { 'x-ebanx-client-user-agent': "ActiveMerchant/#{ActiveMerchant::VERSION}" }
        headers['authorization'] = @options[:integration_key]
        headers['content-type'] = "application/json"

        processing_type = parameters[:processing_type]

        add_processing_type_to_commit_headers(headers, processing_type) if processing_type == 'local'

        response = parse(ssl_get(get_url, headers))

        @gateway_version = response['gateway'] || 'v1'
      end

      def get_url
        if test?
          'https://sandbox.ebanxpay.com/channels/spreedly/flow'
        else
          'https://api.ebanxpay.com/channels/spreedly/flow'
        end
      end

      def new_headers(params)
        headers = { 'x-ebanx-client-user-agent': "ActiveMerchant/#{ActiveMerchant::VERSION}" }
        headers['authorization'] = @options[:integration_key]
        headers['content-type'] = "application/json"

        processing_type = params[:options][:processing_type] if params[:options].present? && params[:options][:processing_type].present?
        add_processing_type_to_headers(headers, processing_type) if processing_type && processing_type == 'local'

        headers
      end
      
      def url_for_v2(is_test_env, action, parameters)
        hostname = is_test_env ? @test_url : @live_url

        return "#{hostname}#{URL_MAP[action]}/#{parameters[:hash]}" if requires_http_get(action)

        "#{hostname}#{URL_MAP[action]}"
      end
    end
  end
end