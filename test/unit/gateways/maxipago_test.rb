require 'test_helper'

class MaxipagoTest < Test::Unit::TestCase
  def setup
    @gateway = MaxipagoGateway.new(
      :login => 'login',
      :password => 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :installments => 3
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '123456789|123456789', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'C0A8013F:014455FCC857:91A0:01A7243E|663921', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(nil, "authorization", @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, "bogus", @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_void_response)
    void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal "VOIDED", void.params["response_message"]

  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void("NOAUTH|0000000")
    assert_failure response
    assert_equal "Unable to validate, original void transaction not found", response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
    assert_equal "CAPTURED", refund.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(failed_refund_response)
    refund_amount = @amount + 10
    refund = @gateway.refund(refund_amount, purchase.authorization, @options)
    assert_failure refund
    assert_equal "The Return amount is greater than the amount that can be returned.", refund.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response).then.returns(successful_void_response)
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "AUTHORIZED", response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal "The transaction has an expired credit card.", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %(
      opening connection to testapi.maxipago.net:443...
      opened
      starting SSL for testapi.maxipago.net:443...
      SSL established
      <- "POST /UniversalAPI/postXML HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: testapi.maxipago.net\r\nContent-Length: 1224\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<transaction-request>\n  <version>3.1.1.15</version>\n  <verification>\n    <merchantId>100</merchantId>\n    <merchantKey>21g8u6gh6szw1gywfs165vui</merchantKey>\n  </verification>\n  <order>\n    <sale>\n      <processorID>1</processorID>\n      <fraudCheck>N</fraudCheck>\n      <referenceNum>12345</referenceNum>\n      <transactionDetail>\n        <payType>\n          <creditCard>\n            <number>4111111111111111</number>\n            <expMonth>9</expMonth>\n            <expYear>2017</expYear>\n            <cvvNumber>444</cvvNumber>\n          </creditCard>\n        </payType>\n      </transactionDetail>\n      <payment>\n        <chargeTotal>10.00</chargeTotal>\n        <creditInstallment>\n          <numberOfInstallments>3</numberOfInstallments>\n          <chargeInterest>N</chargeInterest>\n        </creditInstallment>\n      </payment>\n      <billing>\n        <name>Longbob Longsen</name>\n        <address>456 My Street</address>\n        <address2>Apt 1</address2>\n        <city>Ottawa</city>\n        <state>ON</state>\n        <postalcode>K1C2N6</postalcode>\n        <country>CA</country>\n        <phone>(555)555-5555</phone>\n      </billing>\n    </sale>\n  </order>\n</transaction-request>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 09 Jun 2016 14:54:53 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=31557600; includeSubDomains\r\n"
      -> "Content-Length: 628\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/plain; charset=UTF-8\r\n"
      -> "\r\n"
      reading 628 bytes...
      -> ""
      -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?><transaction-response>\n<authCode>123456</authCode>\n<orderID>C0A8013F:015535A8A798:D12E:006BB50C</orderID>\n<referenceNum>12345</referenceNum>\n<transactionID>1410203</transactionID>\n<transactionTimestamp>1465484093</transactionTimestamp>\n<responseCode>0</responseCode>\n<responseMessage>CAPTURED</responseMessage>\n<avsResponseCode>YYY</avsResponseCode>\n<cvvResponseCode>M</cvvResponseCode>\n<processorCode>A</processorCode>\n<processorMessage>APPROVED</processorMessage>\n<errorMessage/>\n<creditCardCountry>US</creditCardCountry>\n<creditCardScheme>Visa</creditCardScheme>\n</transaction-response>\n"
      read 628 bytes
      Conn close
    )
  end

  def post_scrubbed
    %(
      opening connection to testapi.maxipago.net:443...
      opened
      starting SSL for testapi.maxipago.net:443...
      SSL established
      <- "POST /UniversalAPI/postXML HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: testapi.maxipago.net\r\nContent-Length: 1224\r\n\r\n"
      <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<transaction-request>\n  <version>3.1.1.15</version>\n  <verification>\n    <merchantId>100</merchantId>\n    <merchantKey>[FILTERED]</merchantKey>\n  </verification>\n  <order>\n    <sale>\n      <processorID>1</processorID>\n      <fraudCheck>N</fraudCheck>\n      <referenceNum>12345</referenceNum>\n      <transactionDetail>\n        <payType>\n          <creditCard>\n            <number>[FILTERED]</number>\n            <expMonth>9</expMonth>\n            <expYear>2017</expYear>\n            <cvvNumber>[FILTERED]</cvvNumber>\n          </creditCard>\n        </payType>\n      </transactionDetail>\n      <payment>\n        <chargeTotal>10.00</chargeTotal>\n        <creditInstallment>\n          <numberOfInstallments>3</numberOfInstallments>\n          <chargeInterest>N</chargeInterest>\n        </creditInstallment>\n      </payment>\n      <billing>\n        <name>Longbob Longsen</name>\n        <address>456 My Street</address>\n        <address2>Apt 1</address2>\n        <city>Ottawa</city>\n        <state>ON</state>\n        <postalcode>K1C2N6</postalcode>\n        <country>CA</country>\n        <phone>(555)555-5555</phone>\n      </billing>\n    </sale>\n  </order>\n</transaction-request>\n"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 09 Jun 2016 14:54:53 GMT\r\n"
      -> "Server: Apache\r\n"
      -> "Strict-Transport-Security: max-age=31557600; includeSubDomains\r\n"
      -> "Content-Length: 628\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/plain; charset=UTF-8\r\n"
      -> "\r\n"
      reading 628 bytes...
      -> ""
      -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?><transaction-response>\n<authCode>123456</authCode>\n<orderID>C0A8013F:015535A8A798:D12E:006BB50C</orderID>\n<referenceNum>12345</referenceNum>\n<transactionID>1410203</transactionID>\n<transactionTimestamp>1465484093</transactionTimestamp>\n<responseCode>0</responseCode>\n<responseMessage>CAPTURED</responseMessage>\n<avsResponseCode>YYY</avsResponseCode>\n<cvvResponseCode>M</cvvResponseCode>\n<processorCode>A</processorCode>\n<processorMessage>APPROVED</processorMessage>\n<errorMessage/>\n<creditCardCountry>US</creditCardCountry>\n<creditCardScheme>Visa</creditCardScheme>\n</transaction-response>\n"
      read 628 bytes
      Conn close
    )
  end

  def successful_purchase_response
    %(
      <transaction-response>
        <authCode>555555</authCode>
        <orderID>123456789</orderID>
        <referenceNum>123456789</referenceNum>
        <transactionID>123456789</transactionID>
        <transactionTimestamp>123456789</transactionTimestamp>
        <responseCode>0</responseCode>
        <responseMessage>CAPTURED</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode>0</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
        <processorTransactionID>123456789</processorTransactionID>
        <processorReferenceNumber>123456789</processorReferenceNumber>
        <fraudScore>29</fraudScore>
      </transaction-response>
    )
  end

  def failed_purchase_response
    %(
      <transaction-response>
        <authCode/>
        <orderID>123456789</orderID>
        <referenceNum>123456789</referenceNum>
        <transactionID>123456789</transactionID>
        <transactionTimestamp>123456789</transactionTimestamp>
        <responseCode>1</responseCode>
        <responseMessage>DECLINED</responseMessage>
        <avsResponseCode>NNN</avsResponseCode>
        <cvvResponseCode>N</cvvResponseCode>
        <processorCode>D</processorCode>
        <processorMessage>DECLINED</processorMessage>
        <errorMessage/>
      </transaction-response>
    )
  end

  def successful_authorize_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode>123456</authCode>
        <orderID>C0A8013F:014455FCC857:91A0:01A7243E</orderID>
        <referenceNum>12345</referenceNum>
        <transactionID>663921</transactionID>
        <transactionTimestamp>1393012206</transactionTimestamp>
        <responseCode>0</responseCode>
        <responseMessage>AUTHORIZED</responseMessage>
        <avsResponseCode>YYY</avsResponseCode>
        <cvvResponseCode>M</cvvResponseCode>
        <processorCode>A</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
      </transaction-response>
    )
  end

  def failed_authorize_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID/>
        <referenceNum/>
        <transactionID/>
        <transactionTimestamp>1393012170003</transactionTimestamp>
        <responseCode>1024</responseCode>
        <responseMessage>INVALID REQUEST</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode/>
        <processorMessage/>
        <errorMessage>The transaction has an expired credit card.</errorMessage>
      </transaction-response>
    )
  end

  def successful_capture_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID>C0A8013F:014455FF974D:82CA:01C7717B</orderID>
        <referenceNum>12345</referenceNum>
        <transactionID>663924</transactionID>
        <transactionTimestamp>1393012391</transactionTimestamp>
        <responseCode>0</responseCode>
        <responseMessage>CAPTURED</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode>A</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
      </transaction-response>
    )
  end

  def failed_capture_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID/>
        <referenceNum/>
        <transactionID/>
        <transactionTimestamp>1393012277035</transactionTimestamp>
        <responseCode>1024</responseCode>
        <responseMessage>INVALID REQUEST</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode/>
        <processorMessage/>
        <errorMessage>Reference Number is a required field.</errorMessage>
      </transaction-response>
    )
  end

  def successful_void_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID/>
        <referenceNum/>
        <transactionID>1408584</transactionID>
        <transactionTimestamp/>
        <responseCode>0</responseCode>
        <responseMessage>VOIDED</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode>A</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
      </transaction-response>
    )
  end

  def failed_void_response
    %(
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <api-error>
        <errorCode>1</errorCode>
        <errorMsg><![CDATA[Unable to validate, original void transaction not found]]></errorMsg>
      </api-error>
    )
  end

  def successful_refund_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID>C0A8013F:015527599F53:FAF8:0155C41C</orderID>
        <referenceNum>12345</referenceNum>
        <transactionID>1408589</transactionID>
        <transactionTimestamp>1465244034</transactionTimestamp>
        <responseCode>0</responseCode>
        <responseMessage>CAPTURED</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode>A</processorCode>
        <processorMessage>APPROVED</processorMessage>
        <errorMessage/>
        <creditCardScheme>Visa</creditCardScheme>
      </transaction-response>
    )
  end

  def failed_refund_response
    %(
      <?xml version="1.0" encoding="UTF-8"?>
      <transaction-response>
        <authCode/>
        <orderID/>
        <referenceNum/>
        <transactionID/>
        <transactionTimestamp>1465244175808</transactionTimestamp>
        <responseCode>1024</responseCode>
        <responseMessage>INVALID REQUEST</responseMessage>
        <avsResponseCode/>
        <cvvResponseCode/>
        <processorCode/>
        <processorMessage/>
        <errorMessage>The Return amount is greater than the amount that can be returned.</errorMessage>
      </transaction-response>
    )
  end
end
