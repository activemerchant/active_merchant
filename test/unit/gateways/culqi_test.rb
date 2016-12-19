require 'test_helper'

class CulqiTest < Test::Unit::TestCase
  def setup
    @gateway = CulqiGateway.new(merchant_id: 'merchant', terminal_id: 'terminal', secret_key: 'password')

    @amount = 1000
    @credit_card = credit_card("4111111111111111")

    @options = {
      order_id: generate_unique_id,
      billing_address: address
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Approved}, response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Failed}, response.message
  end

  def test_successful_authorize_and_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Approved}, response.message
    assert_match %r(^\d+$), response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_match %r{Transaction has been successfully captured}, capture.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Failed}, response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, "0")
    assert_failure response
    assert_match %r{Transaction not found}, response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth = @gateway.authorize(@amount, @credit_card, @options)

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    capture = @gateway.capture(@amount, auth.authorization)

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    refund = @gateway.refund(@amount, capture.authorization)
    assert_success refund
    assert_match %r{reversed}, refund.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, "0")
    assert_failure response
    assert_match %r{Transaction not found}, response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    @gateway.expects(:ssl_post).returns(successful_void_response)

    void = @gateway.void(response.authorization, @options)
    assert_success void
    assert_match %r{cancelled}, void.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void("0", @options)
    assert_failure response
    assert_match %r{Transaction not found}, response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_void_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Approved}, response.message
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Approved}, response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_match %r{Failed}, response.message
  end

  def test_successful_store_and_purchase
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options.merge(partner_id: fixtures(:culqi)[:partner_id]))
    assert_success response
    assert_match %r{Card tokenized successfully}, response.message

    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    purchase = @gateway.purchase(@amount, response.authorization, @options.merge(cvv: @credit_card.verification_value))
    assert_success purchase
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options.merge(partner_id: fixtures(:culqi)[:partner_id]))
    assert_failure response
    assert_match %r{Card already tokenized for same merchant}, response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
        opening connection to staging.paymentz.com:443...
        opened
        starting SSL for staging.paymentz.com:443...
        SSL established
        <- "POST /transaction/SingleCallGenericServlet HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded;charset=UTF-8\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: staging.paymentz.com\r\nContent-Length: 442\r\n\r\n"
        <- "toid=10838&totype=Culqi&terminalid=470&amount=10.00&description=f595d9cc63612484a9314f1141e9de75&redirecturl=http%3A%2F%2Fwww.example.com&language=ENG&cardnumber=4000100011112224&cvv=123&expiry_month=09&expiry_year=2017&firstname=Longbob&lastname=Longsen&emailaddr=unspecified%40example.com&street=456+My+Street+Apt+1&city=Ottawa&state=ON&countrycode=CA&zip=K1C2N6&telno=%28555%29555-5555&telnocc=051&checksum=741d5843d64b750ccd749eb8b17be33c"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Date: Tue, 15 Nov 2016 17:43:01 GMT\r\n"
        -> "Server: staging\r\n"
        -> "X-Frame-Options: SAMEORIGIN\r\n"
        -> "Cache-Control: no-store, no-cache, must-revalidate\r\n"
        -> "Pragma: no-cache\r\n"
        -> "Expires: Wed, 31 Dec 1969 23:59:59 GMT\r\n"
        -> "Content-Type: text/html;charset=UTF-8\r\n"
        -> "Content-Length: 510\r\n"
        -> "Set-Cookie: JSESSIONID=98659561D241CA110A65798B34A3150E; Path=/transaction/; HttpOnly;Secure;\r\n"
        -> "Connection: close\r\n"
        -> "\r\n"
        reading 510 bytes...
        -> ""
        -> "{\"fraudscore\":\"\",\"statusdescription\":\"Approved---Your Transaction is successful\",\"billingdiscriptor\":\"Test_Transaction\",\"rulestriggered\":\"\",\"orderid\":\"f595d9cc63612484a9314f1141e9de75\",\"authamount\":\"10.00\",\"resultdescription\":\"\",\"cardissuer\":\"\",\"eci\":\"\",\"validationdescription\":\"\",\"banktransid\":\"\",\"cvvresult\":\"\",\"ecidescription\":\"\",\"token\":\"\",\"authcode\":\"\",\"cardsource\":\"\",\"cardcountrycode\":\"\",\"banktransdate\":\"\",\"checksum\":\"7d65440154044eaa7185d5492c2edd3f\",\"resultcode\":\"\",\"trackingid\":\"37859\",\"status\":\"Y\"}"
        read 510 bytes
        Conn close
    )
  end

  def post_scrubbed
    %q(
        opening connection to staging.paymentz.com:443...
        opened
        starting SSL for staging.paymentz.com:443...
        SSL established
        <- "POST /transaction/SingleCallGenericServlet HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded;charset=UTF-8\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: staging.paymentz.com\r\nContent-Length: 442\r\n\r\n"
        <- "toid=10838&totype=Culqi&terminalid=470&amount=10.00&description=f595d9cc63612484a9314f1141e9de75&redirecturl=http%3A%2F%2Fwww.example.com&language=ENG&cardnumber=[FILTERED]&cvv=[FILTERED]&expiry_month=09&expiry_year=2017&firstname=Longbob&lastname=Longsen&emailaddr=unspecified%40example.com&street=456+My+Street+Apt+1&city=Ottawa&state=ON&countrycode=CA&zip=K1C2N6&telno=%28555%29555-5555&telnocc=051&checksum=741d5843d64b750ccd749eb8b17be33c"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Date: Tue, 15 Nov 2016 17:43:01 GMT\r\n"
        -> "Server: staging\r\n"
        -> "X-Frame-Options: SAMEORIGIN\r\n"
        -> "Cache-Control: no-store, no-cache, must-revalidate\r\n"
        -> "Pragma: no-cache\r\n"
        -> "Expires: Wed, 31 Dec 1969 23:59:59 GMT\r\n"
        -> "Content-Type: text/html;charset=UTF-8\r\n"
        -> "Content-Length: 510\r\n"
        -> "Set-Cookie: JSESSIONID=98659561D241CA110A65798B34A3150E; Path=/transaction/; HttpOnly;Secure;\r\n"
        -> "Connection: close\r\n"
        -> "\r\n"
        reading 510 bytes...
        -> ""
        -> "{\"fraudscore\":\"\",\"statusdescription\":\"Approved---Your Transaction is successful\",\"billingdiscriptor\":\"Test_Transaction\",\"rulestriggered\":\"\",\"orderid\":\"f595d9cc63612484a9314f1141e9de75\",\"authamount\":\"10.00\",\"resultdescription\":\"\",\"cardissuer\":\"\",\"eci\":\"\",\"validationdescription\":\"\",\"banktransid\":\"\",\"cvvresult\":\"\",\"ecidescription\":\"\",\"token\":\"\",\"authcode\":\"\",\"cardsource\":\"\",\"cardcountrycode\":\"\",\"banktransdate\":\"\",\"checksum\":\"7d65440154044eaa7185d5492c2edd3f\",\"resultcode\":\"\",\"trackingid\":\"37859\",\"status\":\"Y\"}"
        read 510 bytes
        Conn close
    )
  end

  def successful_purchase_response
    %(
      {
        "fraudscore": "",
        "statusdescription": "Approved---Your Transaction is successful",
        "billingdiscriptor": "Test_Transaction",
        "rulestriggered": "",
        "orderid": "3ee62ef1b32401e9e9ae1db3c3bbdd2c",
        "authamount": "10.00",
        "resultdescription": "",
        "cardissuer": "",
        "eci": "",
        "validationdescription": "",
        "banktransid": "",
        "cvvresult": "",
        "ecidescription": "",
        "token": "ccIJiW3R6eiiWIQSDsCOPuA47MZEfWNS",
        "authcode": "",
        "cardsource": "",
        "cardcountrycode": "",
        "banktransdate": "",
        "checksum": "3fc8f97d8918cf533006dc89c71e7bd2",
        "resultcode": "",
        "trackingid": "39539",
        "status": "Y"
      }
    )
  end

  def failed_purchase_response
    %(
      {
        "fraudscore": "",
        "statusdescription": "Failed--(Card expired )",
        "billingdiscriptor": " ",
        "rulestriggered": "",
        "orderid": "3a8dab9a1082008519c96cb4170e170e",
        "authamount": "10.00",
        "resultdescription": "",
        "cardissuer": "",
        "eci": "",
        "validationdescription": "",
        "banktransid": "",
        "cvvresult": "",
        "ecidescription": "",
        "token": "",
        "authcode": "",
        "cardsource": "",
        "cardcountrycode": "",
        "banktransdate": "",
        "checksum": "880492e540f4128680f614b9488fe702",
        "resultcode": "",
        "trackingid": "39540",
        "status": "N"
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "fraudscore": "",
        "statusdescription": "Approved---Your Transaction is successful",
        "billingdiscriptor": "Test_Transaction",
        "rulestriggered": "",
        "orderid": "f2868a3fcd2f656ff2e57758df218d4e",
        "authamount": "10.00",
        "resultdescription": "",
        "cardissuer": "",
        "eci": "",
        "validationdescription": "",
        "banktransid": "",
        "cvvresult": "",
        "ecidescription": "",
        "token": "ccIJiW3R6eiiWIQSDsCOPuA47MZEfWNS",
        "authcode": "",
        "cardsource": "",
        "cardcountrycode": "",
        "banktransdate": "",
        "checksum": "2ac8857b8821b1b07f268ec60d6ddb4d",
        "resultcode": "",
        "trackingid": "39541",
        "status": "Y"
      }
    )
  end

  def failed_authorize_response
    %(
      {
        "fraudscore": "",
        "statusdescription": "Failed--(Card expired )",
        "billingdiscriptor": " ",
        "rulestriggered": "",
        "orderid": "cffc3df7cd594844d8f3659336fc7ed9",
        "authamount": "10.00",
        "resultdescription": "",
        "cardissuer": "",
        "eci": "",
        "validationdescription": "",
        "banktransid": "",
        "cvvresult": "",
        "ecidescription": "",
        "token": "",
        "authcode": "",
        "cardsource": "",
        "cardcountrycode": "",
        "banktransdate": "",
        "checksum": "2c62a41893a8a6aed54ba19994c26455",
        "resultcode": "",
        "trackingid": "39542",
        "status": "N"
      }
    )
  end

  def successful_capture_response
    %(
      {
        "amount": "10.00",
        "statusdescription": "Transaction has been successfully captured",
        "resultdescription": "",
        "lote": "",
        "newchecksum": "e64824e56e6fbf6cfc569241cb613e03",
        "bankstatus": "",
        "resultcode": "",
        "trackingid": "39541",
        "status": "Y"
      }
    )
  end

  def failed_capture_response
    %(
      {
        "amount": "10.00",
        "statusdescription": "Transaction not found",
        "resultdescription": "",
        "lote": "",
        "newchecksum": "fa03a809a37f6f3453b2bba25776b280",
        "bankstatus": "",
        "resultcode": "",
        "trackingid": "0",
        "status": "N"
      }
    )
  end

  def successful_refund_response
    %(
      {
        "statusDescription": "Transaction has been successfully reversed",
        "checksum": "6c9a9383627f4527e2476939df445af6",
        "refundamount": "10.00",
        "trackingid": "39543",
        "status": "Y"
      }
    )
  end

  def failed_refund_response
    %(
      {
        "statusDescription": "Transaction not found",
        "checksum": "fa03a809a37f6f3453b2bba25776b280",
        "refundamount": "10.00",
        "trackingid": "0",
        "status": "N"
      }
    )
  end

  def successful_void_response
    %(
      {
        "statusdescription": "Transaction has been successfully cancelled",
        "orderid": "31adcdb52b8e20197e98b2b0ed91725a",
        "resultdescription": "",
        "newchecksum": "e68065b4cb141382aca9ff56fa057f95",
        "bankstatus": "",
        "resultcode": "",
        "status": "Y",
        "trackingid": "39544"
      }
    )
  end

  def failed_void_response
    %(
      {
        "statusdescription": "10080_Transaction not found from provided tracking ID.",
        "orderid": "8501c8205a1b133c41270771a8404334",
        "resultdescription": "",
        "newchecksum": "f599cfcc42950ae4be90414560a723de",
        "bankstatus": "",
        "resultcode": "",
        "status": "N",
        "trackingid": "0"
      }
    )
  end

  def successful_store_response
    %(
      {
        "statusdescription": "Card tokenized successfully",
        "checksum": "232df0e95a26a0efd2321cedbd1b6113",
        "days": "90",
        "status": "Y",
        "token": "3hYBliyBBTL23joK1m1uul7GDT0Mph75"
      }
    )
  end

  def failed_store_response
    %(
      {
        "statusdescription": "Card already tokenized for same merchant",
        "checksum": "d8ae2ac457a0df3d1970dda78a260d5a",
        "days": "",
        "status": "N",
        "token": ""
      }
    )
  end
end
