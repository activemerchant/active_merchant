require 'test_helper'

class GlobalTransportTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test
    @gateway = GlobalTransportGateway.new(global_user_name: 'login', global_password: 'password', term_type: 'ABC')

    @options = {
      order_id: '1',
      billing_address: address,
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(100, credit_card, @options)
    assert_success response
    assert_equal '3648838', response.authorization
    assert response.test?
    assert_equal 'CVV matches', response.cvv_result['message']
    assert_equal 'Street address and postal code do not match. For American Express: Card member\'s name, street address and postal code do not match.', response.avs_result['message']
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(100, credit_card, @options)
    assert_failure response
  end

  def test_successful_partial_purchase
    @gateway.expects(:ssl_post).returns(successful_partial_purchase_response)

    response = @gateway.purchase(200, credit_card, @options)
    assert_success response
    assert_equal '8869188', response.authorization
    assert_equal 'Partial Approval', response.message
    assert_equal '3.54', response.params['balance_due']
    assert_equal '20.00', response.params['approved_amount']
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(100, credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '3648890', response.authorization

    capture = stub_comms do
      @gateway.capture(100, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/PNRef=3648890/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_successful_partial_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(200, credit_card, @options)
    end.respond_with(successful_partial_authorize_response)

    assert_success response
    assert_equal '8869269', response.authorization
    assert_equal 'Partial Approval', response.message

    capture = stub_comms do
      @gateway.capture(150, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/PNRef=8869269/, data)
    end.respond_with(successful_partial_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(100, credit_card, @options)
    assert_failure response
  end

  def test_failed_capture
    capture = stub_comms do
      @gateway.capture(100, 'Authorization')
    end.respond_with(failed_capture_response)

    assert_failure capture
    assert_match(/less than or equal/, capture.message)
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(100, credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal '3648838', response.authorization

    refund = stub_comms do
      @gateway.refund(100, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/PNRef=3648838/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    refund = stub_comms do
      @gateway.refund(100, 'PurchaseAuth')
    end.respond_with(failed_refund_response)

    assert_failure refund
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(100, credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/PNRef=3648838/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    void = stub_comms do
      @gateway.void('PurchaseAuth')
    end.respond_with(failed_void_response)

    assert_failure void
    assert_equal 'Invalid PNRef', void.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(credit_card, @options)
    assert_success response
    assert_equal '3649156', response.authorization
    assert response.test?
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(credit_card, @options)
    assert_failure response
  end

  def test_truncation
    stub_comms do
      @gateway.purchase(100, credit_card, order_id: 'a' * 17)
    end.check_request do |endpoint, data, headers|
      assert_match(/&InvNum=a{16}&/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrub), post_scrub
  end

  private

  def successful_purchase_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>AP</Message>
        <AuthCode>VI0100</AuthCode>
        <PNRef>3648838</PNRef>
        <HostCode>0010</HostCode>
        <GetAVSResult>N</GetAVSResult>
        <GetAVSResultTXT>No Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>No Match</GetZipMatchTXT>
        <GetCVResult>M</GetCVResult>
        <GetCVResultTXT>Match</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa,BatchNum=0003&lt;BatchNum&gt;0003&lt;/BatchNum&gt;&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;014258077000462&lt;/Trans_Id&gt;&lt;Val_Code&gt;ABCA&lt;/Val_Code&gt;&lt;/ReceiptData&gt;</ExtData>
      </Response>
    )
  end

  def failed_purchase_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>12</Result>
        <RespMSG>Declined</RespMSG>
        <Message>DECLINE</Message>
        <PNRef>3648889</PNRef>
        <GetAVSResult>N</GetAVSResult>
        <GetAVSResultTXT>No Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>No Match</GetZipMatchTXT>
        <GetCVResult>M</GetCVResult>
        <GetCVResultTXT>Match</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;014258078002543&lt;/Trans_Id&gt;&lt;Val_Code&gt;ABAD&lt;/Val_Code&gt;&lt;/ReceiptData&gt;&lt;ApprovedAmount&gt;0.00&lt;/ApprovedAmount&gt;&lt;BalanceDue&gt;14.00&lt;/BalanceDue&gt;</ExtData>
      </Response>
    )
  end

  def successful_partial_purchase_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>200</Result>
        <RespMSG>Partial Approval</RespMSG>
        <Message>PARTIAL AP</Message>
        <AuthCode>VI2000</AuthCode>
        <PNRef>8869188</PNRef>
        <HostCode>0004</HostCode>
        <GetAVSResult>N</GetAVSResult>
        <GetAVSResultTXT>No Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>No Match</GetZipMatchTXT>
        <GetCVResult>M</GetCVResult>
        <GetCVResultTXT>Match</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa,BatchNum=0005&lt;BatchNum&gt;0005&lt;/BatchNum&gt;&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;017198190587855&lt;/Trans_Id&gt;&lt;Val_Code&gt;AABC&lt;/Val_Code&gt;&lt;/ReceiptData&gt;&lt;ApprovedAmount&gt;20.00&lt;/ApprovedAmount&gt;&lt;BalanceDue&gt;3.54&lt;/BalanceDue&gt;</ExtData>
        <AcqRefData>aWb017198190587855cAABCd5e10fJj470993170717112415k0057840C000000002354lA  m000005</AcqRefData>
      </Response>
    )
  end

  def successful_partial_authorize_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>200</Result>
        <RespMSG>Partial Approval</RespMSG>
        <Message>PARTIAL AP</Message>
        <AuthCode>VI2000</AuthCode>
        <PNRef>8869269</PNRef>
        <GetAVSResult>N</GetAVSResult>
        <GetAVSResultTXT>No Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>No Match</GetZipMatchTXT>
        <GetCVResult>M</GetCVResult>
        <GetCVResultTXT>Match</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;017198190582649&lt;/Trans_Id&gt;&lt;Val_Code&gt;AABC&lt;/Val_Code&gt;&lt;/ReceiptData&gt;&lt;ApprovedAmount&gt;20.00&lt;/ApprovedAmount&gt;&lt;BalanceDue&gt;3.54&lt;/BalanceDue&gt;</ExtData>
        <AcqRefData>aWb017198190582649cAABCd5e10fJj471048170717124409k0057840C000000002354lA  m000005</AcqRefData>
      </Response>
    )
  end

  def successful_partial_capture_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>AP</Message>
        <AuthCode>VI2000</AuthCode>
        <PNRef>8869275</PNRef>
        <HostCode>0034</HostCode>
        <GetCVResultTXT>Service Not Requested</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa,BatchNum=0005&lt;ExtReceiptData&gt;&lt;AccountNumber&gt;************1111&lt;/AccountNumber&gt;&lt;Issuer&gt;Visa&lt;/Issuer&gt;&lt;Amount&gt;20.00&lt;/Amount&gt;&lt;AuthAmount&gt;20.00&lt;/AuthAmount&gt;&lt;TicketNumber&gt;1&lt;/TicketNumber&gt;&lt;EntryMode&gt;Manual CNP&lt;/EntryMode&gt;&lt;/ExtReceiptData&gt;&lt;BatchNum&gt;0005&lt;/BatchNum&gt;&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;017198190583609&lt;/Trans_Id&gt;&lt;Val_Code&gt;AABC&lt;/Val_Code&gt;&lt;/ReceiptData&gt;</ExtData>
        <AcqRefData>aWb017198190583609cAABCd5e10fJj471054170717130009lA  m000005</AcqRefData>
      </Response>
    )
  end

  def successful_authorize_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>AP</Message>
        <AuthCode>VI0100</AuthCode>
        <PNRef>3648890</PNRef>
        <GetAVSResult>N</GetAVSResult>
        <GetAVSResultTXT>No Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>No Match</GetZipMatchTXT>
        <GetCVResult>M</GetCVResult>
        <GetCVResultTXT>Match</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;014258077002729&lt;/Trans_Id&gt;&lt;Val_Code&gt;ABCA&lt;/Val_Code&gt;&lt;/ReceiptData&gt;</ExtData>
      </Response>
    )
  end

  def failed_authorize_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>12</Result>
        <RespMSG>Declined</RespMSG>
        <Message>DECLINE</Message>
        <PNRef>3648893</PNRef>
        <GetAVSResult>N</GetAVSResult>
        <GetAVSResultTXT>No Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>No Match</GetZipMatchTXT>
        <GetCVResult>M</GetCVResult>
        <GetCVResultTXT>Match</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;014258078002835&lt;/Trans_Id&gt;&lt;Val_Code&gt;ABAD&lt;/Val_Code&gt;&lt;/ReceiptData&gt;&lt;ApprovedAmount&gt;0.00&lt;/ApprovedAmount&gt;&lt;BalanceDue&gt;14.00&lt;/BalanceDue&gt;</ExtData>
      </Response>
    )
  end

  def successful_capture_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>AP</Message>
        <AuthCode>VI0100</AuthCode>
        <PNRef>3648928</PNRef>
        <HostCode>0028</HostCode>
        <GetCVResultTXT>Service Not Requested</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa,BatchNum=0003&lt;ExtReceiptData&gt;&lt;AccountNumber&gt;************6781&lt;/AccountNumber&gt;&lt;Issuer&gt;Visa&lt;/Issuer&gt;&lt;Amount&gt;1.00&lt;/Amount&gt;&lt;AuthAmount&gt;1.00&lt;/AuthAmount&gt;&lt;TicketNumber&gt;1&lt;/TicketNumber&gt;&lt;EntryMode&gt;Manual CNP&lt;/EntryMode&gt;&lt;/ExtReceiptData&gt;&lt;BatchNum&gt;0003&lt;/BatchNum&gt;&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;014258077003984&lt;/Trans_Id&gt;&lt;Val_Code&gt;ABCA&lt;/Val_Code&gt;&lt;/ReceiptData&gt;</ExtData>
      </Response>
    )
  end

  def failed_capture_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>118</Result>
        <RespMSG>The amount of a Pre-Auth Complete (Capture) must be less than or equal to the original amount authorized. Please retry.</RespMSG>
      </Response>
    )
  end

  def successful_refund_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>AP</Message>
        <AuthCode>C04153</AuthCode>
        <PNRef>3649149</PNRef>
        <HostCode>0130</HostCode>
        <GetCVResultTXT>Service Not Requested</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa,BatchNum=0003&lt;ExtReceiptData&gt;&lt;AccountNumber&gt;************8903&lt;/AccountNumber&gt;&lt;Issuer&gt;Visa&lt;/Issuer&gt;&lt;Amount&gt;5.00&lt;/Amount&gt;&lt;AuthAmount&gt;5.00&lt;/AuthAmount&gt;&lt;TicketNumber&gt;1&lt;/TicketNumber&gt;&lt;EntryMode&gt;Manual CNP&lt;/EntryMode&gt;&lt;/ExtReceiptData&gt;&lt;BatchNum&gt;0003&lt;/BatchNum&gt;&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;/ReceiptData&gt;</ExtData>
      </Response>
    )
  end

  def failed_refund_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>113</Result>
        <RespMSG>Requested Refund Exceeds Available Refund Amount</RespMSG>
      </Response>
    )
  end

  def successful_void_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>REVERSED</Message>
        <AuthCode>VOIDED</AuthCode>
        <PNRef>3649152</PNRef>
        <GetCVResultTXT>Service Not Requested</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>InvNum=1,CardType=Visa&lt;ExtReceiptData&gt;&lt;AccountNumber&gt;************8903&lt;/AccountNumber&gt;&lt;Issuer&gt;Visa&lt;/Issuer&gt;&lt;Amount&gt;5.00&lt;/Amount&gt;&lt;AuthAmount&gt;5.00&lt;/AuthAmount&gt;&lt;TicketNumber&gt;1&lt;/TicketNumber&gt;&lt;EntryMode&gt;Manual CNP&lt;/EntryMode&gt;&lt;/ExtReceiptData&gt;&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;/ReceiptData&gt;</ExtData>
      </Response>
    )
  end

  def failed_void_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>26</Result>
        <RespMSG>Invalid PNRef</RespMSG>
      </Response>
    )
  end

  def successful_verify_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>0</Result>
        <RespMSG>Approved</RespMSG>
        <Message>AP</Message>
        <AuthCode>VI0000</AuthCode>
        <PNRef>3649156</PNRef>
        <GetAVSResult>N</GetAVSResult>
        <GetAVSResultTXT>No Match</GetAVSResultTXT>
        <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
        <GetZipMatchTXT>No Match</GetZipMatchTXT>
        <GetCVResult>M</GetCVResult>
        <GetCVResultTXT>Match</GetCVResultTXT>
        <GetCommercialCard>False</GetCommercialCard>
        <ExtData>CardType=Visa&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;Trans_Id&gt;014258000006274&lt;/Trans_Id&gt;&lt;Val_Code&gt;CDCD&lt;/Val_Code&gt;&lt;/ReceiptData&gt;</ExtData>
      </Response>
    )
  end

  def failed_verify_response
    %(
      <Response xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="GlobalPayments">
        <Result>23</Result>
        <RespMSG>Invalid Account Number</RespMSG>
      </Response>
    )
  end

  def pre_scrub
    %q{
opening connection to certapia.globalpay.com:443...
opened
starting SSL for certapia.globalpay.com:443...
SSL established
<- "POST /GlobalPay/transact.asmx/ProcessCreditCard HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: certapia.globalpay.com\r\nContent-Length: 253\r\n\r\n"
<- "CardNum=4003002345678903&ExpDate=0919&NameOnCard=Longbob+Longsen&Amount=&PNRef=&Zip=K1C2N6&Street=456+My+Street&CVNum=123&MagData=&InvNum=1&ExtData=%3CTermType%3E1BJ%3C%2FTermType%3E&GlobalUserName=spre930948&GlobalPassword=AoaeYX2n3Y7wfr&TransType=Sale"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 08 Jan 2018 16:00:33 GMT\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Length: 559\r\n"
-> "Connection: close\r\n"
-> "Cache-Control: private, no-store, max-age=0\r\n"
-> "Pragma: no-cache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Set-Cookie: ASP.NET_SessionId=tawdjune2xixlighniqxcvkm; path=/; HttpOnly\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Set-Cookie: TS012462a7=01cf83bd2f409aa8ee6c4cacb355788019f1a8ff3010306e6b8fe1c42e01745058ecc78aeff78d5071c2b7c56c186a470efd7c78f1; Path=/; Secure\r\n"
-> "Set-Cookie: TS012462a7_28=013b80ac89ca00c8b688533fc64e6f7b3fa3424b483ef82651a9f9a1c184ec131cc099732b39bf84f703f9f0754d2a12a53fe3d537; Path=/; Secure\r\n"
-> "\r\n"
reading 559 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<Response xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"GlobalPayments\">\r\n  <Result>12</Result>\r\n  <RespMSG>Declined</RespMSG>\r\n  <Message>INVLD AMOUNT</Message>\r\n  <PNRef>9169188</PNRef>\r\n  <GetCVResultTXT>Service Not Requested</GetCVResultTXT>\r\n  <GetCommercialCard>False</GetCommercialCard>\r\n  <ExtData>InvNum=1,CardType=Visa&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;/ReceiptData&gt;</ExtData>\r\n  <AcqRefData>aY</AcqRefData>\r\n</Response>"
read 559 bytes
Conn close
    }
  end

  def post_scrub
    %q{
opening connection to certapia.globalpay.com:443...
opened
starting SSL for certapia.globalpay.com:443...
SSL established
<- "POST /GlobalPay/transact.asmx/ProcessCreditCard HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: certapia.globalpay.com\r\nContent-Length: 253\r\n\r\n"
<- "CardNum=[FILTERED]&ExpDate=0919&NameOnCard=Longbob+Longsen&Amount=&PNRef=&Zip=K1C2N6&Street=456+My+Street&CVNum=[FILTERED]&MagData=&InvNum=1&ExtData=%3CTermType%3E1BJ%3C%2FTermType%3E&GlobalUserName=spre930948&GlobalPassword=[FILTERED]&TransType=Sale"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 08 Jan 2018 16:00:33 GMT\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Length: 559\r\n"
-> "Connection: close\r\n"
-> "Cache-Control: private, no-store, max-age=0\r\n"
-> "Pragma: no-cache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "Set-Cookie: ASP.NET_SessionId=tawdjune2xixlighniqxcvkm; path=/; HttpOnly\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Set-Cookie: TS012462a7=01cf83bd2f409aa8ee6c4cacb355788019f1a8ff3010306e6b8fe1c42e01745058ecc78aeff78d5071c2b7c56c186a470efd7c78f1; Path=/; Secure\r\n"
-> "Set-Cookie: TS012462a7_28=013b80ac89ca00c8b688533fc64e6f7b3fa3424b483ef82651a9f9a1c184ec131cc099732b39bf84f703f9f0754d2a12a53fe3d537; Path=/; Secure\r\n"
-> "\r\n"
reading 559 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<Response xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"GlobalPayments\">\r\n  <Result>12</Result>\r\n  <RespMSG>Declined</RespMSG>\r\n  <Message>INVLD AMOUNT</Message>\r\n  <PNRef>9169188</PNRef>\r\n  <GetCVResultTXT>Service Not Requested</GetCVResultTXT>\r\n  <GetCommercialCard>False</GetCommercialCard>\r\n  <ExtData>InvNum=1,CardType=Visa&lt;ReceiptData&gt;&lt;MID&gt;332518545311149&lt;/MID&gt;&lt;/ReceiptData&gt;</ExtData>\r\n  <AcqRefData>aY</AcqRefData>\r\n</Response>"
read 559 bytes
Conn close
    }
  end
end
