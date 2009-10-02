require 'test_helper'

class RemoteSallieMaeTest < Test::Unit::TestCase
  def setup
    @gateway = SallieMaeGateway.new(fixtures(:sallie_mae))
    
    @amount = 100
    @credit_card = credit_card('5454545454545454')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Accepted', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Cvv2 mismatch', response.message
  end

  def test_authorize_and_capture
    amount = (@amount * rand).to_i
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Accepted', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Missing account number', response.message
  end

  def test_invalid_login
    gateway = SallieMaeGateway.new(:login => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid merchant', response.message
  end
end
