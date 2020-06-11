module ActiveMerchant
  module Billing
    class CollectJsPaymentToken
      # This is a representation of a token generated with the Collect.js framework as described here:
      #https://secure.networkmerchants.com/gw/merchants/resources/integration/integration_portal.php#cjs_methodology
      attr_reader :payment_data

      def initialize(payment_token)
        @payment_data = payment_token
      end

      def type
        'collect_js_token'
      end
    end
  end
end
