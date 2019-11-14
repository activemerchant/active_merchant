require 'test_helper'

class BlackbaudPaymentRestTest < Test::Unit::TestCase
  def setup
    @gateway = BlackbaudPaymentRestGateway.new(api_key: 'foo', api_token: 'bearer', merchant_id: 'bar')
    @credit_card = credit_card('4242424242424242')
    @amount = 1000

    @options = {
      first_name: 'Longbob',
      last_name: 'Longsen',
      address: address
    }
  end

  def test_successful_store
    @gateway.expects(:ssl_request).returns(successful_store_response)
    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal 'a792c852-9046-4a8d-884a-6915d742a789', response.authorization
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal '280e7cc2-2c39-4040-8fbb-84a29935e801', response.authorization
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

def pre_scrubbed
  <<-'PRE_SCRUBBED'
  opening connection to api.sky.blackbaud.com:443...\n
  opened
starting SSL for api.sky.blackbaud.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
<- "POST /payments/v1/transactions HTTP/1.1\r\nContent-Type: application/json\r\nX-Accepts: application/json\r\nUser-Agent: ActiveMerchant/1.78.0\r\nX-Client-Ip: \r\nBb-Api-Subscription-Key: 24443892534c48b39499de3be0ec72e4\r\nAuthorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6IjREVjZzVkxIM0FtU1JTbUZqMk04Wm5wWHU3WSJ9.eyJuYW1laWQiOiI4M2FmNmNhZi1mZWQwLTQ2YmMtODc4OC1iNTY4ZGE3NjI1M2UiLCJhcHBsaWNhdGlvbmlkIjoiYTkxODA4ZWMtZGU4Zi00Y2JhLWFkNDEtMDU2NzUyOGRmN2Y4IiwiZW52aXJvbm1lbnRpZCI6InAtZXBRSUpmc0NfVXFsemV3MkdZZVVsQSIsImVudmlyb25tZW50bmFtZSI6IlNPUyBDaGlsZHJlblx1MDAyN3MgVmlsbGFnZXMgQ2FuYWRhIEVudmlyb25tZW50IDEiLCJsZWdhbGVudGl0eWlkIjoicC13MFE2UWRMMmZFQ3ZXLVdSLVFCdmtRIiwibGVnYWxlbnRpdHluYW1lIjoiU09TIENoaWxkcmVuXHUwMDI3cyBWaWxsYWdlcyBDYW5hZGEiLCJpc3MiOiJodHRwczovL29hdXRoMi5za3kuYmxhY2tiYXVkLmNvbS8iLCJhdWQiOiJibGFja2JhdWQiLCJleHAiOjE1NzMwNTk5MDYsIm5iZiI6MTU3MzA1NjMwNn0.AUw_CpJEN_t6b0cqeURfxeAd0CT0yxB2PZh3tDktWltepILLNHhKyQDM-wQXBsQTt2vJldJqpU4UWijTBKTjQy9nnLlhoRSTjVcbyDIB--VXePqEIp1p3b611wqYmFZpMGHXA07VbN9GubjJwhj8knRwIj4ALMAoyqmJ3Gdb4SIvmyj-WRdBjmGXzm337i9wSKxrfZ6zpOrdDfCDbpaiSGlroNEnN_xaI8YQ5yCTdEMLhdLLirNOjK7BcpSv2Ds053cDrSwG7bt494iJm40R67t2q1F_bMZdGfXI_vtE7SDoz2tetaDHXWrh3Gk7mcu3rMxQGuhtF695KIOBER7IKA\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.sky.blackbaud.com\r\nContent-Length: 412\r\n\r\n"
<- "{\"payment_configuration_id\":\"8a998a48-8770-4dc8-b31f-5d26fff5f6cd\",\"amount\":\"1000\",\"transaction_id\":null,\"email\":null,\"phone\":null,\"comment\":null,\"credit_card\":{\"exp_month\":9,\"exp_year\":2020,\"name\":\"Longbob Longsen\",\"number\":\"4242424242424242\"},\"csc\":null,\"billing_contact\":{\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"address\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\",\"post_code\":\"K1C2N6\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Pragma: no-cache\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Expires: -1\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Request-Context: appId=cid-v1:7c79702c-183f-4ce4-88bc-c966ef838843\r\n"
-> "Date: Wed, 06 Nov 2019 16:09:40 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
-> "1E4\r\n"
reading 484 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\x85R\xC1n\x9C0\x10\xFD\x15\xE4k\x17\x05\xB3\xEC\xB6\xCBm\x95\\\xAA6\xC9J\x95z\xB5\x06<,V\x8C\a\xD9&\r\x8A\xF2\xEF\x1DC\xB6m\xAAF\xF5\x01\xCB\xCFof\xDE{\xF8YDz@'jQ\xBC\xAE\xFC\x1F\x9F\xCB\x12\ea4s\xF7\x12;\x89\xBB&\xC7}U\xE6\xD5\xB6\xDA\xE6Pj\xC8?\x16\xBB\xC3\x0E+YT\xBAa.\f4\xB9(j\xC9\xA5\e\x11=\xB8\x00m4\xE4T\x9CG\xE4>\xD7\xE0\xF5\x1D\xC5\x93\xC7\x80L\xDC\x88\xD6\xA36Q\xB5\x8C\x8B\xFAY\xA4\xFD\xC2\xFDn\x020\x03\x9FF5\x90\x8B\xBD\xA8\x0F\xEBiF\xF0\xA2.\x8B\x92gX\bQu41 \xAA\xB2*\xB9\xC0\xC1\x90\xCA\xBF\x92;7\xD4di\xE7a\xE2\x85\xE5i\x9E\xC5j\xC0\xAA\x0E\x99\xC3\xF5\xED\xE4=\xBAvN\xDA\x8E7\xC9\xC28Z\xD3B\xA21v\x82y`\xA1!;\x9E>'\xB54\xA4#_\x88\xB7\xF64\xC44S\xCA\xAB\xFDUY\xC8C&e]\x1C\xEA\xED\xA7\xECx\x9B}(\x8Az\x89R\x93#\xAF\xCC\xA8X\b'\x10\xD6>8\x80\xB1o\xA1\xB1'\x87\xCAMC\x83~ELP\xD6<\xF2\x8C\x0El@neB3\xF9\x80I\x8E\n\x11\xE2\x94J9\xDA\x9B\xF5\x02\x1A\x8B\\\xD6\x18k\x8D;+\xE3:Z\xF251Y\xBD\x8F\x11~\xC0b\x88\xFF\x97_\xDC\x83\x03\x9D\xA0\x918\xD1\x96t\xF2\xF3E^\x97w{\x06\xD3\x84\x04\xDC\xBB\b\xDE\xD0\x82x\xC4\x94D\xB5\xDBg\xB7s\xF6m=s\xCA\x9D\x87I+63\xD9\x98f\x82#7\xF3\xC3\bj\xF4\xF44\xFF\xBA\x11\xCBC\xA0\x96]\xA3^\xB4:\x05N\xA7|^e\xBDK\xED\xCD\xB9W\xDE\x84\x87\xFF2W\xFC\xE2\xE7\xEF\xCB\xD4!\xB4\xE4\xD7\xB7\xB0\x1Cc\xCF%=Y\xBD@\x8Fh)e\xF6N\xFF\x97\xDF\xC9\xFC\x01\xFE\x04\xE0\xBA4Nc\x03\x00\x00"
read 484 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
  PRE_SCRUBBED
  end

  def post_scrubbed
    <<-'POS_SCRUBBED'
  opening connection to api.sky.blackbaud.com:443...\n
  opened
starting SSL for api.sky.blackbaud.com:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
<- "POST /payments/v1/transactions HTTP/1.1\r\nContent-Type: application/json\r\nX-Accepts: application/json\r\nUser-Agent: ActiveMerchant/1.78.0\r\nX-Client-Ip: \r\nBb-Api-Subscription-Key: [FILTERED]\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.sky.blackbaud.com\r\nContent-Length: 412\r\n\r\n"
<- "{\"payment_configuration_id\":\"[FILTERED]\",\"amount\":\"1000\",\"transaction_id\":null,\"email\":null,\"phone\":null,\"comment\":null,\"credit_card\":{\"exp_month\":9,\"exp_year\":2020,\"name\":\"Longbob Longsen\",\"number\":\"[FILTERED]\"},\"csc\":null,\"billing_contact\":{\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"address\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\",\"post_code\":\"K1C2N6\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Pragma: no-cache\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Content-Type: application/json; charset=utf-8\r\n"
-> "Content-Encoding: gzip\r\n"
-> "Expires: -1\r\n"
-> "Vary: Accept-Encoding\r\n"
-> "Request-Context: appId=cid-v1:7c79702c-183f-4ce4-88bc-c966ef838843\r\n"
-> "Date: Wed, 06 Nov 2019 16:09:40 GMT\r\n"
-> "Connection: close\r\n"
-> "\r\n"
-> "1E4\r\n"
reading 484 bytes...
-> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\x85R\xC1n\x9C0\x10\xFD\x15\xE4k\x17\x05\xB3\xEC\xB6\xCBm\x95\\\xAA6\xC9J\x95z\xB5\x06<,V\x8C\a\xD9&\r\x8A\xF2\xEF\x1DC\xB6m\xAAF\xF5\x01\xCB\xCFof\xDE{\xF8YDz@'jQ\xBC\xAE\xFC\x1F\x9F\xCB\x12\ea4s\xF7\x12;\x89\xBB&\xC7}U\xE6\xD5\xB6\xDA\xE6Pj\xC8?\x16\xBB\xC3\x0E+YT\xBAa.\f4\xB9(j\xC9\xA5\e\x11=\xB8\x00m4\xE4T\x9CG\xE4>\xD7\xE0\xF5\x1D\xC5\x93\xC7\x80L\xDC\x88\xD6\xA36Q\xB5\x8C\x8B\xFAY\xA4\xFD\xC2\xFDn\x020\x03\x9FF5\x90\x8B\xBD\xA8\x0F\xEBiF\xF0\xA2.\x8B\x92gX\bQu41 \xAA\xB2*\xB9\xC0\xC1\x90\xCA\xBF\x92;7\xD4di\xE7a\xE2\x85\xE5i\x9E\xC5j\xC0\xAA\x0E\x99\xC3\xF5\xED\xE4=\xBAvN\xDA\x8E7\xC9\xC28Z\xD3B\xA21v\x82y`\xA1!;\x9E>'\xB54\xA4#_\x88\xB7\xF64\xC44S\xCA\xAB\xFDUY\xC8C&e]\x1C\xEA\xED\xA7\xECx\x9B}(\x8Az\x89R\x93#\xAF\xCC\xA8X\b'\x10\xD6>8\x80\xB1o\xA1\xB1'\x87\xCAMC\x83~ELP\xD6<\xF2\x8C\x0El@neB3\xF9\x80I\x8E\n\x11\xE2\x94J9\xDA\x9B\xF5\x02\x1A\x8B\\\xD6\x18k\x8D;+\xE3:Z\xF251Y\xBD\x8F\x11~\xC0b\x88\xFF\x97_\xDC\x83\x03\x9D\xA0\x918\xD1\x96t\xF2\xF3E^\x97w{\x06\xD3\x84\x04\xDC\xBB\b\xDE\xD0\x82x\xC4\x94D\xB5\xDBg\xB7s\xF6m=s\xCA\x9D\x87I+63\xD9\x98f\x82#7\xF3\xC3\bj\xF4\xF44\xFF\xBA\x11\xCBC\xA0\x96]\xA3^\xB4:\x05N\xA7|^e\xBDK\xED\xCD\xB9W\xDE\x84\x87\xFF2W\xFC\xE2\xE7\xEF\xCB\xD4!\xB4\xE4\xD7\xB7\xB0\x1Cc\xCF%=Y\xBD@\x8Fh)e\xF6N\xFF\x97\xDF\xC9\xFC\x01\xFE\x04\xE0\xBA4Nc\x03\x00\x00"
read 484 bytes
reading 2 bytes...
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
  POS_SCRUBBED
  end
  

  def successful_store_response
    { "card_token" => "a792c852-9046-4a8d-884a-6915d742a789" }
  end

  def successful_purchase_response
    {
      "token":"00000000-0000-0000-0000-000000000000",
      "id":"280e7cc2-2c39-4040-8fbb-84a29935e801",
      "amount":1000,
      "transaction_type":"CardNotPresent",
      "credit_card":{
        "card_type":"Visa",
        "exp_month":9,
        "exp_year":2020,
        "last_four":"4242",
        "name":"Longbob Longsen"
      },
      "additional_fee":0,
      "currency":"CAD",
      "application":"Payments API",
      "comment":"",
      "transaction_date":"11/6/2019 10:21:58 AM +00:00",
      "donor_ip_address":"",
      "email_address":"",
      "phone_number":"",
      "is_live":false,
      "disbursement_status":"NotDisbursable",
      "billing_info":{
        "city":"Ottawa",
        "country":"Canada",
        "post_code":"K1C2N6",
        "state":"Ontario",
        "street":"456 My Street"
      },
      "fraud_result":{
        "anonymous_proxy_result":"NotProcessed",
        "bin_and_ip_country_result":"NotProcessed",
        "high_risk_country_result":"NotProcessed",
        "result_code":"NotProcessed",
        "risk_score":0,
        "risk_threshold":0,"velocity_result":"NotProcessed"
      },
      "state":"Processed"
    }
  end
end
