require File.dirname(__FILE__) + '/../test_helper'

class RemoteExactTest < Test::Unit::TestCase
  def setup
    
    
    @gateway = ExactGateway.new( :login    => "A00427-01",
                                 :password => "testus" )

    @credit_card = credit_card("4111111111111111")
    
    @options = { :address => { :address1 => "1234 Testing Ave.",
                               :zip      => "55555" } }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100, @credit_card, @options)
    assert_equal "Transaction Normal - VER UNAVAILABLE", response.message
    assert response.success?
  end

  def test_unsuccessful_purchase
    # ask for error 13 response (Amount Error) via dollar amount 5,000 + error
    assert response = @gateway.purchase(501300, @credit_card, @options )
    assert_equal "Transaction Normal - AMOUNT ERR", response.message
    assert !response.success?
  end

  def test_purchase_and_credit
    amount = 100
    assert purchase = @gateway.purchase(amount, @credit_card, @options)
    assert purchase.success?
    assert purchase.authorization
    assert credit = @gateway.credit(amount, purchase.authorization)
    assert credit.success?
  end
  
  def test_authorize_and_capture
    amount = 100
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert auth.success?
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert capture.success?
  end
  
  def test_failed_capture
    assert response = @gateway.capture(100, String.new)
    assert !response.success?
    assert_match /Precondition Failed/i, response.message
  end
  
  def test_invalid_login
    gateway = ExactGateway.new( :login    => "NotARealUser",
                                :password => "NotARealPassword" )
    assert response = gateway.purchase(100, @credit_card, @options)
    assert_equal "Invalid Logon", response.message
    assert !response.success?
  end
end
