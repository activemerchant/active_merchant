module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class GooglePayNetworkTokenizationCreditCard < NetworkTokenizationCreditCard
      # This is a representation of data specified here:
      # https://developers.google.com/pay/api/android/guides/resources/payment-data-cryptography#encrypted-message
      attr_accessor :auth_method, :payment_method
    end
  end
end
