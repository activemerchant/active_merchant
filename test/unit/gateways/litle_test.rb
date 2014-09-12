require 'test_helper'

class LitleTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = LitleGateway.new(
      login: 'login',
      password: 'password',
      merchant_id: 'merchant_id'
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "100000000000000006;sale", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Insufficient Funds", response.message
    assert_equal "110", response.params["response"]
    assert response.test?
  end

  def test_passing_name_on_card
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(%r(<billToAddress>\s*<name>Longbob Longsen<), data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_order_id
    stub_comms do
      @gateway.purchase(@amount, @credit_card, order_id: "774488")
    end.check_request do |endpoint, data, headers|
      assert_match(/774488/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_billing_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, billing_address: address)
    end.check_request do |endpoint, data, headers|
      assert_match(/<billToAddress>.*Widgets.*1234.*Apt 1.*Otta.*ON.*K1C.*CA.*555-5/m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_shipping_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, shipping_address: address)
    end.check_request do |endpoint, data, headers|
      assert_match(/<shipToAddress>.*Widgets.*1234.*Apt 1.*Otta.*ON.*K1C.*CA.*555-5/m, data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response

    assert_equal "100000000000000001;authorization", response.authorization
    assert response.test?

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/100000000000000001/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Insufficient Funds", response.message
    assert_equal "110", response.params["response"]
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(@amount, @credit_card)
    end.respond_with(failed_capture_response)

    assert_failure response
    assert_equal "No transaction found with specified litleTxnId", response.message
    assert_equal "360", response.params["response"]
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_equal "100000000000000006;sale", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/100000000000000006/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(@amount, "SomeAuthorization")
    end.respond_with(failed_refund_response)

    assert_failure response
    assert_equal "No transaction found with specified litleTxnId", response.message
    assert_equal "360", response.params["response"]
  end

  def test_successful_void_of_authorization
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "100000000000000001;authorization", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/<authReversal.*<litleTxnId>100000000000000001</m, data)
    end.respond_with(successful_void_of_auth_response)

    assert_success void
  end

  def test_successful_void_of_other_things
    refund = stub_comms do
      @gateway.refund(@amount, "SomeAuthorization")
    end.respond_with(successful_refund_response)

    assert_equal "100000000000000003;credit", refund.authorization

    void = stub_comms do
      @gateway.void(refund.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/<void.*<litleTxnId>100000000000000003</m, data)
    end.respond_with(successful_void_of_other_things_response)

    assert_success void
  end

  def test_failed_void_of_authorization
    response = stub_comms do
      @gateway.void("123456789012345360;authorization")
    end.respond_with(failed_void_of_authorization_response)

    assert_failure response
    assert_equal "No transaction found with specified litleTxnId", response.message
    assert_equal "360", response.params["response"]
  end

  def test_failed_void_of_other_things
    response = stub_comms do
      @gateway.void("123456789012345360;credit")
    end.respond_with(failed_void_of_other_things_response)

    assert_failure response
    assert_equal "No transaction found with specified litleTxnId", response.message
    assert_equal "360", response.params["response"]
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/<accountNumber>4242424242424242</, data)
    end.respond_with(successful_store_response)

    assert_success response
    assert_equal "1111222233330123", response.authorization
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal "Credit card number was invalid", response.message
    assert_equal "820", response.params["response"]
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, successful_void_of_auth_response)
    assert_success response
  end

  def test_successful_verify_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_of_authorization_response)
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_of_auth_response)
    assert_failure response
    assert_equal "Insufficient Funds", response.message
  end

  def test_add_swipe_data_with_creditcard
    @credit_card.track_data = "Track Data"

    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match "<track>Track Data</track>", data
      assert_match "<orderSource>retail</orderSource>", data
      assert_match %r{<pos>.+<\/pos>}m, data
    end.respond_with(successful_purchase_response)
  end

  def test_order_source_with_creditcard_no_track_data
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match "<orderSource>ecommerce</orderSource>", data
      assert_not_match %r{<pos>.+<\/pos>}m, data
    end.respond_with(successful_purchase_response)
  end

  private

  def successful_purchase_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <saleResponse id='1' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000006</litleTxnId>
          <orderId>1</orderId>
          <response>000</response>
          <responseTime>2014-03-31T11:34:39</responseTime>
          <message>Approved</message>
          <authCode>11111 </authCode>
          <fraudResult>
            <avsResult>01</avsResult>
            <cardValidationResult>M</cardValidationResult>
          </fraudResult>
        </saleResponse>
      </litleOnlineResponse>
    )
  end

  def failed_purchase_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <saleResponse id='6' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>600000000000000002</litleTxnId>
          <orderId>6</orderId>
          <response>110</response>
          <responseTime>2014-03-31T11:48:47</responseTime>
          <message>Insufficient Funds</message>
          <fraudResult>
            <avsResult>34</avsResult>
            <cardValidationResult>P</cardValidationResult>
          </fraudResult>
        </saleResponse>
      </litleOnlineResponse>
    )
  end

  def successful_authorize_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authorizationResponse id='1' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000001</litleTxnId>
          <orderId>1</orderId>
          <response>000</response>
          <responseTime>2014-03-31T12:21:56</responseTime>
          <message>Approved</message>
          <authCode>11111 </authCode>
          <fraudResult>
            <avsResult>01</avsResult>
            <cardValidationResult>M</cardValidationResult>
          </fraudResult>
        </authorizationResponse>
      </litleOnlineResponse>
    )
  end

  def failed_authorize_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authorizationResponse id='6' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>600000000000000001</litleTxnId>
          <orderId>6</orderId>
          <response>110</response>
          <responseTime>2014-03-31T12:24:21</responseTime>
          <message>Insufficient Funds</message>
          <fraudResult>
            <avsResult>34</avsResult>
            <cardValidationResult>P</cardValidationResult>
          </fraudResult>
        </authorizationResponse>
      </litleOnlineResponse>
    )
  end

  def successful_capture_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <captureResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000002</litleTxnId>
          <response>000</response>
          <responseTime>2014-03-31T12:28:07</responseTime>
          <message>Approved</message>
        </captureResponse>
      </litleOnlineResponse>
    )
  end

  def failed_capture_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <captureResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>304546900824606360</litleTxnId>
          <response>360</response>
          <responseTime>2014-03-31T12:30:53</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </captureResponse>
      </litleOnlineResponse>
    )
  end

  def successful_refund_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <creditResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000003</litleTxnId>
          <response>000</response>
          <responseTime>2014-03-31T12:36:50</responseTime>
          <message>Approved</message>
        </creditResponse>
      </litleOnlineResponse>
    )
  end

  def failed_refund_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <creditResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>996483567570258360</litleTxnId>
          <response>360</response>
          <responseTime>2014-03-31T12:42:41</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </creditResponse>
      </litleOnlineResponse>
    )
  end

  def successful_void_of_auth_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authReversalResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>972619753208653000</litleTxnId>
          <orderId>123</orderId>
          <response>000</response>
          <responseTime>2014-03-31T12:45:44</responseTime>
          <message>Approved</message>
        </authReversalResponse>
      </litleOnlineResponse>
    )
  end

  def successful_void_of_other_things_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <voidResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>100000000000000004</litleTxnId>
          <response>000</response>
          <responseTime>2014-03-31T12:44:52</responseTime>
          <message>Approved</message>
        </voidResponse>
      </litleOnlineResponse>
    )
  end

  def failed_void_of_authorization_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <authReversalResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>775712323632364360</litleTxnId>
          <orderId>123</orderId>
          <response>360</response>
          <responseTime>2014-03-31T13:03:17</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </authReversalResponse>
      </litleOnlineResponse>
    )
  end

  def failed_void_of_other_things_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <voidResponse id='' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>486912375928374360</litleTxnId>
          <response>360</response>
          <responseTime>2014-03-31T12:55:46</responseTime>
          <message>No transaction found with specified litleTxnId</message>
        </voidResponse>
      </litleOnlineResponse>
    )
  end

  def successful_store_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <registerTokenResponse id='50' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>501000000000000001</litleTxnId>
          <orderId>50</orderId>
          <litleToken>1111222233330123</litleToken>
          <response>801</response>
          <responseTime>2014-03-31T13:06:41</responseTime>
          <message>Account number was successfully registered</message>
          <bin>445711</bin>
          <type>VI</type>
        </registerTokenResponse>
      </litleOnlineResponse>
    )
  end

  def failed_store_response
    %(
      <litleOnlineResponse version='8.22' response='0' message='Valid Format' xmlns='http://www.litle.com/schema'>
        <registerTokenResponse id='51' reportGroup='Default Report Group' customerId=''>
          <litleTxnId>510000000000000001</litleTxnId>
          <orderId>51</orderId>
          <response>820</response>
          <responseTime>2014-03-31T13:10:51</responseTime>
          <message>Credit card number was invalid</message>
        </registerTokenResponse>
      </litleOnlineResponse>
    )
  end

end
