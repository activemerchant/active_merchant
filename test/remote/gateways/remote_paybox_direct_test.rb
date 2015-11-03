# encoding: utf-8

require 'test_helper'

class RemotePayboxDirectTest < Test::Unit::TestCase

  def setup
    @gateway = PayboxDirectGateway.new(fixtures(:paybox_direct))
    
    @amount = 100
    @credit_card = credit_card('1111222233334444')
    @declined_card = credit_card('1111222233334445')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "PAYBOX : Num\xE9ro de porteur invalide".force_encoding('ASCII-8BIT'), response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction was approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, :order_id => '1')
    assert_success capture
  end
  
  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'The transaction was approved', purchase.message
    assert purchase.authorization
    # Paybox requires you to remember the expiration date
    assert void = @gateway.void(purchase.authorization, :order_id => '1', :amount => @amount)
    assert_equal 'The transaction was approved', void.message
    assert_success void
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '', :order_id => '1')
    assert_failure response
    assert_equal "Invalid data", response.message
  end
  
  def test_purchase_and_partial_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'The transaction was approved', purchase.message
    assert purchase.authorization
    assert credit = @gateway.credit(@amount / 2, purchase.authorization, :order_id => '1')
    assert_equal 'The transaction was approved', credit.message
    assert_success credit
  end
  
  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, order_id: '1')
    assert_success refund
  end

  def test_partial_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount/2, purchase.authorization, order_id: '1')
    assert_success refund
  end

  def test_failed_refund
    refund = @gateway.refund(@amount, '', order_id: '2') 
    assert_failure refund
    assert_equal 'Invalid data', refund.message
  end

  def test_invalid_login
    gateway = PayboxDirectGateway.new(
                login: '199988899',
                password: '1999888F',
                rang: 100
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Non autorise", response.message
  end

  def test_invalid_login_without_rang
    gateway = PayboxDirectGateway.new(
                login: '199988899',
                password: '1999888F',
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Non autorise", response.message
  end
end
