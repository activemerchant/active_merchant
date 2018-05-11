require 'test_helper'

class WorldNetTest < Test::Unit::TestCase
  def setup
    @gateway = WorldNetGateway.new(terminal_id: '6001', secret: 'SOMECREDENTIAL')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
    @refund_options = {
      operator: 'mr.nobody',
      reason: 'returned'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'GZG6IG6VXI', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'BF4CNN6WXP', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'BF4CNN6WXP', @options)
    assert_success response

    assert_equal 'BF4CNN6WXP', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'BF4CNN6WXP', @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'GIOH10II2J', @refund_options)
    assert_success response

    assert_equal 'GIOH10II2J', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'GIOH10II2J', @refund_options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('GIOH10II2J')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response).then.returns(failed_void_response)
    response = @gateway.verify(credit_card, @options)
    assert_success response
    assert_equal 'APPROVAL', response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.verify(credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    response = @gateway.store(credit_card, @options)
    assert_success response
  end

  def test_unsuccessful_store
    @gateway.expects(:ssl_post).returns(failed_store_response)
    response = @gateway.store(credit_card, @options)
    assert_failure response
  end

  def test_successful_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)
    response = @gateway.unstore('4111111111111111', @options)
    assert_success response
  end

  def test_unsuccessful_unstore
    @gateway.expects(:ssl_post).returns(failed_unstore_response)
    response = @gateway.unstore('4111111111111111', @options)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
opening connection to testpayments.worldnettps.com:443...
opened
starting SSL for testpayments.worldnettps.com:443...
SSL established
<- "POST /merchant/xmlpayment HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: testpayments.worldnettps.com\r\nContent-Length: 516\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<PAYMENT>\n  <ORDERID>144232907005</ORDERID>\n  <TERMINALID>6001</TERMINALID>\n  <AMOUNT>1.00</AMOUNT>\n  <DATETIME>15-09-2015:14:57:50:054</DATETIME>\n  <CARDNUMBER>3779810000000005</CARDNUMBER>\n  <CARDTYPE>VISA</CARDTYPE>\n  <CARDEXPIRY>0916</CARDEXPIRY>\n  <CARDHOLDERNAME>Longbob Longsen</CARDHOLDERNAME>\n  <HASH>e1d545745667ff6ab6c7bd9d961d3090</HASH>\n  <CURRENCY>EUR</CURRENCY>\n  <TERMINALTYPE>2</TERMINALTYPE>\n  <TRANSACTIONTYPE>7</TRANSACTIONTYPE>\n  <CVV>123</CVV>\n</PAYMENT>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 15 Sep 2015 14:57:50 GMT\r\n"
-> "Server: Apache\r\n"
-> "Content-Length: 352\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/xml;charset=UTF-8\r\n"
-> "\r\n"
reading 352 bytes...
-> ""
-> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n<PAYMENTRESPONSE><UNIQUEREF>C41TUQLEKZ</UNIQUEREF><RESPONSECODE>A</RESPONSECODE><RESPONSETEXT>APPROVAL</RESPONSETEXT><APPROVALCODE>475318</APPROVALCODE><DATETIME>2015-09-15T15:57:50</DATETIME><AVSRESPONSE>X</AVSRESPONSE><CVVRESPONSE>M</CVVRESPONSE><HASH>7cddcd17853c9d0736397dfadfb12a3e</HASH></PAYMENTRESPONSE>\n"
read 352 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to testpayments.worldnettps.com:443...
opened
starting SSL for testpayments.worldnettps.com:443...
SSL established
<- "POST /merchant/xmlpayment HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: testpayments.worldnettps.com\r\nContent-Length: 516\r\n\r\n"
<- "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<PAYMENT>\n  <ORDERID>144232907005</ORDERID>\n  <TERMINALID>6001</TERMINALID>\n  <AMOUNT>1.00</AMOUNT>\n  <DATETIME>15-09-2015:14:57:50:054</DATETIME>\n  <CARDNUMBER>377981...0005</CARDNUMBER>\n  <CARDTYPE>VISA</CARDTYPE>\n  <CARDEXPIRY>0916</CARDEXPIRY>\n  <CARDHOLDERNAME>Longbob Longsen</CARDHOLDERNAME>\n  <HASH>e1d545745667ff6ab6c7bd9d961d3090</HASH>\n  <CURRENCY>EUR</CURRENCY>\n  <TERMINALTYPE>2</TERMINALTYPE>\n  <TRANSACTIONTYPE>7</TRANSACTIONTYPE>\n  <CVV>...</CVV>\n</PAYMENT>\n"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Tue, 15 Sep 2015 14:57:50 GMT\r\n"
-> "Server: Apache\r\n"
-> "Content-Length: 352\r\n"
-> "Strict-Transport-Security: max-age=15768000\r\n"
-> "Connection: close\r\n"
-> "Content-Type: text/xml;charset=UTF-8\r\n"
-> "\r\n"
reading 352 bytes...
-> ""
-> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n<PAYMENTRESPONSE><UNIQUEREF>C41TUQLEKZ</UNIQUEREF><RESPONSECODE>A</RESPONSECODE><RESPONSETEXT>APPROVAL</RESPONSETEXT><APPROVALCODE>475318</APPROVALCODE><DATETIME>2015-09-15T15:57:50</DATETIME><AVSRESPONSE>X</AVSRESPONSE><CVVRESPONSE>M</CVVRESPONSE><HASH>7cddcd17853c9d0736397dfadfb12a3e</HASH></PAYMENTRESPONSE>\n"
read 352 bytes
Conn close
    )
  end

  def successful_purchase_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<PAYMENTRESPONSE><UNIQUEREF>GZG6IG6VXI</UNIQUEREF><RESPONSECODE>A</RESPONSECODE><RESPONSETEXT>APPROVAL</RESPONSETEXT><APPROVALCODE>475318</APPROVALCODE><DATETIME>2015-09-14T21:22:12</DATETIME><AVSRESPONSE>X</AVSRESPONSE><CVVRESPONSE>M</CVVRESPONSE><HASH>f8642d613c56628371a579443ce8d895</HASH></PAYMENTRESPONSE>)
  end

  def failed_purchase_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<PAYMENTRESPONSE><UNIQUEREF>JQU1810S4E</UNIQUEREF><RESPONSECODE>D</RESPONSECODE><RESPONSETEXT>DECLINED</RESPONSETEXT><APPROVALCODE></APPROVALCODE><DATETIME>2015-09-14T21:40:07</DATETIME><AVSRESPONSE></AVSRESPONSE><CVVRESPONSE></CVVRESPONSE><HASH>c0ba33a10a6388b12c8fad79a107f2b5</HASH></PAYMENTRESPONSE>)
  end

  def successful_authorize_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<PREAUTHRESPONSE><UNIQUEREF>BF4CNN6WXP</UNIQUEREF><RESPONSECODE>A</RESPONSECODE><RESPONSETEXT>APPROVAL</RESPONSETEXT><APPROVALCODE>450848</APPROVALCODE><DATETIME>2015-09-14T21:53:10</DATETIME><AVSRESPONSE></AVSRESPONSE><CVVRESPONSE></CVVRESPONSE><HASH>e80c52476af1dd969f3bf89ed02fe16f</HASH></PREAUTHRESPONSE>)
  end

  def failed_authorize_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<PREAUTHRESPONSE><UNIQUEREF>IP0PUDDXG5</UNIQUEREF><RESPONSECODE>D</RESPONSECODE><RESPONSETEXT>DECLINED</RESPONSETEXT><APPROVALCODE></APPROVALCODE><DATETIME>2015-09-15T14:21:37</DATETIME><AVSRESPONSE></AVSRESPONSE><CVVRESPONSE></CVVRESPONSE><HASH>05dfa85163ee8d8afa8711019f64acb3</HASH></PREAUTHRESPONSE>)
  end

  def successful_capture_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<PREAUTHCOMPLETIONRESPONSE><UNIQUEREF>BF4CNN6WXP</UNIQUEREF><RESPONSECODE>A</RESPONSECODE><RESPONSETEXT>APPROVAL</RESPONSETEXT><APPROVALCODE>450848</APPROVALCODE><DATETIME>2015-09-14T21:53:10</DATETIME><AVSRESPONSE></AVSRESPONSE><CVVRESPONSE></CVVRESPONSE><HASH>e80c52476af1dd969f3bf89ed02fe16f</HASH></PREAUTHCOMPLETIONRESPONSE>)
  end

  def failed_capture_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<ERROR><ERRORSTRING>cvc-minLength-valid: Value &apos;&apos; with length = &apos;0&apos; is not facet-valid with respect to minLength &apos;10&apos; for type &apos;UID&apos;.</ERRORSTRING></ERROR>)
  end

  def successful_refund_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<REFUNDRESPONSE><RESPONSECODE>A</RESPONSECODE><RESPONSETEXT>SUCCESS</RESPONSETEXT><UNIQUEREF>GIOH10II2J</UNIQUEREF><DATETIME>15-09-2015:14:44:17:999</DATETIME><HASH>aebd69e9db6e4b0db7ecbae79a2970a0</HASH></REFUNDRESPONSE>)
  end

  def failed_refund_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<ERROR><ERRORSTRING>cvc-minLength-valid: Value &apos;&apos; with length = &apos;0&apos; is not facet-valid with respect to minLength &apos;10&apos; for type &apos;UID&apos;.</ERRORSTRING></ERROR>)
  end

  def successful_void_response
  end

  def successful_store_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<SECURECARDREGISTRATIONRESPONSE><MERCHANTREF>146304412401</MERCHANTREF><CARDREFERENCE>2967530956419033</CARDREFERENCE><DATETIME>12-05-2016:10:08:46:269</DATETIME><HASH>b2e497d14014ad9f4770edbf7716435e</HASH></SECURECARDREGISTRATIONRESPONSE>)
  end

  def failed_store_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<ERROR><ERRORCODE>E11</ERRORCODE><ERRORSTRING>INVALID CARDEXPIRY</ERRORSTRING></ERROR>)
  end

  def successful_unstore_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<SECURECARDREMOVALRESPONSE><MERCHANTREF>146304412401</MERCHANTREF><DATETIME>12-05-2016:10:08:48:399</DATETIME><HASH>7f755e185be8066a535699755f709646</HASH></SECURECARDREMOVALRESPONSE>)
  end

  def failed_unstore_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<ERROR><ERRORCODE>E04</ERRORCODE><ERRORSTRING>INVALID REFERENCE DETAILS</ERRORSTRING></ERROR>)
  end

  def failed_void_response
    %q(<?xml version="1.0" encoding="UTF-8"?>
<ERROR><ERRORSTRING>cvc-elt.1: Cannot find the declaration of element &apos;VOID&apos;.</ERRORSTRING></ERROR>)
  end
end
