require 'test_helper'

class DirectConnectTest < Test::Unit::TestCase
  def setup
    @gateway = DirectConnectGateway.new(
      username: 'login',
      password: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @authorization = 12345
  end

  # direct payments

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    
    assert_success response
    assert_equal 12345, response.authorization
    assert response.test?
  end

  def test_failed_purchase
    skip 'fix later'
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal :invalidAccountNumber, DirectConnectGateway::DIRECT_CONNECT_CODES[response.params['result']]
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Approved', response.message
    assert_equal 54321, response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response

    assert_equal :invalidAccountNumber, DirectConnectGateway::DIRECT_CONNECT_CODES[response.params['result']]
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @authorization, @options)

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @authorization, @options)

    assert_failure response
    assert_equal :noRecordsToProcess, DirectConnectGateway::DIRECT_CONNECT_CODES[response.params['result']]
    assert_equal 'No Records To Process', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @authorization, @options)

    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount+1, @credit_card, @authorization, @options)

    assert_failure response
    assert_equal 'Cannot Exceed Sales Cap', response.message
  end

  def test_successful_void
  end

  def test_failed_void
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  # recurring

  def test_successful_add_contract
  end

  def test_failed_add_contract
  end

  def test_successful_update_contract
  end

  def test_failed_update_contract
  end

  def test_successful_delete_contract
  end

  def test_failed_delete_contract
  end

  # crm

  def test_successful_add_customer
  end

  def test_failed_add_customer
  end

  def test_successful_update_customer
  end

  def test_failed_update_customer
  end

  def test_successful_delete_customer
  end

  def test_failed_delete_customer
  end

  def test_successful_add_credit_card_info
  end

  def test_failed_add_credit_card_info
  end

  def test_successful_update_credit_card_info
  end

  def test_failed_update_credit_card_info
  end

  def test_successful_delete_credit_card_info
  end

  def test_failed_delete_credit_card_info
  end

  # card safe

  def test_successful_store_card
  end

  def test_failed_store_card
  end

  def test_successful_process_stored_card
  end

  def test_failed_process_stored_card
  end

  # these are the 'processcreditcard' methods under the recurring tab in the docs
  def test_successful_process_stored_card_recurring
  end

  def test_successful_process_stored_card_recurring
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
opening connection to gateway.1directconnect.com:443...
opened
starting SSL for gateway.1directconnect.com:443...
SSL established
<- "POST /ws/transact.asmx/ProcessCreditCard HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway.1directconnect.com\r\nContent-Length: 199\r\n\r\n"
<- "amount=1.00&invNum=1&cardnum=12345&expdate=0915&cvnum=432&nameOnCard=Jim+Smith&street=1234+My+Street&zip=K1C2N6&username=asdfwAF&password=PASSWORDNO&transType=sale&extData=&pnRef=&magData="
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "X-XSS-Protection: 0\r\n"
-> "Date: Tue, 30 Dec 2014 20:25:38 GMT\r\n"
-> "Content-Length: 565\r\n"
-> "Set-Cookie: BNI_dccpersistence=000000000000000000000000040313ac00005000; Path=/\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 565 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\xED\xBD\a`\x1CI\x96%&/m\xCA{\x7FJ\xF5J\xD7\xE0t\xA1\b\x80`\x13$\xD8\x90@\x10\xEC\xC1\x88\xCD\xE6\x92\xEC\x1DiG#)\xAB*\x81\xCAeVe]f\x16@\xCC\xED\x9D\xBC\xF7\xDE{\xEF\xBD\xF7\xDE{\xEF\xBD\xF7\xBA;\x9DN'\xF7\xDF\xFF?\\fd\x01l\xF6\xCEJ\xDA\xC9\x9E!\x80\xAA\xC8\x1F?~|\x1F?\"\x1E\xFF\x1E\xEF\x16ez\x99\xD7MQ-?\xFBhw\xBC\xF3Q\x9A/\xA7\xD5\xACX^|\xF6\xD1\xBA=\xDF>\xF8\xE8\xF78\xFA\x8D\x93\xC7\xAF\xF2fU-\x9B<\xA5\xF6\xCB\xE6\xD1\xBBf\xF6\xD9G\xF3\xB6]=\xBA{\xF7\xEA\xEAj|uo\\\xD5\x17w\xF7vvv\xEF\xFE\xDE_<\x7F=\x9D\xE7\x8B\xEC#\xDB\xB8\xB8\xB9\xF1v\xB1l\xDAl9\xCD\xF5-\xFB\xC6\x9B\x97g\xAF\xAB\xF3v<\xAD\x16w_/\xB2\xBA}\x99]/\xF2e\xDB\xDC\xFD\x88\x10KS\xA0\xB6.\xDB\xA3\x9D\xC7w\xF57\xF3\xE9\xEA\x8B\xD7\x9F\x1F\x1D\xAFVuu\x99\xCF\xF8[\xFE\x84\xBF\xFE\"o\x9A\xEC\"?:~\xF9\xF2\xD5\x97?y\xFA\xF4\xF1]\xF3\x89\xFF\xF5nz7\xF8{\xCF\xFC}\xBCn\xE7'\xD5,?\xDAy\xF8\xE9\xC3\xFB\a\x8F\xEF\xDA\x0F\xF8\xEB\x97/^\xE5\xE7G\xBB\xFB{;\xF7\xEF\xED\xEE=\xBE+\x7F\xF3W\xDF\xAE\x9A\x96\e\xEE\xE8\xF3\xF8\xAE\xFD\xC86\xF8\xEA\xD5s\xD3\xD3\xE7y{\xFC\x93\xAF\tw\x8C\xEC\xA7\x1E\xDF\r\xFE\xEE\xB5x\xF3{\xBF9\xBA\x9F\xFET\xB1J\xBF\xC8\xDA\xE9<}Q\xA5\xC7\xB3YM\xD8\xCB\a\xE1\xFBhm@\xBCn\xEB<o\xB9\x11>\xA6\x17\xF9w~\xA1\xF3\x9Dy\x85\xBA\xB1\x9F\xF1/\xDC\xD8\xFF\xD4\xB4<\xF9I\xE9\xF0\xE8\x057\xB1\x7Fv\xBF\xC7;A\xCF\xFE\x17\xA61\xFD\xEF\xCB\xBA\xB8\x90/<2\x9DT\x8BE^O\x8B\xAC<\xC9\xEA\xD9\xD1\xB3\xAClr\x01\x12~\xC1\xEDO\xDF\xB5O\xB36;:[^\xBEX/>\xDB\x1D\xE1\xAB7\xD7\xAB\xFC\xB3\x9F<{}<z\x02\f\xF0\x05M\x10=\xBF\xB0l\x0F\xCDG\xBF\xF0\xA2=\xA4\x8F\xE8\xC1\xA7w\xFD\x8F\x1F\xDF5`Ib\x98\xDF 2G\xFF\x0F\xAC\xA6\xB7\xEBe\x03\x00\x00"
read 565 bytes
Conn close
PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
opening connection to gateway.1directconnect.com:443...
opened
starting SSL for gateway.1directconnect.com:443...
SSL established
<- "POST /ws/transact.asmx/ProcessCreditCard HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway.1directconnect.com\r\nContent-Length: 199\r\n\r\n"
<- "amount=1.00&invNum=1&cardnum=[FILTERED]&expdate=0915&cvnum=[FILTERED]&nameOnCard=Jim+Smith&street=1234+My+Street&zip=K1C2N6&username=[FILTERED]&password=[FILTERED]&transType=sale&extData=&pnRef=&magData="
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "X-XSS-Protection: 0\r\n"
-> "Date: Tue, 30 Dec 2014 20:25:38 GMT\r\n"
-> "Content-Length: 565\r\n"
-> "Set-Cookie: BNI_dccpersistence=000000000000000000000000040313ac00005000; Path=/\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 565 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\xED\xBD\a`\x1CI\x96%&/m\xCA{\x7FJ\xF5J\xD7\xE0t\xA1\b\x80`\x13$\xD8\x90@\x10\xEC\xC1\x88\xCD\xE6\x92\xEC\x1DiG#)\xAB*\x81\xCAeVe]f\x16@\xCC\xED\x9D\xBC\xF7\xDE{\xEF\xBD\xF7\xDE{\xEF\xBD\xF7\xBA;\x9DN'\xF7\xDF\xFF?\\fd\x01l\xF6\xCEJ\xDA\xC9\x9E!\x80\xAA\xC8\x1F?~|\x1F?\"\x1E\xFF\x1E\xEF\x16ez\x99\xD7MQ-?\xFBhw\xBC\xF3Q\x9A/\xA7\xD5\xACX^|\xF6\xD1\xBA=\xDF>\xF8\xE8\xF78\xFA\x8D\x93\xC7\xAF\xF2fU-\x9B<\xA5\xF6\xCB\xE6\xD1\xBBf\xF6\xD9G\xF3\xB6]=\xBA{\xF7\xEA\xEAj|uo\\\xD5\x17w\xF7vvv\xEF\xFE\xDE_<\x7F=\x9D\xE7\x8B\xEC#\xDB\xB8\xB8\xB9\xF1v\xB1l\xDAl9\xCD\xF5-\xFB\xC6\x9B\x97g\xAF\xAB\xF3v<\xAD\x16w_/\xB2\xBA}\x99]/\xF2e\xDB\xDC\xFD\x88\x10KS\xA0\xB6.\xDB\xA3\x9D\xC7w\xF57\xF3\xE9\xEA\x8B\xD7\x9F\x1F\x1D\xAFVuu\x99\xCF\xF8[\xFE\x84\xBF\xFE\"o\x9A\xEC\"?:~\xF9\xF2\xD5\x97?y\xFA\xF4\xF1]\xF3\x89\xFF\xF5nz7\xF8{\xCF\xFC}\xBCn\xE7'\xD5,?\xDAy\xF8\xE9\xC3\xFB\a\x8F\xEF\xDA\x0F\xF8\xEB\x97/^\xE5\xE7G\xBB\xFB{;\xF7\xEF\xED\xEE=\xBE+\x7F\xF3W\xDF\xAE\x9A\x96\e\xEE\xE8\xF3\xF8\xAE\xFD\xC86\xF8\xEA\xD5s\xD3\xD3\xE7y{\xFC\x93\xAF\tw\x8C\xEC\xA7\x1E\xDF\r\xFE\xEE\xB5x\xF3{\xBF9\xBA\x9F\xFET\xB1J\xBF\xC8\xDA\xE9<}Q\xA5\xC7\xB3YM\xD8\xCB\a\xE1\xFBhm@\xBCn\xEB<o\xB9\x11>\xA6\x17\xF9w~\xA1\xF3\x9Dy\x85\xBA\xB1\x9F\xF1/\xDC\xD8\xFF\xD4\xB4<\xF9I\xE9\xF0\xE8\x057\xB1\x7Fv\xBF\xC7;A\xCF\xFE\x17\xA61\xFD\xEF\xCB\xBA\xB8\x90/<2\x9DT\x8BE^O\x8B\xAC<\xC9\xEA\xD9\xD1\xB3\xAClr\x01\x12~\xC1\xEDO\xDF\xB5O\xB36;:[^\xBEX/>\xDB\x1D\xE1\xAB7\xD7\xAB\xFC\xB3\x9F<{}<z\x02\f\xF0\x05M\x10=\xBF\xB0l\x0F\xCDG\xBF\xF0\xA2=\xA4\x8F\xE8\xC1\xA7w\xFD\x8F\x1F\xDF5`Ib\x98\xDF 2G\xFF\x0F\xAC\xA6\xB7\xEBe\x03\x00\x00"
read 565 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
%(
<?xml version="1.0" encoding="utf-8"?>
<Response xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://TPISoft.com/SmartPayments/">
  <Result>0</Result>
  <RespMSG>Approved</RespMSG>
  <Message>APPROVED</Message>
  <Message1 />
  <Message2 />
  <AuthCode>123456</AuthCode>
  <PNRef>12345</PNRef>
  <HostCode>00000000</HostCode>
  <HostURL />
  <GetAVSResult>N</GetAVSResult>
  <GetAVSResultTXT>No Match</GetAVSResultTXT>
  <GetStreetMatchTXT>No Match</GetStreetMatchTXT>
  <GetZipMatchTXT>No Match</GetZipMatchTXT>
  <GetCVResult>N</GetCVResult>
  <GetCVResultTXT>No Match</GetCVResultTXT>
  <GetGetOrigResult />
  <GetCommercialCard>False</GetCommercialCard>
  <ExtData>InvNum=1,CardType=VISA,BatchNum=000000&lt;BatchNum&gt;000000&lt;/BatchNum&gt;</ExtData>
</Response>
)
  end

  def failed_purchase_response
  end

  def successful_authorize_response
    %(
<Response>
  <Result>0</Result>
  <RespMSG>Approved</RespMSG>
  <Message>APPROVED</Message>
  <Message1>
  </Message1>
  <Message2>
  </Message2>
  <AuthCode>987654</AuthCode>
  <PNRef>54321</PNRef>
  <HostCode>4321</HostCode>
  <HostURL>
  </HostURL>
  <ReceiptURL>
  </ReceiptURL>
  <GetAVSResult>
  </GetAVSResult>
  <GetAVSResultTXT>
  </GetAVSResultTXT>
  <GetStreetMatchTXT>
  </GetStreetMatchTXT>
  <GetZipMatchTXT>
  </GetZipMatchTXT>
  <GetCVResult>N</GetCVResult>
  <GetCVResultTXT>No Match</GetCVResultTXT>
  <GetGetOrigResult>
  </GetGetOrigResult>
  <GetCommercialCard>False</GetCommercialCard>
  <WorkingKey>
  </WorkingKey>
  <KeyPointer>
  </KeyPointer>
  <ExtData>InvNum=12321,CardType=VISA,BatchNum=000000<BatchNum>000000</BatchNum></ExtData>
</Response>
      )
  end

  def failed_authorize_response
    %(
<Response>
  <Result>23</Result>
  <RespMSG>Invalid Account Number</RespMSG>
  <Message>
  </Message>
  <Message1>
  </Message1>
  <Message2>
  </Message2>
  <AuthCode>
  </AuthCode>
  <PNRef>
  </PNRef>
  <HostCode>
  </HostCode>
  <HostURL>
  </HostURL>
  <ReceiptURL>
  </ReceiptURL>
  <GetAVSResult>
  </GetAVSResult>
  <GetAVSResultTXT>
  </GetAVSResultTXT>
  <GetStreetMatchTXT>
  </GetStreetMatchTXT>
  <GetZipMatchTXT>
  </GetZipMatchTXT>
  <GetCVResult>
  </GetCVResult>
  <GetCVResultTXT>
  </GetCVResultTXT>
  <GetGetOrigResult>
  </GetGetOrigResult>
  <GetCommercialCard>
  </GetCommercialCard>
  <WorkingKey>
  </WorkingKey>
  <KeyPointer>
  </KeyPointer>
  <ExtData>InvNum=12321,CardType=VISA</ExtData>
</Response>
      )
  end

  def successful_capture_response
        %(
<Response>
  <Result>0</Result>
  <RespMSG>Approved</RespMSG>
  <Message>APPROVED</Message>
  <Message1>
  </Message1>
  <Message2>
  </Message2>
  <AuthCode>987654</AuthCode>
  <PNRef>54321</PNRef>
  <HostCode>4321</HostCode>
  <HostURL>
  </HostURL>
  <ReceiptURL>
  </ReceiptURL>
  <GetAVSResult>
  </GetAVSResult>
  <GetAVSResultTXT>
  </GetAVSResultTXT>
  <GetStreetMatchTXT>
  </GetStreetMatchTXT>
  <GetZipMatchTXT>
  </GetZipMatchTXT>
  <GetCVResult>N</GetCVResult>
  <GetCVResultTXT>No Match</GetCVResultTXT>
  <GetGetOrigResult>
  </GetGetOrigResult>
  <GetCommercialCard>False</GetCommercialCard>
  <WorkingKey>
  </WorkingKey>
  <KeyPointer>
  </KeyPointer>
  <ExtData>InvNum=12321,CardType=VISA,BatchNum=000000<BatchNum>000000</BatchNum></ExtData>
</Response>
      )
  end

  def failed_capture_response
    %(
<Response>
  <Result>1015</Result>
  <RespMSG>No Records To Process</RespMSG>
  <Message>No Records To Process</Message>
  <Message1>
  </Message1>
  <Message2>
  </Message2>
  <AuthCode>
  </AuthCode>
  <PNRef>
  </PNRef>
  <HostCode>
  </HostCode>
  <HostURL>
  </HostURL>
  <ReceiptURL>
  </ReceiptURL>
  <GetAVSResult>
  </GetAVSResult>
  <GetAVSResultTXT>
  </GetAVSResultTXT>
  <GetStreetMatchTXT>
  </GetStreetMatchTXT>
  <GetZipMatchTXT>
  </GetZipMatchTXT>
  <GetCVResult>
  </GetCVResult>
  <GetCVResultTXT>
  </GetCVResultTXT>
  <GetGetOrigResult>
  </GetGetOrigResult>
  <GetCommercialCard>
  </GetCommercialCard>
  <WorkingKey>
  </WorkingKey>
  <KeyPointer>
  </KeyPointer>
  <ExtData>
  </ExtData>
</Response>
      )
  end

  def successful_refund_response
    %(
      <Response>
  <Result>0</Result>
  <RespMSG>Approved</RespMSG>
  <Message>APPROVAL</Message>
  <Message1>
  </Message1>
  <Message2>
  </Message2>
  <AuthCode>012345</AuthCode>
  <PNRef>1232321</PNRef>
  <HostCode>012345</HostCode>
  <HostURL>
  </HostURL>
  <ReceiptURL>
  </ReceiptURL>
  <GetAVSResult>
  </GetAVSResult>
  <GetAVSResultTXT>
  </GetAVSResultTXT>
  <GetStreetMatchTXT>
  </GetStreetMatchTXT>
  <GetZipMatchTXT>
  </GetZipMatchTXT>
  <GetCVResult>
  </GetCVResult>
  <GetCVResultTXT>
  </GetCVResultTXT>
  <GetGetOrigResult>
  </GetGetOrigResult>
  <GetCommercialCard>False</GetCommercialCard>
  <WorkingKey>
  </WorkingKey>
  <KeyPointer>
  </KeyPointer>
  <ExtData>CardType=VISA</ExtData>
</Response>
)
  end

  def failed_refund_response
    %(
    <Response>
  <Result>113</Result>
  <RespMSG>Cannot Exceed Sales Cap</RespMSG>
  <Message>Requested Refund Exceeds Available Refund Amount</Message>
  <Message1>
  </Message1>
  <Message2>
  </Message2>
  <AuthCode>Cannot_Exceed_Sales_Cap</AuthCode>
  <PNRef>012345</PNRef>
  <HostCode>Cannot_Exceed_Sales_Cap</HostCode>
  <HostURL>
  </HostURL>
  <ReceiptURL>
  </ReceiptURL>
  <GetAVSResult>
  </GetAVSResult>
  <GetAVSResultTXT>
  </GetAVSResultTXT>
  <GetStreetMatchTXT>
  </GetStreetMatchTXT>
  <GetZipMatchTXT>
  </GetZipMatchTXT>
  <GetCVResult>
  </GetCVResult>
  <GetCVResultTXT>
  </GetCVResultTXT>
  <GetGetOrigResult>
  </GetGetOrigResult>
  <GetCommercialCard>False</GetCommercialCard>
  <WorkingKey>
  </WorkingKey>
  <KeyPointer>
  </KeyPointer>
  <ExtData>CardType=VISA</ExtData>
</Response>
)
  end

  def successful_void_response
  end

  def failed_void_response
  end

  # recurring

  def successful_add_contract_response
  end

  def failed_add_contract_response
  end

  def successful_update_contract_response
  end

  def failed_update_contract_response
  end

  def successful_delete_contract_response
  end

  def failed_delete_contract_response
  end

  # crm

  def successful_add_customer_response
  end

  def failed_add_customer_response
  end

  def successful_update_customer_response
  end

  def failed_update_customer_response
  end

  def successful_delete_customer_response
  end

  def failed_delete_customer_response
  end

  def successful_add_credit_card_info_response
  end

  def failed_add_credit_card_info_response
  end

  def successful_update_credit_card_info_response
  end

  def failed_update_credit_card_info_response
  end

  def successful_delete_credit_card_info_response
  end

  def failed_delete_credit_card_info_response
  end

  # card safe

  def successful_store_card_response
  end

  def failed_store_card_response
  end

  def successful_process_stored_card_response
  end

  def failed_process_stored_card_response
  end

  # these are the 'processcreditcard' methods under the recurring tab in the docs
  def successful_process_stored_card_recurring_response
  end

  def successful_process_stored_card_recurring_response
  end
end
