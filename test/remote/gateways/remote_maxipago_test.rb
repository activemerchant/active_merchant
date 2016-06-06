require 'test_helper'

class RemoteMaxipagoTest < Test::Unit::TestCase
  def setup
    @gateway = MaxipagoGateway.new(fixtures(:maxipago))

    @amount = 1000
    @invalid_amount = 2009
    @credit_card = credit_card('4111111111111111')
    @invalid_card = credit_card('4111111111111111', year: Time.now.year - 1)

    @options = {
      order_id: '12345',
      billing_address: address,
      description: 'Store Purchase',
      installments: 3
    }
  end

  def test_successful_authorize
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @invalid_card, @options)
    assert_failure response
  end

  def test_authorize_and_capture
    amount = @amount
    authorize = @gateway.authorize(amount, @credit_card, @options)
    assert_success authorize

    capture = @gateway.capture(amount, authorize.authorization, @options)
    assert_success capture
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@invalid_amount, @credit_card, @options)
    assert_failure response
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 'bogus')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "VOIDED", void.message

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal "VOIDED", void.params["response_message"]

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture

    void = @gateway.void(capture.authorization)
    assert_success void
    assert_equal "VOIDED", void.params["response_message"]
  end

  def test_failed_void
    response = @gateway.void("NOAUTH|0000000")
    assert_failure response
    assert_equal "error", response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal "APPROVED", refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund_amount = @amount + 10
    refund = @gateway.refund(refund_amount, purchase.authorization, @options)
    assert_failure refund
    assert_equal "The Return amount is greater than the amount that can be returned.", refund.message
  end

  def test_invalid_login
    gateway = MaxipagoGateway.new(
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
