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
    @check = check
    @amount = 100
    @options = {}
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

  def test_successful_purchase_with_echeck
    @gateway.expects(:ssl_post).returns(successful_purchase_with_echeck_response)

    response = @gateway.purchase(@amount, @check)
    assert_success response

    assert_equal 'OK6269|1316661', response.authorization
    assert response.test?
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

  def test_store_and_purchase_with_token
    store = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success store
    assert_equal "Success", store.message

    purchase = stub_comms do
      @gateway.purchase(@amount, store.authorization)
    end.respond_with(successful_purchase_response)

    assert_success purchase
    assert_equal "Approved", purchase.message
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
      assert_match(/Street=456\+My\+Street/, data)
      assert_match(/Zip=K1C2N6/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
    assert_equal "OK2657", response.params["authcode"]
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Approved", response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Invalid Account Number", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_echeck_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(echeck_pre_scrubbed), echeck_post_scrubbed
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

  def successful_purchase_with_echeck_response
    %(
    <Response xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://TPISoft.com/SmartPayments/">
      <Result>0</Result>
      <RespMSG>Approved</RespMSG>
      <Message>APPROVAL</Message>
      <AuthCode>OK6269</AuthCode>
      <PNRef>1316661</PNRef>
      <GetCommercialCard>False</GetCommercialCard>
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
      <Result>23</Result>
      <RespMSG>Invalid Account Number</RespMSG>
      <ExtData>InvNum=73c21272e01d0716d3a3262d8faf5bea,CardType=VISA</ExtData>
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

  def successful_store_response
    %(
    <CardVaultResponse xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://TPISoft.com/SmartPayments/">
      <Result>0</Result>
      <Message>Success</Message>
      <Token>4005552646800019</Token>
      <CustomerPaymentInfoKey>128962</CustomerPaymentInfoKey>
      <ExpDate>0916</ExpDate>
      <NameOnCard>Longbob Longsen</NameOnCard>
      <Street />
      <Zip />
    </CardVaultResponse>
    )
  end

  def pre_scrubbed
    %(
      <- "Amount=1.00&PNRef=&InvNum=1914676616596fbf4c467c02facb81d1&CardNum=4000300011100000&ExpDate=0915&MagData=&NameOnCard=Longbob+Longsen&Zip=K1C2N6&Street=1234+My+Street&CVNum=123&ExtData=%3CForce%3ET%3C%2FForce%3E&UserName=Spre3676&Password=H3392nc5&TransType=Auth"
    )
  end

  def post_scrubbed
    %(
      <- "Amount=1.00&PNRef=&InvNum=1914676616596fbf4c467c02facb81d1&CardNum=[FILTERED]&ExpDate=0915&MagData=&NameOnCard=Longbob+Longsen&Zip=K1C2N6&Street=1234+My+Street&CVNum=[FILTERED]&ExtData=%3CForce%3ET%3C%2FForce%3E&UserName=Spre3676&Password=[FILTERED]&TransType=Auth"
    )
  end

  def echeck_pre_scrubbed
    %(
    <- UserName=Spre3676&Password=H3392nc5&TransType=Sale&Amount=1.00&PNRef=&InvNum=b3ca834652da047353eb96433b2ab7d8&CardNum=&ExpDate=&MagData=&NameOnCard=&Zip=K1C2N6&Street=456+My+Street&CVNum=&ExtData=%3CForce%3ET%3C%2FForce%3E&CheckNum=1001&TransitNum=490000018&AccountNum=1234567890&NameOnCheck=John+Doe&MICR="
    )
  end

  def echeck_post_scrubbed
    %(
    <- UserName=Spre3676&Password=[FILTERED]&TransType=Sale&Amount=1.00&PNRef=&InvNum=b3ca834652da047353eb96433b2ab7d8&CardNum=[FILTERED]&ExpDate=&MagData=&NameOnCard=&Zip=K1C2N6&Street=456+My+Street&CVNum=[FILTERED]&ExtData=%3CForce%3ET%3C%2FForce%3E&CheckNum=1001&TransitNum=[FILTERED]&AccountNum=[FILTERED]&NameOnCheck=John+Doe&MICR="
    )
  end
end
