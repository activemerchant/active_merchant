require 'test_helper'

class NetbanxTest < Test::Unit::TestCase
  def setup
    @gateway = NetbanxGateway.new(account_number: '1234567890', api_key: 'foobar')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '9c13fdfe-77d9-4fef-bfd6-a95132423b99', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The card has been declined due to insufficient funds.', response.message
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'b8c53059-9da3-4054-8caf-3769161a3cdc', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 'The card has been declined due to insufficient funds.', response.message
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.authorize(@amount, '056ff3a9-5274-4452-92ab-0e3b3e591c3b')
    assert_success response

    assert_equal '11e0906b-6596-4490-b0e3-825f71a82799', response.authorization
    assert_equal 'OK', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.authorize(@amount, '056ff3a9-f000-b44r-92ab-0e3b3e591c3b')
    assert_failure response

    assert_equal 'The authorization ID included in this settlement request could not be found.', response.message
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.refund(@amount, '056ff3a9-5274-4452-92ab-0e3b3e591c3b')
    assert_success response

    assert_equal '11e0906b-6596-4490-b0e3-825f71a82799', response.authorization
    assert_equal 'OK', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, '056ff3a9-f000-b44r-92ab-0e3b3e591c3b')
    assert_failure response

    assert_equal 'The settlement you are attempting to refund has not been batched yet. There are no settled funds available to refund.', response.message
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('16d9eafa-cca0-4916-9408-e83c899924a6')
    assert_success response

    assert_equal '64b3f52e-cd0d-474a-8f16-bb9c559d3bca', response.authorization
    assert_equal 'OK', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('056ff3a9-f000-b44r-92ab-0e3b3e591c3b')
    assert_failure response

    assert_equal 'The confirmation number included in this request could not be found.', response.message
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_request).returns(successful_store_response)

    options = @options.merge({ locale: 'en_GB' })

    response = @gateway.store(@credit_card, options)
    assert_success response

    assert_equal '2f840ab3-0e71-4387-bad3-4705e6f4b015|e4a3cd5a-56db-4d9b-97d3-fdd9ab3bd0f4|C6gmdUA1xWT8RsC', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_request).returns(successful_purchase_with_token_response)

    response = @gateway.purchase(@amount, 'CL0RCSnrkREnfwA', @options)
    assert_success response

    assert_equal 'OK', response.message
    assert_equal 'bfc9b743-b9b3-4906-b06b-da4e185d93bf', response.authorization
    assert response.test?
  end

  def test_successful_unstore
     @gateway.expects(:ssl_request).twice.returns(successful_unstore_response)

     response = @gateway.unstore('2f840ab3-0e71-4387-bad3-4705e6f4b015|e4a3cd5a-56db-4d9b-97d3-fdd9ab3bd0f4')
     assert_success response
     assert response.test?

    response = @gateway.unstore('2f840ab3-0e71-4387-bad3-4705e6f4b015')
    assert_success response
    assert response.test?
  end


  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.test.netbanx.com:443...
      opened
      starting SSL for api.test.netbanx.com:443...
      SSL established
      <- "POST /cardpayments/v1/accounts/1234567890/auths HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nAuthorization: Basic b29aNG9zaDhpVGlzZWUwYWVqb2U5cGVlNHRvaDVhYTRPaGdoYWUybGFocGgyT2hyYWU2dGhlZTNQaGVleWVlVzNlaWc5YWVQaWVwaGFpTDU=\r\nUser-Agent: Netbanx-Paysafe v1.0/ActiveMerchant 1.60.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nConnection: close\r\nHost: api.test.netbanx.com\r\nContent-Length: 272\r\n\r\n"
      <- "{\"amount\":\"100\",\"merchantRefNum\":\"feff07f6aac020790c6d68626be3790b\",\"billingDetails\":{\"street\":\"456 My Street\",\"city\":\"Ottawa\",\"zip\":\"K1C2N6\",\"country\":\"CA\"},\"settleWithAuth\":true,\"card\":{\"cardNum\":\"4530910000012345\",\"cvv\":\"123\",\"cardExpiry\":{\"month\":\"09\",\"year\":\"2017\"}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: WebServer32xS10i3\r\n"
      -> "Content-Length: 1190\r\n"
      -> "X-ApplicationUid: GUID=fbf46c92-d3e5-496f-98b4-f56380039396\r\n"
      -> "X-Powered-By: Servlet/2.5 JSP/2.1\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Expires: Thu, 04 Aug 2016 08:29:51 GMT\r\n"
      -> "Cache-Control: max-age=0, no-cache, no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Date: Thu, 04 Aug 2016 08:29:51 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: JSESSIONID=rRtUrEShVlgJ4WUe2aLrCaaKnSq932fmNvhqpKZn22ytPUhPjgG7!-2137665119; path=/; HttpOnly\r\n"
      -> "\r\n"
      reading 1190 bytes...
      -> "{"
      -> "\"links\":[{\"rel\":\"settlement\",\"href\":\"https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/fbf46c92-d3e5-496f-98b4-f56380039396\"},{\"rel\":\"self\",\"href\":\"https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/auths/fbf46c92-d3e5-496f-98b4-f56380039396\"}],\"id\":\"fbf46c92-d3e5-496f-98b4-f56380039396\",\"merchantRefNum\":\"feff07f6aac020790c6d68626be3790b\",\"txnTime\":\"2016-08-04T08:29:51Z\",\"status\":\"COMPLETED\",\"amount\":100,\"settleWithAuth\":true,\"preAuth\":false,\"availableToSettle\":0,\"card\":{\"type\":\"VI\",\"lastDigits\":\"2345\",\"cardExpiry\":{\"month\":9,\"year\":2017}},\"authCode\":\"125492\",\"billingDetails\":{\"street\":\"456 My Street\",\"city\":\"Ottawa\",\"country\":\"CA\",\"zip\":\"K1C2N6\"},\"merchantDescriptor\":{\"dynamicDescriptor\":\"Test\",\"phone\":\"123-1234123\"},\"currencyCode\":\"CAD\",\"avsResponse\":\"MATCH\",\"cvvVerification\":\"MATCH\",\"settlements\":[{\"links\":[{\"rel\":\"self\",\"href\":\"https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/fbf46c92-d3e5-496f-98b4-f56380039396\"}],\"id\":\"fbf46c92-d3e5-496f-98b4-f56380039396\",\"merchantRefNum\":\"feff07f6aac020790c6d68626be3790b\",\"txnTime\":\"2016-08-04T08:29:51Z\",\"status\":\"PENDING\",\"amount\":100,\"availableToRefund\":100}]}"
      read 1190 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api.test.netbanx.com:443...
      opened
      starting SSL for api.test.netbanx.com:443...
      SSL established
      <- "POST /cardpayments/v1/accounts/1234567890/auths HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nAuthorization: Basic [FILTERED]=\r\nUser-Agent: Netbanx-Paysafe v1.0/ActiveMerchant 1.60.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nConnection: close\r\nHost: api.test.netbanx.com\r\nContent-Length: 272\r\n\r\n"
      <- "{\"amount\":\"100\",\"merchantRefNum\":\"feff07f6aac020790c6d68626be3790b\",\"billingDetails\":{\"street\":\"456 My Street\",\"city\":\"Ottawa\",\"zip\":\"K1C2N6\",\"country\":\"CA\"},\"settleWithAuth\":true,\"card\":{\"cardNum\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"cardExpiry\":{\"month\":\"09\",\"year\":\"2017\"}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: WebServer32xS10i3\r\n"
      -> "Content-Length: 1190\r\n"
      -> "X-ApplicationUid: GUID=fbf46c92-d3e5-496f-98b4-f56380039396\r\n"
      -> "X-Powered-By: Servlet/2.5 JSP/2.1\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Expires: Thu, 04 Aug 2016 08:29:51 GMT\r\n"
      -> "Cache-Control: max-age=0, no-cache, no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Date: Thu, 04 Aug 2016 08:29:51 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: JSESSIONID=rRtUrEShVlgJ4WUe2aLrCaaKnSq932fmNvhqpKZn22ytPUhPjgG7!-2137665119; path=/; HttpOnly\r\n"
      -> "\r\n"
      reading 1190 bytes...
      -> "{"
      -> "\"links\":[{\"rel\":\"settlement\",\"href\":\"https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/fbf46c92-d3e5-496f-98b4-f56380039396\"},{\"rel\":\"self\",\"href\":\"https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/auths/fbf46c92-d3e5-496f-98b4-f56380039396\"}],\"id\":\"fbf46c92-d3e5-496f-98b4-f56380039396\",\"merchantRefNum\":\"feff07f6aac020790c6d68626be3790b\",\"txnTime\":\"2016-08-04T08:29:51Z\",\"status\":\"COMPLETED\",\"amount\":100,\"settleWithAuth\":true,\"preAuth\":false,\"availableToSettle\":0,\"card\":{\"type\":\"VI\",\"lastDigits\":\"2345\",\"cardExpiry\":{\"month\":9,\"year\":2017}},\"authCode\":\"125492\",\"billingDetails\":{\"street\":\"456 My Street\",\"city\":\"Ottawa\",\"country\":\"CA\",\"zip\":\"K1C2N6\"},\"merchantDescriptor\":{\"dynamicDescriptor\":\"Test\",\"phone\":\"123-1234123\"},\"currencyCode\":\"CAD\",\"avsResponse\":\"MATCH\",\"cvvVerification\":\"MATCH\",\"settlements\":[{\"links\":[{\"rel\":\"self\",\"href\":\"https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/fbf46c92-d3e5-496f-98b4-f56380039396\"}],\"id\":\"fbf46c92-d3e5-496f-98b4-f56380039396\",\"merchantRefNum\":\"feff07f6aac020790c6d68626be3790b\",\"txnTime\":\"2016-08-04T08:29:51Z\",\"status\":\"PENDING\",\"amount\":100,\"availableToRefund\":100}]}"
      read 1190 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-RESPONSE
      {
      "links": [
        {
          "rel": "settlement",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/123457890/settlements/9c13fdfe-77d9-4fef-bfd6-a95132423b99"
        },
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/123457890/auths/9c13fdfe-77d9-4fef-bfd6-a95132423b99"
        }
      ],
      "id": "9c13fdfe-77d9-4fef-bfd6-a95132423b99",
      "merchantRefNum": "2651eb361b1609777a8b9034257c1be9",
      "txnTime": "2016-08-04T06:37:15Z",
      "status": "COMPLETED",
      "amount": 100,
      "settleWithAuth": true,
      "preAuth": false,
      "availableToSettle": 0,
      "card": {
        "type": "VI",
        "lastDigits": "2345",
        "cardExpiry": {
          "month": 9,
          "year": 2017
        }
      },
      "authCode": "762449",
      "billingDetails": {
        "street": "456 My Street",
        "street2": "Apt 1",
        "city": "Ottawa",
        "state": "ON",
        "country": "CA",
        "zip": "K1C2N6"
      },
      "merchantDescriptor": {
        "dynamicDescriptor": "Test",
        "phone": "123-1234123"
      },
      "currencyCode": "CAD",
      "avsResponse": "MATCH",
      "cvvVerification": "MATCH",
      "settlements": [
        {
          "links": [
            {
              "rel": "self",
              "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/123457890/settlements/9c13fdfe-77d9-4fef-bfd6-a95132423b99"
            }
          ],
          "id": "9c13fdfe-77d9-4fef-bfd6-a95132423b99",
          "merchantRefNum": "2651eb361b1609777a8b9034257c1be9",
          "txnTime": "2016-08-04T06:37:15Z",
          "status": "PENDING",
          "amount": 100,
          "availableToRefund": 100
        }
      ]
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/auths/a3eeaaa7-9f29-4345-b326-46f92300dd6c"
        }
      ],
      "id": "a3eeaaa7-9f29-4345-b326-46f92300dd6c",
      "merchantRefNum": "f37cc5db-d766-477f-b4c2-636ad5664f50",
      "error": {
        "code": "3022",
        "message": "The card has been declined due to insufficient funds.",
        "links": [
          {
            "rel": "errorinfo",
            "href": "https://developer.optimalpayments.com/en/documentation/card-payments-api/error-3022"
          }
        ]
      },
      "riskReasonCode": [
        1059
      ],
      "settleWithAuth": true,
      "cvvVerification": "MATCH"
    }
    RESPONSE
  end

  def successful_purchase_with_token_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "settlement",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/bfc9b743-b9b3-4906-b06b-da4e185d93bf"
        },
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/auths/bfc9b743-b9b3-4906-b06b-da4e185d93bf"
        }
      ],
      "id": "bfc9b743-b9b3-4906-b06b-da4e185d93bf",
      "merchantRefNum": "efdf1a69-2380-4c4f-a392-62ce80970b65",
      "txnTime": "2016-08-08T06:36:50Z",
      "status": "COMPLETED",
      "amount": 100,
      "settleWithAuth": true,
      "preAuth": false,
      "availableToSettle": 0,
      "card": {
        "type": "VI",
        "lastDigits": "2345",
        "cardExpiry": {
          "month": 9,
          "year": 2017
        }
      },
      "authCode": "101408",
      "billingDetails": {
        "street": "456 My Street",
        "city": "Ottawa",
        "country": "CA",
        "zip": "K1C2N6"
      },
      "merchantDescriptor": {
        "dynamicDescriptor": "Test",
        "phone": "123-1234123"
      },
      "currencyCode": "CAD",
      "avsResponse": "MATCH",
      "cvvVerification": "NOT_PROCESSED",
      "settlements": [
        {
          "links": [
            {
              "rel": "self",
              "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/bfc9b743-b9b3-4906-b06b-da4e185d93bf"
            }
          ],
          "id": "bfc9b743-b9b3-4906-b06b-da4e185d93bf",
          "merchantRefNum": "efdf1a69-2380-4c4f-a392-62ce80970b65",
          "txnTime": "2016-08-08T06:36:50Z",
          "status": "PENDING",
          "amount": 100,
          "availableToRefund": 100
        }
      ]
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/auths/b8c53059-9da3-4054-8caf-3769161a3cdc"
        }
      ],
      "id": "b8c53059-9da3-4054-8caf-3769161a3cdc",
      "merchantRefNum": "5e6eb079-33ab-44d5-a376-e7bb5bd5c256",
      "txnTime": "2016-08-08T06:46:26Z",
      "status": "COMPLETED",
      "amount": 100,
      "settleWithAuth": false,
      "availableToSettle": 100,
      "card": {
        "type": "VI",
        "lastDigits": "2345",
        "cardExpiry": {
          "month": 9,
          "year": 2017
        }
      },
      "authCode": "143980",
      "billingDetails": {
        "street": "456 My Street",
        "city": "Ottawa",
        "country": "CA",
        "zip": "K1C2N6"
      },
      "merchantDescriptor": {
        "dynamicDescriptor": "Test",
        "phone": "123-1234123"
      },
      "currencyCode": "CAD",
      "avsResponse": "MATCH",
      "cvvVerification": "MATCH"
    }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/auths/e62d1415-c952-4f09-9e4f-cd733adfca0c"
        }
      ],
      "id": "e62d1415-c952-4f09-9e4f-cd733adfca0c",
      "merchantRefNum": "46a3e959-dbec-4b65-8a6f-d80d83e0f2fa",
      "error": {
        "code": "3022",
        "message": "The card has been declined due to insufficient funds.",
        "links": [
          {
            "rel": "errorinfo",
            "href": "https://developer.optimalpayments.com/en/documentation/card-payments-api/error-3022"
          }
        ]
      },
      "riskReasonCode": [
        1059
      ],
      "settleWithAuth": false,
      "cvvVerification": "MATCH"
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/11e0906b-6596-4490-b0e3-825f71a82799"
        }
      ],
      "id": "11e0906b-6596-4490-b0e3-825f71a82799",
      "merchantRefNum": "0e2c8d4d-f03e-4251-9311-955f5c159b90",
      "txnTime": "2016-08-08T06:49:05Z",
      "status": "PENDING",
      "amount": 100,
      "availableToRefund": 100
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/settlements/4fd1068f-2543-4a38-bb48-2122a1e75c61"
        }
      ],
      "id": "4fd1068f-2543-4a38-bb48-2122a1e75c61",
      "merchantRefNum": "012b0c60-925b-4907-8a56-c9c2336b8648",
      "error": {
        "code": "3201",
        "message": "The authorization ID included in this settlement request could not be found.",
        "links": [
          {
            "rel": "errorinfo",
            "href": "https://developer.optimalpayments.com/en/documentation/card-payments-api/error-3201"
          }
        ]
      }
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/refunds/03a449a3-1709-4ce2-87ba-1e9e8c69eaea"
        }
      ],
      "id": "03a449a3-1709-4ce2-87ba-1e9e8c69eaea",
      "merchantRefNum": "6a9608ba-6c81-4810-ae02-3d9a38ac3400",
      "txnTime": "2016-08-08T07:42:03Z",
      "status": "PENDING",
      "amount": 100
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/refunds/6cc833f9-9d4d-416a-a5a4-18ed785450a2"
        }
      ],
      "id": "6cc833f9-9d4d-416a-a5a4-18ed785450a2",
      "merchantRefNum": "59332fd0-0296-4ae4-b9a4-aa086237b238",
      "error": {
        "code": "3406",
        "message": "The settlement you are attempting to refund has not been batched yet. There are no settled funds available to refund.",
        "links": [
          {
            "rel": "errorinfo",
            "href": "https://developer.optimalpayments.com/en/documentation/card-payments-api/error-3406"
          }
        ]
      }
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/voidauths/64b3f52e-cd0d-474a-8f16-bb9c559d3bca"
        }
      ],
      "id": "64b3f52e-cd0d-474a-8f16-bb9c559d3bca",
      "merchantRefNum": "60edbe35-5779-403b-a633-8685bd7acb4c",
      "txnTime": "2016-08-08T06:50:32Z",
      "status": "COMPLETED",
      "amount": 100
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "links": [
        {
          "rel": "self",
          "href": "https://api.test.netbanx.com/cardpayments/v1/accounts/1234567890/voidauths/96d5c070-e402-4d2d-ae55-addeca4fc4ef"
        }
      ],
      "id": "96d5c070-e402-4d2d-ae55-addeca4fc4ef",
      "merchantRefNum": "5628cddf-ff53-4b70-95e2-ed4762f60c6e",
      "error": {
        "code": "3500",
        "message": "The confirmation number included in this request could not be found.",
        "links": [
          {
            "rel": "errorinfo",
            "href": "https://developer.optimalpayments.com/en/documentation/card-payments-api/error-3500"
          }
        ]
      }
    }
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
    {
      "id": "2f840ab3-0e71-4387-bad3-4705e6f4b015",
      "status": "ACTIVE",
      "merchantCustomerId": "5e9d1ab0f847d147ffe872a9faf76d98",
      "locale": "en_GB",
      "paymentToken": "PJzuA8s6c6pSIs4",
      "addresses": [],
      "cards": [
        {
          "status": "ACTIVE",
          "id": "e4a3cd5a-56db-4d9b-97d3-fdd9ab3bd0f4",
          "cardBin": "453091",
          "lastDigits": "2345",
          "cardExpiry": {
            "year": 2017,
            "month": 9
          },
          "holderName": "Longbob Longsen",
          "cardType": "VI",
          "paymentToken": "C6gmdUA1xWT8RsC",
          "defaultCardIndicator": true
        }
      ]
    }
    RESPONSE
  end

  def successful_unstore_response
    <<-RESPONSE
    {
      "id": "2f840ab3-0e71-4387-bad3-4705e6f4b015",
      "status": "ACTIVE",
      "merchantCustomerId": "5e9d1ab0f847d147ffe872a9faf76d98",
      "locale": "en_GB",
      "paymentToken": "PJzuA8s6c6pSIs4",
      "addresses": [],
      "cards": [
        {
          "status": "ACTIVE",
          "id": "e4a3cd5a-56db-4d9b-97d3-fdd9ab3bd0f4",
          "cardBin": "453091",
          "lastDigits": "2345",
          "cardExpiry": {
            "year": 2017,
            "month": 9
          },
          "holderName": "Longbob Longsen",
          "cardType": "VI",
          "paymentToken": "C6gmdUA1xWT8RsC",
          "defaultCardIndicator": true
        }
      ]
    }
    RESPONSE
  end
end
