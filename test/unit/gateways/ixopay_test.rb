require 'test_helper'

class IxopayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = IxopayGateway.new(
      username: 'username',
      password: 'password',
      secret:   'secret',
      api_key:  'api_key'
    )

    @declined_card = credit_card('4000300011112220')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      ip: '192.168.1.1'
    }

    @extra_data = { extra_data: { customData1: 'some data', customData2: 'Can be anything really' } }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<description>.+<\/description>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_equal 'b2bef23a30b537b90fbe|20191016-b2bef23a30b537b90fbe', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_extra_data
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(@extra_data))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<extraData key="customData1">some data<\/extraData>/, data)
      assert_match(/<extraData key="customData2">Can be anything really<\/extraData>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_equal 'b2bef23a30b537b90fbe|20191016-b2bef23a30b537b90fbe', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'The transaction was declined', response.message
    assert_equal '2003', response.error_code
  end

  def test_failed_authentication
    @gateway.expects(:ssl_post).raises(mock_response_error)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert 'Invalid Signature', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert match(/<description>.+<\/description>/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_equal '00eb44f8f0382443cce5|20191028-00eb44f8f0382443cce5', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_extra_data
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge(@extra_data))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<extraData key="customData1">some data<\/extraData>/, data)
      assert_match(/<extraData key="customData2">Can be anything really<\/extraData>/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_equal '00eb44f8f0382443cce5|20191028-00eb44f8f0382443cce5', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.authorize(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'The transaction was declined', response.message
    assert_equal '2003', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '00eb44f8f0382443cce5|20191028-00eb44f8f0382443cce5')

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_equal '17dd1e0b09221e9db038|20191031-17dd1e0b09221e9db038', response.authorization
    assert response.test?
  end

  def test_successful_capture_with_extra_data
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = stub_comms do
      @gateway.capture(@amount, '00eb44f8f0382443cce5|20191028-00eb44f8f0382443cce5', @options.merge(@extra_data))
    end.check_request do |_endpoint, data, _header|
      assert_match(/<extraData key="customData1">some data<\/extraData>/, data)
      assert_match(/<extraData key="customData2">Can be anything really<\/extraData>/, data)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal 'FINISHED', response.message
    assert_equal '17dd1e0b09221e9db038|20191031-17dd1e0b09221e9db038', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, nil)

    assert_failure response
    assert_equal 'Transaction of type "capture" requires a referenceTransactionId', response.message
    assert_equal '9999', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, 'eb2bef23a30b537b90fb|20191016-b2bef23a30b537b90fbe')

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_successful_refund_with_extra_data
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = stub_comms do
      @gateway.refund(@amount, 'eb2bef23a30b537b90fb|20191016-b2bef23a30b537b90fbe', @options.merge(@extra_data))
    end.check_request do |_endpoint, data, _header|
      assert_match(/<extraData key="customData1">some data<\/extraData>/, data)
      assert_match(/<extraData key="customData2">Can be anything really<\/extraData>/, data)
    end.respond_with(successful_refund_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_refund_includes_currency_option
    options = { currency: 'USD' }

    stub_comms do
      @gateway.refund(@amount, 'eb2bef23a30b537b90fb|20191016-b2bef23a30b537b90fbe', options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<currency>USD<\/currency>/, data)
    end.respond_with(successful_refund_response)
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, nil)

    assert_failure response
    assert_equal 'Transaction of type "refund" requires a referenceTransactionId', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void('eb2bef23a30b537b90fb|20191016-b2bef23a30b537b90fbe')

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_successful_void_with_extra_data
    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = stub_comms do
      @gateway.void('eb2bef23a30b537b90fb|20191016-b2bef23a30b537b90fbe', @options.merge(@extra_data))
    end.check_request do |_endpoint, data, _header|
      assert_match(/<extraData key="customData1">some data<\/extraData>/, data)
      assert_match(/<extraData key="customData2">Can be anything really<\/extraData>/, data)
    end.respond_with(successful_void_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void(nil)

    assert_failure response
    assert_equal 'Transaction of type "void" requires a referenceTransactionId', response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_void_response)
    response = @gateway.verify(credit_card('4111111111111111'), @options)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_successful_verify_with_extra_data
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, successful_void_response)
    response = stub_comms do
      @gateway.verify(credit_card('4111111111111111'), @options.merge(@extra_data))
    end.check_request do |_endpoint, data, _header|
      assert_match(/<extraData key="customData1">some data<\/extraData>/, data)
      assert_match(/<extraData key="customData2">Can be anything really<\/extraData>/, data)
    end.respond_with(successful_authorize_response, successful_void_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(credit_card('4111111111111111'), @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  # Stored Credential Tests
  # Ixopay does not pass any parameters for cardholder/merchant initiated.
  # Ixopay also doesn't support installment transactions, only recurring
  # ("RECURRING") and unscheduled ("CARDONFILE").
  #
  # Furthermore, Ixopay is slightly unusual in its application of stored
  # credentials in that the gateway does not return a true
  # network_transaction_id that can be sent on subsequent transactions.
  def test_purchase_stored_credentials_initial
    options = @options.merge(
      stored_credential: stored_credential(:initial, :recurring)
    )
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<transactionIndicator>INITIAL<\/transactionIndicator>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_authorize_stored_credentials_initial
    options = @options.merge(
      stored_credential: stored_credential(:initial, :unscheduled)
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<transactionIndicator>INITIAL<\/transactionIndicator>/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_purchase_stored_credentials_recurring
    options = @options.merge(
      stored_credential: stored_credential(:recurring)
    )
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<transactionIndicator>RECURRING<\/transactionIndicator>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_authorize_stored_credentials_recurring
    options = @options.merge(
      stored_credential: stored_credential(:recurring)
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<transactionIndicator>RECURRING<\/transactionIndicator>/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_purchase_stored_credentials_unscheduled
    options = @options.merge(
      stored_credential: stored_credential(:unscheduled)
    )
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<transactionIndicator>CARDONFILE<\/transactionIndicator>/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_authorize_stored_credentials_unscheduled
    options = @options.merge(
      stored_credential: stored_credential(:unscheduled)
    )
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<transactionIndicator>CARDONFILE<\/transactionIndicator>/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  def test_three_decimal_currency_handling
    response = stub_comms do
      @gateway.authorize(14200, @credit_card, @options.merge(currency: 'KWD'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/<amount>14.200<\/amount>/, data)
      assert_match(/<currency>KWD<\/currency>/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'FINISHED', response.message
  end

  private

  def mock_response_error
    mock_response = Net::HTTPUnprocessableEntity.new('1.1', '401', 'Unauthorized')
    mock_response.stubs(:body).returns(failed_authentication_response)

    ActiveMerchant::ResponseError.new(mock_response)
  end

  def pre_scrubbed
    <<-TRANSCRIPT
      opening connection to secure.ixopay.com:443...
      opened
      starting SSL for secure.ixopay.com:443...
      SSL established
      <- "POST /transaction HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nAuthorization: Gateway spreedly-integration-1:i8CtuPyY820sX8hvJuRbygSnotj+VibBxqFl9MoFLYdrwC91zxymCv3h72DZBkOYT05P/L1Ig5aQrPf8SdOWtw==\r\nDate: Fri, 18 Oct 2019 19:24:53 GMT\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: secure.ixopay.com\r\nContent-Length: 1717\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<transactionWithCard xmlns=\"http://secure.ixopay.com/Schema/V2/TransactionWithCard\">\n  <username>spreedly-dev-api</username>\n  <password>834ab26f399def0fea3e444d6cecbf6c61230e09</password>\n  <cardData>\n    <cardHolder>Longbob Longsen</cardHolder>\n    <pan>4111111111111111</pan>\n    <cvv>123</cvv>\n    <expirationMonth>09</expirationMonth>\n    <expirationYear>2020</expirationYear>\n  </cardData>\n  <debit>\n    <transactionId>13454623-e012-4f77-b9e7-c9536964f186</transactionId>\n    <customer>\n      <firstName>Jim</firstName>\n      <lastName>Smith</lastName>\n      <billingAddress1>456 My Street</billingAddress1>\n      <billingAddress2>Apt 1</billingAddress2>\n      <billingCity>Ottawa</billingCity>\n      <billingPostcode>K1C2N6</billingPostcode>\n      <billingState>ON</billingState>\n      <billingCountry>CA</billingCountry>\n      <billingPhone>(555)555-5555</billingPhone>\n      <shippingFirstName>Jim</shippingFirstName>\n      <shippingLastName>Smith</shippingLastName>\n      <shippingCompany>Widgets Inc</shippingCompany>\n      <shippingAddress1>456 My Street</shippingAddress1>\n      <shippingAddress2>Apt 1</shippingAddress2>\n      <shippingCity>Ottawa</shippingCity>\n      <shippingPostcode>K1C2N6</shippingPostcode>\n      <shippingState>ON</shippingState>\n      <shippingCountry>CA</shippingCountry>\n      <shippingPhone>(555)555-5555</shippingPhone>\n      <company>Widgets Inc</company>\n      <email>test@example.com</email>\n      <ipAddress>192.168.1.1</ipAddress>\n    </customer>\n    <amount>100</amount>\n    <currency>EUR</currency>\n    <description>Store Purchase</description>\n    <callbackUrl>http://example.com</callbackUrl>\n  </debit>\n</transactionWithCard>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Fri, 18 Oct 2019 19:24:55 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=db8efa44225d95d93942c576b8f53feb31571426693; expires=Sat, 17-Oct-20 19:24:53 GMT; path=/; domain=.ixopay.com; HttpOnly\r\n"
      -> "5: Content-Type: text/xml; charset=UTF-8\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Strict-Transport-Security: max-age=15552000; includeSubDomains; preload\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Server: vau-prod-webfe-esh-02\r\n"
      -> "CF-Cache-Status: DYNAMIC\r\n"
      -> "Expect-CT: max-age=604800, report-uri=\"https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct\"\r\n"
      -> "Server: cloudflare\r\n"
      -> "CF-RAY: 527ce522ab3b9f7c-IAD\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "18c\r\n"
      reading 396 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03l\x92Mo\xDB0\f\x86\xEF\xF9\x15\x82\xEF\x8D\xFC\x91\xA6\xC9 \xAB\x87eE\x03\xAC=4\xC3\x80\x1De\x89\x89\x85\xD9\x92AI\x85\xFD\xEF\v\xD9q\x96\xB4\xD3E\xE0\xCB\x87/EB\xEC\xB1o\e\xF2\x0E\xE8\xB45e\x92-\xD3\x84\x80\x91Vis*\x93\xE0\x8Fw\x9B\xE4\x91/\x18\x82\v\x8D'}\xDB\x18W&\xB5\xF7\xDD7J\x1D\xC8\x80\xB0\xD4\xBD\xED\xC4\xB0\x94\xB6\xA5\aYC+\xE8\xEF\x9C\xBE\x8D\x05\t_\x10\xC2\\\x90\x12\x9C\xE3\x1E\x030:G1\x83p\x04\x04#a\xAF\xF8\xAA(\xF2j\x9D\x17b\xBD\x11\x0F\xD5}Q\xACW\x0F\x8C^\x13\xB1\xA2\v(k\xE1b\x98\xA7\xD96K\xB3\xCD\xDD\xFF+\xAF\xC8\xA9\x95\x0Fh~\r\x1D\xF0\xA7\xFD\xEB\xFE\xF0\xFCc\x17\xDD/\xE2h.\x86\x16\x8C\x7F\x01_[\xC5\xBF#(\xED\xA5@\xC5\xE8m\xE6\x9F\xDFNxA\xFC\xD0A\x99\xC8\v\x1E\xC5qrB\xD8\xAD:\x89\x84\xB0X\xC2\xDF\xB5\x13\x8C\xFAs\xF7\t\x17\xA8\x9Em\xA3\x00\xF9OkN\x95\xADH\xBC\x1D\x18F\xAFr3\x0E}\xA7qx\xB1\xC6\xD7<\xDD2z\x1D\xDF2\x7F@ \xCF\xD3<\x9D\xA1Q\x98\x99\xA3F\xE7\x0F\xBA\xDF\xE9\x93\xF6\x8E\xAF\xB2x\x18\xFD$\xCFt#\x9C\x7F\xB2\x01\xCF\xF2\xC4~\x12\xA7\xE9\xE9\xD7\xF1\xE7\xA5_b\xE8=\x8Aq\x8F\x7Fa(\x13):\x1F\x10\xF6*\xE1\xF7J\x88,\xDB\xAC\xB7\xC5\x16\xAA\xF8\xEE3\xC8\x17\xD1$\xFE/\xBE\xF8\x00\x00\x00\xFF\xFF\x03\x00\x0F\x10\x82\b\xC1\x02\x00\x00"
      read 396 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    TRANSCRIPT
  end

  def post_scrubbed
    transcript = <<-TRANSCRIPT
      opening connection to secure.ixopay.com:443...
      opened
      starting SSL for secure.ixopay.com:443...
      SSL established
      <- "POST /transaction HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nAuthorization: Gateway [FILTERED]:i8CtuPyY820sX8hvJuRbygSnotj+VibBxqFl9MoFLYdrwC91zxymCv3h72DZBkOYT05P/L1Ig5aQrPf8SdOWtw==\r\nDate: Fri, 18 Oct 2019 19:24:53 GMT\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: secure.ixopay.com\r\nContent-Length: 1717\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<transactionWithCard xmlns=\"http://secure.ixopay.com/Schema/V2/TransactionWithCard\">\n  <username>spreedly-dev-api</username>\n  <password>[FILTERED]</password>\n  <cardData>\n    <cardHolder>Longbob Longsen</cardHolder>\n    <pan>[FILTERED]</pan>\n    <cvv>[FILTERED]</cvv>\n    <expirationMonth>09</expirationMonth>\n    <expirationYear>2020</expirationYear>\n  </cardData>\n  <debit>\n    <transactionId>13454623-e012-4f77-b9e7-c9536964f186</transactionId>\n    <customer>\n      <firstName>Jim</firstName>\n      <lastName>Smith</lastName>\n      <billingAddress1>456 My Street</billingAddress1>\n      <billingAddress2>Apt 1</billingAddress2>\n      <billingCity>Ottawa</billingCity>\n      <billingPostcode>K1C2N6</billingPostcode>\n      <billingState>ON</billingState>\n      <billingCountry>CA</billingCountry>\n      <billingPhone>(555)555-5555</billingPhone>\n      <shippingFirstName>Jim</shippingFirstName>\n      <shippingLastName>Smith</shippingLastName>\n      <shippingCompany>Widgets Inc</shippingCompany>\n      <shippingAddress1>456 My Street</shippingAddress1>\n      <shippingAddress2>Apt 1</shippingAddress2>\n      <shippingCity>Ottawa</shippingCity>\n      <shippingPostcode>K1C2N6</shippingPostcode>\n      <shippingState>ON</shippingState>\n      <shippingCountry>CA</shippingCountry>\n      <shippingPhone>(555)555-5555</shippingPhone>\n      <company>Widgets Inc</company>\n      <email>test@example.com</email>\n      <ipAddress>192.168.1.1</ipAddress>\n    </customer>\n    <amount>100</amount>\n    <currency>EUR</currency>\n    <description>Store Purchase</description>\n    <callbackUrl>http://example.com</callbackUrl>\n  </debit>\n</transactionWithCard>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Fri, 18 Oct 2019 19:24:55 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=db8efa44225d95d93942c576b8f53feb31571426693; expires=Sat, 17-Oct-20 19:24:53 GMT; path=/; domain=.ixopay.com; HttpOnly\r\n"
      -> "5: Content-Type: text/xml; charset=UTF-8\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Strict-Transport-Security: max-age=15552000; includeSubDomains; preload\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Server: vau-prod-webfe-esh-02\r\n"
      -> "CF-Cache-Status: DYNAMIC\r\n"
      -> "Expect-CT: max-age=604800, report-uri=\"https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct\"\r\n"
      -> "Server: cloudflare\r\n"
      -> "CF-RAY: 527ce522ab3b9f7c-IAD\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "18c\r\n"
      reading 396 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03l\x92Mo\xDB0\f\x86\xEF\xF9\x15\x82\xEF\x8D\xFC\x91\xA6\xC9 \xAB\x87eE\x03\xAC=4\xC3\x80\x1De\x89\x89\x85\xD9\x92AI\x85\xFD\xEF\v\xD9q\x96\xB4\xD3E\xE0\xCB\x87/EB\xEC\xB1o\e\xF2\x0E\xE8\xB45e\x92-\xD3\x84\x80\x91Vis*\x93\xE0\x8Fw\x9B\xE4\x91/\x18\x82\v\x8D'}\xDB\x18W&\xB5\xF7\xDD7J\x1D\xC8\x80\xB0\xD4\xBD\xED\xC4\xB0\x94\xB6\xA5\aYC+\xE8\xEF\x9C\xBE\x8D\x05\t_\x10\xC2\\\x90\x12\x9C\xE3\x1E\x030:G1\x83p\x04\x04#a\xAF\xF8\xAA(\xF2j\x9D\x17b\xBD\x11\x0F\xD5}Q\xACW\x0F\x8C^\x13\xB1\xA2\v(k\xE1b\x98\xA7\xD96K\xB3\xCD\xDD\xFF+\xAF\xC8\xA9\x95\x0Fh~\r\x1D\xF0\xA7\xFD\xEB\xFE\xF0\xFCc\x17\xDD/\xE2h.\x86\x16\x8C\x7F\x01_[\xC5\xBF#(\xED\xA5@\xC5\xE8m\xE6\x9F\xDFNxA\xFC\xD0A\x99\xC8\v\x1E\xC5qrB\xD8\xAD:\x89\x84\xB0X\xC2\xDF\xB5\x13\x8C\xFAs\xF7\t\x17\xA8\x9Em\xA3\x00\xF9OkN\x95\xADH\xBC\x1D\x18F\xAFr3\x0E}\xA7qx\xB1\xC6\xD7<\xDD2z\x1D\xDF2\x7F@ \xCF\xD3<\x9D\xA1Q\x98\x99\xA3F\xE7\x0F\xBA\xDF\xE9\x93\xF6\x8E\xAF\xB2x\x18\xFD$\xCFt#\x9C\x7F\xB2\x01\xCF\xF2\xC4~\x12\xA7\xE9\xE9\xD7\xF1\xE7\xA5_b\xE8=\x8Aq\x8F\x7Fa(\x13):\x1F\x10\xF6*\xE1\xF7J\x88,\xDB\xAC\xB7\xC5\x16\xAA\xF8\xEE3\xC8\x17\xD1$\xFE/\xBE\xF8\x00\x00\x00\xFF\xFF\x03\x00\x0F\x10\x82\b\xC1\x02\x00\x00"
      read 396 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    TRANSCRIPT

    remove_invalid_utf_8_byte_sequences(transcript)
  end

  def remove_invalid_utf_8_byte_sequences(text)
    text.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
  end

  def successful_purchase_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>true</success>
        <referenceId>b2bef23a30b537b90fbe</referenceId>
        <purchaseId>20191016-b2bef23a30b537b90fbe</purchaseId>
        <returnType>FINISHED</returnType>
        <paymentMethod>Creditcard</paymentMethod>
        <returnData type="creditcardData">
          <creditcardData>
            <type>visa</type>
            <cardHolder>Longbob Longsen</cardHolder>
            <expiryMonth>09</expiryMonth>
            <expiryYear>2020</expiryYear>
            <firstSixDigits>411111</firstSixDigits>
            <lastFourDigits>1111</lastFourDigits>
          </creditcardData>
        </returnData>
        <extraData key="captureId">5da76cc5ce84b</extraData>
      </result>
    XML
  end

  def failed_purchase_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>false</success>
        <referenceId>d74211aa7d0ba8294b4d</referenceId>
        <purchaseId>20191016-d74211aa7d0ba8294b4d</purchaseId>
        <returnType>ERROR</returnType>
        <paymentMethod>Creditcard</paymentMethod>
        <returnData type="creditcardData">
          <creditcardData>
            <type>visa</type>
            <cardHolder>Longbob Longsen</cardHolder>
            <expiryMonth>09</expiryMonth>
            <expiryYear>2020</expiryYear>
            <firstSixDigits>400030</firstSixDigits>
            <lastFourDigits>2220</lastFourDigits>
          </creditcardData>
        </returnData>
        <errors>
          <error>
            <message>The transaction was declined</message>
            <code>2003</code>
            <adapterMessage>Test decline</adapterMessage>
            <adapterCode>transaction_declined</adapterCode>
          </error>
        </errors>
      </result>
    XML
  end

  def failed_authentication_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://gateway/Schema/V2/TransactionWithCard">
        <success>false</success>
        <returnType>ERROR</returnType>
        <errors>
          <error>
            <message>Invalid Signature: Invalid authorization header</message>
            <code>1004</code>
          </error>
        </errors>
      </result>
    XML
  end

  def successful_authorize_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>true</success>
        <referenceId>00eb44f8f0382443cce5</referenceId>
        <purchaseId>20191028-00eb44f8f0382443cce5</purchaseId>
        <returnType>FINISHED</returnType>
        <paymentMethod>Creditcard</paymentMethod>
        <returnData type="creditcardData">
          <creditcardData>
            <type>visa</type>
            <cardHolder>Longbob Longsen</cardHolder>
            <expiryMonth>09</expiryMonth>
            <expiryYear>2020</expiryYear>
            <firstSixDigits>411111</firstSixDigits>
            <lastFourDigits>1111</lastFourDigits>
          </creditcardData>
        </returnData>
      </result>
    XML
  end

  def failed_authorize_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>false</success>
        <referenceId>91278c76405116378b85</referenceId>
        <purchaseId>20191028-91278c76405116378b85</purchaseId>
        <returnType>ERROR</returnType>
        <paymentMethod>Creditcard</paymentMethod>
        <returnData type="creditcardData">
          <creditcardData>
            <type>visa</type>
            <cardHolder>Longbob Longsen</cardHolder>
            <expiryMonth>09</expiryMonth>
            <expiryYear>2020</expiryYear>
            <firstSixDigits>400030</firstSixDigits>
            <lastFourDigits>2220</lastFourDigits>
          </creditcardData>
        </returnData>
        <errors>
          <error>
            <message>The transaction was declined</message>
            <code>2003</code>
            <adapterMessage>Test decline</adapterMessage>
            <adapterCode>transaction_declined</adapterCode>
          </error>
        </errors>
      </result>
    XML
  end

  def successful_capture_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>true</success>
        <referenceId>17dd1e0b09221e9db038</referenceId>
        <purchaseId>20191031-17dd1e0b09221e9db038</purchaseId>
        <returnType>FINISHED</returnType>
        <paymentMethod>Creditcard</paymentMethod>
        <returnData type="creditcardData">
          <creditcardData>
            <type>visa</type>
            <cardHolder>Longbob Longsen</cardHolder>
            <expiryMonth>09</expiryMonth>
            <expiryYear>2020</expiryYear>
            <firstSixDigits>411111</firstSixDigits>
            <lastFourDigits>1111</lastFourDigits>
          </creditcardData>
        </returnData>
      </result>
    XML
  end

  def failed_capture_response
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>false</success>
        <returnType>ERROR</returnType>
        <errors>
          <error>
            <message>Transaction of type "capture" requires a referenceTransactionId</message>
            <code>9999</code>
          </error>
        </errors>
      </result>
    XML
  end

  def successful_refund_response
    <<-XML
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>true</success>
        <referenceId>21c47c977476d5a3b682</referenceId>
        <purchaseId>20191028-c9e173c255d14f90816b</purchaseId>
        <returnType>FINISHED</returnType>
        <paymentMethod>Creditcard</paymentMethod>
      </result>
    XML
  end

  def failed_refund_response
    <<-XML
      <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
        <success>false</success>
        <returnType>ERROR</returnType>
        <errors>
          <error>
            <message>Transaction of type "refund" requires a referenceTransactionId</message>
            <code>9999</code>
          </error>
        </errors>
      </result>
    XML
  end

  def successful_void_response
    <<-XML
    <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
      <success>true</success>
      <referenceId>cb656bd5286e77501b2e</referenceId>
      <purchaseId>20191031-b1f9f7991766cf933659</purchaseId>
      <returnType>FINISHED</returnType>
      <paymentMethod>Creditcard</paymentMethod>
    </result>
    XML
  end

  def failed_void_response
    <<-XML
    <result xmlns="http://secure.ixopay.com/Schema/V2/Result">
      <success>false</success>
      <returnType>ERROR</returnType>
      <errors>
        <error>
          <message>Transaction of type "void" requires a referenceTransactionId</message>
          <code>9999</code>
        </error>
      </errors>
    </result>
    XML
  end
end
