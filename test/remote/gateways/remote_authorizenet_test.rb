require 'test_helper'

class RemoteAuthorizenetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizenetGateway.new(fixtures(:authorizenet))

    @amount = (rand(10000) + 100) / 100.0
    @credit_card = credit_card('4000100011112224')
    #@declined_card = credit_card('4000300011112220')
    @declined_card = credit_card('400030001111222')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid.', response.message
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The credit card number is invalid.', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, nil, '')
    assert_failure response
  end

  # As of June 2014, AuthorizeNet REQUIRES the amount for the refund.
  #def test_successful_refund
  #  purchase = @gateway.purchase(@amount, @credit_card, @options)
  #  assert_success purchase
  #  assert refund = @gateway.refund(nil, purchase.authorization)
  #  assert_success refund
  #end

  #this requires an overnight settlement.  Must be tested with a hard coded transaction id
  #def test_partial_refund
  #  purchase = @gateway.purchase(@amount, @credit_card, @options)
  #  assert_success purchase

  #  assert refund = @gateway.refund(@amount, @credit_card, purchase.authorization)
  #  assert_success refund
  #end

  def test_failed_refund
    response = @gateway.refund(nil, nil, '')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_invalid_login
    gateway = AuthorizenetGateway.new(
      login: '',
      password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
