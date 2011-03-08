require 'test_helper'

class RemotePpiPaymoverTest < Test::Unit::TestCase
  

  def setup
    @gateway = PpiPaymoverGateway.new(fixtures(:ppi_paymover))
    
    @amounts = {
      :success => 1,
      :declined => 10,
      :hold_card => 28
    }
    @credit_card = credit_card('4788250000028291')
    
    @options = { 
      :order_id => Array.new(9, '').collect{("1".."9").to_a[rand(10)]}.join,
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success response
    assert_equal 'Successful transaction: Test transaction response.', response.message
  end
  
  def test_failed_authorization
    assert response = @gateway.authorize(@amounts[:declined], @credit_card, @options)
    assert_failure response
    assert_equal 'Card declined: Test transaction response.', response.message
  end
  
  def test_successful_purchase
     assert response = @gateway.purchase(@amounts[:success], @credit_card, @options)
     assert_success response
     assert !response.fraud_review?
     assert_equal 'Successful transaction: Test transaction response.', response.message
  end
  
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amounts[:declined], @credit_card, @options)
    assert_failure response
    assert !response.fraud_review?
    assert_equal 'Card declined: Test transaction response.', response.message
  end
  
  def test_fraud_purchase
    assert response = @gateway.purchase(@amounts[:hold_card], @credit_card, @options)
    assert_failure response
    assert response.fraud_review?
    assert_equal 'Card declined: Test transaction response: Hold card and call issuer.', response.message
  end
  
  def test_authorize_and_capture
    amount = @amounts[:success]
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction: Test transaction response.', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amounts[:success], @credit_card, @options)
    assert_success authorization
    
    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'Successful transaction: Test transaction response.', void.message
  end
  
  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amounts[:success], @credit_card, @options)
    assert_success purchase
    
    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Successful transaction: Test transaction response.', void.message
  end
  
  def test_auth_capture_and_void
    amount = @amounts[:success]
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Successful transaction: Test transaction response.', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    
    assert void = @gateway.void(capture.authorization)
    assert_success void
    assert_equal 'Successful transaction: Test transaction response.', void.message
  end

  def test_failed_capture
    assert response = @gateway.capture(@amounts[:success], '')
    assert_failure response
    assert_equal 'Missing required request field: Order ID', response.message
  end
  
  def test_invalid_login
    gateway = PpiPaymoverGateway.new(
                :login => ''
              )
    assert response = gateway.purchase(@amounts[:success], @credit_card, @options)
    assert_failure response
    assert_equal 'Missing Required Request Field: Account Token.', response.message
  end
end
