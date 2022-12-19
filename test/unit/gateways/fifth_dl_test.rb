require 'test_helper'

class FifthDlTest < Test::Unit::TestCase
  def setup
    @gateway = FifthDlGateway.new(
      apikey: "QYBS1PMSAG3LAN7C81DPJ8ID",
      mkey: "QYBS1PMSAG3LAN7C81DPJ8ID",
      apiname: "trsdemo"
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '2848055', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "2864506", response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, 411, @options)
    assert_success response
    assert_equal "2864510", response.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(1000, 411)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, 411, @options)
    assert_success response
    assert_equal "2864515", response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(1000, 411)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void("1234")
    assert_success response
    assert_equal "2864516", response.authorization
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void("1234")
    assert_failure response
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  private

  def successful_purchase_response
    { "response"=>"1",
      "textresponse"=>"SUCCESS",
      "transid"=>"2848055",
      "xref"=>"2457314085",
      "authcode"=>"123456",
      "orderid"=>"",
      "type"=>"sale",
      "avsresponse"=>"N",
      "cvvresponse"=>"N",
      "coderesponse"=>"100",
      "codedescription"=>"Transaction was Approved"
    }.to_query
  end

  def failed_purchase_response
    { "response"=>"3",
      "textresponse"=>"Flagged for Review by Velocity and Duplicates Policy (Duplicate Sale Transactions Rule). ",
      "transid"=>"2859339",
      "xref"=>"",
      "authcode"=>"",
      "orderid"=>"",
      "type"=>"sale",
      "avsresponse"=>"",
      "cvvresponse"=>"",
      "coderesponse"=>"",
      "codedescription"=>""
    }.to_query
  end

  def successful_authorize_response
    { "response"=>"1", 
      "textresponse"=>"SUCCESS", 
      "transid"=>"2864506", 
      "xref"=>"2458121998", 
      "authcode"=>"123456", 
      "orderid"=>"", 
      "type"=>"auth", 
      "avsresponse"=>"N", 
      "cvvresponse"=>"N", 
      "coderesponse"=>"100", 
      "codedescription"=>"Transaction was Approved"
    }.to_query
  end

  def failed_authorize_response
    { "response"=>"3",
      "textresponse"=>"Flagged for Review by Velocity and Duplicates Policy (Duplicate Sale Transactions Rule). ",
      "transid"=>"2864507",
      "xref"=>"",
      "authcode"=>"",
      "orderid"=>"",
      "type"=>"auth",
      "avsresponse"=>"",
      "cvvresponse"=>"",
      "coderesponse"=>"",
      "codedescription"=>""
    }.to_query
  end

  def successful_capture_response
    { "response"=>"1", 
      "textresponse"=>"SUCCESS", 
      "transid"=>"2864510", 
      "xref"=>"2458125913", 
      "authcode"=>"123456", 
      "orderid"=>"", 
      "type"=>"capture", 
      "avsresponse"=>"N", 
      "cvvresponse"=>"N", 
      "coderesponse"=>"100", 
      "codedescription"=>"Transaction was Approved"
    }.to_query
  end

  def failed_capture_response
    { "response"=>"3",
      "textresponse"=>"Internal processing error, please try again later",
      "transid"=>"2864510",
      "xref"=>"2458125913",
      "authcode"=>"123456",
      "orderid"=>"",
      "type"=>"capture",
      "avsresponse"=>"N",
      "cvvresponse"=>"N",
      "coderesponse"=>"",
      "codedescription"=>""
    }.to_query
  end

  def successful_refund_response
    { "response"=>"1", 
      "textresponse"=>"SUCCESS",
      "transid"=>"2864515",
      "xref"=>"2458130621", 
      "authcode"=>"123456", 
      "orderid"=>"", 
      "type"=>"refund", 
      "avsresponse"=>"N", 
      "cvvresponse"=>"N",
      "coderesponse"=>"100",
      "codedescription"=>"Transaction was Approved"
    }.to_query
  end

  def failed_refund_response
    { "response"=>"3", 
      "textresponse"=>"Cannot refund more than initial sale amount", 
      "transid"=>"2864515", 
      "xref"=>"2458130621", 
      "authcode"=>"123456", 
      "orderid"=>"", 
      "type"=>"refund", 
      "avsresponse"=>"N", 
      "cvvresponse"=>"N", 
      "coderesponse"=>"", 
      "codedescription"=>"" 
    }.to_query
  end

  def successful_void_response
    { "response"=>"1",
      "textresponse"=>"Transaction Void Successful",
      "transid"=>"2864516",
      "xref"=>"2458132288",
      "authcode"=>"123456",
      "orderid"=>"",
      "type"=>"void",
      "avsresponse"=>"N",
      "cvvresponse"=>"N",
      "coderesponse"=>"100",
      "codedescription"=>"Transaction was Approved" }.to_query
  end

  def failed_void_response
    { "response"=>"3", 
      "textresponse"=>"Can't find transaction. Check the value of payment field transid.", 
      "type"=>"void", 
      "coderesponse"=>"", 
      "codedescription"=>"" }.to_query
  end
end