require 'test_helper'
require 'pp'

class AuthorizeNetCardPresentTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = AuthorizeNetCardPresentGateway.new(fixtures(:authorize_net_card_present))
    @amount = 100
    @credit_card = credit_card('4007000000027')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end
  
  def test_successful_purchase
    puts "purchase"
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end
  
  def test_expired_credit_card
    puts "expired"
    @credit_card.year = 2004 
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match(/The credit card has expired/, response.message)
  end
  
  def test_forced_test_mode_purchase
    puts "test mode"
    gateway = AuthorizeNetCardPresentGateway.new(fixtures(:authorize_net_card_present).update(:test => true))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match(/TESTMODE/, response.message)
    assert response.authorization
  end
  
  def test_successful_authorization
    puts "successful auth"
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end
  
  def test_authorization_and_capture
    puts "auth capture"
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    # assert capture = @gateway.capture(@amount, authorization.authorization)
    assert capture = @gateway.capture(@amount, @options[:order_id])
    assert_success capture
    assert_match(/This transaction has been approved/, capture.message)
  end
  
  def test_authorization_and_void
    puts "auth void"
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_match(/This transaction has been approved/, void.message)
  end
  
  def test_bad_login
    puts "bad login"
    gateway = AuthorizeNetCardPresentGateway.new(
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

    assert_match(/The merchant login ID or password is invalid/, response.message)
    
    assert_equal false, response.success?
  end
  
  def test_using_test_request
    gateway = AuthorizeNetCardPresentGateway.new(
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
  
    assert_match(/The merchant login ID or password is invalid/, response.message)
    
    assert_equal false, response.success?    
  end
end
