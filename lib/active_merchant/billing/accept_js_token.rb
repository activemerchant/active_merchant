module ActiveMerchant
  module Billing
    class AcceptJsToken < PaymentToken
      def type
        'accept_js'
      end

      def opaque_data
        payment_data[:opaque_data]
      end

      def display_number
        @metadata[:card_number]
      end
    end
  end
end
