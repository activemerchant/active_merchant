require 'test_helper'

class BamboraNaTest < Test::Unit::TestCase
  def setup
    @gateway = BamboraNaGateway.new(merchant_id: 'login', api_key: 'password')
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

    assert_equal '10000050|TEST', response.authorization
    assert_equal 'Approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).raises(ActiveMerchant::ResponseError.new(failed_purchase_response))

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    
    response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'a63-155e2ad3-3b1f-41b9-ae5f-85fb6870f958', response.authorization
  end

  private

  def pre_scrubbed
    %q(
opening connection to api.na.bambora.com:443...
opened
starting SSL for api.na.bambora.com:443...
SSL established
<- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Passcode c2Vrcml0LXNxdWlycmVs\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.na.bambora.com\r\nContent-Length: 346\r\n\r\n"
<- "{\"amount\":\"1.00\",\"payment_method\":\"card\",\"order_number\":\"4b158d652109ebc82560\",\"card\":{\"number\":\"4030000010001234\",\"expiry_month\":\"09\",\"expiry_year\":\"19\",\"name\":\"Longbob Longsen\",\"cvd\":\"123\",\"complete\":true},\"billing\":{\"address_line1\":\"456 My Street\",\"address_line2\":\"Apt 1\",\"city\":\"Ottawa\",\"province\":\"ON\",\"postal_code\":\"K1C2N6\",\"country\":\"CA\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Pragma: no-cache\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Expires: -1\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Headers: accept, origin, content-type\r\n"
-> "X-UA-Compatible: IE=edge,chrome=1\r\n"
-> "Date: Wed, 24 Jan 2018 00:49:44 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 726\r\n"
-> "\r\n"
reading 726 bytes...
-> "{\"id\":\"10000050\",\"authorizing_merchant_id\":293110000,\"approved\":\"1\",\"message_id\":\"1\",\"message\":\"Approved\",\"auth_code\":\"TEST\",\"created\":\"2018-01-23T19:49:44\",\"order_number\":\"4b158d652109ebc82560\",\"type\":\"P\",\"payment_method\":\"CC\",\"risk_score\":0.0,\"amount\":1.00,\"custom\":{\"ref1\":\"\",\"ref2\":\"\",\"ref3\":\"\",\"ref4\":\"\",\"ref5\":\"\"},\"card\":{\"card_type\":\"VI\",\"last_four\":\"1234\",\"address_match\":0,\"postal_result\":0,\"avs_result\":\"0\",\"cvd_result\":\"1\",\"avs\":{\"id\":\"N\",\"message\":\"Street address and Postal/ZIP do not match.\",\"processed\":true}},\"links\":[{\"rel\":\"void\",\"href\":\"https://api.na.bambora.com/v1/payments/10000050/void\",\"method\":\"POST\"},{\"rel\":\"return\",\"href\":\"https://api.na.bambora.com/v1/payments/10000050/returns\",\"method\":\"POST\"}]}"
read 726 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to api.na.bambora.com:443...
opened
starting SSL for api.na.bambora.com:443...
SSL established
<- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Passcode [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.na.bambora.com\r\nContent-Length: 346\r\n\r\n"
<- "{\"amount\":\"1.00\",\"payment_method\":\"card\",\"order_number\":\"4b158d652109ebc82560\",\"card\":{\"number\":\"[FILTERED]\",\"expiry_month\":\"09\",\"expiry_year\":\"19\",\"name\":\"Longbob Longsen\",\"cvd\":\"[FILTERED]\",\"complete\":true},\"billing\":{\"address_line1\":\"456 My Street\",\"address_line2\":\"Apt 1\",\"city\":\"Ottawa\",\"province\":\"ON\",\"postal_code\":\"K1C2N6\",\"country\":\"CA\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Pragma: no-cache\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Expires: -1\r\n"
-> "Server: Microsoft-IIS/8.5\r\n"
-> "X-AspNet-Version: 4.0.30319\r\n"
-> "X-Powered-By: ASP.NET\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Headers: accept, origin, content-type\r\n"
-> "X-UA-Compatible: IE=edge,chrome=1\r\n"
-> "Date: Wed, 24 Jan 2018 00:49:44 GMT\r\n"
-> "Connection: close\r\n"
-> "Content-Length: 726\r\n"
-> "\r\n"
reading 726 bytes...
-> "{\"id\":\"10000050\",\"authorizing_merchant_id\":293110000,\"approved\":\"1\",\"message_id\":\"1\",\"message\":\"Approved\",\"auth_code\":\"TEST\",\"created\":\"2018-01-23T19:49:44\",\"order_number\":\"4b158d652109ebc82560\",\"type\":\"P\",\"payment_method\":\"CC\",\"risk_score\":0.0,\"amount\":1.00,\"custom\":{\"ref1\":\"\",\"ref2\":\"\",\"ref3\":\"\",\"ref4\":\"\",\"ref5\":\"\"},\"card\":{\"card_type\":\"VI\",\"last_four\":\"1234\",\"address_match\":0,\"postal_result\":0,\"avs_result\":\"0\",\"cvd_result\":\"1\",\"avs\":{\"id\":\"N\",\"message\":\"Street address and Postal/ZIP do not match.\",\"processed\":true}},\"links\":[{\"rel\":\"void\",\"href\":\"https://api.na.bambora.com/v1/payments/10000050/void\",\"method\":\"POST\"},{\"rel\":\"return\",\"href\":\"https://api.na.bambora.com/v1/payments/10000050/returns\",\"method\":\"POST\"}]}"
read 726 bytes
Conn close
    )
  end

  def successful_purchase_response
    '{
      "amount": 1.0,
      "approved": "1",
      "auth_code": "TEST",
      "authorizing_merchant_id": 293110000,
      "card": {
          "address_match": 0,
          "avs": {
              "id": "N",
              "message": "Street address and Postal/ZIP do not match.",
              "processed": true
          },
          "avs_result": "0",
          "card_type": "VI",
          "cvd_result": "1",
          "last_four": "1234",
          "postal_result": 0
      },
      "created": "2018-01-23T19:49:44",
      "custom": {
          "ref1": "",
          "ref2": "",
          "ref3": "",
          "ref4": "",
          "ref5": ""
      },
      "id": "10000050",
      "links": [
          {
              "href": "https://api.na.bambora.com/v1/payments/10000050/void",
              "method": "POST",
              "rel": "void"
          },
          {
              "href": "https://api.na.bambora.com/v1/payments/10000050/returns",
              "method": "POST",
              "rel": "return"
          }
      ],
      "message": "Approved",
      "message_id": "1",
      "order_number": "4b158d652109ebc82560",
      "payment_method": "CC",
      "risk_score": 0.0,
      "type": "P"
    }'
  end

  def failed_purchase_response
    body = '{
      "code": 7,
      "category": 1,
      "message": "DECLINE",
      "reference": ""
    }'

    MockResponse.failed(body)
  end

  def successful_store_response
    '{
      "token": "a63-155e2ad3-3b1f-41b9-ae5f-85fb6870f958",
      "code": 1,
      "version": 1,
      "message": ""
    }'
  end

end
