require File.dirname(__FILE__) + '/../test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    #  Replace with your login and password for the Authorize.net test environment
    @login = 'X'
    @password = 'Y'
    
    @gateway = AuthorizeNetGateway.new(
      :login => @login,
      :password => @password
    )

    @creditcard = CreditCard.new(
      :number => '4242424242424242',
      :month => 8,
      :year => Time.now.year + 1,
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    )
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100, @creditcard,
      :order_id => generate_order_id,
      :description => 'Store purchase'
    )
    assert response.success?
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
  
  def test_expired_credit_card
    @creditcard.year = 2004 
    assert response = @gateway.purchase(100, @creditcard, :order_id => generate_order_id)
    assert !response.success?
    assert response.test?
    assert_equal 'The credit card has expired', response.message
  end
  
  def test_forced_test_mode_purchase
    gateway = AuthorizeNetGateway.new(
      :login => @login,
      :password => @password,
      :test => true
    )
    assert response = gateway.purchase(100, @creditcard, :order_id => generate_order_id)
    assert response.success?
    assert response.test?
    assert_match /TESTMODE/, response.message
    assert response.authorization
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(100, @creditcard, :order_id => generate_order_id)
    assert response.success?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
  
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(100, @creditcard, :order_id => generate_order_id)
    assert authorization.success?
    assert authorization
    assert capture = @gateway.capture(100, authorization.authorization)
    assert capture.success?
    assert_equal 'This transaction has been approved', capture.message
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(100, @creditcard, :order_id => generate_order_id)
    assert authorization.success?
    assert authorization
    assert void = @gateway.void(authorization.authorization)
    assert void.success?
    assert_equal 'This transaction has been approved', void.message
  end
  
  def test_bad_login
    gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    
    
    assert response = gateway.purchase(100, @creditcard)
        
    assert_equal Response, response.class
    assert_equal ["avs_message",
                  "avs_result_code",
                  "card_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort

    assert_match /The merchant login ID or password is invalid/, response.message
    
    assert_equal false, response.success?
  end
  
  def test_using_test_request
    gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    
    assert response = gateway.purchase(100, @creditcard)
        
    assert_equal Response, response.class
    assert_equal ["avs_message", 
                  "avs_result_code",
                  "card_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort
  
    assert_match /The merchant login ID or password is invalid/, response.message
    
    assert_equal false, response.success?    
  end
end
