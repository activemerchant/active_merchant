require 'test_helper'

class RemotePaymentExpressTest < Test::Unit::TestCase

  def setup
    @gateway = PaymentExpressGateway.new(fixtures(:payment_express))

    @credit_card = credit_card('4111111111111111')

    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :email => 'cody@example.com',
      :description => 'Store purchase'
    }

    @amount = 100
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "The Transaction was approved", response.message
    assert_not_nil response.authorization
  end

  def test_successful_purchase_with_reference_id
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal "The Transaction was approved", response.message
    assert_success response
    assert_not_nil response.authorization
  end

  def test_declined_purchase
    assert response = @gateway.purchase(@amount, credit_card("5431111111111228"), @options)
    assert_match %r{declined}i, response.message
    assert_failure response
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "The Transaction was approved", response.message
    assert_success response
    assert_not_nil response.authorization
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The Transaction was approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_purchase_and_refund
    amount = 10000
    assert purchase = @gateway.purchase(amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'The Transaction was approved', purchase.message
    assert !purchase.authorization.blank?
    assert refund = @gateway.refund(amount, purchase.authorization, :description => "Giving a refund")
    assert_success refund
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '999')
    assert_failure response
    assert_equal 'DpsTxnRef Invalid', response.message
  end

  def test_invalid_login
    gateway = PaymentExpressGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match %r{error}i, response.message
    assert_failure response
  end

  def test_store_credit_card
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal "The Transaction was approved", response.message
    assert_not_nil token = response.authorization
    assert_equal token, response.token
  end

  def test_store_with_custom_token
    token = Time.now.to_i.to_s #hehe
    assert response = @gateway.store(@credit_card, :billing_id => token)
    assert_success response
    assert_equal "The Transaction was approved", response.message
    assert_not_nil response.authorization
    assert_equal token, response.authorization
  end

  def test_store_invalid_credit_card
    original_number = @credit_card.number
    @credit_card.number = 2

    assert response = @gateway.store(@credit_card)
    assert_failure response
  end

  def test_store_and_charge
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal "The Transaction was approved", response.message
    assert (token = response.authorization)

    assert purchase = @gateway.purchase( @amount, token)
    assert_equal "The Transaction was approved", purchase.message
    assert_success purchase
    assert_not_nil purchase.authorization
  end

  def test_store_and_authorize_and_capture
    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal "The Transaction was approved", response.message
    assert (token = response.authorization)

    assert auth = @gateway.authorize(@amount, token, @options)
    assert_success auth
    assert_equal 'The Transaction was approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

end
