require 'test_helper'

class RemoteAdyenTest < Test::Unit::TestCase
  def setup
    @gateway = AdyenGateway.new(fixtures(:adyen))

    @amount = 100
    @credit_card = credit_card('4111111111111111', :month => 6, :year => 2016, :verification_value => 737)
    @declined_card = credit_card('4000300011112220', :month => 6, :year => 2016, :verification_value => 737)

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '', @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, nil, @options)
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void(nil, @options)
    assert_failure response
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal "Authorised", response.message
    assert response.authorization
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "Refused", response.message
  end

  def test_invalid_login
    gateway = AdyenGateway.new(
      company: '',
      merchant: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
