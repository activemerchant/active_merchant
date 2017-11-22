require 'test_helper'

class NetworkTokenizationCreditCardTest < Test::Unit::TestCase

  def setup
    @tokenized_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      number: "4242424242424242", :brand => "visa",
      month: default_expiration_date.month, year: default_expiration_date.year,
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=", eci: "05"
    })
    @tokenized_apple_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      source: :apple_pay
    })
    @tokenized_android_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      source: :android_pay
    })
    @tokenized_bogus_pay_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      source: :bogus_pay
    })
    @tokenized_apple_pay_discover_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      number: "6011111111111117",
      brand: "discover",
      month: default_expiration_date.month,
      year: default_expiration_date.year,
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      eci: "05",
      source: :apple_pay
    })
  end

  def test_type
    assert_equal "network_tokenization", @tokenized_card.type
  end

  def test_credit_card?
    assert @tokenized_card.credit_card?
    assert @tokenized_apple_pay_card.credit_card?
    assert @tokenized_android_pay_card.credit_card?
    assert @tokenized_bogus_pay_card.credit_card?
  end

  def test_optional_validations
    assert_valid @tokenized_card, "Network tokenization card should not require name or verification value"
  end

  def test_source
    assert_equal @tokenized_card.source, :apple_pay
    assert_equal @tokenized_apple_pay_card.source, :apple_pay
    assert_equal @tokenized_android_pay_card.source, :android_pay
    assert_equal @tokenized_bogus_pay_card.source, :apple_pay
  end

  def test_eci
    assert_equal "05", @tokenized_card.eci
  end

  def test_discover_eci_override
    assert_equal "04", @tokenized_apple_pay_discover_card.eci
  end
end
