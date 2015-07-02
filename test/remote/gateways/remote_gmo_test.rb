require 'test_helper'

class RemoteGmoTest < Test::Unit::TestCase
  def setup
    @gateway = GmoGateway.new(fixtures(:gmo))

    @amount = 100
    @too_large_amount = 5000
    @credit_card = credit_card('4111111111111111', :month => '10',
      :year => '2025', :verification_value => '999')
    @invalid_credit_card = credit_card('4999000000000002', :month => '10',
      :year => '2025', :verification_value => '999')
  end

  def options_order_id(seed)
    {
      :email       => 'john@example.com',
      :order_id    => "#{seed}-#{Time.now.utc.to_i}",
      :description => 'Test Transaction',
      :currency    => 'JPY',
      :customer    => 12345678
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, options_order_id(1))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @invalid_credit_card, options_order_id(2))
    assert_failure response
    assert_equal 'Card balance is insufficient', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, options_order_id(3))
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Success', capture.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @invalid_credit_card, options_order_id(4))
    assert_failure response
    assert_equal 'Card balance is insufficient', response.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '3d4d68f3ad1c6335fb679a251d6fc195-07f7fbf0a729b8019947a04e1a4adae1')
    assert_failure response
    assert_equal 'Access ID and Password are invalid', response.message
  end

  def test_failed_too_large_capture
    assert auth = @gateway.authorize(@amount, @credit_card, options_order_id(5))
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert response = @gateway.capture(@too_large_amount, auth.authorization)
    assert_failure response
    assert_equal 'Capture Amount does not match Authorization Amount', response.message
  end

  def test_successful_void
    assert purchase = @gateway.purchase(@amount, @credit_card, options_order_id(6))
    assert_success purchase
    assert_equal 'Success', purchase.message
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Success', void.message
  end

  def test_unsuccessful_void
    assert void = @gateway.void('3d4d68f3ad1c6335fb679a251d6fc195-07f7fbf0a729b8019947a04e1a4adae1', @options)
    assert_failure void
    assert_equal 'Access ID and Password are invalid', void.message
  end

  def test_successful_full_refund
    options = options_order_id(7)
    assert purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase
    assert_equal 'Success', purchase.message
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_successful_partial_refund
    options = options_order_id(8)
    assert purchase = @gateway.purchase(@amount * 2, @credit_card, options)
    assert_success purchase
    assert_equal 'Success', purchase.message
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Success', refund.message
  end

  def test_unsuccessful_refund
    assert refund = @gateway.refund(@amount, '3d4d68f3ad1c6335fb679a251d6fc195-07f7fbf0a729b8019947a04e1a4adae1', @options)
    assert_failure refund
    assert_equal 'Access ID and Password are invalid', refund.message
  end

  def test_invalid_login
    gateway = GmoGateway.new(
                :login => 'demo123',
                :password => 'password123'
              )
    assert response = gateway.purchase(@amount, @credit_card, options_order_id(9))
    assert_failure response
    assert_equal 'Shop ID and Password are invalid', response.message
  end

end
