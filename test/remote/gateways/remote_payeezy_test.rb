require 'test_helper'

class RemotePayeezyTest < Test::Unit::TestCase
  def setup
    @gateway = PayeezyGateway.new(fixtures(:payeezy))
    @credit_card = credit_card
    @bad_credit_card = credit_card('4111111111111113')
    @amount = 100
    @options = {
      :billing_address => address,
      :merchant_ref => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_unsuccessful_purchase
    @amount = 501300
    assert response = @gateway.purchase(@amount, @credit_card, @options )
    assert_match(/Transaction not approved/, response.message)
    assert_failure response
  end

  def test_bad_creditcard_number
    assert response = @gateway.purchase(@amount, @bad_credit_card, @options)
    assert_failure response
    assert_equal response.error_code, "invalid_card_number"
  end

  def test_trans_error
    # ask for error 42 (unable to send trans) as the cents bit...
    @amount = 500042
    assert response = @gateway.purchase(@amount, @credit_card, @options )
    assert_match(/Internal Server Error/, response.message) # 42 is 'unable to send trans'
    assert_failure response
    assert_equal response.error_code, "internal_server_error"
  end

  def test_purchase_and_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization
    assert credit = @gateway.refund(@amount, purchase.authorization)
    assert_success credit
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert purchase.authorization
    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '1|1')
    assert_failure response
  end

  def test_invalid_login
    gateway = PayeezyGateway.new(apikey: "NotARealUser", apisecret: "NotARealPassword", token: "token")
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match %r{Invalid Api Key}, response.message
    assert_failure response
  end

  def test_response_contains_cvv_and_avs_results
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'M', response.cvv_result["code"]
    assert_equal '4', response.avs_result["code"]
  end

  def test_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end
end
