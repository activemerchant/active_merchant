require 'test_helper'

class RemotePayconexTest < Test::Unit::TestCase


  def setup
    @gateway = PayconexGateway.new(fixtures(:payconex))

    @amount = 100
    @amount_decline = 101
    @credit_card = credit_card('4000100011112224')

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount_decline, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.params['transaction_id'])
    assert_equal 'CAPTURED', capture.message
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Must send token_id', response.message
  end

  def test_invalid_login
    gateway = PayconexGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid account_id', response.message
  end
end
