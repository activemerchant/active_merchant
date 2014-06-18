require 'test_helper'

class RemoteAuthorizenetTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizenetGateway.new(fixtures(:authorizenet))

    @amount = (rand(10000) + 100) / 100.0
    @credit_card = credit_card('4000100011112224')
    @check = check
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

  def test_card_present_purchase_with_no_data
    no_data_credit_card = ActiveMerchant::Billing::CreditCard.new()
    assert response = @gateway.purchase(@amount, no_data_credit_card, @options)
    assert response.test?
    assert_equal 'credit card number is invalid.', response.message
  end

  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired.', response.message
  end

  def test_successful_echeck_purchase
    assert response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_successful_echeck_authorization
    assert response = @gateway.authorize(@amount, @check, @options)
    assert_success response
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
  end

  def test_card_present_purchase_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(:track_data => '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    assert response = @gateway.purchase(@amount, track_credit_card, @options)
    assert response.test?
    assert_equal 'This transaction has been approved.', response.message
    assert response.authorization
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

  def test_card_present_authorize_and_capture_with_track_data_only
    track_credit_card = ActiveMerchant::Billing::CreditCard.new(:track_data => '%B378282246310005^LONGSON/LONGBOB^1705101130504392?')
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture

    assert_equal 'This transaction has been approved.', capture.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(20, '23124#1234')
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

  def test_failed_refund
    response = @gateway.refund(nil, '')
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
  #credit card is required to do this.
  #def test_partial_refund
  #  assert refund = @gateway.refund(78.56, '2215043618#2224')
  #  assert_success refund
  #end
end
