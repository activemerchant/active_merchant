require 'test_helper'

class RemoteItransactTest < Test::Unit::TestCase
  

  def setup
    @gateway = ItransactGateway.new(fixtures(:itransact))
    
    @amount = 1065
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_nil response.message
  end

#  As of March 8, 2012, iTransact does not provide a way to generate unsuccessful transactions through use of a
#  production gateway account in test mode.
#  def test_unsuccessful_purchase
#    assert response = @gateway.purchase(@amount, @credit_card, @options)
#    assert_failure response
#    assert_equal 'DECLINE', response.params['error_category']
#    assert_equal 'Code: NBE001 Your credit card was declined by the credit card processing network. Please use another card and resubmit your transaction.', response.message
#  end

  def test_authorize_and_capture
    amount = @amount
    assert response = @gateway.authorize(amount, @credit_card, @options)
    assert_success response
    assert_nil response.message
    assert response.authorization
    assert capture = @gateway.capture(amount, response.authorization)
    assert_success capture
  end

#  As of March 8, 2012, iTransact does not provide a way to generate unsuccessful transactions through use of a
#  production gateway account in test mode.
#  def test_failed_capture
#    assert response = @gateway.capture(@amount, '9999999999')
#    assert_failure response
#    assert_equal 'REPLACE WITH GATEWAY FAILURE MESSAGE', response.message
#  end

  def test_authorize_and_void
    amount = @amount
    assert response = @gateway.authorize(amount, @credit_card, @options)
    assert_success response
    assert_nil response.message
    assert response.authorization
    assert capture = @gateway.void(response.authorization)
    assert_success capture
  end

  def test_void
    assert void = @gateway.void('9999999999')
    assert_success void
  end

# As of Sep 19, 2012, iTransact REQUIRES the total amount for the refund.
#  def test_refund
#    assert refund = @gateway.refund(nil, '9999999999')
#    assert_success refund
#  end

  def test_refund_partial
    assert refund = @gateway.refund(555, '9999999999') # $5.55 in cents
    assert_success refund
  end

  def test_invalid_login
    gateway = ItransactGateway.new(
                :login => 'x',
                :password => 'x',
                :gateway_id => 'x'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid login credentials', response.message
  end
end
