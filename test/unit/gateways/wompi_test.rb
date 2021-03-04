require 'test_helper'

class WompiTest < Test::Unit::TestCase
  def setup
    @gateway =
      WompiGateway.new(public_key: 'pub_test_key', private_key: 'priv_test_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
    }
  end

  def test_acceptance_token
    @gateway
      .expects(:ssl_request)
      .with(:get, any_parameters)
      .returns(acceptance_token_response)

    response = @gateway.query_acceptance_token
    assert_success response
  end

  def test_successful_purchase
    @gateway
      .expects(:store)
      .with(any_parameters)
      .returns(success_store_response)
    @gateway
      .expects(:ssl_request)
      .with(:get, any_parameters)
      .returns(acceptance_token_response)
    @gateway
      .expects(:ssl_request)
      .with(:post, any_parameters)
      .returns(successful_purchase_response)
    @gateway
      .expects(:query_transaction)
      .with(any_parameters)
      .returns(success_query_transaction_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal 'PENDING', response.error_code
    assert_equal '18020-1613658963-86049', response.authorization
    assert response.test?

    query_transaction_response =
      @gateway.query_transaction('31ca6742-ee1f-4216-bbb3-4dbc9a08a264')

    assert_equal 'APPROVED', query_transaction_response.message
  end

  def test_failed_purchase
    @gateway
      .expects(:store)
      .with(any_parameters)
      .returns(success_store_response)
    @gateway
      .expects(:ssl_request)
      .with(:get, any_parameters)
      .returns(acceptance_token_response)
    @gateway
      .expects(:ssl_request)
      .with(:post, any_parameters)
      .returns(failed_purchase_response)
    @gateway
      .expects(:query_transaction)
      .with(any_parameters)
      .returns(failed_query_transaction_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'PENDING', response.error_code

    query_transaction_response =
      @gateway.query_transaction('f1ddd87d-afe1-49d8-964b-39191053f2c1')

    assert_equal 'DECLINED', query_transaction_response.message
  end

  def test_successful_financial_institution_gathering
    @gateway
      .expects(:ssl_request)
      .returns(successful_financial_institutions_response)

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
    "opening connection to sandbox.wompi.co:443...\n" +
    "opened\n" +
    "starting SSL for sandbox.wompi.co:443...\n" +
    "SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256\n" +
    "<- \"POST /v1/tokens/cards HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAccept: */*\\r\\nAuthorization: Bearer [FILTERED] gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nUser-Agent: Ruby\\r\\nConnection: close\\r\\nHost: sandbox.wompi.co\\r\\nContent-Length: 106\\r\\n\\r\\n\"\n" +
    "<- \"{\\\"number\\\":\\\"[FILTERED]\\\",\\\"cvc\\\":\\\"[FILTERED]\\\",\\\"exp_month\\\":\\\"09\\\",\\\"exp_year\\\":\\\"22\\\",\\\"card_holder\\\":\\\"Longbob Longsen\\\"}\"\n" +
    "-> \"HTTP/1.1 201 Created\\r\\n\"\n" +
    "-> \"Content-Type: application/json\\r\\n\"\n" +
    "-> \"Content-Length: 301\\r\\n\"\n" +
    "-> \"Connection: close\\r\\n\"\n" +
    "-> \"Date: Wed, 03 Feb 2021 05:47:35 GMT\\r\\n\"\n" +
    "-> \"x-amzn-RequestId: 422a3b67-ebc0-4548-9623-c3ab5d7fc2dd\\r\\n\"\n" +
    "-> \"Access-Control-Allow-Origin: *\\r\\n\"\n" +
    "-> \"x-amz-apigw-id: aJ3WhHF5oAMFnFQ=\\r\\n\"\n" +
    "-> \"X-Amzn-Trace-Id: Root=1-601a38f6-4cc8e48520ebcd0d62d636e3;Sampled=0\\r\\n\"\n" +
    "-> \"X-Cache: Miss from cloudfront\\r\\n\"\n" +
    "-> \"Via: 1.1 786adf19b53b584c0a277661acb7690d.cloudfront.net (CloudFront)\\r\\n\"\n" +
    "-> \"X-Amz-Cf-Pop: MIA3-C1\\r\\n\"\n" +
    "-> \"X-Amz-Cf-Id: D6fj2PCoZ7U9zYAL-1BTYKaYwMqIooTUaeFLvwvMFMjuuLo55zWAEQ==\\r\\n\"\n" +
    "-> \"\\r\\n\"\n" +
    "reading 301 bytes...\n" +
    "-> \"{\\\"status\\\":\\\"CREATED\\\",\\\"data\\\":{\\\"id\\\":\\\"tok_test_8020_3E8Ff29600Db6EB81727F110d26BaEE4\\\",\\\"created_at\\\":\\\"2021-02-03T05:47:35.306+00:00\\\",\\\"brand\\\":\\\"VISA\\\",\\\"name\\\":\\\"VISA-4242\\\",\\\"last_four\\\":\\\"4242\\\",\\\"bin\\\":\\\"424242\\\",\\\"exp_year\\\":\\\"22\\\",\\\"exp_month\\\":\\\"09\\\",\\\"card_holder\\\":\\\"Longbob Longsen\\\",\\\"expires_at\\\":\\\"2021-08-02T05:47:34.000Z\\\"}}\"\n" +
    "read 301 bytes\n" +
    "Conn close\n"
  end

  def acceptance_token_response
    '{
      "data":{
        "id":8020,
        "name":"Fondo de las Naciones Unidas para la Infancia",
        "email":"ikerguelen@unicef.org",
        "contact_name":"Idual Kerguelen",
        "phone_number":"+573118889793",
        "active":true,
        "logo_url":null,
        "legal_name":"Fondo de las Naciones Unidas para la Infancia",
        "legal_id_type":"NIT",
        "legal_id":"800176994-3",
        "public_key":"pub_test_rxLNy4HKU8geG0Nh2SJuEknZf5plwB0I",
        "accepted_currencies":["COP"],
        "fraud_javascript_key":"zzzzz",
        "accepted_payment_methods":["BANCOLOMBIA_TRANSFER", "NEQUI", "PSE", "CARD", "BANCOLOMBIA_COLLECT"],
        "presigned_acceptance":{
          "acceptance_token":"eyJhbGciOiJIUzI1NiJ9.eyJjb250cmFjdF9pZCI6MSwicGVybWFsaW5rIjoiaHR0cHM6Ly93b21waS5jby93cC1jb250ZW50L3VwbG9hZHMvMjAxOS8wOS9URVJNSU5PUy1ZLUNPTkRJQ0lPTkVTLURFLVVTTy1VU1VBUklPUy1XT01QSS5wZGYiLCJmaWxlX2hhc2giOiIzZGNkMGM5OGU3NGFhYjk3OTdjZmY3ODExNzMxZjc3YiIsImppdCI6IjE2MTI0NDU2NjctNDUyNTciLCJleHAiOjE2MTI0NDkyNjd9.0keZVJbWeN2T83mrZvGQ0goSDUO2Tp6ff4f9hKzlyPE",
          "permalink":"https://wompi.co/wp-content/uploads/2019/09/TERMINOS-Y-CONDICIONES-DE-USO-USUARIOS-WOMPI.pdf",
          "type":"END_USER_POLICY"
        }
      },
      "meta":{}
    }'
  end

  def success_store_response
    raw_response =
      '{
        "status": "CREATED",
        "data": {
          "id": "tok_test_8020_A9Bdc8e874944a478c6ea8e242aa0114",
          "created_at": "2021-02-18T17:32:29.611+00:00",
          "brand": "VISA",
          "name": "VISA-1111",
          "last_four": "1111",
          "bin": "411111",
          "exp_year": "22",
          "exp_month": "09",
          "card_holder": "Longbob Longsen",
          "expires_at": "2021-08-17T17:32:29.000Z"
        }
      }'

    create_active_merchant_response(raw_response)
  end

  def successful_purchase_response
    '{
      "data":{
        "id":"18020-1613658963-86049",
        "created_at":"2021-02-18T14:36:03.646Z",
        "amount_in_cents":1000000,
        "reference":"31ca6742-ee1f-4216-bbb3-4dbc9a08a264",
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
            "last_four":"4242"
          },
          "installments":1
        },
        "status":"PENDING",
        "status_message":null,
        "shipping_address":{
          "address_line_1":"456 My Street",
          "address_line_2":"Apt 1",
          "city":"Ottawa",
          "region":"ON",
          "name":"John smith",
          "phone_number":"08032000001",
          "postal_code":null,
          "country":"CO"
        },
        "redirect_url":null,
        "payment_source_id":null,
        "payment_link_id":null,
        "customer_data":{
          "full_name":"John smith",
          "phone_number":"08032000001"
        },
        "bill_id":null,
        "taxes":[]
      },
      "meta":{}
    }'
  end

  def failed_query_transaction_response
    raw_response =
      '{
      "data":[
        {
          "id":"18020-1613645528-18530",
          "created_at":"2021-02-18T10:52:08.218Z",
          "amount_in_cents":1000000,
          "reference":"f1ddd87d-afe1-49d8-964b-39191053f2c1",
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
            "external_identifier":"DLGR2zsdWv"
          },
          "token":"tok_test_8020_84Ecda6A12E4976f9D85194688AD593e",
          "installments":1
        },
        "status":"DECLINED",
        "status_message":"La transacci\xC3\xB3n fue rechazada (Sandbox)",
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

    create_active_merchant_response(raw_response)
  end

  def success_query_transaction_response
    raw_response =
      '{
        "data":[
          {
            "id":"18020-1613658963-86049",
            "created_at":"2021-02-18T14:36:03.646Z",
            "amount_in_cents":1000000,
            "reference":"31ca6742-ee1f-4216-bbb3-4dbc9a08a264",
            "customer_email":"john.smith@test.com",
            "currency":"COP",
            "payment_method_type":"CARD",
            "payment_method":{
              "type":"CARD",
              "extra":{"bin":"424242",
              "name":"VISA-4242",
              "brand":"VISA",
              "exp_year":"22",
              "exp_month":"09",
              "last_four":"4242",
              "external_identifier":"QR3kN04BsP"
            },
            "token":"tok_test_8020_3d76d3Ceb92d6C47109dDF2b12eFc647",
            "installments":1
          },
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
            "country":"CO"
          },
          "redirect_url":null,
          "payment_source_id":null,
          "payment_link_id":null,
          "customer_data":{
            "full_name":"John smith",
            "phone_number":"08032000001"
          }}],
          "meta":{}
        }'

    create_active_merchant_response(raw_response)
  end

  def create_active_merchant_response(response)
     parsed_response = JSON.parse(response)
    Response.new(
      true,
      @gateway.send(
        :message_from,
        '/transactions?reference=id',
        parsed_response,
      ),
      parsed_response,
    )
  end

  def failed_purchase_response
    '{
      "data":{
        "id":"18020-1613645528-18530",
        "created_at":"2021-02-18T10:52:08.218Z",
        "amount_in_cents":1000000,
        "reference":"f1ddd87d-afe1-49d8-964b-39191053f2c1",
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
          "last_four":"1111"
        },
        "installments":1
      },
      "status":"PENDING",
      "status_message":null,
      "shipping_address":{
        "address_line_1":"456 My Street",
        "address_line_2":"Apt 1",
        "city":"Ottawa",
        "region":"ON",
        "name":"John smith",
        "phone_number":"08032000001",
        "postal_code":null,
        "country":"CO"
      },
      "redirect_url":null,
      "payment_source_id":null,
      "payment_link_id":null,
      "customer_data":{
        "full_name":"John smith",
        "phone_number":"08032000001"
      },
      "bill_id":null,
      "taxes":[]
      },
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
