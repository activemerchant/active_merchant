module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class NetworkTokenizationCreditCard < CreditCard
      # A +NetworkTokenizationCreditCard+ object represents a tokenized credit card
      # using the EMV Network Tokenization specification, http://www.emvco.com/specifications.aspx?id=263.
      #
      # It includes all fields of the +CreditCard+ class with additional fields for
      # verification data that must be given to gateways through existing fields (3DS / EMV).
      #
      # The only tested usage of this at the moment is with an Apple Pay decrypted PKPaymentToken,
      # https://developer.apple.com/library/ios/documentation/PassKit/Reference/PaymentTokenJSON/PaymentTokenJSON.html

      # These are not relevant (verification) or optional (name) for Apple Pay
      self.require_verification_value = false
      self.require_name = false

      attr_accessor :payment_cryptogram, :eci, :transaction_id

      def type
        "network_tokenization"
      end
    end
  end
end
