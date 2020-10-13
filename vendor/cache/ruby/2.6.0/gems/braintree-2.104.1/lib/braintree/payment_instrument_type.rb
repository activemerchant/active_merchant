module Braintree
  module PaymentInstrumentType
    PayPalAccount = 'paypal_account'
    EuropeBankAccount = 'europe_bank_account'
    CreditCard = 'credit_card'
    CoinbaseAccount = 'coinbase_account'
    ApplePayCard = 'apple_pay_card'
    # NEXT_MAJOR_VERSION rename Android Pay to Google Pay
    AndroidPayCard = 'android_pay_card'
    VenmoAccount = 'venmo_account'
    UsBankAccount = 'us_bank_account'
    VisaCheckoutCard = 'visa_checkout_card'
    MasterpassCard = 'masterpass_card' # Deprecated
    SamsungPayCard = 'samsung_pay_card'
    LocalPayment = 'local_payment'
    PayPalHere = 'paypal_here'
  end
end
