require 'test_helper'
class AuthorizeNetCardPresentTest < Test::Unit::TestCase

  # These tests have been updated to use a "test account" at Authorize.net (register here:  https://developer.authorize.net/testaccount/) as opposed to a "real account" 
  # and sending the x_test_request parameter.  When using the test endpoint, you should NOT send the x_test_request parameter by using the {test: true} gateway option.
  # Instead, you should treat the requests exactly as you would in a real, production situation, but submit them against the test endpoint by including the {test_url: true}
  # gateway option.  It is possible to test a real account using the x_test_request parameter, however, testing using the testing endpoint
  # seems to be the most accurate reproduction of a real, production transaction.  More information here: http://developer.authorize.net/api/cardpresent/
  
  def setup
    Base.mode = :production # since we are using the testing endpoint, we do not want to be in "testmode" 
    @gateway = AuthorizeNetCardPresentGateway.new(fixtures(:authorize_net_card_present).merge(test_url: true))
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @year = Time.now.strftime("%y").to_i
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => 'Store purchase'
    }
  end
  
  def test_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
    assert_match(/This transaction has been approved/, capture.message)
  end
  
  def test_authorization_and_void
    assert authorization = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorization
    assert void = @gateway.void(authorization.authorization)
    assert_success void
    assert_match(/This transaction has been approved/, void.message)
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end
  
  def test_successful_purchase_with_track1_card_present
    track1_card_present = credit_card(nil, :track_data => "B4111111111111111^JOE/SCHMOE          ^#{(@year + 1)}01101150250000000000534000000")
    @options.merge!(:track_type => 1)
    assert response = @gateway.purchase(@amount, track1_card_present, @options)
    assert_success response
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end

  def test_successful_purchase_with_track2_card_present
    track2_card_present = credit_card(nil, :track_data => "4007000000027=#{(@year + 1)}12XXXXXXXXXXX")
    @options.merge!(:track_type => 2)
    assert response = @gateway.purchase(@amount, track2_card_present, @options)
    assert_success response
    assert_match(/This transaction has been approved/, response.message)
    assert response.authorization
  end
  
  def test_expired_credit_card
    @credit_card.year = 2004
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/The credit card has expired/, response.message)
  end

  def test_expired_credit_card_with_card_present
    track1_expired_card_present = credit_card(nil, :track_data => "B4111111111111111^JOE/SCHMOE          ^#{(@year - 1)}01101150250000000000534000000")
    @options.merge!(:track_type => 1)
    assert response = @gateway.purchase(@amount, track1_expired_card_present, @options)
    assert_failure response
    assert_match(/The credit card has expired/, response.message)
  end
  
  def test_forced_test_mode_purchase
    gateway = AuthorizeNetCardPresentGateway.new(fixtures(:authorize_net_card_present).update(:test => true).merge(test_url: true))
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
      :password => 'Y',
      :test_url => true
    )
    
    assert response = gateway.purchase(@amount, @credit_card)
        
    assert_equal Response, response.class
    assert_equal %w( authorization_code
                     avs_result_code
                     card_code
                     card_number
                     card_type
                     response_code
                     response_reason_code
                     response_reason_text
                     transaction_id ), 
                     response.params.keys.sort

    assert_match(/The merchant login ID or password is invalid/, response.message)
    
    assert_equal false, response.success?
  end
  
  def test_using_test_request
    gateway = AuthorizeNetCardPresentGateway.new(
      :login => 'X',
      :password => 'Y',
      :test_url => true
    )
    
    assert response = gateway.purchase(@amount, @credit_card)
        
    assert_equal Response, response.class
    assert_equal %w( authorization_code
                     avs_result_code
                     card_code
                     card_number
                     card_type
                     response_code
                     response_reason_code
                     response_reason_text
                     transaction_id ), 
                     response.params.keys.sort
  
    assert_match(/The merchant login ID or password is invalid/, response.message)
    
    assert_equal false, response.success?    
  end
end
