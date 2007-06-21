require File.dirname(__FILE__) + '/../test_helper'

class PlugnpayTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  def setup
    
    # To run these tests, you must obtain a gateway test account from plugnpay.com and enter the login/passwd below.
    @login = 'login'
    @password = 'password'
   
    
    @gateway = PlugnpayGateway.new(
      :login => @login,
      :password => @password
    )

    @good_creditcard = credit_card('4242424242424242')
    @bad_creditcard = credit_card('1234123412341234')
  end
  
  def test_bad_credit_card
    assert response = @gateway.authorize(1000, @bad_creditcard)
    assert !response.success?
    assert_equal 'Invalid Credit Card No.', response.message
  end
  
  def test_good_credit_card
    assert response = @gateway.authorize(1000, @good_creditcard)
    assert response.success?
    assert !response.authorization.blank?
    assert_equal 'Success', response.message
  end
  
  def test_purchase_transaction
    assert response = @gateway.purchase(1000, @good_creditcard)        
    assert response.success? 
    assert !response.authorization.blank?
    assert_equal 'Success', response.message
  end
  
  # Capture, and Void require that you Whitelist your IP address.
  # In the gateway admin tool, you must add your IP address to the allowed addresses and uncheck "Remote client" under the 
  # "Auth Transactions" section of the "Security Requirements" area in the test account Security Administration Area.
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(100, @good_creditcard)
    assert authorization.success?
    
    assert capture = @gateway.capture(100, authorization.authorization)
    assert capture.success?
    assert_equal 'Success', capture.message
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(100, @good_creditcard)
    assert authorization.success?
    
    assert void = @gateway.void(authorization.authorization)
    assert void.success?
    assert_equal 'Success', void.message
  end
  
  def test_purchase_and_credit
    amount = 100
    
    assert purchase = @gateway.purchase(amount, @good_creditcard)
    assert purchase.success?
    
    assert credit = @gateway.credit(amount, purchase.authorization)
    assert credit.success?
    assert_equal 'Success', credit.message
  end
  
  def test_credit_with_no_previous_transaction
    assert credit = @gateway.credit(100, @good_creditcard)
    
    assert credit.success?
    assert_equal 'Success', credit.message
  end
end