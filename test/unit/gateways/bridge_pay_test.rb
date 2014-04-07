require 'test_helper'

class BridgePayTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = BridgePayGateway.new(
      user_name: 'login',
      password: 'password'
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    assert_equal 'OK9757|837495', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Duplicate Transaction', response.message
  end

  def test_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "OK2657|838662", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/OK2657/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "OK9757|837495", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/OK9757/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "OK9757|837495", response.authorization

    refund = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/OK9757/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_passing_cvv
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/#{@credit_card.verification_value}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_billing_address
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :billing_address => address)
    end.check_request do |endpoint, data, headers|
      assert_match(/Street=1234\+My\+Street/, data)
      assert_match(/Zip=K1C2N6/, data)
    end.respond_with(successful_purchase_response)
  end

  private

  def successful_purchase_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>APPROVAL</Message>
        <AuthCode>OK9757</AuthCode>
        <PNRef>837495</PNRef>
        <HostCode>837495</HostCode>
        <GetAVSResult>Z</GetAVSResult>
        <GetAVSResultTXT>5 Zip Match No Address Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>Match</GetZipMatchTXT>
        <GetCVResult>P</GetCVResult>
        <GetCVResultTXT>Service Not Available</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=VISA</ExtData>
      </Response>
    )
  end

  def failed_purchase_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>110</Result>
        <RespMSG>Duplicate Transaction</RespMSG>
        <Message>Duplicate transaction</Message>
        <PNRef>837614</PNRef>
        <HostCode>837613</HostCode>
        <GetGetOrigResult>OK2538</GetGetOrigResult>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=VISA</ExtData>
      </Response>
    )
  end

  def successful_authorize_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>APPROVAL</Message>
        <AuthCode>OK2657</AuthCode>
        <PNRef>838662</PNRef>
        <HostCode>838662</HostCode>
        <GetAVSResult>Z</GetAVSResult>
        <GetAVSResultTXT>5 Zip Match No Address Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>Match</GetZipMatchTXT>
        <GetCVResult>P</GetCVResult>
        <GetCVResultTXT>Service Not Available</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=ebd7cd3348d4789e2cabf31e5914ef24,CardType=VISA</ExtData>
      </Response>
    )
  end

  def failed_authorize_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>APPROVAL</Message>
        <AuthCode>OK9877</AuthCode>
        <PNRef>837499</PNRef>
        <HostCode>837499</HostCode>
        <GetAVSResult>Z</GetAVSResult>
        <GetAVSResultTXT>5 Zip Match No Address Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>Match</GetZipMatchTXT>
        <GetCVResult>P</GetCVResult>
        <GetCVResultTXT>Service Not Available</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=VISA</ExtData>
      </Response>
    )
  end

  def successful_capture_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>APPROVAL</Message>
        <AuthCode>OK2667</AuthCode>
        <PNRef>838665</PNRef>
        <GetCommercialCard>False</GetCommercialCard>
      </Response>
    )
  end

  def failed_capture_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>1000</Result>
        <RespMSG>Error - Unknown Card Type : </RespMSG>
      </Response>
    )
  end

  def successful_refund_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>APPROVAL</Message>
        <AuthCode>868686</AuthCode>
        <PNRef>838669</PNRef>
        <HostCode>838669</HostCode>
        <GetCommercialCard>False</GetCommercialCard>
      </Response>
    )
  end

  def failed_refund_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>19</Result>
        <RespMSG>Original Transaction ID Not Found</RespMSG>
        <Message>Original PNRef is required.</Message>
      </Response>
    )
  end

  def successful_void_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>APPROVAL</Message>
        <AuthCode>OK2707</AuthCode>
        <PNRef>838671</PNRef>
        <GetCommercialCard>False</GetCommercialCard>
      </Response>
    )
  end

  def failed_void_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://TPISoft.com/SmartPayments/">
        <Result>19</Result>
        <RespMSG>Original Transaction ID Not Found</RespMSG>
        <Message>Original PNRef is required.</Message>
      </Response>
    )
  end
end
