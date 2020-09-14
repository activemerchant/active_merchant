
require 'active_merchant/billing/gateways/paypal/paypal_common_api'
require 'active_merchant/billing/gateways/paypal_commerce_platform_api'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCommercePlatformGateway < Gateway
      attr_accessor :test_redirect_url
      NON_STANDARD_LOCALE_CODES = {
          'DK' => 'da_DK',
          'IL' => 'he_IL',
          'ID' => 'id_ID',
          'JP' => 'jp_JP',
          'NO' => 'no_NO',
          'BR' => 'pt_BR',
          'RU' => 'ru_RU',
          'SE' => 'sv_SE',
          'TH' => 'th_TH',
          'TR' => 'tr_TR',
          'CN' => 'zh_CN',
          'HK' => 'zh_HK',
          'TW' => 'zh_TW'
      }
     def api_adapter
       @api_adapter ||= ActiveMerchant::Billing::PaypalCommercePlatformApi.new(self)
     end

      def initialize
        self.test_redirect_url = 'https://api.sandbox.paypal.com'
      end

      self.supported_countries = ['US']
      self.homepage_url = 'https://www.paypal.com/cgi-bin/webscr?cmd=xpt/merchant/ExpressCheckoutIntro-outside'
      self.display_name = 'PPCP Checkout'
      self.currencies_without_fractions = %w(HUF JPY TWD)


      delegate :post, to: :api_adapter
      delegate :patch, to: :api_adapter

      private
      def commit(method, url, parameters = nil, options = {})
        #post('v2/checkout/orders', options)
        response = api_request(method, "#{ test_redirect_url }/#{ url }", parameters, options[:headers])

        success = success_from(response, options)

        success ? success : response_error(response)
      end

      def success_from(response, options)
        !response.key?('error') && response['status'] != 'failed'
      end

      def response_error(raw_response)
        parse(raw_response)
      rescue JSON::ParserError
        json_error(raw_response)
      end
      def api_version(options)
        options[:version] || @options[:version] || self.class::DEFAULT_API_VERSION
      end

      def api_request(method, endpoint, parameters = nil, opt_headers = {})
        raw_response = response = nil
        begin
          raw_response = ssl_request(method, endpoint, parameters, opt_headers)
        rescue ResponseError => e
          raw_response = e.response.body
          response = response_error(raw_response)
        rescue JSON::ParserError
          response = json_error(raw_response)
        end
        raw_response
      end
      def headers(params)
        params[:headers]
      end
      def prepare_request_to_get_access_token(options)
        @options = options
        "basic #{ encoded_credentials }"
      end
      def encoded_credentials
        Base64.encode64("#{ @options[:authorization][:username] }:#{ @options[:authorization][:password] }").gsub("\n", "")
      end

    end
  end
end
