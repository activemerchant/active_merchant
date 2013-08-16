require 'test_helper'

class RemoteRavenPacNetTest < Test::Unit::TestCase

  def setup
    @gateway = RavenPacNetGateway.new(fixtures(:raven_pac_net))

    @amount = 100
    @credit_card = credit_card('4000000000000028')
    @declined_card = credit_card('5100000000000040')

    @options = {
      :billing_address => address
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    
    puts response.inspect
    
    assert_equal 'This transaction has been approved', response.message
  end
  
  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'This transaction has been approved', auth.message
    assert auth.authorization
  
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end
  
  def test_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'This transaction has been approved', purchase.message
  
    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'This transaction has been approved', refund.message
  end
  
  def test_purchase_and_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'This transaction has been approved', purchase.message
    
    assert void = @gateway.void(purchase.authorization, {'PymtType' =>  purchase.params['PymtType']})
    assert_success void
    assert_equal "This transaction has been voided", void.message
  end
  
  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
  
    assert_failure response
    assert response.message.include?('Error processing transaction because the pre-auth number')
  end
  
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'This transaction has been declined', response.message
  end
end
