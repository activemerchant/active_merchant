require File.dirname(__FILE__) + '/../test_helper'

class VerifiTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  LOGIN  = 'demo'
  PASSWORD = 'password'
  
  def setup
    @gateway = VerifiGateway.new(
      :login => LOGIN,
      :password => PASSWORD
    )
    
    @creditcard = credit_card('4111111111111111')
    
    #  Replace with your login and password for the Verifi test environment
    @options = {
      :order_id => 37,
      :email => "test@domain.com",   
      :address => { 
         :address1 => '164 Waverley Street', 
         :address2 => 'APT #7', 
         :country => 'US', 
         :city => 'Boulder', 
         :state => 'CO', 
         :zip => 12345 
         }     
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100, @creditcard, @options)
    assert response.success?
    assert_equal 'Transaction was Approved', response.message
    assert !response.authorization.blank?
  end
  
  # FOR SOME REASON Verify DOESN'T MIND EXPIRED CARDS
  # I talked to support and they said that they are loose on expiration dates being expired.
  def test_expired_credit_card
    @creditcard.year = (Time.now.year - 3) 
    assert response = @gateway.purchase(100, @creditcard, @options)
    assert response.success?
    assert_equal 'Transaction was Approved', response.message   
  end
    
  def test_successful_authorization
    assert response = @gateway.authorize(100, @creditcard, @options)
    assert response.success?
    assert_equal 'Transaction was Approved', response.message
    assert response.authorization
  end
  
  def test_authorization_and_capture
    amount = 100
    assert authorization = @gateway.authorize(amount, @creditcard, @options)
    assert authorization.success?
    assert authorization
    assert capture = @gateway.capture(amount, authorization.authorization, @options)  
    assert capture.success?
    assert_equal 'Transaction was Approved', capture.message
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(100, @creditcard, @options)
    assert authorization.success?
    assert authorization
    assert void = @gateway.void(authorization.authorization, @options)
    assert void.success?
    assert_equal 'Transaction was Approved', void.message
  end
  
  # Credits are not enabled on test accounts, so this should always fail  
  def test_credit
    assert response = @gateway.credit(100, @creditcard, @options)
    assert_match /Credits are not enabled/, response.params['responsetext']
    assert !response.success?  
  end
  
  def test_authorization_and_void
    amount = 100
    assert authorization = @gateway.authorize(amount, @creditcard, @options)
    assert authorization.success?
    assert void = @gateway.void(authorization.authorization, @options)
    assert void.success?
    assert_equal 'Transaction was Approved', void.message
    assert_match /Transaction Void Successful/, void.params['responsetext']
  end
  
  def test_purchase_and_credit
    amount = 100
    assert purchase = @gateway.purchase(amount, @creditcard, @options)
    assert purchase.success?
    
    assert credit = @gateway.credit(amount, purchase.authorization, @options)
    assert credit.success?
    assert_equal 'Transaction was Approved', credit.message
  end
  
  def test_bad_login
    gateway = VerifiGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    
    assert response = gateway.purchase(100, @creditcard, @options)
    assert_equal 'Transaction was Rejected by Gateway', response.message
    assert_equal 'Authentication Failed', response.params['responsetext']
    
    assert !response.success?
  end
end
