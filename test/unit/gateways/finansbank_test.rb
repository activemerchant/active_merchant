require 'test_helper'

class FinansbankTest < Test::Unit::TestCase
  def setup
    if RUBY_VERSION < '1.9' && $KCODE == "NONE"
      @original_kcode = $KCODE
      $KCODE = 'u'
    end

    @gateway = FinansbankGateway.new(
      :login => 'login',
      :password => 'password',
      :client_id => 'client_id'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def teardown
    $KCODE = @original_kcode if @original_kcode
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1', response.authorization
    assert response.test?
  end

  def test_successful_authorize_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1', response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, response.authorization, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '1', response.authorization

    assert response.test?
  end

  def test_capture_without_authorize
    @gateway.expects(:ssl_post).returns(capture_without_authorize_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    <<-EOF
<CC5Response>
      <OrderId>1</OrderId>
      <GroupId>1</GroupId>
      <Response>Approved</Response>
      <AuthCode>123456</AuthCode>
      <HostRefNum>123456</HostRefNum>
      <ProcReturnCode>00</ProcReturnCode>
      <TransId>123456</TransId>
      <ErrMsg></ErrMsg>
</CC5Response>
    EOF
  end

  def failed_purchase_response
    <<-EOF
<CC5Response>
      <OrderId>1</OrderId>
      <GroupId>2</GroupId>
      <Response>Declined</Response>
      <AuthCode></AuthCode>
      <HostRefNum>123456</HostRefNum>
      <ProcReturnCode>12</ProcReturnCode>
      <TransId>123456</TransId>
      <ErrMsg>Not enough credit</ErrMsg>
</CC5Response>
    EOF
  end

  def successful_authorize_response
    <<-EOF
<CC5Response>
  <OrderId>1</OrderId>
  <GroupId>1</GroupId>
  <Response>Approved</Response>
  <AuthCode>794573</AuthCode>
  <HostRefNum>305219419620</HostRefNum>
  <ProcReturnCode>00</ProcReturnCode>
  <TransId>13052TpOI06012476</TransId>
  <ErrMsg></ErrMsg>
  <Extra>
    <SETTLEID>411</SETTLEID>
    <TRXDATE>20130221 19:41:14</TRXDATE>
    <ERRORCODE></ERRORCODE>
    <HOSTMSG>ISLEMINIZ ONAYLANDI</HOSTMSG>
    <NUMCODE>00</NUMCODE>
    <HOSTCODE>000</HOSTCODE>
    <ISYERI3DSECURE>N</ISYERI3DSECURE>
  </Extra>
</CC5Response>
    EOF
  end

  def successful_capture_response
    <<-EOF
<CC5Response>
  <OrderId>1</OrderId>
  <GroupId>1</GroupId>
  <Response>Approved</Response>
  <AuthCode>794573</AuthCode>
  <HostRefNum>305219419622</HostRefNum>
  <ProcReturnCode>00</ProcReturnCode>
  <TransId>13052TpPH06012485</TransId>
  <ErrMsg></ErrMsg>
  <Extra>
    <SETTLEID>411</SETTLEID>
    <TRXDATE>20130221 19:41:15</TRXDATE>
    <ERRORCODE></ERRORCODE>
    <NUMCODE>00</NUMCODE>
  </Extra>
</CC5Response>
    EOF
  end

  def capture_without_authorize_response
    <<-EOF
<CC5Response>
  <OrderId></OrderId>
  <GroupId></GroupId>
  <Response>Error</Response>
  <AuthCode></AuthCode>
  <HostRefNum></HostRefNum>
  <ProcReturnCode>99</ProcReturnCode>
  <TransId>13052TtZF06012712</TransId>
  <ErrMsg>PostAuth sadece iliskili bir PreAuth icin yapilabilir.</ErrMsg>
  <Extra>
    <SETTLEID></SETTLEID>
    <TRXDATE>20130221 19:45:25</TRXDATE>
    <ERRORCODE>CORE-2115</ERRORCODE>
    <NUMCODE>992115</NUMCODE>
  </Extra>
</CC5Response>
    EOF
  end
end
