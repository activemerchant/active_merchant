require 'test_helper'

class QuickBooksTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = QuickbooksGateway.new(
      consumer_key: 'consumer_key',
      consumer_secret: 'consumer_secret',
      access_token: 'access_token',
      token_secret: 'token_secret',
      realm: 'realm_ID',
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @authorization = "ECZ7U0SO423E"
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "EF1IQ9GGXS2D", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal @authorization, response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @authorization)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @authorization)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @authorization)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @authorization)
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_not_nil response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.send(:scrub, pre_scrubbed), post_scrubbed
  end

  def test_scrub_with_small_json
    assert_equal @gateway.scrub(pre_scrubbed_small_json), post_scrubbed_small_json
  end

  private

  def pre_scrubbed_small_json
    "intuit.com\\r\\nContent-Length: 258\\r\\n\\r\\n\"\n<- \"{\\\"amount\\\":\\\"34.50\\\",\\\"currency\\\":\\\"USD\\\",\\\"card\\\":{\\\"number\\\":\\\"4111111111111111\\\",\\\"expMonth\\\":\\\"09\\\",\\\"expYear\\\":2016,\\\"cvc\\\":\\\"123\\\",\\\"name\\\":\\\"Bob Bobson\\\",\\\"address\\\":{\\\"streetAddress\\\":null,\\\"city\\\":\\\"Los Santos\\\",\\\"region\\\":\\\"CA\\\",\\\"country\\\":\\\"US\\\",\\\"postalCode\\\":\\\"90210\\\"}},\\\"capture\\\":\\\"true\\\"}\"\n-> \"HTTP/1.1 201 Created\\r\\n\"\n-> \"Date: Tue, 03 Mar 2015 20:00:35 GMT\\r\\n\"\n-> \"Content-Type: "
  end

  def post_scrubbed_small_json
    "intuit.com\\r\\nContent-Length: 258\\r\\n\\r\\n\"\n<- \"{\\\"amount\\\":\\\"34.50\\\",\\\"currency\\\":\\\"USD\\\",\\\"card\\\":{\\\"number\\\":\\\"[FILTERED]\\\",\\\"expMonth\\\":\\\"09\\\",\\\"expYear\\\":2016,\\\"cvc\\\":\\\"[FILTERED]\\\",\\\"name\\\":\\\"Bob Bobson\\\",\\\"address\\\":{\\\"streetAddress\\\":null,\\\"city\\\":\\\"Los Santos\\\",\\\"region\\\":\\\"CA\\\",\\\"country\\\":\\\"US\\\",\\\"postalCode\\\":\\\"90210\\\"}},\\\"capture\\\":\\\"true\\\"}\"\n-> \"HTTP/1.1 201 Created\\r\\n\"\n-> \"Date: Tue, 03 Mar 2015 20:00:35 GMT\\r\\n\"\n-> \"Content-Type: "
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "created": "2014-11-27T22:09:01Z",
      "status": "CAPTURED",
      "amount": "20.00",
      "currency": "USD",
      "card": {
        "number": "xxxxxxxxxxxx1111",
        "name": "alicks profit",
        "address": {
          "city": "xxxxxxxx",
          "region": "xx",
          "country": "xx",
          "streetAddress": "xxxxxxxxxxxxx",
          "postalCode": "xxxxx"
        },
        "expMonth": "01",
        "expYear": "2021"
      },
      "id": "EF1IQ9GGXS2D",
      "authCode": "664472",
      "capture": "true"
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "errors":[{
        "code": "PMT-4000",
        "type": "invalid_request",
        "message": "the request to process this transaction has been declined.",
        "detail": "Amount.",
        "infoLink": "https://developer.intuit.com/v2/docs?redirectID=PayErrors"
      }]
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "created": "2014-11-27T22:17:22Z",
      "status": "AUTHORIZED",
      "amount": "2000.00",
      "currency": "USD",
      "card": {
        "number": "xxxxxxxxxxxx4242",
        "name": "alicks profit",
        "address": {
          "city": "xxxxxxxx",
          "region": "xx",
          "country": "xx",
          "streetAddress": "xxxxxxxxxxxxx",
          "postalCode": "xxxxx"
        },
        "expMonth": "01",
        "expYear": "2021"
      },
      "capture": false,
      "id": "ECZ7U0SO423E",
      "authCode": "279714"
    }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    {
      "errors":[{
        "code": "PMT-5000",
        "type": "invalid_request",
        "message": "he request to process this transaction has been declined.",
        "detail": "Amount.",
        "infoLink": "https://developer.intuit.com/v2/docs?redirectID=PayErrors"
      }]
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "created": "2014-12-17T22:39:21Z",
      "status": "CAPTURED",
      "amount": "10.55",
      "currency": "USD",
      "card": {
        "number": "xxxxxxxxxxxx4444",
        "cvc": "xxx",
        "name": "emulate=0",
        "address": {
          "city": "xxxxxxxxx",
          "region": "xx",
          "country": "xx",
          "streetAddress": "xxxxxxxxxxxxx",
          "postalCode": "xxxxx"
        },
        "expMonth": "02",
        "expYear": "2020"
      },
      "id": "ELFWEU8LS00K",
      "authCode": "537265"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "errors":[{
        "code": "PMT-5000",
        "type": "invalid_request",
        "message": "he request to process this transaction has been declined.",
        "detail": "Amount.",
        "infoLink": "https://developer.intuit.com/v2/docs?redirectID=PayErrors"
      }]
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "created": "2014-09-23T01:49:12Z",
      "status": "ISSUED",
      "amount": "5.00",
      "description": "first refund",
      "id": "EMU891209421",
      "context": {
        "tax": "0.00",
        "recurring": false,
        "deviceInfo": {
          "id": "",
          "type": "",
          "longitude": "",
          "latitude": "",
          "phoneNumber": "",
          "macAddress": "",
          "ipAddress": ""
        }
      }
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "errors":[{
        "code": "PMT-5000",
        "type": "invalid_request",
        "message": "he request to process this transaction has been declined.",
        "detail": "Amount.",
        "infoLink": "https://developer.intuit.com/v2/docs?redirectID=PayErrors"
      }]
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "created": "2014-09-23T01:49:12Z",
      "status": "ISSUED",
      "amount": "5.00",
      "description": "first refund",
      "id": "EMU891209421",
      "context": {
        "tax": "0.00",
        "recurring": false,
        "deviceInfo": {
          "id": "",
          "type": "",
          "longitude": "",
          "latitude": "",
          "phoneNumber": "",
          "macAddress": "",
          "ipAddress": ""
        }
      }
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "errors":[{
        "code": "PMT-5000",
        "type": "invalid_request",
        "message": "he request to process this transaction has been declined.",
        "detail": "Amount.",
        "infoLink": "https://developer.intuit.com/v2/docs?redirectID=PayErrors"
      }]
    }
    RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to sandbox.api.intuit.com:443...
      opened
      starting SSL for sandbox.api.intuit.com:443...
      SSL established
      <- "POST /quickbooks/v4/payments/charges HTTP/1.1\r\nContent-Type: application/json\r\nRequest-Id: f8b0ce95a6e5fe249b52b23112443221\r\nAuthorization: OAuth realm=\"1292767175\", oauth_consumer_key=\"qyprdSPSxCNr5XLx0Px6g4h43zRcl6\", oauth_nonce=\"aZgGttabmZeU8ST6OjhUEMYWg7HLoyxZirBLJZVeA\", oauth_signature=\"iltPw94HHT7QCuEPTJ4RnfwY%2FzU%3D\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"1418937070\", oauth_token=\"qyprdDJJpRXRsoLDQMqaDk68c4ovXjMMVL2Wzs9RI0VNb52B\", oauth_version=\"1.0\"\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.api.intuit.com\r\nContent-Length: 265\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"4000100011112224\",\"expMonth\":\"09\",\"expYear\":2015,\"cvc\":\"123\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"1234 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"capture\":\"true\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 18 Dec 2014 21:11:11 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: DELETE, POST, GET, OPTIONS\r\n"
      -> "Access-Control-Allow-Headers: realmid, realm_id, intuit_realm_id, Origin, X-Requested-With, Content-Type, Accept, intuit_tid, intuittid, Authorization, company_id, company-id, intuit_company_id, request_id, request-id\r\n"
      -> "intuit_tid: gw-f4c34b4f-54ec-4350-b44f-c46d4b2d003d\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      -> "168\r\n"
      reading 360 bytes...
      -> "{\"created\":\"2014-12-18T21:11:12Z\",\"status\":\"CAPTURED\",\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"xxxxxxxxxxxx2224\",\"cvc\":\"xxx\",\"name\":\"Longbob Longsen\",\"address\":{\"city\":\"xxxxxx\",\"region\":\"xx\",\"country\":\"xx\",\"streetAddress\":\"xxxxxxxxxxxxxx\",\"postalCode\":\"xxxxx\"},\"expMonth\":\"09\",\"expYear\":\"2015\"},\"capture\":true,\"id\":\"EE228DLEWTNE\",\"authCode\":\"586868\"}"
      read 360 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to sandbox.api.intuit.com:443...
      opened
      starting SSL for sandbox.api.intuit.com:443...
      SSL established
      <- "POST /quickbooks/v4/payments/charges HTTP/1.1\r\nContent-Type: application/json\r\nRequest-Id: f8b0ce95a6e5fe249b52b23112443221\r\nAuthorization: OAuth realm=\"[FILTERED]\", oauth_consumer_key=\"[FILTERED]\", oauth_nonce=\"[FILTERED]\", oauth_signature=\"[FILTERED]\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"1418937070\", oauth_token=\"[FILTERED]\", oauth_version=\"1.0\"\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.api.intuit.com\r\nContent-Length: 265\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"[FILTERED]\",\"expMonth\":\"09\",\"expYear\":2015,\"cvc\":\"[FILTERED]\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"1234 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"capture\":\"true\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 18 Dec 2014 21:11:11 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: DELETE, POST, GET, OPTIONS\r\n"
      -> "Access-Control-Allow-Headers: realmid, realm_id, intuit_realm_id, Origin, X-Requested-With, Content-Type, Accept, intuit_tid, intuittid, Authorization, company_id, company-id, intuit_company_id, request_id, request-id\r\n"
      -> "intuit_tid: gw-f4c34b4f-54ec-4350-b44f-c46d4b2d003d\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "\r\n"
      -> "168\r\n"
      reading 360 bytes...
      -> "{\"created\":\"2014-12-18T21:11:12Z\",\"status\":\"CAPTURED\",\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"xxxxxxxxxxxx2224\",\"cvc\":\"xxx\",\"name\":\"Longbob Longsen\",\"address\":{\"city\":\"xxxxxx\",\"region\":\"xx\",\"country\":\"xx\",\"streetAddress\":\"xxxxxxxxxxxxxx\",\"postalCode\":\"xxxxx\"},\"expMonth\":\"09\",\"expYear\":\"2015\"},\"capture\":true,\"id\":\"EE228DLEWTNE\",\"authCode\":\"586868\"}"
      read 360 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end
end
