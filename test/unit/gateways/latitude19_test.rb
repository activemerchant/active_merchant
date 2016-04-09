require 'test_helper'

class Latitude19Test < Test::Unit::TestCase
  def setup
    @gateway = Latitude19Gateway.new(fixtures(:latitude19))

    @amount = 100
    @credit_card = credit_card("4000100011112224", verification_value: "747")
    @declined_card = credit_card("0000000000000000")

    @options = {
      order_id: generate_unique_id,
      billing_address: address
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
    assert response.test?
  end

  # def test_failed_purchase
  # end

  def test_successful_authorize_and_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
    assert_match %r(^auth\|\w+$), response.authorization

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    capture = @gateway.capture(@amount, response.authorization, @options)
    assert_success capture
    assert_equal "Approved", capture.message
  end

  # def test_failed_authorize
  # end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    authorization = "auth" + "|" + SecureRandom.hex(6)
    response = @gateway.capture(@amount, authorization, @options)
    assert_failure response
    assert_equal "Not submitted", response.message
    assert_equal "400", response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_reversal_response)

    void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal "Approved", void.message

    # response = @gateway.authorize(@amount, @credit_card, @options)
    # assert_success response
    # assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", response.message

    # capture = @gateway.capture(@amount, response.authorization, @options)
    # assert_success capture
    # assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", capture.message

    # void = @gateway.void(capture.authorization, @options)
    # assert_success void
    # assert_equal "pgwResponseCodeDescription|Approved|responseText|00 -- APPROVAL|processorResponseCode|00", void.message

    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(successful_void_response)

    void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal "Approved", void.message
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(failed_reversal_response)

    authorization = auth.authorization[0..9] + "XX"
    response = @gateway.void(authorization, @options)

    assert_failure response
    assert_equal "Not submitted", response.message
    assert_equal "400", response.error_code
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
  end

  # def test_failed_credit
  # end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "Approved", response.message
  end

  # def test_failed_verify
  # end

  def test_successful_store_and_purchase
    @gateway.expects(:ssl_post).returns(successful_verify_response)
    @gateway.expects(:ssl_post).returns(successful_token_response)
    @gateway.expects(:ssl_post).returns(successful_session_response)

    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal "Approved", store.message

    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_equal "Approved", purchase.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to gateway-sb.l19tech.com:443...
      opened
      starting SSL for gateway-sb.l19tech.com:443...
      SSL established
      <- "POST /payments/session HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway-sb.l19tech.com\r\nContent-Length: 319\r\n\r\n"
      <- "{\"method\":\"getSession\",\"id\":\"c8829a018d77c5ecf4f68f307f6ab640\",\"params\":[{\"pgwAccountNumber\":\"03022016\",\"pgwConfigurationId\":\"380835424362\",\"requestTimeStamp\":\"20160407141623\",\"pgwHMAC\":\"e5a4f078d9cde4e520ffb8b073365deecb43e2f0accc44d26bccdfe47abdf52479fcd15098d9c741b22520d6bbab1f0107a1674a350fe387774896044c831758\"}]}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.0.15\r\n"
      -> "Date: Thu, 07 Apr 2016 14:16:24 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: POST, HEAD, OPTIONS\r\n"
      -> "\r\n"
      -> "a2\r\n"
      reading 162 bytes...
      -> "{\"error\": null, \"result\": {\"sessionId\": \"000008HH2RNN2PWBSW20160407141623\", \"version\": \"1.0\", \"lastActionSucceeded\": 1}, \"id\": \"c8829a018d77c5ecf4f68f307f6ab640\"}"
      read 162 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to gateway-sb.l19tech.com:443...
      opened
      starting SSL for gateway-sb.l19tech.com:443...
      SSL established
      <- "POST /payments/token HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway-sb.l19tech.com\r\nContent-Length: 153\r\n\r\n"
      <- "{\"method\":\"tokenize\",\"id\":\"f077295af9de092b2b1867d89c74fd4d\",\"params\":[{\"sessionId\":\"000008HH2RNN2PWBSW20160407141623\",\"cardNumber\":\"4000100011112224\"}]}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.0.15\r\n"
      -> "Date: Thu, 07 Apr 2016 14:16:26 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: POST, HEAD, OPTIONS\r\n"
      -> "\r\n"
      -> "94\r\n"
      reading 148 bytes...
      -> "{\"error\": null, \"result\": {\"version\": \"1.0\", \"lastActionSucceeded\": 1, \"sessionToken\": \"d133b6d9b992443\"}, \"id\": \"f077295af9de092b2b1867d89c74fd4d\"}"
      read 148 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to gateway-sb.l19tech.com:443...
      opened
      starting SSL for gateway-sb.l19tech.com:443...
      SSL established
      <- "POST /payments/v1/ HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway-sb.l19tech.com\r\nContent-Length: 621\r\n\r\n"
      <- "{\"method\":\"sale\",\"id\":\"db4f39966113020eab9c50ec626be3ce\",\"params\":[{\"sessionToken\":\"d133b6d9b992443\",\"amount\":\"100\",\"orderNumber\":\"6b122930383de3e1e355c48f863e002c\",\"transactionClass\":\"eCommerce\",\"cardExp\":\"09/17\",\"cardType\":\"VI\",\"cvv\":\"123\",\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"address1\":\"456 My Street\",\"address2\":\"Apt 1\",\"city\":\"Ottawa\",\"stateProvince\":\"ON\",\"zipPostalCode\":\"K1C2N6\",\"countryCode\":\"CA\",\"pgwAccountNumber\":\"03022016\",\"pgwConfigurationId\":\"380835424362\",\"pgwHMAC\":\"f3ebc73f54474c253bbafb88330f9db6bc3331544140d70a928dd264703653094187b9bde70d339dd680d612291e4981f92dc4e69d7f264d3fcd8a9cb09bca43\"}]}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.0.15\r\n"
      -> "Date: Thu, 07 Apr 2016 14:16:29 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: POST, HEAD, OPTIONS\r\n"
      -> "\r\n"
      -> "1e0\r\n"
      reading 480 bytes...
      -> "{\"error\": null, \"result\": {\"accountToken\": \"d133b6d9b992443\", \"responseText\": \"00 -- APPROVAL\", \"cvvResponse\": \"M\", \"cardLevelResponse\": \"A\", \"authCode\": \"AU1C1Q\", \"avsResponse\": \"Y\", \"threeDSecureResponse\": \"\", \"pgwTID\": \"00002KUZ6WY7\", \"last4\": \"2224\", \"cardType\": \"VI\", \"version\": \"1.0\", \"authDate\": \"\", \"processor\": {\"TID\": \"00002KUZ6WY7\", \"orderNumber\": \"\", \"responseCode\": \"00\"}, \"lastActionSucceeded\": 1, \"pgwResponseCode\": \"100\"}, \"id\": \"db4f39966113020eab9c50ec626be3ce\"}"
      read 480 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to gateway-sb.l19tech.com:443...
      opened
      starting SSL for gateway-sb.l19tech.com:443...
      SSL established
      <- "POST /payments/session HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway-sb.l19tech.com\r\nContent-Length: 319\r\n\r\n"
      <- "{\"method\":\"getSession\",\"id\":\"c8829a018d77c5ecf4f68f307f6ab640\",\"params\":[{\"pgwAccountNumber\":\"03022016\",\"pgwConfigurationId\":\"380835424362\",\"requestTimeStamp\":\"20160407141623\",\"pgwHMAC\":\"e5a4f078d9cde4e520ffb8b073365deecb43e2f0accc44d26bccdfe47abdf52479fcd15098d9c741b22520d6bbab1f0107a1674a350fe387774896044c831758\"}]}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.0.15\r\n"
      -> "Date: Thu, 07 Apr 2016 14:16:24 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: POST, HEAD, OPTIONS\r\n"
      -> "\r\n"
      -> "a2\r\n"
      reading 162 bytes...
      -> "{\"error\": null, \"result\": {\"sessionId\": \"000008HH2RNN2PWBSW20160407141623\", \"version\": \"1.0\", \"lastActionSucceeded\": 1}, \"id\": \"c8829a018d77c5ecf4f68f307f6ab640\"}"
      read 162 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to gateway-sb.l19tech.com:443...
      opened
      starting SSL for gateway-sb.l19tech.com:443...
      SSL established
      <- "POST /payments/token HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway-sb.l19tech.com\r\nContent-Length: 153\r\n\r\n"
      <- "{\"method\":\"tokenize\",\"id\":\"f077295af9de092b2b1867d89c74fd4d\",\"params\":[{\"sessionId\":\"000008HH2RNN2PWBSW20160407141623\",\"cardNumber\":\"[FILTERED]\"}]}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.0.15\r\n"
      -> "Date: Thu, 07 Apr 2016 14:16:26 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: POST, HEAD, OPTIONS\r\n"
      -> "\r\n"
      -> "94\r\n"
      reading 148 bytes...
      -> "{\"error\": null, \"result\": {\"version\": \"1.0\", \"lastActionSucceeded\": 1, \"sessionToken\": \"d133b6d9b992443\"}, \"id\": \"f077295af9de092b2b1867d89c74fd4d\"}"
      read 148 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to gateway-sb.l19tech.com:443...
      opened
      starting SSL for gateway-sb.l19tech.com:443...
      SSL established
      <- "POST /payments/v1/ HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: gateway-sb.l19tech.com\r\nContent-Length: 621\r\n\r\n"
      <- "{\"method\":\"sale\",\"id\":\"db4f39966113020eab9c50ec626be3ce\",\"params\":[{\"sessionToken\":\"d133b6d9b992443\",\"amount\":\"100\",\"orderNumber\":\"6b122930383de3e1e355c48f863e002c\",\"transactionClass\":\"eCommerce\",\"cardExp\":\"09/17\",\"cardType\":\"VI\",\"cvv\":\"[FILTERED]\",\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"address1\":\"456 My Street\",\"address2\":\"Apt 1\",\"city\":\"Ottawa\",\"stateProvince\":\"ON\",\"zipPostalCode\":\"K1C2N6\",\"countryCode\":\"CA\",\"pgwAccountNumber\":\"03022016\",\"pgwConfigurationId\":\"380835424362\",\"pgwHMAC\":\"f3ebc73f54474c253bbafb88330f9db6bc3331544140d70a928dd264703653094187b9bde70d339dd680d612291e4981f92dc4e69d7f264d3fcd8a9cb09bca43\"}]}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx/1.0.15\r\n"
      -> "Date: Thu, 07 Apr 2016 14:16:29 GMT\r\n"
      -> "Content-Type: text/html; charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Methods: POST, HEAD, OPTIONS\r\n"
      -> "\r\n"
      -> "1e0\r\n"
      reading 480 bytes...
      -> "{\"error\": null, \"result\": {\"accountToken\": \"d133b6d9b992443\", \"responseText\": \"00 -- APPROVAL\", \"cvvResponse\": \"M\", \"cardLevelResponse\": \"A\", \"authCode\": \"AU1C1Q\", \"avsResponse\": \"Y\", \"threeDSecureResponse\": \"\", \"pgwTID\": \"00002KUZ6WY7\", \"last4\": \"2224\", \"cardType\": \"VI\", \"version\": \"1.0\", \"authDate\": \"\", \"processor\": {\"TID\": \"00002KUZ6WY7\", \"orderNumber\": \"\", \"responseCode\": \"00\"}, \"lastActionSucceeded\": 1, \"pgwResponseCode\": \"100\"}, \"id\": \"db4f39966113020eab9c50ec626be3ce\"}"
      read 480 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def successful_session_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "sessionId": "000008HH2RO24UPJ3220160407195951",
        "version": "1.0",
        "lastActionSucceeded": 1
      },
      "id": "578b19e6ab40636236c5613e9530116a"
    }
    RESPONSE
  end

  def successful_token_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "version": "1.0",
        "lastActionSucceeded": 1,
          "sessionToken": "cf239e74c6c64ed"
      },
      "id": "5f3290299575e1ca1075648de677c69f"
    }
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "cf239e74c6c64ed",
        "responseText": "00 -- APPROVAL",
        "cvvResponse": "M",
        "cardLevelResponse": "A",
        "authCode": "AUPZ1U",
        "avsResponse": "Y",
        "threeDSecureResponse": "",
        "pgwTID": "00002KUZCJD1",
        "last4": "2224",
        "cardType": "VI",
        "version": "1.0",
        "authDate": "",
        "pgwResponseCode": "100",
        "lastActionSucceeded": 1,
        "processor": {
          "TID": "00002KUZCJD1",
          "orderNumber": "",
          "responseCode": "00"
        }
      },
      "id": "b6bd0e612f7e1090130ed3ca76ded99d"
    }
    RESPONSE
  end

  def failed_purchase_response
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "49763642056e4e3",
        "responseText": "00 -- APPROVAL",
        "cvvResponse": "M",
        "cardLevelResponse": "A",
        "authCode": "AUNAIA",
        "avsResponse": "Y",
        "threeDSecureResponse": "",
        "pgwTID": "00002KUZH81E",
        "last4": "2224",
        "cardType": "VI",
        "version": "1.0",
        "authDate": "",
        "processor": {
          "TID": "00002KUZH81E",
          "orderNumber": "",
          "responseCode": "00"
        },
        "lastActionSucceeded": 1,
        "pgwResponseCode": "100"
      },
      "id": "7d8dbf1603f86aab09730c0863eab073"
    }
    RESPONSE
  end

  def failed_authorize_response
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "49763642056e4e3",
        "responseText": "00 -- APPROVAL",
        "pgwTID": "00002KUZH81E",
        "last4": "2224",
        "cardType": "VI",
        "version": "1.0",
        "processor": {
          "TID": "00002KUZH81E",
          "orderNumber": "",
          "responseCode": "00"
        },
        "lastActionSucceeded": 1,
        "pgwResponseCode": "100"
      },
      "id": "63969448557de48aee071734d8721e94"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "",
        "responseText": "CNR -- Missing required token.",
        "pgwTID": "ba479cac02ae",
        "last4": "",
        "cardType": "UK",
        "version": "1.0",
        "processor": {
          "TID": "ba479cac02ae",
          "orderNumber": "",
          "responseCode": ""
        },
        "lastActionSucceeded": 0,
        "pgwResponseCode": "400"
      },
      "id": "bad12bcb3992dc80f1fdee8de7787b17"
    }
    RESPONSE
  end

  def successful_reversal_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "370a4f1ed5bc4e8",
        "responseText": "00 -- APPROVAL",
        "last4": "2224",
        "cardType": "VI",
        "version": "1.0",
        "processor": {
          "TID": "",
          "orderNumber": "",
          "responseCode": "00"
        },
        "lastActionSucceeded": 1,
        "pgwResponseCode": "100"
      },
      "id": "d56d9cf246c9c829ade1d86aed9e5eff"
    }
    RESPONSE
  end

  def failed_reversal_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "",
        "responseText": "CNR -- Missing required token.",
        "last4": "",
        "cardType": "UK",
        "version": "1.0",
        "processor": {
          "TID": "",
          "orderNumber": "",
          "responseCode": ""
        },
        "lastActionSucceeded": 0,
        "pgwResponseCode": "400"
      },
      "id": "633cd63f8d97f3e51744afd55ce55023"
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "aaa3a8ac2a974d2",
        "responseText": "00 -- APPROVAL",
        "last4": "2224",
        "cardType": "VI",
        "version": "1.0",
        "processor": {
          "TID": "",
          "orderNumber": "",
          "responseCode": "00"
        },
        "lastActionSucceeded": 1,
        "pgwResponseCode": "100"
      },
      "id": "1e7808e2e579779fa976a4472a4bc36a"
    }
    RESPONSE
  end

  def failed_void_response
  end

  def successful_credit_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "b9e35e6ba0b34f6",
        "responseText": "00 -- APPROVAL",
        "pgwTID": "00002KUZSGV2",
        "last4": "2224",
        "cardType": "VI",
        "version": "1.0",
        "processor": {
          "TID": "00002KUZSGV2",
          "orderNumber": "",
          "responseCode": "00"
        },
        "lastActionSucceeded": 1,
        "pgwResponseCode": "100"
      },
      "id": "7815e15188b44db93e710db1f4744010"
    }
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
    {
      "error": null,
      "result": {
        "accountToken": "d079e09f2ec14af",
        "responseText": "85 -- AVS ACCEPTED",
        "cvvResponse": "M",
        "avsResponse": "Y",
        "last4": "2224",
        "cardType": "VI",
        "version": "1.0",
        "processor": {
          "TID": "",
          "orderNumber": "",
          "responseCode": "85"
        },
        "lastActionSucceeded": 1,
        "pgwResponseCode": "100"
      },
      "id": "f8463871ea905306f7446cf8937b0bfa"
    }
    RESPONSE
  end
end
