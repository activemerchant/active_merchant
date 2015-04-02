module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Base class representation of cryptographic payment data tokens that may be used for EMV-style transactions
    # like Apple Pay. Payment data may be transmitted via any data type, and may also be padded
    # with metadata specific to the cryptographer. This metadata should be parsed and interpreted in concrete
    # implementations of your given cryptographer. Like credit cards, you must also return a string representing
    # the token's type, like 'apple_pay' or 'stripe' should your target payment gateway process these tokens.
    class PaymentToken
      attr_reader :payment_data

      def initialize(payment_data, options = {})
        @payment_data = payment_data
        @metadata = options.with_indifferent_access
      end

      def type
        raise NotImplementedError
      end
    end
  end
end
