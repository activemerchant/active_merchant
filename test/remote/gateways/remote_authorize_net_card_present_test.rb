require 'test_helper'

class AuthorizeNetCardPresentTest < Test::Unit::TestCase
  def setup
    # To test authorize_and_void and authorize_and_capture you must configure a REAL CREDIT CARD
    # Base.mode = :production # uncomment this line to test ONLY authorize_and_void and authorize_and_capture
    
    @gateway = AuthorizeNetCardPresentGateway.new(fixtures(:authorize_net_card_present))
    @amount = 100
    @credit_card = credit_card('4007000000027')
    @credit_card_present = credit_card(nil, :track2 => '4007000000027=1206XXXXXXXXXXX')
    @expired_credit_card_present = credit_card(nil, :track2 => '4007000000027=0805XXXXXXXXXXX')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end
  
  # This test requires live production access with a real credit card.
  # This test WILL MOVE MONEY.
  def test_authorization_and_capture
    return if Base.mode == :test # only tests in production mode
    assert_equal Base.mode, :production
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_match(/This transaction has been approved/, capture.message)
  end
  
  # This test requires live production access with a real credit card.
  # This test will attempt to move money, but void the transaction.
  def test_authorization_and_void
    return if Base.mode == :test # only tests in production mode
    assert_equal Base.mode, :production
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
  
    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_match(/This transaction has been approved/, void.message)
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end
  
  def test_successful_purchase_with_card_present
    assert response = @gateway.purchase(@amount, @credit_card_present, @options)
    assert_success response
    assert response.test?
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end
  
  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match(/The credit card has expired/, response.message)
  end

  def test_expired_credit_card_with_card_present
    assert response = @gateway.purchase(@amount, @expired_credit_card_present, @options)
    assert_failure response
    assert response.test?
    assert_match(/The credit card has expired/, response.message)
  end
  
  def test_forced_test_mode_purchase
    gateway = AuthorizeNetCardPresentGateway.new(fixtures(:authorize_net_card_present).update(:test => true))
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match(/TESTMODE/, response.message)
    assert response.authorization
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end
  
  def test_bad_login
    gateway = AuthorizeNetCardPresentGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    
    assert response = gateway.purchase(@amount, @credit_card)
        
    assert_equal Response, response.class
    assert_equal %w( authorization_code
                     avs_result_code
                     card_code
                     response_code
                     response_reason_code
                     response_reason_text
                     transaction_hash
                     transaction_id ), 
                     response.params.keys.sort

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
    assert_equal %w( authorization_code
                     avs_result_code
                     card_code
                     response_code
                     response_reason_code
                     response_reason_text
                     transaction_hash
                     transaction_id ), 
                     response.params.keys.sort
  
    assert_match(/The merchant login ID or password is invalid/, response.message)
    
    assert_equal false, response.success?    
  end
end
