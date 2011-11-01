require 'test_helper'

class RemoteJetpayTest < Test::Unit::TestCase

  def setup
    @gateway = JetpayGateway.new(fixtures(:jetpay))
    
    @credit_card = credit_card('4000300020001000')
    @declined_card = credit_card('4000300020001000')
    
    @options = {
      :order_id => '1',
      :billing_address => address(:country => 'US', :zip => '75008'),
      :shipping_address => address(:country => 'US'),
      :email => 'test@test.com',
      :ip => '127.0.0.1',
      :order_id => '12345',
      :tax => 7
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(9900, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]
  end
  
  def test_unsuccessful_purchase
    assert response = @gateway.purchase(5205, @declined_card, @options)
    assert_failure response
    assert_equal "Do not honor.", response.message
  end
  
  def test_authorize_and_capture
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]
    
    assert capture = @gateway.capture(9900, auth.authorization)
    assert_success capture
  end
  
  def test_void
    # must void a valid auth
    assert auth = @gateway.authorize(9900, @credit_card, @options)
    assert_success auth
    assert_equal 'APPROVED', auth.message
    assert_not_nil auth.authorization
    assert_not_nil auth.params["approval"]
    
    assert void = @gateway.void(auth.authorization)
    assert_success void
  end
  
  def test_refund
    # no need for csv
    card = credit_card('4242424242424242', :verification_value => nil)
    
    assert response = @gateway.purchase(9900, card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_not_nil response.authorization
    assert_not_nil response.params["approval"]
    
    # linked to a specific transaction_id
    assert credit = @gateway.refund(9900, response.authorization, :credit_card => card)
    assert_success credit
    assert_not_nil(credit.authorization)
    assert_not_nil(response.params["approval"])
    assert_equal [response.params['transaction_id'], response.params["approval"], 9900].join(";"), response.authorization
  end
  
  def test_credit
    # no need for csv
    card = credit_card('4242424242424242', :verification_value => nil)
    
    # no link to a specific transaction_id
    assert credit = @gateway.credit(9900, card)
    assert_success credit
    assert_not_nil(credit.authorization)
    assert_not_nil(credit.params["approval"])
  end
  
  def test_failed_capture
    assert response = @gateway.capture(9900, '7605f7c5d6e8f74deb')
    assert_failure response
    assert_equal 'Transaction Not Found.', response.message
  end

  def test_invalid_login
    gateway = JetpayGateway.new(:login => 'bogus')
    assert response = gateway.purchase(9900, @credit_card, @options)
    assert_failure response
    
    assert_equal 'Terminal ID Not Found.', response.message
  end
  
  def test_missing_login
    gateway = JetpayGateway.new(:login => '')
    assert response = gateway.purchase(9900, @credit_card, @options)
    assert_failure response
    
    assert_equal 'No response returned (missing credentials?).', response.message
  end
end
