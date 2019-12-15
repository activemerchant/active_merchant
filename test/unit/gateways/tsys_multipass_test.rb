require 'test_helper'

class TsysMultipassTest < Test::Unit::TestCase
  include CommStub

  def setup
    @card_token = 'asdsWPabcabcqsdfsd'
    @amount = 100
    @expiration_date = '122020'
    @auth_id = 'XYZabc'

    @gateway = TsysMultipassGateway.new(
      device_id: 'device_id',
      transaction_key: 'reg_key'
    )

    @auth_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: @amount,
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    @purchase_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: @amount,
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    @capture_options = {
      transactionAmount: @amount.to_s,
      transactionID: @auth_id
    }

    @refund_options = {
      transactionAmount: @amount.to_s,
      transactionID: @auth_id
    }

    @void_options = {
      transactionAmount: @amount.to_s,
      transactionID: @auth_id
    }
  end

  def test_successful_purchase
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(successful_purchase_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.purchase(@amount, @card_token, @purchase_options)

    assert_equal true, response.success?
    assert_equal '12345678', response.authorization
    assert_equal '100', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_purchase
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(failed_purchase_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.authorize(@amount, @card_token, @purchase_options)

    assert_equal false, response.success?
    assert_equal nil, response.authorization
    assert_equal nil, response.amount
    assert_equal 'F0001', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_authorize
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(successful_authorize_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.authorize(@amount, @card_token, @auth_options)

    assert_equal true, response.success?
    assert_equal '12345678', response.authorization
    assert_equal '100', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_authorize
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(failed_authorize_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.authorize(@amount, @card_token, @auth_options)

    assert_equal false, response.success?
    assert_equal nil, response.authorization
    assert_equal nil, response.amount
    assert_equal 'F9901', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_capture
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(successful_capture_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.capture(@amount, @auth_id, @capture_options)

    assert_equal true, response.success?
    assert_equal '21462680', response.authorization
    assert_equal '1100', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_capture
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(failed_capture_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.capture(@amount, @auth_id, @capture_options)

    assert_equal false, response.success?
    assert_equal nil, response.authorization
    assert_equal nil, response.amount
    assert_equal 'F9901', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_void
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(successful_void_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.void(@auth_id, @void_options)

    assert_equal true, response.success?
    assert_equal '21468076', response.authorization
    assert_equal '10000', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_void
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(failed_void_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.void(@auth_id, @void_options)

    assert_equal false, response.success?
    assert_equal nil, response.authorization
    assert_equal nil, response.amount
    assert_equal 'D0004', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_refund
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(successful_refund_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.refund(@amount, @auth_id, @refund_options)

    assert_equal true, response.success?
    assert_equal '21468126', response.authorization
    assert_equal '11250', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_refund
    # Stubbing external response
    response_obj = mock()
    response_obj.stubs(:body).returns(failed_refund_response)

    @gateway.expects(:response).returns(response_obj)

    response = @gateway.refund(@amount, @auth_id, @refund_options)

    assert_equal false, response.success?
    assert_equal nil, response.authorization
    assert_equal nil, response.amount
    assert_equal 'D0005', response.error_code
    assert_instance_of Response, response
  end

  def test_supports_scrubbing
    is_scrubbing_supported = @gateway.supports_scrubbing?

    assert_equal true, is_scrubbing_supported
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    %({"SaleResponse":{"status":"PASS","responseCode":"A0000","responseMessage":"Success","authCode":"TAS111","hostReferenceNumber":"12345678912345","hostResponseCode":"00","taskID":"12345678","transactionID":"12345678","transactionTimestamp":"2019-12-04T13:17:47","transactionAmount":"100","processedAmount":"100","totalAmount":"100","addressVerificationCode":"0","cardType":"V","maskedCardNumber":"5439","token":"ABCabcssdf5439","expirationDate":"122020","commercialCard":"0","aci":"N","cardTransactionIdentifier":"000000000123456","customerReceipt":"DUMMY RECEIPT TEXT" }})
  end

  def failed_purchase_response
    %({"SaleResponse":{"status":"FAIL","responseCode":"F0001","responseMessage":"Error Message"}})
  end

  def successful_authorize_response
    %({"AuthResponse":{"status":"PASS","responseCode":"A0000","responseMessage":"Success","authCode":"TAS111","hostReferenceNumber":"12345678912345","hostResponseCode":"00","taskID":"12345678","transactionID":"12345678","transactionTimestamp":"2019-12-04T13:17:47","transactionAmount":"100","processedAmount":"100","totalAmount":"100","addressVerificationCode":"0","cardType":"V","maskedCardNumber":"5439","token":"ABCabcssdf5439","expirationDate":"122020","commercialCard":"0","aci":"N","cardTransactionIdentifier":"000000000123456","customerReceipt":"DUMMY RECEIPT TEXT" }})
  end

  def failed_authorize_response
    %({"AuthResponse":{"status":"FAIL","responseCode":"F9901","responseMessage":"Error Message"}})
  end

  def successful_capture_response
    %({"CaptureResponse":{"status":"PASS", "responseCode":"A0000", "responseMessage":"Success", "authCode":"TAS817", "cardType":"V", "taskID":"21160272", "transactionID":"21462680", "transactionTimestamp":"2019-12-12T17:37:20", "transactionAmount":"1100", "totalAmount":"1100", "customerReceipt":"DUMMY RECEIPT BODY"}})
  end

  def failed_capture_response
    %({"CaptureResponse":{"status":"FAIL", "responseCode":"F9901", "responseMessage":"Error Message"}})
  end

  def successful_void_response
    %({"VoidResponse":{"status":"PASS","responseCode":"A0000","responseMessage":"Success","authCode":"TAS554","hostReferenceNumber":"934720500625","hostResponseCode":"00","taskID":"21165594","transactionID":"21468076","transactionTimestamp":"2019-12-13T13:02:04","orderNumber":"21468074","externalReferenceID":"21468074","transactionAmount":"10000","voidedAmount":"10000","cardType":"V","maskedCardNumber":"5439","customerReceipt":"DUMMY RECEIPT BODY"}})
  end

  def failed_void_response
    %({"VoidResponse":{"status":"FAIL","responseCode":"D0004","responseMessage":"Error Message"}})
  end

  def successful_refund_response
    %({"ReturnResponse":{"status":"PASS","responseCode":"A0014","responseMessage":"Return requested, Void successful","authCode":"TAS638","hostReferenceNumber":"934720500671","hostResponseCode":"00","taskID":"21164738","transactionID":"21468126","transactionTimestamp":"2019-12-13T13:08:59","orderNumber":"21468126","externalReferenceID":"21468126","transactionAmount":"11250","returnedAmount":"11250","cardType":"V","maskedCardNumber":"5439","customerReceipt":"DUMMY RECEIPT BODY"}})
  end

  def failed_refund_response
    %({"ReturnResponse":{"status":"FAIL","responseCode":"D0005","responseMessage":"Error Message"}})
  end

  def transcript
    <<-PRE_SCRUBBED
    opening connection to stagegw.transnox.com:443...
opened
starting SSL for stagegw.transnox.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
<- "POST /servlets/TransNox_API_Server HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: stagegw.transnox.com\r\nContent-Length: 241\r\n\r\n"
<- "{\"Auth\":{\"deviceID\":\"88700000321502\",\"transactionKey\":\"RRTSRFXLE8L5L64KSINCYEANQ0UNM5U0\",\"cardDataSource\":\"INTERNET\",\"transactionAmount\":\"10000\",\"cardNumber\":\"Py2ARW2LJpbd5439\",\"expirationDate\":\"12/20\",\"softDescriptor\":\"DUMMY DATA FOR NOW\"}}"
-> "HTTP/1.1 200 \r\n"
-> "Date: Fri, 13 Dec 2019 21:49:04 GMT\r\n"
-> "Content-Type: application/json;charset=ISO-8859-1\r\n"
-> "Set-Cookie: TS01bcb3a9=01e23550884a78befd6dc913284f327d61dec76e50caa3fe81aa15e8804acdab14e80a85ad3bc36c28f64de8667bf10feefc1638f6; Path=/; Secure; HTTPOnly\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "a87\r\n"
reading 2695 bytes...
-> "{\"AuthResponse\":{\"status\":\"PASS\",\"responseCode\":\"A0000\",\"responseMessage\":\"Success\",\"authCode\":\"TAS989\",\"hostReferenceNumber\":\"934721501245\",\"hostResponseCode\":\"00\",\"taskID\":\"21165218\",\"transactionID\":\"21469132\",\"transactionTimestamp\":\"2019-12-13T14:49:03\",\"transactionAmount\":\"10000\",\"processedAmount\":\"10000\",\"totalAmount\":\"10000\",\"addressVerificationCode\":\"0\",\"cardType\":\"V\",\"maskedCardNumber\":\"5439\",\"token\":\"Py2ARW2LJpbd5439\",\"expirationDate\":\"122020\",\"commercialCard\":\"0\",\"aci\":\"N\",\"cardTransactionIdentifier\":\"000000000591089\",\"customerReceipt\":\"DUMMY RECEIPT\n"
read 2695 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn keep-alive
    PRE_SCRUBBED
  end

  def scrubbed_transcript
    <<-POST_SCRUBBED
    opening connection to stagegw.transnox.com:443...
opened
starting SSL for stagegw.transnox.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
<- "POST /servlets/TransNox_API_Server HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: stagegw.transnox.com\r\nContent-Length: 241\r\n\r\n"
<- "{\"Auth\":{\"deviceID\":[FILTERED],\"transactionKey\":[FILTERED],\"cardDataSource\":\"INTERNET\",\"transactionAmount\":\"10000\",\"cardNumber\":[FILTERED],\"expirationDate\":[FILTERED],\"softDescriptor\":\"DUMMY DATA FOR NOW\"}}"
-> "HTTP/1.1 200 \r\n"
-> "Date: Fri, 13 Dec 2019 21:49:04 GMT\r\n"
-> "Content-Type: application/json;charset=ISO-8859-1\r\n"
-> "Set-Cookie: TS01bcb3a9=01e23550884a78befd6dc913284f327d61dec76e50caa3fe81aa15e8804acdab14e80a85ad3bc36c28f64de8667bf10feefc1638f6; Path=/; Secure; HTTPOnly\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "a87\r\n"
reading 2695 bytes...
-> "{\"AuthResponse\":{\"status\":\"PASS\",\"responseCode\":\"A0000\",\"responseMessage\":\"Success\",\"authCode\":\"TAS989\",\"hostReferenceNumber\":\"934721501245\",\"hostResponseCode\":\"00\",\"taskID\":\"21165218\",\"transactionID\":\"21469132\",\"transactionTimestamp\":\"2019-12-13T14:49:03\",\"transactionAmount\":\"10000\",\"processedAmount\":\"10000\",\"totalAmount\":\"10000\",\"addressVerificationCode\":\"0\",\"cardType\":\"V\",\"maskedCardNumber\":\"5439\",\"token\":[FILTERED],\"expirationDate\":[FILTERED],\"commercialCard\":\"0\",\"aci\":\"N\",\"cardTransactionIdentifier\":\"000000000591089\",\"customerReceipt\":\"DUMMY RECEIPT\n"
read 2695 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn keep-alive
    POST_SCRUBBED
  end
end
