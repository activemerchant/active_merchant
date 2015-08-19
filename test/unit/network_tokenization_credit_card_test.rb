require 'test_helper'

class NetworkTokenizationCreditCardTest < Test::Unit::TestCase

  def setup
    @tokenized_card = ActiveMerchant::Billing::NetworkTokenizationCreditCard.new({
      number: "4242424242424242", :brand => "visa",
      month: default_expiration_date.month, year: default_expiration_date.year,
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=", eci: "05"
    })
  end

  def test_type
    assert_equal "network_tokenization", @tokenized_card.type
  end

  def test_optional_validations
    assert_valid @tokenized_card, "Network tokenization card should not require name or verification value"
  end
end
