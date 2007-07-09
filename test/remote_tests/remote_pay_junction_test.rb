require File.dirname(__FILE__) + '/../test_helper'

class PayJunctionTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  cattr_accessor :current_invoice
  
  AMOUNT = 250
  
  def setup
    @gateway = PayJunctionGateway.new(
      :login => 'pj-ql-01',
      :password => 'pj-ql-01p'
    )

    @creditcard = credit_card('4433221111223344')
    
    @valid_verification_value = '123'
    @invalid_verification_value = '1234'
    
    @valid_address = {
      :address1 => '123 Test St.',
      :address2 => nil,
      :city => 'Somewhere', 
      :state => 'CA',
      :zip => '90001'
    }
    @invalid_address = {
      :address1 => '187 Apple Tree Lane.',
      :address2 => nil,
      :city => 'Woodside', 
      :state => 'CA', 
      :zip => '94062'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(AMOUNT, 
                                        @creditcard, 
                                        :order_id => generate_order_id)
    
    #p response
    assert_equal Response, response.class
    assert_match /APPROVAL/, response.message
    assert_equal 'capture', response.params["posture"], 'Should be captured funds'
    assert_equal 'charge', response.params["transaction_action"]
    
    assert_equal true, response.success?    
  end

  def test_successful_purchase_with_cvv
    @creditcard.verification_value = @valid_verification_value
    assert response = @gateway.purchase(AMOUNT, 
                                        @creditcard, 
                                        :order_id => generate_order_id)
        
    assert_equal Response, response.class  
    assert_match /APPROVAL/, response.message
    assert_equal 'capture', response.params["posture"], 'Should be captured funds'
    assert_equal 'charge', response.params["transaction_action"]
    
    assert_equal true, response.success?
  end

  def test_successful_authorize
    assert response = @gateway.authorize( AMOUNT, 
                                          @creditcard, 
                                          :order_id => generate_order_id)
    
    assert_equal Response, response.class
    assert_match /APPROVAL/, response.message
    assert_equal 'hold', response.params["posture"], 'Should be a held charge'
    assert_equal 'charge', response.params["transaction_action"]
    
    assert_equal true, response.success?    
  end

  def test_successful_capture
    order_id = generate_order_id
    auth = @gateway.authorize(AMOUNT, @creditcard, :order_id => order_id)
    assert auth.success?
    response = @gateway.capture(AMOUNT, auth.authorization, :order_id => order_id)
    
    assert response.success?
    assert_equal 'capture', response.params["posture"], 'Should be a capture'
    assert_equal auth.authorization, response.authorization,
        "Should maintain transaction ID across request"
  end

  def test_successful_credit
    purchase = @gateway.purchase(AMOUNT, @creditcard, :order_id => generate_order_id)
    assert purchase.success?
    
    assert response = @gateway.credit(success_price, purchase.authorization)
  
    assert_equal Response, response.class
    assert_equal 'refund', response.params["transaction_action"]
    
    assert_equal true, response.success?    
  end

  def test_successful_void
    order_id = generate_order_id
    purchase = @gateway.purchase(AMOUNT, @creditcard, :order_id => order_id)
    assert purchase.success?
    
    assert response = @gateway.void(AMOUNT, purchase.authorization, :order_id => order_id)
    assert_equal Response, response.class
    
    assert_equal true, response.success?
    assert_equal 'void', response.params["posture"], 'Should be a capture'
    assert_equal purchase.authorization, response.authorization,
        "Should maintain transaction ID across request"
  end

  def test_successful_instant_purchase
    # this takes advatange of the PayJunction feature where another
    # transaction can be executed if you have the transaction ID of a
    # previous successful transaction.
    
    purchase = @gateway.purchase( AMOUNT, 
                                  @creditcard, 
                                  :order_id => generate_order_id)
    assert purchase.success?
    
    assert response = @gateway.purchase(AMOUNT, 
                                        purchase.authorization, 
                                        :order_id => generate_order_id)

    assert_equal Response, response.class
    assert_match /APPROVAL/, response.message
    assert_equal 'capture', response.params["posture"], 'Should be captured funds'
    assert_equal 'charge', response.params["transaction_action"]
    assert_not_equal purchase.authorization, response.authorization,
        'Should have recieved new transaction ID'
    
    assert_equal true, response.success?
  end

  def test_successful_recurring
    assert response = @gateway.recurring(AMOUNT, @creditcard, 
                                            :periodicity  => :monthly,
                                            :payments     => 12,
                                            :order_id => generate_order_id)
    assert_equal Response, response.class
    assert_match /APPROVAL/, response.message
    assert_equal 'charge', response.params["transaction_action"]
    
    assert_equal true, response.success?
  end

  def test_should_send_invoice
    order_id = generate_order_id
    
    response = @gateway.purchase(AMOUNT, @creditcard, :order_id => order_id)
    assert response.success?
    
    assert_equal order_id, response.params["invoice_number"], 'Should have set invoice'
  end

  private
  def success_price
    200 + rand(200)
  end
end