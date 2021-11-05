module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WalletToken < PaymentToken
      # This is a representation of the wallet token object for PSPs
      # payment_data: { token: "", type: "" }

      attr_reader :token

      def initialize(payment_data, options = {})
        super
        @token = @payment_data[:token]
      end

      def type
        'wallet'
      end
    end
  end
end
