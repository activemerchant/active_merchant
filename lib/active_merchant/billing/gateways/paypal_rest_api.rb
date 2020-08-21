require 'httparty'
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalRestApi < SimpleDelegator
      include ActiveMerchant::PostsData
      def post(url, options)
        url = "#{test_redirect_url}/#{url}"
        # response = ssl_post(url, options[:body].to_json, options[:headers])
        HTTParty.post(url, {
            body: options[:body].to_json, headers: options[:headers]})
      end
    end
  end
end
