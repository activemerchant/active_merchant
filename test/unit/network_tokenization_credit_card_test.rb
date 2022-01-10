require 'test_helper'

class NetworkTokenizationCreditCardTest < Test::Unit::TestCase
  def setup
    @tokenized_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      number: '4242424242424242', brand: 'visa',
      month: default_expiration_date.month, year: default_expiration_date.year,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=', eci: '05'
    })
    @tokenized_apple_pay_card = ActiveMerchant::Billing::ApplePayNetworkTokenizationCreditCard.new({
      payment_data_type: '3DSecure',
      device_manufacturer_id: '040010030273',
      source: :apple_pay
    })
    @tokenized_android_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      source: :android_pay
    })
    @tokenized_google_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      source: :google_pay
    })
    @existing_network_token = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      source: :network_token
    })
    @tokenized_bogus_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      source: :bogus_pay
    })
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

  def test_tokenized_apple_pay_metadata
    assert_equal '3DSecure', @tokenized_apple_pay_card.payment_data_type
    assert_equal '040010030273', @tokenized_apple_pay_card.device_manufacturer_id
  end
end
