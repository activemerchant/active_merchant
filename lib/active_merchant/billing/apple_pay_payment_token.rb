module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ApplePayPaymentToken < PaymentToken
      # This is a representation of the token object specified here:
      # https://developer.apple.com/library/ios/documentation/PassKit/Reference/PKPaymentToken_Ref/
      # https://developer.apple.com/library/IOs//documentation/PassKit/Reference/PaymentTokenJSON/PaymentTokenJSON.html

      attr_reader :payment_instrument_name, :payment_network
      attr_accessor :transaction_identifier

      def initialize(payment_data, options = {})
        super
        @payment_instrument_name = @metadata[:payment_instrument_name]
        @payment_network = @metadata[:payment_network]
      end

      def type
        'apple_pay'
      end
    end
  end
end
