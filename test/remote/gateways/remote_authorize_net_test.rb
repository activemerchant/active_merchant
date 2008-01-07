require File.dirname(__FILE__) + '/../../test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = AuthorizeNetGateway.new(fixtures(:authorize_net))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :order_id => generate_order_id, 
                 :billing_address => address,
                 :description => 'Store purchase'
               }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
  
  def test_expired_credit_card
    @credit_card.year = 2004 
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal 'The credit card has expired', response.message
  end
  
  def test_forced_test_mode_purchase
    gateway = AuthorizeNetGateway.new(fixtures(:authorize_net).update(:test => true))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match /TESTMODE/, response.message
    assert response.authorization
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
    assert response.authorization
  end
  
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_equal 'This transaction has been approved', capture.message
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_equal 'This transaction has been approved', void.message
  end
  
  def test_bad_login
    gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    
    assert response = gateway.purchase(@amount, @credit_card)
        
    assert_equal Response, response.class
    assert_equal ["avs_result_code",
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
    
    assert response = gateway.purchase(@amount, @credit_card)
        
    assert_equal Response, response.class
    assert_equal ["avs_result_code",
                  "card_code",
                  "response_code",
                  "response_reason_code",
                  "response_reason_text",
                  "transaction_id"], response.params.keys.sort
  
    assert_match /The merchant login ID or password is invalid/, response.message
    
    assert_equal false, response.success?    
  end
end
