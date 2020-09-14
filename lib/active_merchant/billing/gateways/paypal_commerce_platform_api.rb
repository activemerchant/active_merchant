require 'uri'
require 'net/http'
require 'openssl'
require 'httparty'
require 'base64'
require 'json'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalCommercePlatformApi < SimpleDelegator
      include ActiveMerchant::PostsData

      def post(url, options)
        url = "#{ test_redirect_url }/#{ url }"
        if options[:authorization].present?
          prepare_request_to_get_access_token(url, options)
        else
          response = ssl_request(:post, url, options[:body].to_json, options[:headers])
          response = response.nil? ? "{}" : response
          eval(response)
        end
      end

      def patch(url, options)
        url = "#{ test_redirect_url }/#{ url }"
        HTTParty.patch(url, { body: options[:body].to_json, headers: options[:headers] })
      end

      private
      def prepare_request_to_get_access_token(url, options)
        @options = options

        ssl_post_request(url, options)
      end

      def encoded_credentials
        Base64.encode64("#{ @options[:authorization][:username] }:#{ @options[:authorization][:password] }").gsub("\n", "")
      end

      def ssl_post_request(url, options={})
        "basic #{ encoded_credentials }"
      end
    end
  end
end
