module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PspTokenizedCard < PaymentToken
      # This is a representation of the card token object for PSPs
      # payment_data: { token: "", type: "" }
      def initialize(payment_data, options = {})
        super
      end

      def type
        'card_token'
      end
    end
  end
end
