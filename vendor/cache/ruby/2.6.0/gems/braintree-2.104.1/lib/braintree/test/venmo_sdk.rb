module Braintree
  module Test
    module VenmoSDK
      def self.generate_test_payment_method_code(card_number)
        "stub-#{card_number}"
      end

      AmExPaymentMethodCode = generate_test_payment_method_code(CreditCardNumbers::AmExes.first)
      DiscoverPaymentMethodCode = generate_test_payment_method_code(CreditCardNumbers::Discovers.first)
      JCBPaymentMethodCode = generate_test_payment_method_code(CreditCardNumbers::JCBs.first)
      MasterCardPaymentMethodCode = generate_test_payment_method_code(CreditCardNumbers::MasterCards.first)
      VisaPaymentMethodCode = generate_test_payment_method_code(CreditCardNumbers::Visas.first)
      InvalidPaymentMethodCode = "stub-invalid-payment-method-code"

      Session = "stub-session"
      InvalidSession = "stub-invalid-session"
    end
  end
end
