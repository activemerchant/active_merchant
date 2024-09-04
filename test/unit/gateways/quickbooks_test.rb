require 'test_helper'

class QuickBooksTest < Test::Unit::TestCase
  include CommStub

  def setup
    @oauth_1_gateway = QuickbooksGateway.new(
      consumer_key: 'consumer_key',
      consumer_secret: 'consumer_secret',
      access_token: 'access_token',
      token_secret: 'token_secret',
      realm: 'realm_ID'
    )

    @oauth_2_gateway = QuickbooksGateway.new(
      client_id: 'client_id',
      client_secret: 'client_secret',
      access_token: 'access_token',
      refresh_token: 'refresh_token'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @authorization = 'ECZ7U0SO423E|d40f8a8007ba1af90a656d7f6371f641'
    @authorization_no_request_id = 'ECZ7U0SO423E'
  end

  def test_successful_purchase
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(successful_purchase_response)
      response = gateway.purchase(@amount, @credit_card, @options)
      assert_success response

      assert_match(/EF1IQ9GGXS2D|/, response.authorization)
      assert response.test?
    end
  end

  def test_failed_purchase
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(failed_purchase_response)

      response = gateway.purchase(@amount, @credit_card, @options)
      assert_failure response
      assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
    end
  end

  def test_successful_authorize
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(successful_authorize_response)
      response = gateway.authorize(@amount, @credit_card, @options)
      assert_success response

      assert_match(/ECZ7U0SO423E|/, response.authorization)
      assert response.test?
    end
  end

  def test_failed_authorize
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(failed_authorize_response)

      response = gateway.authorize(@amount, @credit_card, @options)
      assert_failure response
      assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    end
  end

  def test_successful_capture
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(successful_capture_response)

      response = gateway.capture(@amount, @authorization)
      assert_success response
    end
  end

  def test_successful_capture_when_authorization_does_not_include_request_id
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(successful_capture_response)

      response = gateway.capture(@amount, @authorization_no_request_id)
      assert_success response
    end
  end

  def test_failed_capture
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(failed_capture_response)

      response = gateway.capture(@amount, @authorization)
      assert_failure response
    end
  end

  def test_successful_refund
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(successful_refund_response)

      response = gateway.refund(@amount, @authorization)
      assert_success response
    end
  end

  def test_successful_refund_when_authorization_does_not_include_request_id
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(successful_refund_response)

      response = gateway.refund(@amount, @authorization_no_request_id)
      assert_success response
    end
  end

  def test_failed_refund
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      gateway.expects(:ssl_post).returns(failed_refund_response)

      response = gateway.refund(@amount, @authorization)
      assert_failure response
    end
  end

  def test_successful_verify
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      response = stub_comms(gateway) do
        gateway.verify(@credit_card)
      end.respond_with(successful_authorize_response)

      assert_success response
    end
  end

  def test_failed_verify
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      response = stub_comms(gateway) do
        gateway.verify(@credit_card, @options)
      end.respond_with(failed_authorize_response)

      assert_failure response
      assert_not_nil response.message
    end
  end

  def test_successful_void
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      response = stub_comms(gateway) do
        gateway.void(@authorization)
      end.respond_with(successful_void_response)

      assert_success response
    end
  end

  def test_failed_void
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      response = stub_comms(gateway) do
        gateway.void(@authorization)
      end.respond_with(failed_void_response)

      assert_failure response
    end
  end

  def test_scrub_oauth_1
    assert @oauth_1_gateway.supports_scrubbing?
    assert_equal @oauth_1_gateway.send(:scrub, pre_scrubbed), post_scrubbed
  end

  def test_scrub_oauth_2
    assert @oauth_2_gateway.supports_scrubbing?
    assert_equal @oauth_2_gateway.send(:scrub, pre_scrubbed_oauth_2), post_scrubbed_oauth_2
  end

  def test_scrub_with_small_json
    assert_equal @oauth_1_gateway.scrub(pre_scrubbed_small_json), post_scrubbed_small_json
  end

  def test_default_context
    [@oauth_1_gateway, @oauth_2_gateway].each do |gateway|
      stub_comms(gateway) do
        gateway.purchase(@amount, @credit_card, @options)
      end.check_request do |_endpoint, data, _headers|
        json = JSON.parse(data)
        refute json.fetch('context').fetch('mobile')
        assert json.fetch('context').fetch('isEcommerce')
      end.respond_with(successful_purchase_response)
    end
  end

  def test_refresh_does_not_occur_for_oauth_1
    @oauth_1_gateway.expects(:ssl_post).with(
      anything,
      Not(regexp_matches(%r{grant_type=refresh_token})),
      anything
    ).returns(successful_purchase_response)

    response = @oauth_1_gateway.purchase(@amount, @credit_card, @options.merge(allow_refresh: true))

    assert_success response

    assert_match(/EF1IQ9GGXS2D|/, response.authorization)
    assert response.test?
  end

  def test_refresh_does_not_occur_when_token_valid_for_oauth_2
    @oauth_2_gateway.expects(:ssl_post).with(
      anything,
      Not(regexp_matches(%r{grant_type=refresh_token})),
      has_entries('Authorization' => 'Bearer access_token')
    ).returns(successful_purchase_response)

    response = @oauth_2_gateway.purchase(@amount, @credit_card, @options.merge(allow_refresh: true))
    assert_success response
  end

  def test_refresh_does_occur_when_token_invalid_for_oauth_2
    @oauth_2_gateway.expects(:ssl_post).with(
      anything,
      anything,
      has_entries('Authorization' => 'Bearer access_token')
    ).returns(authentication_failed_oauth_2_response)

    @oauth_2_gateway.expects(:ssl_post).with(
      anything,
      all_of(regexp_matches(%r{grant_type=refresh_token})),
      anything
    ).returns(successful_refresh_token_response)

    @oauth_2_gateway.expects(:ssl_post).with(
      anything,
      anything,
      has_entries('Authorization' => 'Bearer new_access_token')
    ).returns(successful_purchase_response)

    response = @oauth_2_gateway.purchase(@amount, @credit_card, @options.merge(allow_refresh: true))
    assert_success response

    assert_match(/EF1IQ9GGXS2D|/, response.authorization)
    assert response.test?
  end

  def test_authorization_failed_code_results_in_failure
    @oauth_2_gateway.expects(:ssl_post).returns(authorization_failed_oauth_2_response)

    response = @oauth_2_gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'AuthorizationFailed', response.error_code
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

  def authentication_failed_oauth_2_response
    <<-RESPONSE
      {
         "code": "AuthenticationFailed",
         "type": "INPUT",
         "message": null,
         "detail": null,
         "moreInfo": null
      }
    RESPONSE
  end

  def authorization_failed_oauth_2_response
    <<-RESPONSE
      {
         "code": "AuthorizationFailed",
         "type": "INPUT",
         "message": null,
         "detail": null,
         "moreInfo": null
      }
    RESPONSE
  end

  def successful_refresh_token_response
    <<-RESPONSE
      {
        "x_refresh_token_expires_in": 8719040,
        "refresh_token": "refresh_token",
        "access_token": "new_access_token",
        "token_type": "bearer",
        "expires_in": 3600
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
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\\\":\\\"4000100011112224\",\"expMonth\":\"09\",\"expYear\":2015,\"cvc\\\":\\\"123\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"1234 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"capture\":\"true\"}"
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
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\\\":\\\"[FILTERED]\",\"expMonth\":\"09\",\"expYear\":2015,\"cvc\\\":\\\"[FILTERED]\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"1234 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"capture\":\"true\"}"
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

  def pre_scrubbed_oauth_2
    %q(
      opening connection to sandbox.api.intuit.com:443...
      opened
      starting SSL for sandbox.api.intuit.com:443...
      SSL established
      <- "POST /quickbooks/v4/payments/charges HTTP/1.1\r\nContent-Type: application/json\r\nRequest-Id: 3b098cc41f53562ec0f36a0fc7071ff8\r\nAccept: application/json\r\nAuthorization: Bearer eyabcd9ewjie0w9fj9jkewjaiojfiew0..rEVIND9few90zsg.CyFO4k9gR-t5yJsc0lxGrPPLGeO-JRa_5MZ_vG_H5AMlObrPpfhBRK51jUukhh0QOUjgkGm2jJb8c_haieKnkb3nY_W7giZyIG6d5g5XPqRZLhDnMCVVFHZyLIbBT_TDvZWROeOGY10xrDnUY5O05LYnOZc8gq7k_VTHHDrrmyeon3EmerAGjDUhnpp1DJRvR7SLUWgZQOuR997OuaP31_ZesKACzdVSw5QBJAhBeRqGl8LaNjjveQMo1c20CjWr_-c0EWbp0frMAA_UYaxtuzgRRs_opnMr4_PD7axQQevAzftSR1cQfUDAu_uybV5lyiUTfX80B3NBlLihWLiqCD9yWiYmup4TpNbapTL4x9CQz_WobicwWbhIJ7P1IrnxeJh2pW3ijjrBhbgLCCZ-6tcNUsD697ywn3YknT-iTSH-BIpGE_43bEOHyUtwZcIZIeb-6KtZIjQ_fjHfkRz66IrpP0V-XZ7_N5hJ7UIuQ34gOiuxdFJtbiMSUW1GnanJ9aRH8Fbzk_UzrWyuSs.XnsOxzQ\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: sandbox.api.intuit.com\r\nContent-Length: 310\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"4000100011112224\",\"expMonth\":\"09\",\"expYear\":2020,\"cvc\":\"123\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"456 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"context\":{\"mobile\":false,\"isEcommerce\":true},\"capture\":\"true\"}"
      -> "HTTP/1.1 401 Unauthorized\r\n"
      -> "Date: Thu, 17 Oct 2019 15:40:43 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 91\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "intuit_tid: adca0516-0af2-48cd-a704-095529fe615c\r\n"
      -> "WWW-Authenticate: Bearer realm=\"Intuit\", error=\"invalid_token\"\r\n"
      -> "\r\n"
      reading 91 bytes...
      -> "{\"code\":\"AuthenticationFailed\",\"type\":\"INPUT\",\"message\":null,\"detail\":null,\"moreInfo\":null}"
      read 91 bytes
      Conn close
      opening connection to oauth.platform.intuit.com:443...
      opened
      starting SSL for oauth.platform.intuit.com:443...
      SSL established
      <- "POST /oauth2/v1/tokens/bearer HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nAuthorization: Basic QUI3QWFkWGZYRWZyRE1WN0k2a3RFYXoyT2hCeHdhVkdtZUU5N3pmeGdjSllPUU40Qmo6ZEVJcms2bHozclVvQ05wRXFSbFV6bFd6STBYRUtyeDBYcDdoYVd3RQ==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: oauth.platform.intuit.com\r\nContent-Length: 89\r\n\r\n"
      <- "grant_type=refresh_token&refresh_token=DE123456780s7AvBrjWjfiowji9IIKDU4zE237CmbGO"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 17 Oct 2019 15:40:43 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 1007\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "Strict-Transport-Security: max-age=15552000\r\n"
      -> "intuit_tid: c9aff174-410e-4683-8a35-2591c659550f\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "\r\n"
      reading 1007 bytes...
      -> "{\"x_refresh_token_expires_in\":8719040,\"refresh_token\":\"DE987654s7AvBrjWOCJYWsifjewaifjeiowja4zE237CmbGO\",\"access_token\":\"abcifejwiajJJJIDJFIEJQ0JDLUhTMjU2IiwiYWxnIjoiZGlyIn0..DIoIqgR5MP51jw.SK_1VawNWV1SC9ZSRu278imQXb-Fsn4K6gJK_IuEcG2p5xf9bj5fO6p8M8cN2HOw8D9TNuqR3u4POypw-QR4xfjiewjaifeDzc_L1D9cR_Zypcss0CWlk3Wl5Sm-Yel6Ej6DZPdMRYDVzFQIy-ugvlcbBMs_TBhPWuidiL7Gdy61iMW-CUG80iy0VN8TrOTTxI7oRlrsKeVF_htYbwfafeYxUnMIMnjz8BxsWHCj2Dj3Osx1d1RScHPlrzQhO8t9s0MpGbpO0Ygiu5H3-E5KC5ihnDtgTFeyyHFx8hPiG_ScbdnYgXQPqJiJIJ47Us9Jv0kXA1YxQr35-vL2IGHa6haofByqLJjXIKlYi-suu1Xl6wlCCZufXvELBcfhdkG4iCKGO3KXOozUkZOav9IqPM7qjGskTzbmR4zMzCmf0ypQbmk-4NXQT3N1Z_mxTX4ebCfjF7h0LjX3sgFcwYtNKS_iLsygU8mPZScCthBH67bO2ce35ZjHr2kHYKKxAYS-wXmiMpFM7NvEkVjoWJarrMF-Q4DB7eLKezmEKuRMDr6Q6_gDEbeyHqqCauEczBriq61LnWlDuqJtySL-amSrADFU7SU8fmD4DhgxU.f0o4123vdcxH_zvzfaewa7Q\",\"token_type\":\"bearer\",\"expires_in\":3600}"
      read 1007 bytes
      Conn close
      opening connection to sandbox.api.intuit.com:443...
      opened
      starting SSL for sandbox.api.intuit.com:443...
      SSL established
      <- "POST /quickbooks/v4/payments/charges HTTP/1.1\r\nContent-Type: application/json\r\nRequest-Id: da14d01c3608a0a036c4e7298cb5d56a\r\nAccept: application/json\r\nAuthorization: Bearer abcifejwiajJJJIDJFIEJQ0JDLUhTMjU2IiwiYWxnIjoiZGlyIn0..DIoIqgR5MP51jw.SK_1VawNWV1SC9ZSRu278imQXb-Fsn4K6gJK_IuEcG2p5xf9bj5fO6p8M8cN2HOw8D9TNuqR3u4POypw-QR4xfjiewjaifeDzc_L1D9cR_Zypcss0CWlk3Wl5Sm-Yel6Ej6DZPdMRYDVzFQIy-ugvlcbBMs_TBhPWuidiL7Gdy61iMW-CUG80iy0VN8TrOTTxI7oRlrsKeVF_htYbwfafeYxUnMIMnjz8BxsWHCj2Dj3Osx1d1RScHPlrzQhO8t9s0MpGbpO0Ygiu5H3-E5KC5ihnDtgTFeyyHFx8hPiG_ScbdnYgXQPqJiJIJ47Us9Jv0kXA1YxQr35-vL2IGHa6haofByqLJjXIKlYi-suu1Xl6wlCCZufXvELBcfhdkG4iCKGO3KXOozUkZOav9IqPM7qjGskTzbmR4zMzCmf0ypQbmk-4NXQT3N1Z_mxTX4ebCfjF7h0LjX3sgFcwYtNKS_iLsygU8mPZScCthBH67bO2ce35ZjHr2kHYKKxAYS-wXmiMpFM7NvEkVjoWJarrMF-Q4DB7eLKezmEKuRMDr6Q6_gDEbeyHqqCauEczBriq61LnWlDuqJtySL-amSrADFU7SU8fmD4DhgxU.f0o4123vdcxH_zvzfaewa7Q\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: sandbox.api.intuit.com\r\nContent-Length: 310\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"4000100011112224\",\"expMonth\":\"09\",\"expYear\":2020,\"cvc\":\"123\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"456 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"context\":{\"mobile\":false,\"isEcommerce\":true},\"capture\":\"true\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 17 Oct 2019 15:40:44 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "Strict-Transport-Security: max-age=15552000\r\n"
      -> "intuit_tid: 09ce7b7f-e19a-4567-8d7f-cf6ce81a9c75\r\n"
      -> "\r\n"
      -> "213\r\n"
      reading 531 bytes...
      -> "{\"created\":\"2019-10-17T15:40:44Z\",\"status\":\"CAPTURED\",\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"xxxxxxxxxxxx2224\",\"name\":\"Longbob Longsen\",\"address\":{\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"streetAddress\":\"456 My Street\",\"postalCode\":\"90210\"},\"cardType\":\"Visa\",\"expMonth\":\"09\",\"expYear\":\"2020\",\"cvc\":\"xxx\"},\"capture\":true,\"avsStreet\":\"Pass\",\"avsZip\":\"Pass\",\"cardSecurityCodeMatch\":\"NotAvailable\",\"id\":\"ES2Q849Y8KQ9\",\"context\":{\"mobile\":false,\"deviceInfo\":{},\"recurring\":false,\"isEcommerce\":true},\"authCode\":\"574943\"}"
      read 531 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def post_scrubbed_oauth_2
    %q(
      opening connection to sandbox.api.intuit.com:443...
      opened
      starting SSL for sandbox.api.intuit.com:443...
      SSL established
      <- "POST /quickbooks/v4/payments/charges HTTP/1.1\r\nContent-Type: application/json\r\nRequest-Id: 3b098cc41f53562ec0f36a0fc7071ff8\r\nAccept: application/json\r\nAuthorization: Bearer [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: sandbox.api.intuit.com\r\nContent-Length: 310\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"[FILTERED]\",\"expMonth\":\"09\",\"expYear\":2020,\"cvc\":\"[FILTERED]\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"456 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"context\":{\"mobile\":false,\"isEcommerce\":true},\"capture\":\"true\"}"
      -> "HTTP/1.1 401 Unauthorized\r\n"
      -> "Date: Thu, 17 Oct 2019 15:40:43 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 91\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "intuit_tid: adca0516-0af2-48cd-a704-095529fe615c\r\n"
      -> "WWW-Authenticate: Bearer realm=\"Intuit\", error=\"invalid_token\"\r\n"
      -> "\r\n"
      reading 91 bytes...
      -> "{\"code\":\"AuthenticationFailed\",\"type\":\"INPUT\",\"message\":null,\"detail\":null,\"moreInfo\":null}"
      read 91 bytes
      Conn close
      opening connection to oauth.platform.intuit.com:443...
      opened
      starting SSL for oauth.platform.intuit.com:443...
      SSL established
      <- "POST /oauth2/v1/tokens/bearer HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nAuthorization: Basic [FILTERED]==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: oauth.platform.intuit.com\r\nContent-Length: 89\r\n\r\n"
      <- "grant_type=refresh_token&refresh_token=[FILTERED]"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 17 Oct 2019 15:40:43 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 1007\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "Strict-Transport-Security: max-age=15552000\r\n"
      -> "intuit_tid: c9aff174-410e-4683-8a35-2591c659550f\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "\r\n"
      reading 1007 bytes...
      -> "{\"x_refresh_token_expires_in\":8719040,\"refresh_token\":\"[FILTERED]\",\"access_token\":\"[FILTERED]\",\"token_type\":\"bearer\",\"expires_in\":3600}"
      read 1007 bytes
      Conn close
      opening connection to sandbox.api.intuit.com:443...
      opened
      starting SSL for sandbox.api.intuit.com:443...
      SSL established
      <- "POST /quickbooks/v4/payments/charges HTTP/1.1\r\nContent-Type: application/json\r\nRequest-Id: da14d01c3608a0a036c4e7298cb5d56a\r\nAccept: application/json\r\nAuthorization: Bearer [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: sandbox.api.intuit.com\r\nContent-Length: 310\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"[FILTERED]\",\"expMonth\":\"09\",\"expYear\":2020,\"cvc\":\"[FILTERED]\",\"name\":\"Longbob Longsen\",\"address\":{\"streetAddress\":\"456 My Street\",\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"postalCode\":90210}},\"context\":{\"mobile\":false,\"isEcommerce\":true},\"capture\":\"true\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 17 Oct 2019 15:40:44 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "Strict-Transport-Security: max-age=15552000\r\n"
      -> "intuit_tid: 09ce7b7f-e19a-4567-8d7f-cf6ce81a9c75\r\n"
      -> "\r\n"
      -> "213\r\n"
      reading 531 bytes...
      -> "{\"created\":\"2019-10-17T15:40:44Z\",\"status\":\"CAPTURED\",\"amount\":\"1.00\",\"currency\":\"USD\",\"card\":{\"number\":\"xxxxxxxxxxxx2224\",\"name\":\"Longbob Longsen\",\"address\":{\"city\":\"Ottawa\",\"region\":\"CA\",\"country\":\"US\",\"streetAddress\":\"456 My Street\",\"postalCode\":\"90210\"},\"cardType\":\"Visa\",\"expMonth\":\"09\",\"expYear\":\"2020\",\"cvc\":\"xxx\"},\"capture\":true,\"avsStreet\":\"Pass\",\"avsZip\":\"Pass\",\"cardSecurityCodeMatch\":\"NotAvailable\",\"id\":\"ES2Q849Y8KQ9\",\"context\":{\"mobile\":false,\"deviceInfo\":{},\"recurring\":false,\"isEcommerce\":true},\"authCode\":\"574943\"}"
      read 531 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end
end
