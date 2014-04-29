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

  def test_invalid_login
    gateway = MaxipagoGateway.new(
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
