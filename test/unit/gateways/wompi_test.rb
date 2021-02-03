require 'test_helper'

class WompiTest < Test::Unit::TestCase
  def setup
    @gateway = WompiGateway.new(public_key: 'login', private_key: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:acceptance_token).returns('123')
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '18020-1612330162-69314', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:acceptance_token).returns('123')
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.error_code
  end

  def test_successful_financial_institution_gathering
    @gateway.expects(:ssl_request).returns(successful_financial_institutions_response)

    response = @gateway.pse_financial_institutions
    assert_success response

    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~'PRE_SCRUBBED'
      opening connection to sandbox.wompi.co:443...
      opened
      starting SSL for sandbox.wompi.co:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
      <- "POST /v1/tokens/cards HTTP/1.1\r\nContent-Type: application/json\r\nAccept: */*\r\nAuthorization: Bearer pub_test_rxLNy4HKU8geG0Nh2SJuEknZf5plwB0I\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.wompi.co\r\nContent-Length: 106\r\n\r\n"
      <- "{\"number\":\"4242424242424242\",\"cvc\":\"123\",\"exp_month\":\"09\",\"exp_year\":\"22\",\"card_holder\":\"Longbob Longsen\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 301\r\n"
      -> "Connection: close\r\n"
      -> "Date: Wed, 03 Feb 2021 05:47:35 GMT\r\n"
      -> "x-amzn-RequestId: 422a3b67-ebc0-4548-9623-c3ab5d7fc2dd\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: aJ3WhHF5oAMFnFQ=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-601a38f6-4cc8e48520ebcd0d62d636e3;Sampled=0\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 786adf19b53b584c0a277661acb7690d.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: MIA3-C1\r\n"
      -> "X-Amz-Cf-Id: D6fj2PCoZ7U9zYAL-1BTYKaYwMqIooTUaeFLvwvMFMjuuLo55zWAEQ==\r\n"
      -> "\r\n"
      reading 301 bytes...
      -> "{\"status\":\"CREATED\",\"data\":{\"id\":\"tok_test_8020_3E8Ff29600Db6EB81727F110d26BaEE4\",\"created_at\":\"2021-02-03T05:47:35.306+00:00\",\"brand\":\"VISA\",\"name\":\"VISA-4242\",\"last_four\":\"4242\",\"bin\":\"424242\",\"exp_year\":\"22\",\"exp_month\":\"09\",\"card_holder\":\"Longbob Longsen\",\"expires_at\":\"2021-08-02T05:47:34.000Z\"}}"
      read 301 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~'POST_SCRUBBED'
      opening connection to sandbox.wompi.co:443...
      opened
      starting SSL for sandbox.wompi.co:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
      <- "POST /v1/tokens/cards HTTP/1.1\r\nContent-Type: application/json\r\nAccept: */*\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.wompi.co\r\nContent-Length: 106\r\n\r\n"
      <- "{\"number\":\"[FILTERED]\",\"cvc\":\"[FILTERED]\",\"exp_month\":\"09\",\"exp_year\":\"22\",\"card_holder\":\"Longbob Longsen\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 301\r\n"
      -> "Connection: close\r\n"
      -> "Date: Wed, 03 Feb 2021 05:47:35 GMT\r\n"
      -> "x-amzn-RequestId: 422a3b67-ebc0-4548-9623-c3ab5d7fc2dd\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: aJ3WhHF5oAMFnFQ=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-601a38f6-4cc8e48520ebcd0d62d636e3;Sampled=0\r\n"
      -> "X-Cache: Miss from cloudfront\r\n"
      -> "Via: 1.1 786adf19b53b584c0a277661acb7690d.cloudfront.net (CloudFront)\r\n"
      -> "X-Amz-Cf-Pop: MIA3-C1\r\n"
      -> "X-Amz-Cf-Id: D6fj2PCoZ7U9zYAL-1BTYKaYwMqIooTUaeFLvwvMFMjuuLo55zWAEQ==\r\n"
      -> "\r\n"
      reading 301 bytes...
      -> "{\"status\":\"CREATED\",\"data\":{\"id\":\"tok_test_8020_3E8Ff29600Db6EB81727F110d26BaEE4\",\"created_at\":\"2021-02-03T05:47:35.306+00:00\",\"brand\":\"VISA\",\"name\":\"VISA-4242\",\"last_four\":\"4242\",\"bin\":\"424242\",\"exp_year\":\"22\",\"exp_month\":\"09\",\"card_holder\":\"Longbob Longsen\",\"expires_at\":\"2021-08-02T05:47:34.000Z\"}}"
      read 301 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    '{
      "data":[
        {
          "id":"18020-1612330162-69314",
          "created_at":"2021-02-03T05:29:23.017Z",
          "amount_in_cents":1000000,
          "reference":"988178d0-4711-4dc5-91e6-3ee7d59d204e",
          "customer_email":"john.smith@test.com",
          "currency":"COP",
          "payment_method_type":"CARD",
          "payment_method":{
            "type":"CARD",
            "extra":{
              "bin":"424242",
              "name":"VISA-4242",
              "brand":"VISA",
              "exp_year":"22",
              "exp_month":"09",
              "last_four":"4242",
              "external_identifier":"xmzeOjDePy"},
            "token":"tok_test_8020_4D0e205EC281049d201d9A0445e213d0",
            "installments":1},
          "status":"APPROVED",
          "status_message":null,
          "shipping_address":{
            "address_line_1":"456 My Street",
            "address_line_2":"Apt 1",
            "city":"Ottawa",
            "region":"ON",
            "name":"John smith",
            "phone_number":"08032000001",
            "postal_code":null,
            "country":"CO"},
          "redirect_url":null,
          "payment_source_id":null,
          "payment_link_id":null,
          "customer_data":{
            "full_name":"John smith",
            "phone_number":"08032000001"
          }}],
        "meta":{}
      }'
  end

  def failed_purchase_response
    '{
      "data":[
        {
          "id":"18020-1612331980-99648",
          "created_at":"2021-02-03T05:59:40.329Z",
          "amount_in_cents":1000000,
          "reference":"cdbd9a99-d06c-41c2-b536-70bb476d6130",
          "customer_email":"john.smith@test.com",
          "currency":"COP",
          "payment_method_type":"CARD",
          "payment_method":{
            "type":"CARD",
            "extra":{"bin":"411111",
            "name":"VISA-1111",
            "brand":"VISA",
            "exp_year":"22",
            "exp_month":"09",
            "last_four":"1111",
            "external_identifier":"72TdupPphv"},
          "token":"tok_test_8020_f770448fd9CE667AD29EaCa8f9c61333",
          "installments":1},
          "status":"DECLINED",
          "status_message":"La transacción fue rechazada (Sandbox)",
          "shipping_address":{
            "address_line_1":"456 My Street",
            "address_line_2":"Apt 1",
            "city":"Ottawa",
            "region":"ON",
            "name":"John smith",
            "phone_number":"08032000001",
            "postal_code":null,
            "country":"CO"},
          "redirect_url":null,
          "payment_source_id":null,
          "payment_link_id":null,
          "customer_data":{
            "full_name":"John smith",
            "phone_number":"08032000001"}
        }
      ],
      "meta":{}
    }'
  end

  def successful_financial_institutions_response
    '{
      "data":[
        {
          "financial_institution_code":"1",
          "financial_institution_name":"Banco que aprueba"
        },
        {
          "financial_institution_code":"2",
          "financial_institution_name":"Banco que rechaza"
        }
      ],
      "meta":{}
    }'
  end
end
