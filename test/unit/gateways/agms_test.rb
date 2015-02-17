require 'test_helper'

require 'pp'

class AgmsTest < Test::Unit::TestCase
  
  def setup
    @gateway = AgmsGateway.new(
      login: 'login',
      password: 'password',
      api_key: 'api key',
      account_number: 'account number'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '549865', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '550945', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, auth
    assert_success auth

    assert_equal '550945', auth.authorization
    assert auth.test?

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert response = @gateway.capture(nil, auth.authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal '550946', response.authorization
    assert response.test?
    
  end

  def test_partial_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, auth
    assert_success auth

    assert_equal '550945', auth.authorization
    assert auth.test?

    @gateway.expects(:ssl_post).returns(partial_capture_response)

    assert response = @gateway.capture(@amount-1, auth.authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal '550946', response.authorization
    assert response.test?
    
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, auth
    assert_success auth

    assert_equal '550945', auth.authorization
    assert auth.test?

    @gateway.expects(:ssl_post).returns(failed_capture_response)

    assert response = @gateway.capture(nil, '')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction ID is required when performing a capture.  ', response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert purchase = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, purchase
    assert_success purchase

    assert_equal '550945', purchase.authorization
    assert purchase.test?

    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert response = @gateway.refund(nil, purchase.authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal '550946', response.authorization
    assert response.test?
  end

  def test_partial_refund
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert purchase = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, purchase
    assert_success purchase

    assert_equal '550945', purchase.authorization
    assert purchase.test?

    @gateway.expects(:ssl_post).returns(partial_refund_response)

    assert response = @gateway.refund(@amount-1, purchase.authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal '550946', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert purchase = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, purchase
    assert_success purchase

    assert_equal '550945', purchase.authorization
    assert purchase.test?

    @gateway.expects(:ssl_post).returns(failed_refund_response)

    assert response = @gateway.refund(nil, '')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction ID is required when performing a void or refund.  ', response.message
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, auth
    assert_success auth

    assert_equal '550945', auth.authorization
    assert auth.test?

    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert response = @gateway.void(auth.authorization)
    assert_instance_of Response, response
    assert_success response

    assert_equal '550946', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    assert purchase = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, purchase
    assert_success purchase

    assert_equal '550945', purchase.authorization
    assert purchase.test?

    @gateway.expects(:ssl_post).returns(failed_void_response)

    assert response = @gateway.void(nil, '')
    assert_instance_of Response, response
    assert_failure response
    assert_equal 'Transaction ID is required when performing a void or refund.  ', response.message
    assert response.test?
  end

  def test_successful_verify
  end

  def test_successful_verify_with_failed_void
  end

  def test_failed_verify
  end

  def test_invalid_login
    @gateway.expects(:ssl_post).returns(invalid_login_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
opening connection to gateway.agms.com...
opened
<- "POST /roxapi/agms.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nSoapaction: https://gateway.agms.com/roxapi/ProcessTransaction\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway.agms.com\r\nContent-Length: 1025\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <soap:Body>\n    <ProcessTransaction xmlns=\"https://gateway.agms.com/roxapi/\">\n      <objparameters>\n        <GatewayUserName>login</GatewayUserName>\n        <GatewayPassword>password</GatewayPassword>\n        <TransactionType>sale</TransactionType>\n        <CCNumber>4000100011112224</CCNumber>\n        <CVV>123</CVV>\n        <CCExpDate>0916</CCExpDate>\n        <FirstName>Longbob</FirstName>\n        <LastName>Longsen</LastName>\n        <Amount>1.00</Amount>\n        <Address1>1234 My Street</Address1>\n        <Address2>Apt 1</Address2>\n        <Company>Widgets Inc</Company>\n        <Phone>(555)555-5555</Phone>\n        <Zip>K1C2N6</Zip>\n        <City>Ottawa</City>\n        <Country>CA</Country>\n        <State>ON</State>\n      </objparameters>\n    </ProcessTransaction>\n  </soap:Body>\n</soap:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Length: 696\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Tue, 27 Jan 2015 18:10:38 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 696 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>Approved</STATUS_MSG><TRANS_ID>549776</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>"
read 696 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
opening connection to gateway.agms.com...
opened
<- "POST /roxapi/agms.asmx HTTP/1.1\r\nContent-Type: text/xml; charset=utf-8\r\nSoapaction: https://gateway.agms.com/roxapi/ProcessTransaction\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway.agms.com\r\nContent-Length: 1025\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n  <soap:Body>\n    <ProcessTransaction xmlns=\"https://gateway.agms.com/roxapi/\">\n      <objparameters>\n        <GatewayUserName>[FILTERED]</GatewayUserName>\n        <GatewayPassword>[FILTERED]</GatewayPassword>\n        <TransactionType>sale</TransactionType>\n        <CCNumber>[FILTERED]</CCNumber>\n        <CVV>[FILTERED]</CVV>\n        <CCExpDate>0916</CCExpDate>\n        <FirstName>Longbob</FirstName>\n        <LastName>Longsen</LastName>\n        <Amount>1.00</Amount>\n        <Address1>1234 My Street</Address1>\n        <Address2>Apt 1</Address2>\n        <Company>Widgets Inc</Company>\n        <Phone>(555)555-5555</Phone>\n        <Zip>K1C2N6</Zip>\n        <City>Ottawa</City>\n        <Country>CA</Country>\n        <State>ON</State>\n      </objparameters>\n    </ProcessTransaction>\n  </soap:Body>\n</soap:Envelope>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: private, max-age=0\r\n"
-> "Content-Length: 696\r\n"
-> "Content-Type: text/xml; charset=utf-8\r\n"
-> "Server: Microsoft-IIS/7.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Date: Tue, 27 Jan 2015 18:10:38 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 696 bytes...
-> "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>Approved</STATUS_MSG><TRANS_ID>549776</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>"
read 696 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>Approved</STATUS_MSG><TRANS_ID>549865</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
    )
  end

  def failed_purchase_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>2</STATUS_CODE><STATUS_MSG>Declined</STATUS_MSG><TRANS_ID>549879</TRANS_ID><AUTH_CODE>1234</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
    )
  end

  def successful_authorize_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>Approved</STATUS_MSG><TRANS_ID>550945</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>     )
  end

  def failed_authorize_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>2</STATUS_CODE><STATUS_MSG>Declined</STATUS_MSG><TRANS_ID>550941</TRANS_ID><AUTH_CODE>1234</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def successful_capture_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>Capture successful: Approved</STATUS_MSG><TRANS_ID>550946</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def partial_capture_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>Capture successful: Approved</STATUS_MSG><TRANS_ID>550946</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def failed_capture_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>10</STATUS_CODE><STATUS_MSG>Transaction ID is required when performing a capture.  </STATUS_MSG><TRANS_ID>550949</TRANS_ID><AUTH_CODE /><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def successful_refund_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>refund successful: Approved</STATUS_MSG><TRANS_ID>550946</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def partial_refund_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>refund successful: Approved</STATUS_MSG><TRANS_ID>550946</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def failed_refund_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>2</STATUS_CODE><STATUS_MSG>Transaction ID is required when performing a void or refund.  </STATUS_MSG><TRANS_ID>550953</TRANS_ID><AUTH_CODE /><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def successful_void_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>1</STATUS_CODE><STATUS_MSG>void successful: Approved</STATUS_MSG><TRANS_ID>550946</TRANS_ID><AUTH_CODE>9999</AUTH_CODE><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
     )
  end

  def failed_void_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>2</STATUS_CODE><STATUS_MSG>Transaction ID is required when performing a void or refund.  </STATUS_MSG><TRANS_ID>550953</TRANS_ID><AUTH_CODE /><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID>652</MERCHANT_ID><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

  def invalid_login_response
    %(
<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><soap:Body><ProcessTransactionResponse xmlns=\"https://gateway.agms.com/roxapi/\"><ProcessTransactionResult><STATUS_CODE>20</STATUS_CODE><STATUS_MSG>Authentication Failed</STATUS_MSG><TRANS_ID /><AUTH_CODE /><AVS_CODE /><AVS_MSG /><CVV2_CODE /><CVV2_MSG /><ORDERID /><SAFE_ID /><FULLRESPONSE /><POSTSTRING /><BALANCE /><GIFTRESPONSE /><MERCHANT_ID /><CUSTOMER_MESSAGE /><RRN /></ProcessTransactionResult></ProcessTransactionResponse></soap:Body></soap:Envelope>
      )
  end

end
