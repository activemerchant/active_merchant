require File.dirname(__FILE__) + '/../test_helper'

class MonerisRemoteTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = MonerisGateway.new(fixtures(:moneris))
    @creditcard = credit_card('4242424242424242')
    @expected_response_headers = [
      "auth_code",
      "bank_totals",
      "card_type",
      "complete",
      "iso",
      "message",
      "receipt_id",
      "reference_num",
      "response_code",
      "ticket",
      "timed_out",
      "trans_amount",
      "trans_date",
      "trans_id",
      "trans_time",
      "trans_type"
     ]
  end
  
  def test_should_be_a_successful_remote_purchase
    order_id = generate_order_id
    assert response = @gateway.purchase(100, @creditcard, :order_id => order_id)
    assert_equal Response, response.class
    assert_equal @expected_response_headers, response.params.keys.sort
    assert_match /APPROVED/, response.params['message']
    assert_equal 'Approved', response.message
    assert_equal true, response.params['complete']
    assert_equal true, response.success? # Checking for type-casting of XML, not actual success
    assert_equal order_id, response.params['receipt_id']
    assert_equal "#{response.params['trans_id']};#{response.params['receipt_id']}", response.authorization
  end
  
  def test_should_be_a_successful_authorization
    response = @gateway.authorize(100, @creditcard, :order_id => generate_order_id)
    assert_success response
    assert response.authorization
  end

  def test_should_not_be_a_successful_authorization
    response = @gateway.authorize(105, @creditcard, :order_id => generate_order_id)
    assert_failure response
  end

  def test_should_be_a_successful_authorization_and_capture
    response = @gateway.authorize(100, @creditcard, :order_id => generate_order_id)
    assert_success response
    assert response.authorization

    response = @gateway.capture(100, response.authorization)
    assert_success response
  end
  
  def test_should_be_a_successful_capture_and_void
    # First perform a successful authorization and capture
    response = @gateway.authorize(100, @creditcard, :order_id => generate_order_id)
    assert_success response
    assert response.authorization
    
    capture = @gateway.capture(100, response.authorization)
    assert_success capture
    assert capture.authorization
    
    # Now void it
    void = @gateway.void(capture.authorization)
    assert_success void
  end
  
  def test_should_be_a_successful_purchase_and_void
    purchase = @gateway.purchase(100, @creditcard, :order_id => generate_order_id)
    assert_success purchase
    
    void = @gateway.void(purchase.authorization)
    assert_success void
  end
  
  def test_should_not_be_a_successful_purchase_and_void
    purchase = @gateway.purchase(101, @creditcard, :order_id => generate_order_id)
    assert_failure purchase
    
    void = @gateway.void(purchase.authorization)
    assert_failure void
  end
  
  def test_should_be_a_successful_purchase_and_refund
    purchase = @gateway.purchase(100, @creditcard, :order_id => generate_order_id)
    assert_success purchase
    
    credit = @gateway.credit(100, purchase.authorization)
    assert_success credit
  end

  def test_should_be_a_remote_error
    assert response = @gateway.purchase(150, @creditcard, :order_id => generate_order_id)
    assert_equal Response, response.class
    assert_equal @expected_response_headers, response.params.keys.sort
    assert_match /DECLINED/, response.params['message']
    assert_equal 'Declined', response.message
    assert_equal true, response.params['complete']
    assert_equal false, response.success? # Checking for XML type-casting, not failure
  end
end
