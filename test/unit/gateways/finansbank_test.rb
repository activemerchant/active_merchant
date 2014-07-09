# encoding: utf-8
require 'test_helper'

class FinansbankTest < Test::Unit::TestCase
  def setup
    @original_kcode = nil
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
    assert_equal '1', response.authorization
    assert response.test?
  end

  def test_successful_authorize_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
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

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void(@options[:order_id])
    assert_success response
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void(@options[:order_id])
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(success_refund_response)

    assert response = @gateway.refund(5 * 100, @options[:order_id])
    assert_success response
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(5 * 100, @options[:order_id])
    assert_failure response
    assert response.test?
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(success_credit_response)

    assert response = @gateway.credit(5 * 100, @credit_card)
    assert_success response
    assert response.test?
  end

  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)

    assert response = @gateway.credit(5 * 100, @credit_card)
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

  def successful_void_response
    <<-EOF
<CC5Response>
  <OrderId>1</OrderId>
  <GroupId>1</GroupId>
  <Response>Approved</Response>
  <AuthCode>794573</AuthCode>
  <HostRefNum>402310197597</HostRefNum>
  <ProcReturnCode>00</ProcReturnCode>
  <TransId>14023KVGD18549</TransId>
  <ErrMsg></ErrMsg>
    <Extra>
    <SETTLEID>1363</SETTLEID>
    <TRXDATE>20140123 10:21:05</TRXDATE>
    <ERRORCODE></ERRORCODE>
    <NUMCODE>00</NUMCODE>
    </Extra>
</CC5Response>
  EOF
  end

  def failed_void_response
    <<-EOF
<CC5Response>
  <OrderId></OrderId>
  <GroupId></GroupId>
  <Response>Error</Response>
  <AuthCode></AuthCode>
  <HostRefNum></HostRefNum>
  <ProcReturnCode>99</ProcReturnCode>
  <TransId>14023KvNI18702</TransId>
  <ErrMsg>İptal edilmeye uygun satış işlemi bulunamadı.</ErrMsg>
  <Extra>
    <SETTLEID></SETTLEID>
    <TRXDATE>20140123 10:47:13</TRXDATE>
    <ERRORCODE>CORE-2008</ERRORCODE>
    <NUMCODE>992008</NUMCODE>
  </Extra>
</CC5Response>
    EOF
  end

  def success_refund_response
    <<-EOF
<CC5Response>
  <OrderId>1</OrderId>
  <GroupId>1</GroupId>
  <Response>Approved</Response>
  <AuthCode>811778</AuthCode>
  <HostRefNum>402410197809</HostRefNum>
  <ProcReturnCode>00</ProcReturnCode>
  <TransId>14024KACE13836</TransId>
  <ErrMsg></ErrMsg>
  <Extra>
    <SETTLEID>1364</SETTLEID>
    <TRXDATE>20140124 10:00:02</TRXDATE>
    <ERRORCODE></ERRORCODE>
    <PARAPUANTRL>000000001634</PARAPUANTRL>
    <PARAPUAN>000000001634</PARAPUAN>
    <NUMCODE>00</NUMCODE>
    <CAVVRESULTCODE>3</CAVVRESULTCODE>
  </Extra>
</CC5Response>
    EOF
  end

  def failed_refund_response
    <<-EOF
<CC5Response>
  <OrderId></OrderId>
  <GroupId></GroupId>
  <Response>Error</Response>
  <AuthCode></AuthCode>
  <HostRefNum></HostRefNum>
  <ProcReturnCode>99</ProcReturnCode>
  <TransId>14024KEwH13882</TransId>
  <ErrMsg>Iade yapilamaz, siparis gunsonuna girmemis.</ErrMsg>
  <Extra>
    <SETTLEID></SETTLEID>
    <TRXDATE>20140124 10:04:48</TRXDATE>
    <ERRORCODE>CORE-2508</ERRORCODE>
    <NUMCODE>992508</NUMCODE>
  </Extra>
</CC5Response>
    EOF
  end

  def success_credit_response
    <<-EOF
<CC5Response>
  <OrderId>ORDER-14024KUGB13953</OrderId>
  <GroupId>ORDER-14024KUGB13953</GroupId>
  <Response>Approved</Response>
  <AuthCode>718160</AuthCode>
  <HostRefNum>402410197818</HostRefNum>
  <ProcReturnCode>00</ProcReturnCode>
  <TransId>14024KUGD13955</TransId>
  <ErrMsg></ErrMsg>
  <Extra>
    <SETTLEID>1364</SETTLEID>
    <TRXDATE>20140124 10:20:06</TRXDATE>
    <ERRORCODE></ERRORCODE>
    <NUMCODE>00</NUMCODE>
    <CAVVRESULTCODE>3</CAVVRESULTCODE>
  </Extra>
</CC5Response>
    EOF
  end

  def failed_credit_response
    <<-EOF
<CC5Response>
  <OrderId></OrderId>
  <GroupId></GroupId>
  <Response>Error</Response>
  <AuthCode></AuthCode>
  <HostRefNum></HostRefNum>
  <ProcReturnCode>99</ProcReturnCode>
  <TransId>14024KUtG13966</TransId>
  <ErrMsg>Kredi karti numarasi gecerli formatta degil.</ErrMsg>
  <Extra>
    <SETTLEID></SETTLEID>
    <TRXDATE>20140124 10:20:45</TRXDATE>
    <ERRORCODE>CORE-2012</ERRORCODE>
    <NUMCODE>992012</NUMCODE>
  </Extra>
</CC5Response>
    EOF
  end
end
