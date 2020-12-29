require 'test_helper'

class PlaceToPayTest < Test::Unit::TestCase
  def setup
    @gateway = PlaceToPayGateway.new(login: 'login', secret_key: 'secret_key')
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

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '999999', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~'PRE_SCRUBBED'
      opening connection to test.placetopay.ec:443...
      opened
      starting SSL for test.placetopay.ec:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /rest/gateway/process HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.placetopay.ec\r\nContent-Length: 565\r\n\r\n"
      <- "{\"auth\":{\"login\":\"2b58818b47f407e837d2da6e04d91da1\",\"nonce\":\"a2VpbmJkWTc=\",\"seed\":\"2020-12-08T13:50:40+00:00\",\"tranKey\":\"oFOd1cKzFsozQIaHfUMwoP0vNWW4T1XkDKirQvpR2yM=\"},\"locale\":\"es_EC\",\"payment\":{\"reference\":\"3176f5afbb08456fb49ec9d84af7e70e\",\"description\":\"Description\",\"amount\":{\"currency\":\"USD\",\"total\":\"1.00\"}},\"instrument\":{\"card\":{\"number\":\"36545400000008\",\"expirationMonth\":9,\"expirationYear\":2021,\"cvv\":\"123\"}},\"payer\":{\"name\":\"Longbob\",\"surname\":\"Longsen\",\"email\":null,\"address\":{}},\"buyer\":{\"name\":\"Longbob\",\"surname\":\"Longsen\",\"email\":null,\"address\":{}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Tue, 08 Dec 2020 13:50:40 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=da6c90365198f67ece965fb4bca6e1fdb1607435440; expires=Thu, 07-Jan-21 13:50:40 GMT; path=/; domain=.placetopay.ec; HttpOnly; SameSite=Lax; Secure\r\n"
      -> "Cache-Control: no-cache, private\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "CF-Cache-Status: DYNAMIC\r\n"
      -> "cf-request-id: 06e437690d000098db25838000000001\r\n"
      -> "Expect-CT: max-age=604800, report-uri=\"https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct\"\r\n"
      -> "Server: cloudflare\r\n"
      -> "CF-RAY: 5fe6f4ee7ab698db-LAX\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "20e\r\n"
      reading 526 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x8CR\xC1j\xDC0\x10\xFD\x979;E\xF6Z^\xDB\xB7\x10\xA74\xD0nB\x9A\x04z\nci\x94\x15\xD8\xD2\"\xC9\xA1\xE9\xB2\xFF^F\x9B\ri\x0FM\x05\x82a\xF4f4\xF3\xDE\xDBCL\x98\x96\b\xFD\xFE-\x82\xF3\x9B\x9B\xDB\xEB\x87\xCB\x01\n\b\x84\xD1;\xE8A\b(`\xA6\x18\xF1\x89\x18\xB2\v~D\x8DP\x80\xC6\xC4\x99JT\xE2\xAC\xAC\xCED{'\xDA^\x8A~\xD5\x9D\t\xD9\v\x01\x87\xFF\xC0\x14\x90\x02\xBA\x88*Y\xEF\x86\x8F\xD1\xD6%\n\x0E\xA7[2\x14\xC8)\x82\xBEl*\xD1\xD4<\xF2[\nV\xE5\xBA1\x12\xCD8\x8A\xB6\x96\x8D\x19\xEB\x8ET\xA7\xDB\x1A\xCD\x9A\xD6\x82\xA0\x80\x1D\xBE\xCC\xE4\xD27J[\xAF\xA1\x87\xAB\xE1q\xD8@\x01&\xA0S[\e\xB9\x8D\xB6\x8EB|\x9F\xDC\xE0\xCC\x0F\xC3\xE9\xC1\xC6\xB8P\xF8;\x8B\xB3_\\bn\xD5\x12x\xA6\x17\xE8\xE1\xFE;\x13\x9B|\xC2\tz(?\x1D\x19R\xDE=S\x88\x96\xC9\xDE\x83\t~\xFEWYy\xE0\xF0#\x84A\x95|8\xC6\xB8\xA4\xAD\x0F\xF6\x17\xA6\xFC\x05t\xF9d\x85\x15\xD9]\xE2Q2\x81\xDC\xE2e\x975\xBE\xBF\xFB\xF2x\xBD\xF9\xFA#\xA3\xCC\xE24i\xE8\rN\x91\n\x980\xA6\xC1>\xD9\x14\xB39D\xCBT\x06\xFFl5\x05fqswy;\\1\x91\xDAFu\xA4\xC1-\xD3\x94Q\x8Ab\xF4\xE1\xB3\xA5Ig\xE7Y&^V\xD5\xD8u\xC2\xB4\xC6`\xD5\x8CbU\xB7j\x94\xE5J\x89\n\xA5\x94\n\n\x18\xAB\xFAhE^Hk\xCB\xBB\xF0\xB2{\x98)\xA8-\xBAt\xE15\x8F^\xD6\x8Dl\xD6\x92w\xA10[\x87\xD3f\x99\xC7<\x99\x10]\xC7\x17\nP\x81\xB4=\xCA\x93\xCB\xCA\xB7\xD5\xB3\xC7\x9E\x82_v\xAF\r/\xB2\xE7b\xC2ib\xB7\xC4\x93\x04\t\xA7\xF3W\x91\xCBWWRL\xA7\x94\xF8\xA3\xE8=P\xD1;\xCC\x88ImO\xF4L\xD6\xD1)\x1E-K\xB5jd-Y\x17\xFA\xB9\xB3\xE1$\xA0\xE8\xAA\x12\x0E\x87\xDF\x00\x00\x00\xFF\xFF\x03\x00\xFB\x1F\xEFA\xC1\x03\x00\x00"
      read 526 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~'POST_SCRUBBED'
      opening connection to test.placetopay.ec:443...
      opened
      starting SSL for test.placetopay.ec:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /rest/gateway/process HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: test.placetopay.ec\r\nContent-Length: 565\r\n\r\n"
      <- "{\"auth\":{\"login\":\"2b58818b47f407e837d2da6e04d91da1\",\"nonce\":\"a2VpbmJkWTc=\",\"seed\":\"2020-12-08T13:50:40+00:00\",\"tranKey\":\"oFOd1cKzFsozQIaHfUMwoP0vNWW4T1XkDKirQvpR2yM=\"},\"locale\":\"es_EC\",\"payment\":{\"reference\":\"3176f5afbb08456fb49ec9d84af7e70e\",\"description\":\"Description\",\"amount\":{\"currency\":\"USD\",\"total\":\"1.00\"}},\"instrument\":{\"card\":{\"number\":\"[FILTERED]\",\"expirationMonth\":9,\"expirationYear\":2021,\"cvv\":\"[FILTERED]\"}},\"payer\":{\"name\":\"Longbob\",\"surname\":\"Longsen\",\"email\":null,\"address\":{}},\"buyer\":{\"name\":\"Longbob\",\"surname\":\"Longsen\",\"email\":null,\"address\":{}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Tue, 08 Dec 2020 13:50:40 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=da6c90365198f67ece965fb4bca6e1fdb1607435440; expires=Thu, 07-Jan-21 13:50:40 GMT; path=/; domain=.placetopay.ec; HttpOnly; SameSite=Lax; Secure\r\n"
      -> "Cache-Control: no-cache, private\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "CF-Cache-Status: DYNAMIC\r\n"
      -> "cf-request-id: 06e437690d000098db25838000000001\r\n"
      -> "Expect-CT: max-age=604800, report-uri=\"https://report-uri.cloudflare.com/cdn-cgi/beacon/expect-ct\"\r\n"
      -> "Server: cloudflare\r\n"
      -> "CF-RAY: 5fe6f4ee7ab698db-LAX\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "20e\r\n"
      reading 526 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x00\x03\x8CR\xC1j\xDC0\x10\xFD\x979;E\xF6Z^\xDB\xB7\x10\xA74\xD0nB\x9A\x04z\nci\x94\x15\xD8\xD2\"\xC9\xA1\xE9\xB2\xFF^F\x9B\ri\x0FM\x05\x82a\xF4f4\xF3\xDE\xDBCL\x98\x96\b\xFD\xFE-\x82\xF3\x9B\x9B\xDB\xEB\x87\xCB\x01\n\b\x84\xD1;\xE8A\b(`\xA6\x18\xF1\x89\x18\xB2\v~D\x8DP\x80\xC6\xC4\x99JT\xE2\xAC\xAC\xCED{'\xDA^\x8A~\xD5\x9D\t\xD9\v\x01\x87\xFF\xC0\x14\x90\x02\xBA\x88*Y\xEF\x86\x8F\xD1\xD6%\n\x0E\xA7[2\x14\xC8)\x82\xBEl*\xD1\xD4<\xF2[\nV\xE5\xBA1\x12\xCD8\x8A\xB6\x96\x8D\x19\xEB\x8ET\xA7\xDB\x1A\xCD\x9A\xD6\x82\xA0\x80\x1D\xBE\xCC\xE4\xD27J[\xAF\xA1\x87\xAB\xE1q\xD8@\x01&\xA0S[\e\xB9\x8D\xB6\x8EB|\x9F\xDC\xE0\xCC\x0F\xC3\xE9\xC1\xC6\xB8P\xF8;\x8B\xB3_\\bn\xD5\x12x\xA6\x17\xE8\xE1\xFE;\x13\x9B|\xC2\tz(?\x1D\x19R\xDE=S\x88\x96\xC9\xDE\x83\t~\xFEWYy\xE0\xF0#\x84A\x95|8\xC6\xB8\xA4\xAD\x0F\xF6\x17\xA6\xFC\x05t\xF9d\x85\x15\xD9]\xE2Q2\x81\xDC\xE2e\x975\xBE\xBF\xFB\xF2x\xBD\xF9\xFA#\xA3\xCC\xE24i\xE8\rN\x91\n\x980\xA6\xC1>\xD9\x14\xB39D\xCBT\x06\xFFl5\x05fqswy;\\1\x91\xDAFu\xA4\xC1-\xD3\x94Q\x8Ab\xF4\xE1\xB3\xA5Ig\xE7Y&^V\xD5\xD8u\xC2\xB4\xC6`\xD5\x8CbU\xB7j\x94\xE5J\x89\n\xA5\x94\n\n\x18\xAB\xFAhE^Hk\xCB\xBB\xF0\xB2{\x98)\xA8-\xBAt\xE15\x8F^\xD6\x8Dl\xD6\x92w\xA10[\x87\xD3f\x99\xC7<\x99\x10]\xC7\x17\nP\x81\xB4=\xCA\x93\xCB\xCA\xB7\xD5\xB3\xC7\x9E\x82_v\xAF\r/\xB2\xE7b\xC2ib\xB7\xC4\x93\x04\t\xA7\xF3W\x91\xCBWWRL\xA7\x94\xF8\xA3\xE8=P\xD1;\xCC\x88ImO\xF4L\xD6\xD1)\x1E-K\xB5jd-Y\x17\xFA\xB9\xB3\xE1$\xA0\xE8\xAA\x12\x0E\x87\xDF\x00\x00\x00\xFF\xFF\x03\x00\xFB\x1F\xEFA\xC1\x03\x00\x00"
      read 526 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-RESPONSE
      {
        "status":{
          "status":"APPROVED",
          "reason":"00",
          "message":"Aprobada",
          "date":"2020-12-07T14:10:07-05:00"
        },
        "date":"2020-12-07T14:10:06-05:00",
        "transactionDate":"2020-12-07T14:10:07-05:00",
        "internalReference":161909,
        "reference":"baa98be688d44cbb9692f145621c8d0a",
        "paymentMethod":"ID_DN",
        "franchise":"diners",
        "franchiseName":"Diners",
        "issuerName":"Diners",
        "amount":{
          "currency":"USD",
          "total":"1.00"
        },
        "conversion":{
          "from":{
            "currency":"USD",
            "total":1
          },
          "to":{
            "currency":"USD",
            "total":1
          },
          "factor":1
        },
        "authorization":"999999",
        "receipt":"161909",
        "type":"AUTH_ONLY",
        "refunded":false,
        "lastDigits":"0008",
        "provider":"INTERDIN",
        "discount":null,
        "processorFields":{
          "id":"062bb99a9bd2f26b5efdd0cc9a2e4a4f",
          "b24":"00"
        },
        "additional":{
          "merchantCode":"1465675",
          "terminalNumber":"00990099",
          "credit":{
            "code":1,
            "type":"00",
            "groupCode":"C",
            "installments":1
          },
          "totalAmount":1,
          "interestAmount":0,
          "installmentAmount":1,
          "iceAmount":0,
          "batch":null,
          "line":null,
          "bin":"365454",
          "expiration":"0921"
        }
      }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
      {
        "status":{
          "status":"REJECTED",
          "reason":"05",
          "message":"Rechazada",
          "date":"2020-12-07T14:29:15-05:00"
        },
        "date":"2020-12-07T14:29:15-05:00",
        "transactionDate":"2020-12-07T14:29:15-05:00",
        "internalReference":161910,
        "reference":"760eea09454b4c61aaba1410b9f6275f",
        "paymentMethod":"ID_DN",
        "franchise":"diners",
        "franchiseName":"Diners",
        "issuerName":"Diners",
        "amount":{
          "currency":"USD",
          "total":"1.00"
        },
        "conversion":{
          "from":{
            "currency":"USD",
            "total":1
          },
          "to":{
            "currency":"USD",
            "total":1
          },
          "factor":1
        },
        "authorization":"000000",
        "receipt":"161910",
        "type":"AUTH_ONLY",
        "refunded":false,
        "lastDigits":"0248",
        "provider":"INTERDIN",
        "discount":null,
        "processorFields":{
          "id":"558a1241a708d5cb4f25894c36b32ed8",
          "b24":"05"
        },
        "additional":{
          "merchantCode":"1465675",
          "terminalNumber":"00990099",
          "credit":{
            "code":1,
            "type":"00",
            "groupCode":"C",
            "installments":1
          },
          "totalAmount":1,
          "interestAmount":0,
          "installmentAmount":1,
          "iceAmount":0,
          "batch":null,
          "line":null,
          "bin":"365454",
          "expiration":"0921"
        }
      }
    RESPONSE
  end
end
