module Braintree
  module PaymentMethodParser

    def self.parse_payment_method(gateway, attributes)
      if attributes[:credit_card]
        CreditCard._new(gateway, attributes[:credit_card])
      elsif attributes[:paypal_account]
        PayPalAccount._new(gateway, attributes[:paypal_account])
      elsif attributes[:coinbase_account]
        CoinbaseAccount._new(gateway, attributes[:coinbase_account])
      elsif attributes[:us_bank_account]
        UsBankAccount._new(gateway, attributes[:us_bank_account])
      elsif attributes[:apple_pay_card]
        ApplePayCard._new(gateway, attributes[:apple_pay_card])
      elsif attributes[:android_pay_card]
        # NEXT_MAJOR_VERSION rename Android Pay to Google Pay
        AndroidPayCard._new(gateway, attributes[:android_pay_card])
      elsif attributes[:amex_express_checkout_card]
        AmexExpressCheckoutCard._new(gateway, attributes[:amex_express_checkout_card])
      elsif attributes[:venmo_account]
        VenmoAccount._new(gateway, attributes[:venmo_account])
      elsif attributes[:visa_checkout_card]
        VisaCheckoutCard._new(gateway, attributes[:visa_checkout_card])
      elsif attributes[:masterpass_card]
        MasterpassCard._new(gateway, attributes[:masterpass_card])
      elsif attributes[:samsung_pay_card]
        SamsungPayCard._new(gateway, attributes[:samsung_pay_card])
      else
        UnknownPaymentMethod._new(gateway, attributes)
      end
    end
  end
end
