require 'test_helper'

class MoneiTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = MoneiGateway.new(
      fixtures(:monei)
    )

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

    assert_equal '067574158f1f42499c31404752d52d06', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_capture_response)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_post).returns(successful_refund_response)

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_post).returns(successful_void_response)

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
  end

  def test_3ds_request
    authentication_eci = '05'
    authentication_cavv = 'AAACAgSRBklmQCFgMpEGAAAAAAA='
    authentication_xid = 'CAACCVVUlwCXUyhQNlSXAAAAAAA='

    three_d_secure_options = {
      eci: authentication_eci,
      cavv: authentication_cavv,
      xid: authentication_xid
    }
    options = @options.merge!({
      three_d_secure: three_d_secure_options
    })
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"eci\":\"#{authentication_eci}\"/, data)
      assert_match(/\"cavv\":\"#{authentication_cavv}\"/, data)
      assert_match(/\"xid\":\"#{authentication_xid}\"/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_sending_cardholder_name
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal @credit_card.name, JSON.parse(data)['paymentMethod']['card']['cardholderName']
    end.respond_with(successful_purchase_response)
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_scrubs_auth_data
    assert_equal @gateway.scrub(pre_scrubbed_with_auth), post_scrubbed_with_auth
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  private

  def successful_purchase_response
    <<-RESPONSE
    {
      "id": "067574158f1f42499c31404752d52d06",
      "amount": 110,
      "currency": "EUR",
      "orderId": "1",
      "accountId": "00000000-aaaa-bbbb-cccc-dddd123456789",
      "status": "SUCCEEDED",
      "statusMessage": "Transaction Approved",
      "signature": "3dc52e4dbcc15cee5bb03cb7e3ab90708bf8b8a21818c0262ac05ec0c01780d0"
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "status": "error",
      "message": "Card number declined by processor"
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "id": "067574158f1f42499c31404752d52d06",
      "amount": 110,
      "currency": "EUR",
      "orderId": "1",
      "accountId": "00000000-aaaa-bbbb-cccc-dddd123456789",
      "status": "AUTHORIZED",
      "statusMessage": "Transaction Approved",
      "signature": "3dc52e4dbcc15cee5bb03cb7e3ab90708bf8b8a21818c0262ac05ec0c01780d0"
    }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    {
      "status": "error",
      "message": "Card number declined by processor"
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "id": "067574158f1f42499c31404752d52d06",
      "amount": 110,
      "currency": "EUR",
      "orderId": "1",
      "accountId": "00000000-aaaa-bbbb-cccc-dddd123456789",
      "status": "SUCCEEDED",
      "statusMessage": "Transaction Approved",
      "signature": "3dc52e4dbcc15cee5bb03cb7e3ab90708bf8b8a21818c0262ac05ec0c01780d0"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "status": "error",
      "message": "Card number declined by processor"
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
      "id": "067574158f1f42499c31404752d52d06",
      "amount": 110,
      "currency": "EUR",
      "orderId": "1",
      "accountId": "00000000-aaaa-bbbb-cccc-dddd123456789",
      "status": "REFUNDED",
      "statusMessage": "Transaction Approved",
      "signature": "3dc52e4dbcc15cee5bb03cb7e3ab90708bf8b8a21818c0262ac05ec0c01780d0"
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "status": "error",
      "message": "Card number declined by processor"
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "id": "067574158f1f42499c31404752d52d06",
      "amount": 110,
      "currency": "EUR",
      "orderId": "1",
      "accountId": "00000000-aaaa-bbbb-cccc-dddd123456789",
      "status": "CANCELED",
      "statusMessage": "Transaction Approved",
      "signature": "3dc52e4dbcc15cee5bb03cb7e3ab90708bf8b8a21818c0262ac05ec0c01780d0"
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "status": "error",
      "message": "Card number declined by processor"
    }
    RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      <- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: pk_test_3cb2d54b7ee145fa92d683c01816ad15\r\nUser-Agent: MONEI/Shopify/0.1.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.monei.com\r\nContent-Length: 443\r\n\r\n"
      <- "{\"livemode\":\"false\",\"orderId\":\"66e0d04361fb7b401bec3b078744c21e\",\"transactionType\":\"AUTH\",\"description\":\"Store Purchase\",\"amount\":100,\"currency\":\"EUR\",\"paymentMethod\":{\"card\":{\"number\":\"5453010000059675\",\"expMonth\":\"12\",\"expYear\":\"34\",\"cvc\":\"123\"}},\"customer\":{\"email\":\"support@monei.com\",\"name\":\"Jim Smith\"},\"billingDetails\":{\"address\":{\"line1\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country\":\"CA\"}},\"sessionDetails\":{}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1069\r\n"
      -> "Connection: close\r\n"
      -> "Date: Mon, 05 Jul 2021 15:59:36 GMT\r\n"
      -> "x-amzn-RequestId: 75b637ff-f230-4522-b6c5-bc5b95495a55\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: CAPf6EPXjoEFdxA=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-60e32c65-625fbe465afdff1666fa4da9;Sampled=0\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 508a0f3451a34ff5e6a3963c94ef304d.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: MAD51-C3\r\n"
      -> "X-Amz-Cf-Id: SH_5SGGltcCwOgNwn4cnuZAYCa8__JZuUe5lj_Dnvkhigu2yB8M-SQ==\r\n"
      -> "\r\n"
      reading 1069 bytes...
      -> "{\"id\":\"cdc503654e76e29051bce6054e4b4d47dfb63edc\",\"amount\":100,\"currency\":\"EUR\",\"orderId\":\"66e0d04361fb7b401bec3b078744c21e\",\"description\":\"Store Purchase\",\"accountId\":\"00000000-aaaa-bbbb-cccc-dddd123456789\",\"authorizationCode\":\"++++++\",\"livemode\":false,\"status\":\"FAILED\",\"statusCode\":\"E501\",\"statusMessage\":\"Card rejected: invalid card number\",\"customer\":{\"name\":\"Jim Smith\",\"email\":\"support@monei.com\"},\"billingDetails\":{\"address\":{\"zip\":\"K1C2N6\",\"country\":\"CA\",\"state\":\"ON\",\"city\":\"Ottawa\",\"line1\":\"456 My Street\"}},\"sessionDetails\":{\"deviceType\":\"desktop\"},\"traceDetails\":{\"deviceType\":\"desktop\",\"sourceVersion\":\"0.1.0\",\"countryCode\":\"ES\",\"ip\":\"217.61.227.107\",\"userAgent\":\"MONEI/Shopify/0.1.0\",\"source\":\"MONEI/Shopify\",\"lang\":\"en\"},\"createdAt\":1625500773,\"updatedAt\":1625500776,\"paymentMethod\":{\"method\":\"card\",\"card\":{\"country\":\"US\",\"last4\":\"9675\",\"threeDSecure\":false,\"expiration\":2048544000,\"type\":\"credit\",\"brand\":\"mastercard\"}},\"nextAction\":{\"type\":\"COMPLETE\",\"redirectUrl\":\"https://secure.monei.com/payments/cdc503654e76e29051bce6054e4b4d47dfb63edc/receipt\"}}"
      read 1069 bytes
      Conn close
    PRE_SCRUBBED
  end

  def pre_scrubbed_with_auth
    <<-PRE_SCRUBBED_WITH_AUTH
      <- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: pk_test_3cb2d54b7ee145fa92d683c01816ad15\r\nUser-Agent: MONEI/Shopify/0.1.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.monei.com\r\nContent-Length: 1063\r\n\r\n"
      <- "{\"livemode\":\"false\",\"orderId\":\"851925032d391d67e3fbf70b06aa182d\",\"transactionType\":\"SALE\",\"description\":\"Store Purchase\",\"amount\":100,\"currency\":\"EUR\",\"paymentMethod\":{\"card\":{\"number\":\"4444444444444406\",\"expMonth\":\"12\",\"expYear\":\"34\",\"cvc\":\"123\",\"auth\":{\"threeDSVersion\":null,\"eci\":\"05\",\"cavv\":\"AAACAgSRBklmQCFgMpEGAAAAAAA=\",\"dsTransID\":\"7eac9571-3533-4c38-addd-00cf34af6a52\",\"directoryResponse\":null,\"authenticationResponse\":null,\"notificationUrl\":\"https://example.com/notification\"}}},\"customer\":{\"email\":\"support@monei.com\",\"name\":\"Jim Smith\"},\"billingDetails\":{\"address\":{\"line1\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country\":\"CA\"}},\"sessionDetails\":{\"ip\":\"77.110.174.153\",\"userAgent\":\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36\",\"browserAccept\":\"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,application/json\",\"browserColorDepth\":\"100\",\"lang\":\"US\",\"browserScreenHeight\":\"1000\",\"browserScreenWidth\":\"500\",\"browserTimezoneOffset\":\"-120\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 253\r\n"
      -> "Connection: close\r\n"
      -> "Date: Mon, 05 Jul 2021 15:59:59 GMT\r\n"
      -> "x-amzn-RequestId: ac5a5ec8-6dd4-4254-a28a-8e9fa652ba90\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: CAPj7FFfDoEFXOQ=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-60e32c7f-690a46280dc8da307f679795;Sampled=0\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 1868e2f5b79bbf25cd21cd4b652be313.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: MAD51-C3\r\n"
      -> "X-Amz-Cf-Id: RVunC63Qvaswh2fcVB5n0p0BB_1zxbMOx68nuq5m6GKhWUFPpfAgVQ==\r\n"
      -> "\r\n"
      reading 253 bytes...
      -> "{\"id\":\"e1310ab50f7cf1dcf87f1ae75b2ed0fbd2a4d05f\",\"amount\":100,\"currency\":\"EUR\",\"orderId\":\"851925032d391d67e3fbf70b06aa182d\",\"accountId\":\"00000000-aaaa-bbbb-cccc-dddd123456789\",\"liveMode\":false,\"status\":\"SUCCEEDED\",\"statusMessage\":\"Transaction Approved\"}"
      read 253 bytes
      Conn close
    PRE_SCRUBBED_WITH_AUTH
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      <- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\n\Authorization: [FILTERED]\r\nUser-Agent: MONEI/Shopify/0.1.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.monei.com\r\nContent-Length: 443\r\n\r\n"
      <- "{\"livemode\":\"false\",\"orderId\":\"66e0d04361fb7b401bec3b078744c21e\",\"transactionType\":\"AUTH\",\"description\":\"Store Purchase\",\"amount\":100,\"currency\":\"EUR\",\"paymentMethod\":{\"card\":{\"number\":\"[FILTERED]\",\"expMonth\":\"12\",\"expYear\":\"34\",\"cvc\":\"[FILTERED]\"}},\"customer\":{\"email\":\"support@monei.com\",\"name\":\"Jim Smith\"},\"billingDetails\":{\"address\":{\"line1\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country\":\"CA\"}},\"sessionDetails\":{}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1069\r\n"
      -> "Connection: close\r\n"
      -> "Date: Mon, 05 Jul 2021 15:59:36 GMT\r\n"
      -> "x-amzn-RequestId: 75b637ff-f230-4522-b6c5-bc5b95495a55\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: CAPf6EPXjoEFdxA=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-60e32c65-625fbe465afdff1666fa4da9;Sampled=0\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 508a0f3451a34ff5e6a3963c94ef304d.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: MAD51-C3\r\n"
      -> "X-Amz-Cf-Id: SH_5SGGltcCwOgNwn4cnuZAYCa8__JZuUe5lj_Dnvkhigu2yB8M-SQ==\r\n"
      -> "\r\n"
      reading 1069 bytes...
      -> "{\"id\":\"cdc503654e76e29051bce6054e4b4d47dfb63edc\",\"amount\":100,\"currency\":\"EUR\",\"orderId\":\"66e0d04361fb7b401bec3b078744c21e\",\"description\":\"Store Purchase\",\"accountId\":\"00000000-aaaa-bbbb-cccc-dddd123456789\",\"authorizationCode\":\"++++++\",\"livemode\":false,\"status\":\"FAILED\",\"statusCode\":\"E501\",\"statusMessage\":\"Card rejected: invalid card number\",\"customer\":{\"name\":\"Jim Smith\",\"email\":\"support@monei.com\"},\"billingDetails\":{\"address\":{\"zip\":\"K1C2N6\",\"country\":\"CA\",\"state\":\"ON\",\"city\":\"Ottawa\",\"line1\":\"456 My Street\"}},\"sessionDetails\":{\"deviceType\":\"desktop\"},\"traceDetails\":{\"deviceType\":\"desktop\",\"sourceVersion\":\"0.1.0\",\"countryCode\":\"ES\",\"ip\":\"217.61.227.107\",\"userAgent\":\"MONEI/Shopify/0.1.0\",\"source\":\"MONEI/Shopify\",\"lang\":\"en\"},\"createdAt\":1625500773,\"updatedAt\":1625500776,\"paymentMethod\":{\"method\":\"card\",\"card\":{\"country\":\"US\",\"last4\":\"9675\",\"threeDSecure\":false,\"expiration\":2048544000,\"type\":\"credit\",\"brand\":\"mastercard\"}},\"nextAction\":{\"type\":\"COMPLETE\",\"redirectUrl\":\"https://secure.monei.com/payments/cdc503654e76e29051bce6054e4b4d47dfb63edc/receipt\"}}"
      read 1069 bytes
      Conn close
    POST_SCRUBBED
  end

  def post_scrubbed_with_auth
    <<-POST_SCRUBBED_WITH_AUTH
      <- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: [FILTERED]\r\nUser-Agent: MONEI/Shopify/0.1.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.monei.com\r\nContent-Length: 1063\r\n\r\n"
      <- "{\"livemode\":\"false\",\"orderId\":\"851925032d391d67e3fbf70b06aa182d\",\"transactionType\":\"SALE\",\"description\":\"Store Purchase\",\"amount\":100,\"currency\":\"EUR\",\"paymentMethod\":{\"card\":{\"number\":\"[FILTERED]\",\"expMonth\":\"12\",\"expYear\":\"34\",\"cvc\":\"[FILTERED]\",\"auth\":{\"threeDSVersion\":null,\"eci\":\"05\",\"cavv\":\"[FILTERED]\",\"dsTransID\":\"7eac9571-3533-4c38-addd-00cf34af6a52\",\"directoryResponse\":null,\"authenticationResponse\":null,\"notificationUrl\":\"https://example.com/notification\"}}},\"customer\":{\"email\":\"support@monei.com\",\"name\":\"Jim Smith\"},\"billingDetails\":{\"address\":{\"line1\":\"456 My Street\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"country\":\"CA\"}},\"sessionDetails\":{\"ip\":\"77.110.174.153\",\"userAgent\":\"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36\",\"browserAccept\":\"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,application/json\",\"browserColorDepth\":\"100\",\"lang\":\"US\",\"browserScreenHeight\":\"1000\",\"browserScreenWidth\":\"500\",\"browserTimezoneOffset\":\"-120\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 253\r\n"
      -> "Connection: close\r\n"
      -> "Date: Mon, 05 Jul 2021 15:59:59 GMT\r\n"
      -> "x-amzn-RequestId: ac5a5ec8-6dd4-4254-a28a-8e9fa652ba90\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: CAPj7FFfDoEFXOQ=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-60e32c7f-690a46280dc8da307f679795;Sampled=0\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 1868e2f5b79bbf25cd21cd4b652be313.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: MAD51-C3\r\n"
      -> "X-Amz-Cf-Id: RVunC63Qvaswh2fcVB5n0p0BB_1zxbMOx68nuq5m6GKhWUFPpfAgVQ==\r\n"
      -> "\r\n"
      reading 253 bytes...
      -> "{\"id\":\"e1310ab50f7cf1dcf87f1ae75b2ed0fbd2a4d05f\",\"amount\":100,\"currency\":\"EUR\",\"orderId\":\"851925032d391d67e3fbf70b06aa182d\",\"accountId\":\"00000000-aaaa-bbbb-cccc-dddd123456789\",\"liveMode\":false,\"status\":\"SUCCEEDED\",\"statusMessage\":\"Transaction Approved\"}"
      read 253 bytes
      Conn close
    POST_SCRUBBED_WITH_AUTH
  end
end
