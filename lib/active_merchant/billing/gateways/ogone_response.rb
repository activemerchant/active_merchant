module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class OgoneResponse < Response
      def order_id
        @params['orderID']
      end

      def billing_id
        @params['ALIAS']
      end
    end
  end
end