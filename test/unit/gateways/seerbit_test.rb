require 'test_helper'

class SeerbitTest < Test::Unit::TestCase
  def setup
    @gateway = SeerbitGateway.new(fixtures(:seerbit))
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

    assert_equal 'SEERBIT586217191602884005900', response.authorization
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
        <<-'PRE_SCRUBBED'
    opening connection to seerbitapi.com:443...
opened
starting SSL for seerbitapi.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /api/v2/payments/charge HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic U0JURVNUUFVCS183MFFoSkFONTc1eFAyZXdsYjRnWTdsc284SWcydWxjQzpTQlRFU1RTRUNLX2ZWWTBYTUpqbDZCNm1DTXdSdVBSVWV4SWFkY0RCazdFYjM4NHlOY0k=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: seerbitapi.com\r\nContent-Length: 360\r\n\r\n"
<- "{\"amount\":\"100\",\"currency\":\"GHS\",\"country\":\"GH\",\"paymentReference\":\"4774a962-f952-49b4-800e-f55ad675bf91\",\"retry\":false,\"email\":null,\"fullName\":null,\"mobileNumber\":null,\"payment\":{},\"paymentType\":\"CARD\",\"cardNumber\":\"5123450000000008\",\"cvv\":100,\"expiryMonth\":\"5\",\"expiryYear\":\"21\",\"channelType\":\"visa\",\"publicKey\":\"SBTESTPUBK_70QhJAN575xP2ewlb4gY7lso8Ig2ulcC\"}"
-> "HTTP/1.1 201 OK\r\n"
-> "Date: Fri, 16 Oct 2020 21:40:04 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 292\r\n"
-> "Connection: close\r\n"
-> "X-Powered-By: seerbit\r\n"
-> "Access-Control-Allow-Methods: OPTIONS, GET, POST, PUT, DELETE, PATCH\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Server: Seerbit AS\r\n"
-> "\r\n"
reading 292 bytes...
-> "{\"status\":\"SUCCESS\",\"data\":{\"code\":\"00\",\"payments\":{\"paymentReference\":\"4774a962-f952-49b4-800e-f55ad675bf91\",\"linkingReference\":\"SEERBIT635764791602884399698\",\"status\":\"CAPTURED\",\"card\":{\"bin\":\"512345\",\"last4\":\"0008\",\"token\":\"tk_c83abb5d-b07a-4e22-a86a-17fe393d138c\"}},\"message\":\"APPROVED\"}}"
read 292 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-'PRE_SCRUBBED'
    opening connection to seerbitapi.com:443...
opened
starting SSL for seerbitapi.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /api/v2/payments/charge HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: seerbitapi.com\r\nContent-Length: 360\r\n\r\n"
<- "{\"amount\":\"100\",\"currency\":\"GHS\",\"country\":\"GH\",\"paymentReference\":\"4774a962-f952-49b4-800e-f55ad675bf91\",\"retry\":false,\"email\":null,\"fullName\":null,\"mobileNumber\":null,\"payment\":{},\"paymentType\":\"CARD\",\"cardNumber\":\"[FILTERED]\",\"cvv\":[FILTERED],\"expiryMonth\":\"5\",\"expiryYear\":\"21\",\"channelType\":\"visa\",\"publicKey\":\"SBTESTPUBK_70QhJAN575xP2ewlb4gY7lso8Ig2ulcC\"}"
-> "HTTP/1.1 201 OK\r\n"
-> "Date: Fri, 16 Oct 2020 21:40:04 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 292\r\n"
-> "Connection: close\r\n"
-> "X-Powered-By: seerbit\r\n"
-> "Access-Control-Allow-Methods: OPTIONS, GET, POST, PUT, DELETE, PATCH\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Server: Seerbit AS\r\n"
-> "\r\n"
reading 292 bytes...
-> "{\"status\":\"SUCCESS\",\"data\":{\"code\":\"00\",\"payments\":{\"paymentReference\":\"4774a962-f952-49b4-800e-f55ad675bf91\",\"linkingReference\":\"SEERBIT635764791602884399698\",\"status\":\"CAPTURED\",\"card\":{\"bin\":\"512345\",\"last4\":\"0008\",\"token\":\"tk_c83abb5d-b07a-4e22-a86a-17fe393d138c\"}},\"message\":\"APPROVED\"}}"
read 292 bytes
Conn close
    PRE_SCRUBBED
  end

  def successful_purchase_response
    {
      "status":"SUCCESS",
      "data":{
        "code":"00",
        "payments":{
          "paymentReference":"08d8451d-0cb8-49cc-ab00-9015cda018b0",
          "linkingReference":"SEERBIT586217191602884005900",
          "status":"CAPTURED",
          "card":{
            "bin":"512345",
            "last4":"0008",
            "token":"tk_65051df2-e97b-4843-89b1-bac27af7a9f0"
          }
        },
        "message":"APPROVED"
      }
    }.to_json
  end
end
