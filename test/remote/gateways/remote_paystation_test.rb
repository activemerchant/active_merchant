require 'test_helper'

class RemotePaystationTest < Test::Unit::TestCase
  

  def setup
    @gateway = PaystationGateway.new(fixtures(:paystation))
    
    @credit_card = credit_card('5123456789012346', :month => 5, :year => 13, :verification_value => 123)
  
    @successful_amount          = 10000
    @insufficient_funds_amount  = 10051
    @invalid_transaction_amount = 10012
    @expired_card_amount        = 10054
    @bank_error_amount          = 10091
    
    @options = { 
      :billing_address => address,
      :description     => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@successful_amount, @credit_card, @options.merge(:order_id => get_uid))
    assert_success response
    
    assert_equal 'Transaction successful', response.message
  end
  
  def test_successful_purchase_in_gbp
    assert response = @gateway.purchase(@successful_amount, @credit_card, @options.merge(:currency => "GBP", :order_id => get_uid))
    assert_success response
    
    assert_equal 'Transaction successful', response.message
  end
  
  def test_failed_purchases
    [ 
      ["insufficient_funds", @insufficient_funds_amount, "Insufficient Funds"], 
      ["invalid_transaction", @invalid_transaction_amount, "Transaction Type Not Supported"],
      ["expired_card", @expired_card_amount, "Expired Card"],
      ["bank_error", @bank_error_amount, "Error Communicating with Bank"] 
    ].each do |name, amount, message|
     
        assert response = @gateway.purchase(amount, @credit_card, @options.merge(:order_id => get_uid))
        assert_failure response
        assert_equal message, response.message
      
    end
  end
  
  def test_storing_token  
    time = Time.now.to_i
    assert response = @gateway.store(@credit_card, @options.merge(:order_id => get_uid, :token => "justatest#{time}"))
    assert_success response
  
    assert_equal "Future Payment Saved Ok", response.message
    assert_equal "justatest#{time}", response.token
  end
  
  def test_billing_stored_token
    assert store_response = @gateway.store(@credit_card, @options.merge(:order_id => get_uid))
    assert_success store_response
    
    assert charge_response = @gateway.purchase(@successful_amount, store_response.token, @options.merge(:order_id => get_uid))
    assert_success charge_response
    assert_equal "Transaction successful", charge_response.message
  end
  
  def test_authorize_and_capture
    assert auth = @gateway.authorize(@successful_amount, @credit_card, @options.merge(:order_id => get_uid))
    
    assert_success auth
    assert auth.authorization 
    
    assert capture = @gateway.capture(@successful_amount, auth.authorization, @options.merge(:order_id => get_uid, :credit_card_verification => 123))
    assert_success capture
  end
  
  def test_capture_without_cvv
    # for some merchant accounts, paystation requires you send through the card verification value
    # on a capture request
    
    assert auth = @gateway.authorize(@successful_amount, @credit_card, @options.merge(:order_id => get_uid))
    
    assert_success auth
    assert auth.authorization
    
    assert capture = @gateway.capture(@successful_amount, auth.authorization, @options.merge(:order_id => get_uid))
    assert_failure capture
    
    assert_equal "Card Security Code (CVV/CSC) Required", capture.message
  end
  

  def test_invalid_login
    gateway = PaystationGateway.new(
               :paystation_id => '',
               :gateway_id    => ''
             )
    assert response = gateway.purchase(@amount, @credit_card, @options.merge(:order_id => get_uid))
  
    assert_failure response
    assert_nil response.authorization
  end
  
  private
  
    # should be unique enough for test purposes
    def get_uid
      ActiveSupport::SecureRandom.hex(16)
    end
end
