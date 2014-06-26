require 'test_helper'

class RemotePaymillTest < Test::Unit::TestCase
  def setup
    @gateway = PaymillGateway.new(fixtures(:paymill))

    @amount = 100
    @credit_card = credit_card('5500000000000004')
    @declined_card = credit_card('5105105105105100', month: 5, year: 2020)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'General success response.', response.message
  end

  def test_successful_purchase_with_token
    assert response = @gateway.purchase(@amount, '098f6bcd4621d373cade4e832627b4f6', { description: 'from active merchant' } )
    assert_success response
    assert_equal 'General success response.', response.message
  end

  def test_failed_store_card_attempting_purchase
    @credit_card.number = ''
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Account or Bank Details Incorrect', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card)
    assert_failure response
    assert_equal 'Card declined by authorization system.', response.message
  end

  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response
    assert_equal 'General success response.', response.message
    assert response.authorization

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response
    assert_equal 'General success response.', capture_response.message
  end

  def test_successful_authorize_and_capture_with_token
    assert response = @gateway.authorize(@amount, '098f6bcd4621d373cade4e832627b4f6')
    assert_success response
    assert_equal 'General success response.', response.message
    assert response.authorization

    assert capture_response = @gateway.capture(@amount, response.authorization, { description: 'from active merchant' })
    assert_success capture_response
    assert_equal 'General success response.', capture_response.message
  end

  def test_successful_authorize_with_token
    assert response = @gateway.authorize(@amount, '098f6bcd4621d373cade4e832627b4f6', { description: 'from active merchant' })
    assert_success response
    assert_equal 'General success response.', response.message
    assert response.authorization
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card)
    assert_failure response
    assert_equal 'Card declined by authorization system.', response.message
  end

  def test_failed_capture
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response

    assert capture_response = @gateway.capture(@amount, response.authorization)
    assert_failure capture_response
    assert_equal 'Transaction duplicate', capture_response.message
  end

  def test_successful_authorize_and_void
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response
    assert_equal 'General success response.', response.message
    assert response.authorization

    assert void_response = @gateway.void(response.authorization)
    assert_success void_response
    assert_equal 'Transaction approved.', void_response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.authorization

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'General success response.', refund.message
  end

  def test_failed_refund
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert response.authorization

    assert refund = @gateway.refund(300, response.authorization)
    assert_failure refund
    assert_equal 'Amount to high', refund.message
  end

  def test_invalid_login
    gateway = PaymillGateway.new(fixtures(:paymill).merge(:private_key => "SomeBogusValue"))
    response = gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Access Denied', response.message
  end

  def test_successful_store_and_purchase
    store = @gateway.store(@credit_card)
    assert_success store
    assert_not_nil store.authorization

    purchase = @gateway.purchase(@amount, store.authorization)
    assert_success purchase
  end

  def test_failed_store_with_invalid_card
    @credit_card.number = ''
    assert response = @gateway.store(@credit_card)
    assert_failure response
    assert_equal 'Account or Bank Details Incorrect', response.message
  end

  def test_successful_store_and_authorize
    store = @gateway.store(@credit_card)
    assert_success store
    assert_not_nil store.authorization

    authorize = @gateway.authorize(@amount, store.authorization)
    assert_success authorize
  end

end
