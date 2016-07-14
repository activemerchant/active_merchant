require 'test_helper'

class RemoteStripeApplePayTest < Test::Unit::TestCase
  CHARGE_ID_REGEX = /ch_[a-zA-Z\d]{24}/

  def setup
    @gateway = StripeGateway.new(fixtures(:stripe))
    @amount = 100

    @options = {
      :currency => "USD",
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com'
    }
    @apple_pay_payment_token = apple_pay_payment_token
  end

  def test_successful_purchase_with_apple_pay_payment_token
    assert response = @gateway.purchase(@amount, @apple_pay_payment_token, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_authorization_and_capture_with_apple_pay_payment_token
    assert authorization = @gateway.authorize(@amount, @apple_pay_payment_token, @options)
    assert_success authorization
    refute authorization.params["captured"]
    assert_equal "ActiveMerchant Test Purchase", authorization.params["description"]
    assert_equal "wow@example.com", authorization.params["metadata"]["email"]

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end

  def test_authorization_and_void_with_apple_pay_payment_token
    assert authorization = @gateway.authorize(@amount, @apple_pay_payment_token, @options)
    assert_success authorization
    refute authorization.params["captured"]

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_successful_void_with_apple_pay_payment_token
    assert response = @gateway.purchase(@amount, @apple_pay_payment_token, @options)
    assert_success response
    assert response.authorization
    assert void = @gateway.void(response.authorization)
    assert_success void
  end

  def test_successful_store_with_apple_pay_payment_token
    assert response = @gateway.store(@apple_pay_payment_token, {:description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal "customer", response.params["object"]
    assert_equal "Active Merchant Test Customer", response.params["description"]
    assert_equal "email@example.com", response.params["email"]
    first_card = response.params["cards"]["data"].first
    assert_equal response.params["default_card"], first_card["id"]
    assert_equal "4242", first_card["dynamic_last4"] # when stripe is in test mode, token exchanged will return a test card with dynamic_last4 4242
    assert_equal "0000", first_card["last4"] # last4 is 0000 when using an apple pay token
  end

  def test_successful_store_with_existing_customer_and_apple_pay_payment_token
    assert response = @gateway.store(@credit_card, {:description => "Active Merchant Test Customer"})
    assert_success response

    assert response = @gateway.store(@apple_pay_payment_token, {:customer => response.params['id'], :description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert_equal 2, response.responses.size

    card_response = response.responses[0]
    assert_equal "card", card_response.params["object"]
    assert_equal "4242", card_response.params["dynamic_last4"] # when stripe is in test mode, token exchanged will return a test card with dynamic_last4 4242
    assert_equal "0000", card_response.params["last4"] # last4 is 0000 when using an apple pay token

    customer_response = response.responses[1]
    assert_equal "customer", customer_response.params["object"]
    assert_equal "Active Merchant Test Customer", customer_response.params["description"]
    assert_equal "email@example.com", customer_response.params["email"]
    assert_equal 2, customer_response.params["cards"]["count"]
  end

  def test_successful_recurring_with_apple_pay_payment_token
    assert response = @gateway.store(@apple_pay_payment_token, {:description => "Active Merchant Test Customer", :email => "email@example.com"})
    assert_success response
    assert recharge_options = @options.merge(:customer => response.params["id"])
    assert response = @gateway.purchase(@amount, nil, recharge_options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
  end

  def test_purchase_with_unsuccessful_apple_pay_token_exchange
    assert response = @gateway.purchase(@amount, ApplePayPaymentToken.new('garbage'), @options)
    assert_failure response
  end

  def test_successful_purchase_with_apple_pay_raw_cryptogram_with_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil,
      eci: '05',
      source: :apple_pay
    )
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_purchase_with_apple_pay_raw_cryptogram_without_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil,
      source: :apple_pay
    )
    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_auth_with_apple_pay_raw_cryptogram_with_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil,
      eci: '05',
      source: :apple_pay
    )
    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_success response
    assert_equal "charge", response.params["object"]
    assert response.params["paid"]
    assert_equal "ActiveMerchant Test Purchase", response.params["description"]
    assert_equal "wow@example.com", response.params["metadata"]["email"]
    assert_match CHARGE_ID_REGEX, response.authorization
  end

  def test_successful_auth_with_apple_pay_raw_cryptogram_without_eci
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: "EHuWW9PiBkWvqE5juRwDzAUFBAk=",
      verification_value: nil,
      source: :apple_pay
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

