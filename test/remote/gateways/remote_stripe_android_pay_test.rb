require 'test_helper'

class RemoteStripeAndroidPayTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /ch_[a-zA-Z\d]{24}/

  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))
    @amount = 100

    @options = {
      :currency => "USD",
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }
  end

  def test_successful_purchase_with_android_pay_raw_cryptogram
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil,
      eci: '05',
      source: :android_pay
    )
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_auth_with_android_pay_raw_cryptogram
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil,
      eci: '05',
      source: :android_pay
    )
    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end
end