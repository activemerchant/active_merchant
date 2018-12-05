require 'test_helper'

class MercuryTest < Test::Unit::TestCase
  include CommStub

  def setup
    Base.mode = :test

    @gateway = MercuryGateway.new(fixtures(:mercury))

    @amount = 100
    @credit_card = credit_card('5499990123456781', :brand => 'master')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => 'c111111111.1'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/InvoiceNo>c111111111.1</, data)
      assert_match(/Frequency>OneTime/, data)
      assert_match(/RecordNo>RecordNumberRequested/, data)
    end.respond_with(successful_purchase_response)

    assert_instance_of Response, response
    assert_success response

    assert_equal '1;0194;000011;KbMCC0742510421  ;|17|410100700000;;100', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_allow_partial_auth
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(allow_partial_auth: true))
    end.check_request do |endpoint, data, headers|
      assert_match(/PartialAuth>Allow</, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    refund = @gateway.refund(nil, response.authorization)
    assert_instance_of Response, refund
    assert_success refund
    assert refund.test?
  end

  def test_card_present_with_track_1_data
    track_data = '%B4003000123456781^LONGSEN/L. ^15121200000000000000123?'
    @credit_card.track_data = track_data
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<Track1>#{Regexp.escape(track_data)}<\/Track1>/, data)
    end.respond_with(successful_purchase_response)

    assert_instance_of Response, response
    assert_success response
  end

  def test_card_present_with_track_2_data
    track_data = ';5413330089010608=2512101097750213?'
    stripped_track_data = '5413330089010608=2512101097750213'
    @credit_card.track_data = track_data
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<Track2>#{Regexp.escape(stripped_track_data)}<\/Track2>/, data)
    end.respond_with(successful_purchase_response)

    assert_instance_of Response, response
    assert_success response
  end

  def test_card_present_with_max_length_track_1_data
    track_data    = '%B373953192351004^CARDUSER/JOHN^200910100000019301000000877000000930001234567?'
    stripped_data =  'B373953192351004^CARDUSER/JOHN^200910100000019301000000877000000930001234567'
    @credit_card.track_data = track_data
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<Track1>#{Regexp.escape(stripped_data)}<\/Track1>/, data)
    end.respond_with(successful_purchase_response)

    assert_instance_of Response, response
    assert_success response
  end

  def test_card_present_with_invalid_data
    track_data = 'this is not valid track data'
    @credit_card.track_data = track_data
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/<Track1>#{Regexp.escape(track_data)}<\/Track1>/, data)
    end.respond_with(successful_purchase_response)

    assert_instance_of Response, response
    assert_success response
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrub), post_scrub
  end

  private

  def successful_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditTransactionResponse xmlns="http://www.mercurypay.com"><CreditTransactionResult><?xml version="1.0"?>
<RStream>
  <CmdResponse>
    <ResponseOrigin>Processor</ResponseOrigin>
    <DSIXReturnCode>000000</DSIXReturnCode>
    <CmdStatus>Approved</CmdStatus>
    <TextResponse>AP*</TextResponse>
    <UserTraceData></UserTraceData>
  </CmdResponse>
  <TranResponse>
    <MerchantID>595901</MerchantID>
    <AcctNo>5499990123456781</AcctNo>
    <ExpDate>0813</ExpDate>
    <CardType>M/C</CardType>
    <TranCode>Sale</TranCode>
    <AuthCode>000011</AuthCode>
    <CaptureStatus>Captured</CaptureStatus>
    <RefNo>0194</RefNo>
    <InvoiceNo>1</InvoiceNo>
    <AVSResult>Y</AVSResult>
    <CVVResult>M</CVVResult>
    <OperatorID>999</OperatorID>
    <Memo>LM Integration (Ruby)</Memo>
    <Amount>
      <Purchase>1.00</Purchase>
      <Authorize>1.00</Authorize>
    </Amount>
    <AcqRefData>KbMCC0742510421  </AcqRefData>
    <ProcessData>|17|410100700000</ProcessData>
  </TranResponse>
</RStream>
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditTransactionResponse xmlns="http://www.mercurypay.com"><CreditTransactionResult><?xml version="1.0"?>
<RStream>
  <CmdResponse>
    <ResponseOrigin>Server</ResponseOrigin>
    <DSIXReturnCode>000000</DSIXReturnCode>
    <CmdStatus>Error</CmdStatus>
    <TextResponse>No Live Cards on Test Merchant ID Allowed.</TextResponse>
    <UserTraceData></UserTraceData>
  </CmdResponse>
</RStream>
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreditTransactionResponse xmlns="http://www.mercurypay.com"><CreditTransactionResult><?xml version="1.0"?>
<RStream>
  <CmdResponse>
    <ResponseOrigin>Processor</ResponseOrigin>
    <DSIXReturnCode>000000</DSIXReturnCode>
    <CmdStatus>Approved</CmdStatus>
    <TextResponse>AP</TextResponse>
    <UserTraceData></UserTraceData>
  </CmdResponse>
  <TranResponse>
    <MerchantID>595901</MerchantID>
    <AcctNo>5499990123456781</AcctNo>
    <ExpDate>0813</ExpDate>
    <CardType>M/C</CardType>
    <TranCode>VoidSale</TranCode>
    <AuthCode>VOIDED</AuthCode>
    <CaptureStatus>Captured</CaptureStatus>
    <RefNo>0568</RefNo>
    <InvoiceNo>123</InvoiceNo>
    <OperatorID>999</OperatorID>
    <Amount>
      <Purchase>1.00</Purchase>
      <Authorize>1.00</Authorize>
    </Amount>
    <AcqRefData>K</AcqRefData>
  </TranResponse>
</RStream>
</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>
    RESPONSE
  end

  def pre_scrub
    %q{
opening connection to w1.mercurycert.net:443...
opened
starting SSL for w1.mercurycert.net:443...
SSL established
<- "POST /ws/ws.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nSoapaction: http://www.mercurypay.com/CreditTransaction\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: w1.mercurycert.net\r\nContent-Length: 823\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?><soap:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soap:Body><CreditTransaction xmlns=\"http://www.mercurypay.com\"><tran>\n<![CDATA[\n<TStream><Transaction><TranType>Credit</TranType><TranCode>Sale</TranCode><InvoiceNo>c111111111.1</InvoiceNo><RefNo>c111111111.1</RefNo><Memo>ActiveMerchant</Memo><Frequency>OneTime</Frequency><RecordNo>RecordNumberRequested</RecordNo><MerchantID>089716741701445</MerchantID><Amount><Purchase>1.00</Purchase></Amount><Account><AcctNo>4003000123456781</AcctNo><ExpDate>1218</ExpDate></Account><CardType>VISA</CardType><CVVData>123</CVVData></Transaction></TStream>\n]]>\n</tran><pw>xyz</pw></CreditTransaction></soap:Body></soap:Envelope>"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 08 Jan 2018 19:49:31 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 1648\r\n"
-> "\r\n"
reading 1648 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditTransactionResponse xmlns=\"http://www.mercurypay.com\"><CreditTransactionResult><?xml version=\"1.0\"?>\r\n<RStream>\r\n\t<CmdResponse>\r\n\t\t<ResponseOrigin>Processor</ResponseOrigin>\r\n\t\t<DSIXReturnCode>000000</DSIXReturnCode>\r\n\t\t<CmdStatus>Approved</CmdStatus>\r\n\t\t<TextResponse>AP*</TextResponse>\r\n\t\t<UserTraceData></UserTraceData>\r\n\t</CmdResponse>\r\n\t<TranResponse>\r\n\t\t<MerchantID>089716741701445</MerchantID>\r\n\t\t<AcctNo>400300XXXXXX6781</AcctNo>\r\n\t\t<ExpDate>XXXX</ExpDate>\r\n\t\t<CardType>VISA</CardType>\r\n\t\t<TranCode>Sale</TranCode>\r\n\t\t<AuthCode>VI0100</AuthCode>\r\n\t\t<CaptureStatus>Captured</CaptureStatus>\r\n\t\t<RefNo>0001</RefNo>\r\n\t\t<InvoiceNo>C111111111.1</InvoiceNo>\r\n\t\t<CVVResult>U</CVVResult>\r\n\t\t<Memo>ActiveMerchant</Memo>\r\n\t\t<Amount>\r\n\t\t\t<Purchase>1.00</Purchase>\r\n\t\t\t<Authorize>1.00</Authorize>\r\n\t\t</Amount>\r\n\t\t<AcqRefData>KaNb018008177003332cABCAd5e00fJlA  m000005</AcqRefData>\r\n\t\t<RecordNo>win4rRFHp8+AV/vstAfKvsUvZ5IH+bHblTktfumnY/EiEgUQFyIQGjMM</RecordNo>\r\n\t\t<ProcessData>|00|600550672000</ProcessData>\r\n\t</TranResponse>\r\n</RStream>\r\n</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>"
read 1648 bytes
Conn close
    }
  end

  def post_scrub
    %q{
opening connection to w1.mercurycert.net:443...
opened
starting SSL for w1.mercurycert.net:443...
SSL established
<- "POST /ws/ws.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nSoapaction: http://www.mercurypay.com/CreditTransaction\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: w1.mercurycert.net\r\nContent-Length: 823\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?><soap:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soap:Body><CreditTransaction xmlns=\"http://www.mercurypay.com\"><tran>\n<![CDATA[\n<TStream><Transaction><TranType>Credit</TranType><TranCode>Sale</TranCode><InvoiceNo>c111111111.1</InvoiceNo><RefNo>c111111111.1</RefNo><Memo>ActiveMerchant</Memo><Frequency>OneTime</Frequency><RecordNo>RecordNumberRequested</RecordNo><MerchantID>089716741701445</MerchantID><Amount><Purchase>1.00</Purchase></Amount><Account><AcctNo>[FILTERED]</AcctNo><ExpDate>1218</ExpDate></Account><CardType>VISA</CardType><CVVData>[FILTERED]</CVVData></Transaction></TStream>\n]]>\n</tran><pw>[FILTERED]</pw></CreditTransaction></soap:Body></soap:Envelope>"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Mon, 08 Jan 2018 19:49:31 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 1648\r\n"
-> "\r\n"
reading 1648 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><CreditTransactionResponse xmlns=\"http://www.mercurypay.com\"><CreditTransactionResult><?xml version=\"1.0\"?>\r\n<RStream>\r\n\t<CmdResponse>\r\n\t\t<ResponseOrigin>Processor</ResponseOrigin>\r\n\t\t<DSIXReturnCode>000000</DSIXReturnCode>\r\n\t\t<CmdStatus>Approved</CmdStatus>\r\n\t\t<TextResponse>AP*</TextResponse>\r\n\t\t<UserTraceData></UserTraceData>\r\n\t</CmdResponse>\r\n\t<TranResponse>\r\n\t\t<MerchantID>089716741701445</MerchantID>\r\n\t\t<AcctNo>[FILTERED]</AcctNo>\r\n\t\t<ExpDate>XXXX</ExpDate>\r\n\t\t<CardType>VISA</CardType>\r\n\t\t<TranCode>Sale</TranCode>\r\n\t\t<AuthCode>VI0100</AuthCode>\r\n\t\t<CaptureStatus>Captured</CaptureStatus>\r\n\t\t<RefNo>0001</RefNo>\r\n\t\t<InvoiceNo>C111111111.1</InvoiceNo>\r\n\t\t<CVVResult>U</CVVResult>\r\n\t\t<Memo>ActiveMerchant</Memo>\r\n\t\t<Amount>\r\n\t\t\t<Purchase>1.00</Purchase>\r\n\t\t\t<Authorize>1.00</Authorize>\r\n\t\t</Amount>\r\n\t\t<AcqRefData>KaNb018008177003332cABCAd5e00fJlA  m000005</AcqRefData>\r\n\t\t<RecordNo>win4rRFHp8+AV/vstAfKvsUvZ5IH+bHblTktfumnY/EiEgUQFyIQGjMM</RecordNo>\r\n\t\t<ProcessData>|00|600550672000</ProcessData>\r\n\t</TranResponse>\r\n</RStream>\r\n</CreditTransactionResult></CreditTransactionResponse></soap:Body></soap:Envelope>"
read 1648 bytes
Conn close
    }
  end
end
