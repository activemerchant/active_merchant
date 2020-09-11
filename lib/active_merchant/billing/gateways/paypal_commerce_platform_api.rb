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
          eval(ssl_request(:post, url, options[:body].to_json, options[:headers]))
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

      def return_response(http, request)
        response = http.request(request)
        eval(response.body)
      end

      def ssl_post_request(url, options={})
        @url = url
        url = URI(@url)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        params = {
            :grant_type   => "client_credentials"
        }
        url.query = URI.encode_www_form(params)
        request = Net::HTTP::Post.new(url)
        request["accept"]           = 'application/json'
        request["accept-language"]  = 'en_US'

        if @url.include?("token")
          request["authorization"]    = "basic #{ encoded_credentials }"
          request["content-type"]   = 'application/x-www-form-urlencoded'
        else
          request["content-type"]   = 'application/json'
          request.body = options[:body].to_json
        end

        return_response(http, request)
      end
    end
  end
end
