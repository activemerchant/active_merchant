require 'uri'
require 'net/http'
require 'openssl'
require 'httparty'
require 'base64'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalRestApi < SimpleDelegator
      include ActiveMerchant::PostsData

      def post(url, options)
        url = "#{test_redirect_url}/#{url}"
        if options[:authorization].present?
          prepare_request_to_get_access_token(url, options)
        else
          HTTParty.post(url, { body: options[:body].to_json, headers: options[:headers] })
        end
      end

      private
      def prepare_request_to_get_access_token(url, options)
        @options = options
        url = URI(url)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER

        request = Net::HTTP::Post.new(url)
        request["accept"] = 'application/json'
        request["accept-language"] = 'en_US'
        request["content-type"] = 'application/x-www-form-urlencoded'
        request["authorization"] = "basic #{ encoded_credentials }"
        request.body = "grant_type=client_credentials"
        return_response(http, request)
      end
      def encoded_credentials
        Base64.encode64("#{@options[:authorization][:username]}:#{@options[:authorization][:password]}").gsub("\n", "")
      end
      def return_response(http, request)
        response = http.request(request)
        eval(response.body)
      end
    end
  end
end
