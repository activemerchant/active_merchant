require 'test_helper'

class RemoteQuantumTest < Test::Unit::TestCase
  

  def setup
    @gateway = QuantumGateway.new(fixtures(:quantum))
    
    @amount = 100
    @credit_card = credit_card('4000100011112224')
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Transaction is APPROVED', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(1, @credit_card)
    assert_failure response
    assert_equal 'Transaction is DECLINED', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card)
    assert_success auth
    assert_equal 'Transaction is APPROVED', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'ERROR: TransactionID not found', response.message
  end

  def test_credit
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    assert response = @gateway.credit(@amount, response.authorization)
    assert_success response
  end

  def test_void
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
  end
  
  def test_passing_billing_address
    options = {:billing_address => address}
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Transaction is APPROVED', response.message
  end

  # For some reason, Quantum Gateway currently returns an HTML response if the login is invalid
  # So we check to see if the parse failed and report
  def test_invalid_login
    gateway = QuantumGateway.new(
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'ERROR: Invalid Gateway Login!!', response.message
  end
end
