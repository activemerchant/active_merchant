require 'test_helper'

class WepayTest < Test::Unit::TestCase
  def setup
    @gateway = WepayGateway.new(
      client_id: 'client_id',
      account_id: 'account_id',
      access_token: 'access_token'
    )

    @credit_card = credit_card
    @amount = 20000

    @options = {
      email: "test@example.com"
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "1117213582|200.00", response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, "1422891921", @options)
    assert_success response

    assert_equal "1117213582|200.00", response.authorization
  end

  def test_failed_purchase_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, "1422891921", @options)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "refund_reason parameter is required", response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "checkout type parameter must be either GOODS, SERVICE, DONATION, or PERSONAL", response.message
  end

  def test_successful_authorize_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, "1422891921", @options)
    assert_success response
  end

  def test_failed_authorize_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, "1422891921", @options)
    assert_failure response
    assert_equal "checkout type parameter must be either GOODS, SERVICE, DONATION, or PERSONAL", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).at_most(2).returns(successful_capture_response)

    response = @gateway.capture(@amount, "auth|amount", @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).at_most(2).returns(failed_capture_response)

    response = @gateway.capture("auth|amount", @options)
    assert_failure response
    assert_equal "Checkout object must be in state 'Reserved' to capture. Currently it is in state captured", response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void("auth|amount", @options)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void("auth|amount", @options)
    assert_failure response
    assert_equal "this checkout has already been cancelled", response.message
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "3322208138", response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal "Invalid credit card number", response.message
  end

  private

  def successful_store_response
    %({"credit_card_id": 3322208138,"state": "new"})
  end

  def failed_store_response
    %({"error": "invalid_request","error_description": "Invalid credit card number","error_code": 1003})
  end

  def successful_purchase_response
    %({"checkout_id":1117213582,"checkout_uri":"https://stage.wepay.com/api/checkout/1117213582/974ff0c0"})
  end

  def failed_purchase_response
    %({"error":"access_denied","error_description":"invalid account_id, account does not exist or does not belong to user","error_code":3002})
  end

  def successful_refund_response
    %({"checkout_id":1852898602,"state":"refunded"})
  end

  def failed_refund_response
    %({"error":"invalid_request","error_description":"refund_reason parameter is required","error_code":1004})
  end

  def successful_void_response
    %({"checkout_id":225040456,"state":"cancelled"})
  end

  def failed_void_response
    %({"error":"invalid_request","error_description":"this checkout has already been cancelled","error_code":4004})
  end

  def successful_authorize_response
    %({"checkout_id":640816095,"checkout_uri":"https://stage.wepay.com/api/checkout/640816095/974ff0c0"})
  end

  def failed_authorize_response
    %({"error":"invalid_request","error_description":"checkout type parameter must be either GOODS, SERVICE, DONATION, or PERSONAL","error_code":1003})
  end

  def successful_capture_response
    %({"checkout_id":1852898602,"state":"captured"})
  end

  def failed_capture_response
    %({"error":"invalid_request","error_description":"Checkout object must be in state 'Reserved' to capture. Currently it is in state captured","error_code":4004})
  end

end
