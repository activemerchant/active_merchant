module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class ApplePayNetworkTokenizationCreditCard < NetworkTokenizationCreditCard
      # This is a representation of the data specified here:
      # https://developer.apple.com/library/archive/documentation/PassKit/Reference/PaymentTokenJSON/PaymentTokenJSON.html
      attr_accessor :payment_data_type, :device_manufacturer_id
    end
  end
end
