module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayflowResponse < Response
      def profile_id
        @params['profile_id']
      end
    end
  end
end