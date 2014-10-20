module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ApplePayPaymentToken < Model
      # This is a representation of the object specified here:
      # https://developer.apple.com/library/ios/documentation/PassKit/Reference/PKPaymentToken_Ref/
      attr_accessor :payment_data, :payment_instrument_name, :payment_network, :transaction_identifier

      def type
        'apple_pay'
      end
    end
  end
end