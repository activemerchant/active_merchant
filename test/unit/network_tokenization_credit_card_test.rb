require 'test_helper'

class NetworkTokenizationCreditCardTest < Test::Unit::TestCase
  def setup
    @tokenized_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      number: '4242424242424242', brand: 'visa',
      month: default_expiration_date.month, year: default_expiration_date.year,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=', eci: '05',
      metadata: { device_manufacturer_id: '1324' },
      payment_data: {
        version: 'EC_v1',
        data: 'QlzLxRFnNP9/GTaMhBwgmZ2ywntbr9iOcBY4TjPZyNrnCwsJd2cq61bDQjo3agVU0LuEot2VIHHocVrp5jdy0FkxdFhGd+j7hPvutFYGwZPcuuBgROb0beA1wfGDi09I+OWL+8x5+8QPl+y8EAGJdWHXr4CuL7hEj4CjtUhfj5GYLMceUcvwgGaWY7WzqnEO9UwUowlDP9C3cD21cW8osn/IKROTInGcZB0mzM5bVHM73NSFiFepNL6rQtomp034C+p9mikB4nc+vR49oVop0Pf+uO7YVq7cIWrrpgMG7ussnc3u4bmr3JhCNtKZzRQ2MqTxKv/CfDq099JQIvTj8hbqswv1t+yQ5ZhJ3m4bcPwrcyIVej5J241R7dNPu9xVjM6LSOX9KeGZQGud',
        signature: 'MIAGCSqGSIb3DQEHAqCAMIACAQExDzANBglghkgBZKYr/0F+3ZD3VNoo6+8ZyBXkK3ifiY95tZn5jVQQ2PnenC/gIwMi3VRCGwowV3bF3zODuQZ/0XfCwhbZZPxnJpghJvVPh6fRuZy5sJiSFhBpkPCZIdAAAxggFfMIIBWwIBATCBhjB6MS4wLAYDVQQDDCVBcHBsZSBBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMCCCRD8qgGnfV3MA0GCWCGSAFlAwQCAQUAoGkwGAYkiG3j7AAAAAAAA',
        header: {
          ephemeralPublicKey: 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEQwjaSlnZ3EXpwKfWAd2e1VnbS6vmioMyF6bNcq/Qd65NLQsjrPatzHWbJzG7v5vJtAyrf6WhoNx3C1VchQxYuw==', transactionId: 'e220cc1504ec15835a375e9e8659e27dcbc1abe1f959a179d8308dd8211c9371", "publicKeyHash": "/4UKqrtx7AmlRvLatYt9LDt64IYo+G9eaqqS6LFOAdI='
        }
      }
    )
    @tokenized_apple_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      source: :apple_pay
    )
    @tokenized_android_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      source: :android_pay
    )
    @tokenized_google_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      source: :google_pay
    )
    @existing_network_token = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      source: :network_token
    )
    @tokenized_bogus_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new(
      source: :bogus_pay
    )
  end

  def test_type
    assert_equal 'network_tokenization', @tokenized_card.type
  end

  def test_credit_card?
    assert @tokenized_card.credit_card?
    assert @tokenized_apple_pay_card.credit_card?
    assert @tokenized_android_pay_card.credit_card?
    assert @tokenized_google_pay_card.credit_card?
    assert @tokenized_bogus_pay_card.credit_card?
  end

  def test_optional_validations
    assert_valid @tokenized_card, 'Network tokenization card should not require name or verification value'
  end

  def test_source
    assert_equal @tokenized_card.source, :apple_pay
    assert_equal @tokenized_apple_pay_card.source, :apple_pay
    assert_equal @tokenized_android_pay_card.source, :android_pay
    assert_equal @tokenized_google_pay_card.source, :google_pay
    assert_equal @tokenized_bogus_pay_card.source, :apple_pay
    assert_equal @existing_network_token.source, :network_token
  end
end
