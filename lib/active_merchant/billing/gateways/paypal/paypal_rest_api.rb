module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalRestapi < SimpleDelegator

      def post(url, options)
        HTTParty.post("#{endpoint_url}/#{url}", options)
      end
    end
  end
end
