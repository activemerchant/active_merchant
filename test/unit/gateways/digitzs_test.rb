require 'test_helper'

class DigitzsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = DigitzsGateway.new(api_key: 'api_key', app_key: 'app_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      merchant_id: 'spreedly-susanswidg-32268973-2091076-148408385',
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @options_with_split = {
      merchant_id: 'spreedly-susanswidg-32268973-2091076-148408385',
      billing_address: address,
      description: 'Split Purchase',
      payment_type: 'card_split',
      split_amount: 100,
      split_merchant_id: 'spreedly-susanswidg-32270590-2095203-148657924'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_app_token_response, successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'spreedly-susanswidg-32268973-2091076-148408385-124-148606421', response.authorization
    assert response.test?
  end

  def test_successful_card_split_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options_with_split)
    end.check_request do |endpoint, data, headers|
      if data =~ /"cardSplit"/
        assert_match(%r(split), data)
        assert_match(%r("merchantId":"spreedly-susanswidg-32270590-2095203-148657924"), data)
      end
    end.respond_with(successful_app_token_response, successful_purchase_response)
    assert_success response

    assert_equal 'spreedly-susanswidg-32268973-2091076-148408385-124-148606421', response.authorization
  end

  def test_successful_token_split_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options_with_split)
    end.check_request do |endpoint, data, headers|
      if data =~ /"tokenSplit"/
        assert_match(%r(split), data)
        assert_match(%r("merchantId":"spreedly-susanswidg-32270590-2095203-148657924"), data)
      end
    end.respond_with(successful_app_token_response, successful_purchase_response)
    assert_success response

    assert_equal 'spreedly-susanswidg-32268973-2091076-148408385-124-148606421', response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_app_token_response, failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "58", response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).times(2).returns(successful_app_token_response, successful_refund_response)

    response = @gateway.refund(@amount, "authorization", @options)
    assert_success response

    assert_equal 'spreedly-susanswidg-32268973-2091076-148408385-127-148606617', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).times(2).returns(successful_app_token_response, failed_refund_response)

    response = @gateway.refund(@amount, "", @options)
    assert_failure response

    assert_equal nil, response.authorization
    assert response.test?
  end

  def test_successful_store
    @gateway.expects(:ssl_post).times(3).returns(successful_app_token_response, successful_create_customer_response, successful_token_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "spreedly-susanswidg-32268973-2091076-148408385-2894006614343495-148710226|c0302d83-a694-4bec-9086-d1886b9eefd9-148710226", response.authorization
  end

  def test_successful_store_creates_new_customer
    @gateway.expects(:ssl_get).returns(customer_id_exists_response)
    @gateway.expects(:ssl_post).times(3).returns(successful_app_token_response, successful_create_customer_response, successful_token_response)

    assert response = @gateway.store(@credit_card, @options.merge({customer_id: "pre_existing_customer_id"}))
    assert_success response
    assert_equal "spreedly-susanswidg-32268973-2091076-148408385-2894006614343495-148710226|c0302d83-a694-4bec-9086-d1886b9eefd9-148710226", response.authorization
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
opening connection to beta.digitzsapi.com:443...
opened
starting SSL for beta.digitzsapi.com:443...
SSL established
<- "POST /sandbox/auth/token HTTP/1.1\r\nContent-Type: application/json\r\nX-Api-Key: 0HhRdOU2AsWVEu3gRIKi2UpMMmj8Fj48qggBYTo4\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: beta.digitzsapi.com\r\nContent-Length: 115\r\n\r\n"
<- "{\"data\":{\"attributes\":{\"appKey\":\"tcwtTux8SPZYO44Gf0UHZH74Z1HSutqCxmIV2PFj2jRc9Poroh3Z3R1BBQNRQ98Q\"},\"type\":\"auth\"}}"
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 434\r\n"
-> "Connection: close\r\n"
-> "Date: Fri, 27 Jan 2017 20:47:32 GMT\r\n"
-> "Content-Location: https://beta.digitzsapi.com/sandbox/auth/token\r\n"
-> "x-amzn-RequestId: d3637ff0-e4d1-11e6-a393-3dbd03385fb7\r\n"
-> "X-Amzn-Trace-Id: Root=1-588bb1e4-49acd61c62e319bc67e443d8\r\n"
-> "Via: 1.1 344c0192a2becdfa5c3c6b927653ff8b.cloudfront.net (CloudFront), 1.1 986a2cb4ab6fb48c9a4379a4e9d691c4.cloudfront.net (CloudFront)\r\n"
-> "X-Cache: Miss from cloudfront\r\n"
-> "X-Amz-Cf-Id: NfmaknL15LfaGNXlXtc2mhwFwpzNHMbNExCfsMxORdRF7t3bbc77vA==\r\n"
-> "\r\n"
reading 434 bytes...
-> "{\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/auth/token\"},\"data\":{\"type\":\"auth\",\"id\":\"0HhRdOU2AsWVEu3gRIKi2UpMMmj8Fj48qggBYTo4\",\"attributes\":{\"appToken\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwYXJ0bmVySWQiOiJzcHJlZWRseS0xNDgyMzAxOTEiLCJwYXJ0bmVyUHJlZml4Ijoic3ByZWVkbHkiLCJwcm9wYXlUaWVyIjoiU2V0TGlzdGVyIiwicHJvcGF5TWNjIjoiNTk5OSIsImlhdCI6MTQ4NTU1MDA1MiwiZXhwIjoxNDg1NTUzNjUyfQ.P2gunlNF56IKbAKpnRci7vLgUK0Yd7K1PGPzTtYP3Nc\"}}}"
read 434 bytes
Conn close
opening connection to beta.digitzsapi.com:443...
opened
starting SSL for beta.digitzsapi.com:443...
SSL established
<- "POST /sandbox/payments HTTP/1.1\r\nContent-Type: application/json\r\nX-Api-Key: 0HhRdOU2AsWVEu3gRIKi2UpMMmj8Fj48qggBYTo4\r\nAuthorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwYXJ0bmVySWQiOiJzcHJlZWRseS0xNDgyMzAxOTEiLCJwYXJ0bmVyUHJlZml4Ijoic3ByZWVkbHkiLCJwcm9wYXlUaWVyIjoiU2V0TGlzdGVyIiwicHJvcGF5TWNjIjoiNTk5OSIsImlhdCI6MTQ4NTU1MDA1MiwiZXhwIjoxNDg1NTUzNjUyfQ.P2gunlNF56IKbAKpnRci7vLgUK0Yd7K1PGPzTtYP3Nc\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: beta.digitzsapi.com\r\nContent-Length: 430\r\n\r\n"
<- "{\"data\":{\"attributes\":{\"paymentType\":\"card\",\"merchantId\":\"spreedly-susanswidg-32268973-2091076-148408385\",\"card\":{\"holder\":\"Longbob Longsen\",\"number\":\"4747474747474747\",\"expiry\":\"0918\",\"code\":\"999\"},\"transaction\":{\"amount\":\"200\",\"currency\":\"USD\",\"invoice\":\"91bbccdd926ab8effc53bc7be094bd2b\"},\"billingAddress\":{\"line1\":\"456 My Street\",\"line2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country\":\"US\"}},\"type\":\"payments\"}}"
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 504\r\n"
-> "Connection: close\r\n"
-> "Date: Fri, 27 Jan 2017 20:47:35 GMT\r\n"
-> "Content-Location: https://beta.digitzsapi.com/sandbox/payments/spreedly-susanswidg-32268973-2091076-148408385-88-148555005\r\n"
-> "x-amzn-RequestId: d3dcf5b4-e4d1-11e6-9d9a-59db6e3f8bc6\r\n"
-> "X-Amzn-Trace-Id: Root=1-588bb1e5-5c6481e9f44a8bd604900914\r\n"
-> "Via: 1.1 b06057d522f80c65400aebb1c06a2d72.cloudfront.net (CloudFront), 1.1 e6cb8f0dccd39d6bf4fcef2d892671bf.cloudfront.net (CloudFront)\r\n"
-> "X-Cache: Miss from cloudfront\r\n"
-> "X-Amz-Cf-Id: Q62cc8eH9XbSUl9No6Mp_xPS10ld0GQ8XN_S5uT4RdxkvUUA97a2kg==\r\n"
-> "\r\n"
reading 504 bytes...
-> "{\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/payments/spreedly-susanswidg-32268973-2091076-148408385-88-148555005\"},\"data\":{\"type\":\"payments\",\"id\":\"spreedly-susanswidg-32268973-2091076-148408385-88-148555005\",\"attributes\":{\"paymentType\":\"card\",\"transaction\":{\"code\":\"0\",\"message\":\"Success\",\"amount\":\"200\",\"invoice\":\"91bbccdd926ab8effc53bc7be094bd2b\",\"currency\":\"USD\",\"authCode\":\"A11111\",\"avsResult\":\"T\",\"codeResult\":\"M\",\"gross\":\"200\",\"net\":\"169\",\"grossMinusNet\":\"31\",\"fee\":\"25\",\"rate\":\"2.90\"}}}}"
read 504 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to beta.digitzsapi.com:443...
opened
starting SSL for beta.digitzsapi.com:443...
SSL established
<- "POST /sandbox/auth/token HTTP/1.1\r\nContent-Type: application/json\r\nX-Api-Key: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: beta.digitzsapi.com\r\nContent-Length: 115\r\n\r\n"
<- "{\"data\":{\"attributes\":{\"appKey\":\"[FILTERED]
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 434\r\n"
-> "Connection: close\r\n"
-> "Date: Fri, 27 Jan 2017 20:47:32 GMT\r\n"
-> "Content-Location: https://beta.digitzsapi.com/sandbox/auth/token\r\n"
-> "x-amzn-RequestId: d3637ff0-e4d1-11e6-a393-3dbd03385fb7\r\n"
-> "X-Amzn-Trace-Id: Root=1-588bb1e4-49acd61c62e319bc67e443d8\r\n"
-> "Via: 1.1 344c0192a2becdfa5c3c6b927653ff8b.cloudfront.net (CloudFront), 1.1 986a2cb4ab6fb48c9a4379a4e9d691c4.cloudfront.net (CloudFront)\r\n"
-> "X-Cache: Miss from cloudfront\r\n"
-> "X-Amz-Cf-Id: NfmaknL15LfaGNXlXtc2mhwFwpzNHMbNExCfsMxORdRF7t3bbc77vA==\r\n"
-> "\r\n"
reading 434 bytes...
-> "{\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/auth/token\"},\"data\":{\"type\":\"auth\",\"id\":\"[FILTERED]
read 434 bytes
Conn close
opening connection to beta.digitzsapi.com:443...
opened
starting SSL for beta.digitzsapi.com:443...
SSL established
<- "POST /sandbox/payments HTTP/1.1\r\nContent-Type: application/json\r\nX-Api-Key: [FILTERED]\r\nAuthorization: Bearer [FILTERED]
<- "{\"data\":{\"attributes\":{\"paymentType\":\"card\",\"merchantId\":\"spreedly-susanswidg-32268973-2091076-148408385\",\"card\":{\"holder\":\"Longbob Longsen\",\"number\":\"[FILTERED]\",\"expiry\":\"0918\",\"code\":\"[FILTERED]\"},\"transaction\":{\"amount\":\"200\",\"currency\":\"USD\",\"invoice\":\"91bbccdd926ab8effc53bc7be094bd2b\"},\"billingAddress\":{\"line1\":\"456 My Street\",\"line2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country\":\"US\"}},\"type\":\"payments\"}}"
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 504\r\n"
-> "Connection: close\r\n"
-> "Date: Fri, 27 Jan 2017 20:47:35 GMT\r\n"
-> "Content-Location: https://beta.digitzsapi.com/sandbox/payments/spreedly-susanswidg-32268973-2091076-148408385-88-148555005\r\n"
-> "x-amzn-RequestId: d3dcf5b4-e4d1-11e6-9d9a-59db6e3f8bc6\r\n"
-> "X-Amzn-Trace-Id: Root=1-588bb1e5-5c6481e9f44a8bd604900914\r\n"
-> "Via: 1.1 b06057d522f80c65400aebb1c06a2d72.cloudfront.net (CloudFront), 1.1 e6cb8f0dccd39d6bf4fcef2d892671bf.cloudfront.net (CloudFront)\r\n"
-> "X-Cache: Miss from cloudfront\r\n"
-> "X-Amz-Cf-Id: Q62cc8eH9XbSUl9No6Mp_xPS10ld0GQ8XN_S5uT4RdxkvUUA97a2kg==\r\n"
-> "\r\n"
reading 504 bytes...
-> "{\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/payments/spreedly-susanswidg-32268973-2091076-148408385-88-148555005\"},\"data\":{\"type\":\"payments\",\"id\":\"[FILTERED]
read 504 bytes
Conn close
    )
  end

  def successful_app_token_response
    %(
      {\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/auth/token\"},\"data\":{\"type\":\"auth\",\"id\":\"0HhRdOU2AsWVEu3gRIKi2UpMMmj8Fj48qggBYTo4\",\"attributes\":{\"appToken\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwYXJ0bmVySWQiOiJzcHJlZWRseS0xNDgyMzAxOTEiLCJwYXJ0bmVyUHJlZml4Ijoic3ByZWVkbHkiLCJwcm9wYXlUaWVyIjoiU2V0TGlzdGVyIiwicHJvcGF5TWNjIjoiNTk5OSIsImlhdCI6MTQ4NjA2NDIxNiwiZXhwIjoxNDg2MDY3ODE2fQ.MaLR3ijeMuIGSHnNYINVILwa9hpxahd4U4Q44HW4jFQ\"}}}
    )
  end

  def successful_purchase_response
    %(
      {\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/payments/spreedly-susanswidg-32268973-2091076-148408385-124-148606421\"},\"data\":{\"type\":\"payments\",\"id\":\"spreedly-susanswidg-32268973-2091076-148408385-124-148606421\",\"attributes\":{\"paymentType\":\"card\",\"transaction\":{\"code\":\"0\",\"message\":\"Success\",\"amount\":\"200\",\"invoice\":\"42d7b1d026becf29e2005bae84e8935b\",\"currency\":\"USD\",\"authCode\":\"A11111\",\"avsResult\":\"T\",\"codeResult\":\"M\",\"gross\":\"200\",\"net\":\"169\",\"grossMinusNet\":\"31\",\"fee\":\"25\",\"rate\":\"2.90\"}}}}
    )
  end

  def successful_split_purchase_response
    %(
      {\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/payments/spreedly-susanswidg-32268973-2091076-148408385-153-148658575\"},\"data\":{\"type\":\"payments\",\"id\":\"spreedly-susanswidg-32268973-2091076-148408385-153-148658575\",\"attributes\":{\"paymentType\":\"cardSplit\",\"transaction\":{\"code\":\"0\",\"message\":\"Success\",\"amount\":\"500\",\"invoice\":\"88ec8adf6c86762684ae54820423acc8\",\"currency\":\"USD\",\"authCode\":\"A11111\",\"avsResult\":\"T\",\"codeResult\":\"M\"},\"split\":{\"merchantId\":\"spreedly-susanswidg-32270590-2095203-148657924\",\"amount\":\"100\",\"splitId\":\"spreedly-susanswidg-32270590-2095203-148657924-2-148658575\"}}}}
    )
  end


  def failed_purchase_response
    %(
      {\"meta\":{},\"errors\":[{\"status\":\"400\",\"source\":{\"pointer\":\"/payments\"},\"title\":\"Bad Request\",\"detail\":\"Partner error: Credit card declined (transaction element shows reason for decline)\",\"code\":\"58\",\"meta\":{\"debug\":{\"message\":\"Include debug info with support request.\",\"resource\":\"/payments POST\",\"log\":\"2017/02/02/[23]eb325f3ca78b4f7eb2178a0d1e635a0e\",\"request\":\"73c22dc3-e980-11e6-9390-69c24d5ed1f4\"},\"transaction\":{\"code\":\"51\",\"message\":\"Insufficient funds\",\"invoice\":\"3d1f247d9112349e3db252f9f3327047\",\"authCode\":\"A11111\",\"avsResult\":\"T\"}}}]}
    )
  end

  def successful_refund_response
    %(
      {\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/payments/spreedly-susanswidg-32268973-2091076-148408385-127-148606617\"},\"data\":{\"type\":\"payments\",\"id\":\"spreedly-susanswidg-32268973-2091076-148408385-127-148606617\",\"attributes\":{\"paymentType\":\"cardRefund\",\"transaction\":{\"code\":\"0\",\"message\":\"Success\",\"amount\":\"200\",\"invoice\":\"f87139e53b5273c12bc32d4be6fff9a8\",\"currency\":\"USD\"}}}}
    )
  end

  def failed_refund_response
    %(
      {\"meta\":{},\"errors\":[{\"status\":\"400\",\"source\":{\"pointer\":\"/data/attributes/originalTransaction/id\"},\"title\":\"Bad Request\",\"detail\":\"\\\"id\\\" is not allowed to be empty\"}]}
    )
  end

  def successful_create_customer_response
    %(
      {\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/customers/spreedly-susanswidg-32268973-2091076-148408385-2894006614343495-148710226\"},\"data\":{\"type\":\"customers\",\"id\":\"spreedly-susanswidg-32268973-2091076-148408385-2894006614343495-148710226\",\"attributes\":{\"name\":\"Longbob Longsen\",\"externalId\":\"2b942bae49e9297f60428ee841f30724\"}}}
    )
  end

  def successful_token_response
    %(
      {\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/tokens/c0302d83-a694-4bec-9086-d1886b9eefd9-148710226\"},\"data\":{\"type\":\"tokens\",\"id\":\"c0302d83-a694-4bec-9086-d1886b9eefd9-148710226\",\"attributes\":{\"label\":\"Credit Card\",\"customerId\":\"spreedly-susanswidg-32268973-2091076-148408385-2894006614343495-148710226\"}}}
    )
  end

  def customer_id_exists_response
    %(
      {\"links\":{\"self\":\"https://beta.digitzsapi.com/sandbox/customers/spreedly-susanswidg-32268973-2091076-148408385-5980208887457495-148700575\"},\"data\":{\"id\":\"spreedly-susanswidg-32268973-2091076-148408385-5980208887457495-148700575\",\"attributes\":{\"merchantId\":\"spreedly-susanswidg-32268973-2091076-148408385\",\"created\":\"2017-02-13T17:09:12.724Z\",\"name\":\"Jon Doe\",\"externalId\":\"123456\"},\"type\":\"customers\"}}
    )
  end
end
