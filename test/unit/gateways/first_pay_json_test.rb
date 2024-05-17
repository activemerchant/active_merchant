require 'test_helper'

class FirstPayJsonTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FirstPayJsonGateway.new(
      processor_id: 1234,
      merchant_key: 'a91c38c3-7d7f-4d29-acc7-927b4dca0dbe'
    )

    @credit_card = credit_card
    @google_pay = network_tokenization_credit_card(
      '4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :google_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      transaction_id: '13456789'
    )
    @apple_pay = network_tokenization_credit_card(
      '4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :apple_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      transaction_id: '13456789'
    )
    @amount = 100

    @options = {
      order_id: SecureRandom.hex(24),
      billing_address: address
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"transactionAmount\":\"1.00\"/, data)
      assert_match(/\"cardNumber\":\"4242424242424242\"/, data)
      assert_match(/\"cardExpMonth\":9/, data)
      assert_match(/\"cardExpYear\":\"25\"/, data)
      assert_match(/\"cvv\":\"123\"/, data)
      assert_match(/\"ownerName\":\"Jim Smith\"/, data)
      assert_match(/\"ownerStreet\":\"456 My Street\"/, data)
      assert_match(/\"ownerCity\":\"Ottawa\"/, data)
      assert_match(/\"ownerState\":\"ON\"/, data)
      assert_match(/\"ownerZip\":\"K1C2N6\"/, data)
      assert_match(/\"ownerCountry\":\"CA\"/, data)
      assert_match(/\"processorId\":1234/, data)
      assert_match(/\"merchantKey\":\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\"/, data)
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '31076534', response.authorization
    assert_equal 'Approved 735498', response.message
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(200, @credit_card, @options)
    end.respond_with(failed_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_failure response
    assert_equal '31076656', response.authorization
    assert_equal 'Auth Declined', response.message
  end

  def test_successful_google_pay_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @google_pay, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"walletType\":\"GooglePay\"/, data)
      assert_match(/\"paymentCryptogram\":\"EHuWW9PiBkWvqE5juRwDzAUFBAk=\"/, data)
      assert_match(/\"eciIndicator\":\"05\"/, data)
      assert_match(/\"transactionAmount\":\"1.00\"/, data)
      assert_match(/\"cardNumber\":\"4005550000000019\"/, data)
      assert_match(/\"cardExpMonth\":2/, data)
      assert_match(/\"cardExpYear\":\"35\"/, data)
      assert_match(/\"ownerName\":\"Jim Smith\"/, data)
      assert_match(/\"ownerStreet\":\"456 My Street\"/, data)
      assert_match(/\"ownerCity\":\"Ottawa\"/, data)
      assert_match(/\"ownerState\":\"ON\"/, data)
      assert_match(/\"ownerZip\":\"K1C2N6\"/, data)
      assert_match(/\"ownerCountry\":\"CA\"/, data)
      assert_match(/\"processorId\":1234/, data)
      assert_match(/\"merchantKey\":\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\"/, data)
    end.respond_with(successful_purchase_google_pay_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '31079731', response.authorization
    assert_equal 'Approved 507983', response.message
  end

  def test_successful_apple_pay_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @apple_pay, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"walletType\":\"ApplePay\"/, data)
      assert_match(/\"paymentCryptogram\":\"EHuWW9PiBkWvqE5juRwDzAUFBAk=\"/, data)
      assert_match(/\"eciIndicator\":\"05\"/, data)
      assert_match(/\"transactionAmount\":\"1.00\"/, data)
      assert_match(/\"cardNumber\":\"4005550000000019\"/, data)
      assert_match(/\"cardExpMonth\":2/, data)
      assert_match(/\"cardExpYear\":\"35\"/, data)
      assert_match(/\"ownerName\":\"Jim Smith\"/, data)
      assert_match(/\"ownerStreet\":\"456 My Street\"/, data)
      assert_match(/\"ownerCity\":\"Ottawa\"/, data)
      assert_match(/\"ownerState\":\"ON\"/, data)
      assert_match(/\"ownerZip\":\"K1C2N6\"/, data)
      assert_match(/\"ownerCountry\":\"CA\"/, data)
      assert_match(/\"processorId\":1234/, data)
      assert_match(/\"merchantKey\":\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\"/, data)
    end.respond_with(successful_purchase_apple_pay_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '31080040', response.authorization
    assert_equal 'Approved 576126', response.message
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"transactionAmount\":\"1.00\"/, data)
      assert_match(/\"cardNumber\":\"4242424242424242\"/, data)
      assert_match(/\"cardExpMonth\":9/, data)
      assert_match(/\"cardExpYear\":\"25\"/, data)
      assert_match(/\"cvv\":\"123\"/, data)
      assert_match(/\"ownerName\":\"Jim Smith\"/, data)
      assert_match(/\"ownerStreet\":\"456 My Street\"/, data)
      assert_match(/\"ownerCity\":\"Ottawa\"/, data)
      assert_match(/\"ownerState\":\"ON\"/, data)
      assert_match(/\"ownerZip\":\"K1C2N6\"/, data)
      assert_match(/\"ownerCountry\":\"CA\"/, data)
      assert_match(/\"processorId\":1234/, data)
      assert_match(/\"merchantKey\":\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\"/, data)
    end.respond_with(successful_authorize_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '31076755', response.authorization
    assert_equal 'Approved 487154', response.message
  end

  def test_failed_authorize
    @gateway.stubs(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal '31076792', response.authorization
    assert_equal 'Auth Declined', response.message
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, '31076883')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"transactionAmount\":\"1.00\"/, data)
      assert_match(/\"refNumber\":\"31076883\"/, data)
      assert_match(/\"processorId\":1234/, data)
      assert_match(/\"merchantKey\":\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\"/, data)
    end.respond_with(successful_capture_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '31076883', response.authorization
    assert_equal 'APPROVED', response.message
  end

  def test_failed_capture
    @gateway.stubs(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, '1234')

    assert_failure response
    assert_equal '1234', response.authorization
    assert response.message.include?('Settle Failed')
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, '31077003')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"transactionAmount\":\"1.00\"/, data)
      assert_match(/\"refNumber\":\"31077003\"/, data)
      assert_match(/\"processorId\":1234/, data)
      assert_match(/\"merchantKey\":\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\"/, data)
    end.respond_with(successful_refund_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '31077004', response.authorization
    assert_equal 'APPROVED', response.message
  end

  def test_failed_refund
    @gateway.stubs(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, '1234')

    assert_failure response
    assert_equal '', response.authorization
    assert response.message.include?('No transaction was found to refund.')
  end

  def test_successful_void
    response = stub_comms do
      @gateway.void('31077140')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/\"refNumber\":\"31077140\"/, data)
      assert_match(/\"processorId\":1234/, data)
      assert_match(/\"merchantKey\":\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\"/, data)
    end.respond_with(successful_void_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '31077142', response.authorization
    assert_equal 'APPROVED', response.message
  end

  def test_failed_void
    @gateway.stubs(:ssl_post).returns(failed_void_response)
    response = @gateway.void('1234')

    assert_failure response
    assert_equal '', response.authorization
    assert response.message.include?('Void Failed. Transaction cannot be voided.')
  end

  def test_error_message
    @gateway.stubs(:ssl_post).returns(failed_login_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'isError', response.error_code
    assert response.message.include?('Unable to retrieve merchant information')
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_purchase_response
    <<~RESPONSE
      {
        "data": {
          "authResponse": "Approved 735498",
          "authCode": "735498",
          "referenceNumber": "31076534",
          "isPartial": false,
          "partialId": "",
          "originalFullAmount": 1.0,
          "partialAmountApproved": 0.0,
          "avsResponse": "Y",
          "cvv2Response": "",
          "orderId": "638430008263685218",
          "cardType": "Visa",
          "last4": "1111",
          "maskedPan": "411111******1111",
          "token": "1266392642841111",
          "cardExpMonth": "9",
          "cardExpYear": "25",
          "hasFee": false,
          "fee": null,
          "billingAddress": { "ownerName": "Jim Smith", "ownerStreet": "456 My Street", "ownerStreet2": null, "ownerCity": "Ottawa", "ownerState": "ON", "ownerZip": "K1C2N6", "ownerCountry": "CA", "ownerEmail": null, "ownerPhone": null }
        },
        "isError": false,
        "errorMessages": [],
        "validationHasFailed": false,
        "validationFailures": [],
        "isSuccess": true,
        "action": "Sale"
      }
    RESPONSE
  end

  def failed_purchase_response
    <<~RESPONSE
      {
        "data": {
          "authResponse": "Auth Declined",
          "authCode": "200",
          "referenceNumber": "31076656",
          "isPartial": false,
          "partialId": "",
          "originalFullAmount": 2.0,
          "partialAmountApproved": 0.0,
          "avsResponse": "",
          "cvv2Response": "",
          "orderId": "",
          "cardType": "Visa",
          "last4": "1111",
          "maskedPan": "411111******1111",
          "token": "1266392642841111",
          "cardExpMonth": "9",
          "cardExpYear": "25",
          "hasFee": false,
          "fee": null,
          "billingAddress": { "ownerName": "Jim Smith", "ownerStreet": "456 My Street", "ownerStreet2": null, "ownerCity": "Ottawa", "ownerState": "ON", "ownerZip": "K1C2N6", "ownerCountry": "CA", "ownerEmail": null, "ownerPhone": null }
        },
        "isError": true,
        "errorMessages": ["Auth Declined"],
        "validationHasFailed": false,
        "validationFailures": [],
        "isSuccess": false,
        "action": "Sale"
      }
    RESPONSE
  end

  def successful_purchase_google_pay_response
    <<~RESPONSE
      {
        "data":{
          "authResponse":"Approved 507983",
          "authCode":"507983",
          "referenceNumber":"31079731",
          "isPartial":false,
          "partialId":"",
          "originalFullAmount":1.0,
          "partialAmountApproved":0.0,
          "avsResponse":"Y",
          "cvv2Response":"",
          "orderId":"bbabd4c3b486eed0935a0e12bf4b000579274dfea330223a",
          "cardType":"Visa-GooglePay",
          "last4":"0019",
          "maskedPan":"400555******0019",
          "token":"8257959132340019",
          "cardExpMonth":"2",
          "cardExpYear":"35",
          "hasFee":false,
          "fee":null,
          "billingAddress":{"ownerName":"Jim Smith", "ownerStreet":"456 My Street", "ownerStreet2":null, "ownerCity":"Ottawa", "ownerState":"ON", "ownerZip":"K1C2N6", "ownerCountry":"CA", "ownerEmail":null, "ownerPhone":null}
        },
        "isError":false,
        "errorMessages":[],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":true,
        "action":"Sale"
      }
    RESPONSE
  end

  def successful_purchase_apple_pay_response
    <<~RESPONSE
      {
        "data":{
          "authResponse":"Approved 576126",
          "authCode":"576126",
          "referenceNumber":"31080040",
          "isPartial":false,
          "partialId":"",
          "originalFullAmount":1.0,
          "partialAmountApproved":0.0,
          "avsResponse":"Y",
          "cvv2Response":"",
          "orderId":"f6527d4f5ebc29a60662239be0221f612797030cde82d50c",
          "cardType":"Visa-ApplePay",
          "last4":"0019",
          "maskedPan":"400555******0019",
          "token":"8257959132340019",
          "cardExpMonth":"2",
          "cardExpYear":"35",
          "hasFee":false,
          "fee":null,
          "billingAddress":{"ownerName":"Jim Smith", "ownerStreet":"456 My Street", "ownerStreet2":null, "ownerCity":"Ottawa", "ownerState":"ON", "ownerZip":"K1C2N6", "ownerCountry":"CA", "ownerEmail":null, "ownerPhone":null}
        },
        "isError":false,
        "errorMessages":[],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":true,
        "action":"Sale"
      }
    RESPONSE
  end

  def successful_authorize_response
    <<~RESPONSE
      {
        "data": {
          "authResponse": "Approved 487154",
          "authCode": "487154",
          "referenceNumber": "31076755",
          "isPartial": false,
          "partialId": "",
          "originalFullAmount": 1.0,
          "partialAmountApproved": 0.0,
          "avsResponse": "Y",
          "cvv2Response": "",
          "orderId": "638430019493711407",
          "cardType": "Visa",
          "last4": "1111",
          "maskedPan": "411111******1111",
          "token": "1266392642841111",
          "hasFee": false,
          "fee": null
        },
        "isError": false,
        "errorMessages": [],
        "validationHasFailed": false,
        "validationFailures": [],
        "isSuccess": true,
        "action": "Auth"
      }
    RESPONSE
  end

  def failed_authorize_response
    <<~RESPONSE
      {
        "data": {
          "authResponse": "Auth Declined",
          "authCode": "200",
          "referenceNumber": "31076792",
          "isPartial": false,
          "partialId": "",
          "originalFullAmount": 2.0,
          "partialAmountApproved": 0.0,
          "avsResponse": "",
          "cvv2Response": "",
          "orderId": "",
          "cardType": "Visa",
          "last4": "1111",
          "maskedPan": "411111******1111",
          "token": "1266392642841111",
          "hasFee": false,
          "fee": null
        },
        "isError": true,
        "errorMessages": ["Auth Declined"],
        "validationHasFailed": false,
        "validationFailures": [],
        "isSuccess": false,
        "action": "Auth"
      }
    RESPONSE
  end

  def successful_capture_response
    <<~RESPONSE
      {
        "data": {
          "authResponse": "APPROVED",
          "referenceNumber": "31076883",
          "settleAmount": "1",
          "batchNumber": "20240208"
        },
        "isError": false,
        "errorMessages": [],
        "validationHasFailed": false,
        "validationFailures": [],
        "isSuccess": true,
        "action": "Settle"
      }
    RESPONSE
  end

  def failed_capture_response
    <<~RESPONSE
      {
        "data":{
          "authResponse":"Settle Failed. Transaction cannot be settled. Make sure the settlement amount does not exceed the original auth amount and that is was authorized less than 30 days ago.",
          "referenceNumber":"1234",
          "settleAmount":"1",
          "batchNumber":"20240208"
        },
        "isError":true,
        "errorMessages":["Settle Failed. Transaction cannot be settled. Make sure the settlement amount does not exceed the original auth amount and that is was authorized less than 30 days ago."],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":false,
        "action":"Settle"
      }
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
      {
        "data":{
          "authResponse":"APPROVED",
          "referenceNumber":"31077004",
          "parentReferenceNumber":"31077003",
          "refundAmount":"1.00",
          "refundType":"void"
        },
        "isError":false,
        "errorMessages":[],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":true,
        "action":"Refund"
      }
    RESPONSE
  end

  def failed_refund_response
    <<~RESPONSE
      {
        "data":{
          "authResponse":"No transaction was found to refund.",
          "referenceNumber":"",
          "parentReferenceNumber":"",
          "refundAmount":"",
          "refundType":"void"
        },
        "isError":true,
        "errorMessages":["No transaction was found to refund."],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":false,
        "action":"Refund"
      }
    RESPONSE
  end

  def successful_void_response
    <<~RESPONSE
      {
        "data":{
          "authResponse":"APPROVED",
          "referenceNumber":"31077142",
          "parentReferenceNumber":"31077140"
        },
        "isError":false,
        "errorMessages":[],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":true,
        "action":"Void"
      }
    RESPONSE
  end

  def failed_void_response
    <<~RESPONSE
      {
        "data":{
          "authResponse":"Void Failed. Transaction cannot be voided.",
          "referenceNumber":"",
          "parentReferenceNumber":""
        },
        "isError":true,
        "errorMessages":["Void Failed. Transaction cannot be voided."],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":false,
        "action":"Void"
      }
    RESPONSE
  end

  def failed_login_response
    <<~RESPONSE
      {
        "isError":true,
        "errorMessages":["Unable to retrieve merchant information"],
        "validationHasFailed":false,
        "validationFailures":[],
        "isSuccess":false,
        "action":"Sale"
      }
    RESPONSE
  end

  def pre_scrubbed
    <<~RESPONSE
      "opening connection to secure.1stpaygateway.net:443...\nopened\nstarting SSL for secure.1stpaygateway.net:443...\nSSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256\n<- \"POST /secure/RestGW/Gateway/Transaction/Sale HTTP/1.1\\r\\nContent-Type: application/json\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: secure.1stpaygateway.net\\r\\nContent-Length: 314\\r\\n\\r\\n\"\n<- \"{\\\"transactionAmount\\\":\\\"1.00\\\",\\\"cardNumber\\\":\\\"4111111111111111\\\",\\\"cardExpMonth\\\":9,\\\"cardExpYear\\\":\\\"25\\\",\\\"cvv\\\":789,\\\"ownerName\\\":\\\"Jim Smith\\\",\\\"ownerStreet\\\":\\\"456 My Street\\\",\\\"ownerCity\\\":\\\"Ottawa\\\",\\\"ownerState\\\":\\\"ON\\\",\\\"ownerZip\\\":\\\"K1C2N6\\\",\\\"ownerCountry\\\":\\\"CA\\\",\\\"processorId\\\":\\\"15417\\\",\\\"merchantKey\\\":\\\"a91c38c3-7d7f-4d29-acc7-927b4dca0dbe\\\"}\"\n-> \"HTTP/1.1 201 Created\\r\\n\"\n-> \"Cache-Control: no-cache\\r\\n\"\n-> \"Pragma: no-cache\\r\\n\"\n-> \"Content-Type: application/json; charset=utf-8\\r\\n\"\n-> \"Expires: -1\\r\\n\"\n-> \"Server: Microsoft-IIS/8.5\\r\\n\"\n-> \"cacheControlHeader: max-age=604800\\r\\n\"\n-> \"X-Frame-Options: SAMEORIGIN\\r\\n\"\n-> \"Server-Timing: dtSInfo;desc=\\\"0\\\", dtRpid;desc=\\\"6653911\\\"\\r\\n\"\n-> \"Set-Cookie: dtCookie=v_4_srv_25_sn_229120735766FEB2E6DDFF943AAE854B_perc_100000_ol_0_mul_1_app-3A9b02c199f0b03d02_1_rcs-3Acss_0; Path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"Date: Thu, 08 Feb 2024 16:01:55 GMT\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Content-Length: 728\\r\\n\"\n-> \"Set-Cookie: visid_incap_1062257=eHvRBa+XQCW1gGR0YBPEY/P6xGUAAAAAQUIPAAAAAACnSZS9oi5gsXdpeLLAD5GF; expires=Fri, 07 Feb 2025 06:54:02 GMT; HttpOnly; path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"Set-Cookie: nlbi_1062257=dhZJMDyfcwOqd4xnV7L7rwAAAAC5FWzum6uW3m7ncs3yPd5v; path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"Set-Cookie: incap_ses_1431_1062257=KaP3NrSI5RQVmH3mPu/bE/P6xGUAAAAAjL9pVzaGFN+QxtEAMI1qbQ==; path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"X-CDN: Imperva\\r\\n\"\n-> \"X-Iinfo: 12-32874223-32874361 NNNN CT(38 76 0) RT(1707408112989 881) q(0 0 1 -1) r(17 17) U24\\r\\n\"\n-> \"\\r\\n\"\nreading 728 bytes...\n-> \"{\\\"data\\\":{\\\"authResponse\\\":\\\"Approved 360176\\\",\\\"authCode\\\":\\\"360176\\\",\\\"referenceNumber\\\":\\\"31077352\\\",\\\"isPartial\\\":false,\\\"partialId\\\":\\\"\\\",\\\"originalFullAmount\\\":1.0,\\\"partialAmountApproved\\\":0.0,\\\"avsResponse\\\":\\\"Y\\\",\\\"cvv2Response\\\":\\\"\\\",\\\"orderId\\\":\\\"638430049144239976\\\",\\\"cardType\\\":\\\"Visa\\\",\\\"last4\\\":\\\"1111\\\",\\\"maskedPan\\\":\\\"411111******1111\\\",\\\"token\\\":\\\"1266392642841111\\\",\\\"cardExpMonth\\\":\\\"9\\\",\\\"cardExpYear\\\":\\\"25\\\",\\\"hasFee\\\":false,\\\"fee\\\":null,\\\"billi\"\n-> \"ngAddress\\\":{\\\"ownerName\\\":\\\"Jim Smith\\\",\\\"ownerStreet\\\":\\\"456 My Street\\\",\\\"ownerStreet2\\\":null,\\\"ownerCity\\\":\\\"Ottawa\\\",\\\"ownerState\\\":\\\"ON\\\",\\\"ownerZip\\\":\\\"K1C2N6\\\",\\\"ownerCountry\\\":\\\"CA\\\",\\\"ownerEmail\\\":null,\\\"ownerPhone\\\":null}},\\\"isError\\\":false,\\\"errorMessages\\\":[],\\\"validationHasFailed\\\":false,\\\"validationFailures\\\":[],\\\"isSuccess\\\":true,\\\"action\\\":\\\"Sale\\\"}\"\nread 728 bytes\nConn close\n"
    RESPONSE
  end

  def post_scrubbed
    <<~RESPONSE
      "opening connection to secure.1stpaygateway.net:443...\nopened\nstarting SSL for secure.1stpaygateway.net:443...\nSSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256\n<- \"POST /secure/RestGW/Gateway/Transaction/Sale HTTP/1.1\\r\\nContent-Type: application/json\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: secure.1stpaygateway.net\\r\\nContent-Length: 314\\r\\n\\r\\n\"\n<- \"{\\\"transactionAmount\\\":\\\"1.00\\\",\\\"cardNumber\\\":\\\"[FILTERED]\",\\\"cardExpMonth\\\":9,\\\"cardExpYear\\\":\\\"25\\\",\\\"cvv\\\":[FILTERED],\\\"ownerName\\\":\\\"Jim Smith\\\",\\\"ownerStreet\\\":\\\"456 My Street\\\",\\\"ownerCity\\\":\\\"Ottawa\\\",\\\"ownerState\\\":\\\"ON\\\",\\\"ownerZip\\\":\\\"K1C2N6\\\",\\\"ownerCountry\\\":\\\"CA\\\",\\\"processorId\\\":\\\"[FILTERED]\",\\\"merchantKey\\\":\\\"[FILTERED]\"}\"\n-> \"HTTP/1.1 201 Created\\r\\n\"\n-> \"Cache-Control: no-cache\\r\\n\"\n-> \"Pragma: no-cache\\r\\n\"\n-> \"Content-Type: application/json; charset=utf-8\\r\\n\"\n-> \"Expires: -1\\r\\n\"\n-> \"Server: Microsoft-IIS/8.5\\r\\n\"\n-> \"cacheControlHeader: max-age=604800\\r\\n\"\n-> \"X-Frame-Options: SAMEORIGIN\\r\\n\"\n-> \"Server-Timing: dtSInfo;desc=\\\"0\\\", dtRpid;desc=\\\"6653911\\\"\\r\\n\"\n-> \"Set-Cookie: dtCookie=v_4_srv_25_sn_229120735766FEB2E6DDFF943AAE854B_perc_100000_ol_0_mul_1_app-3A9b02c199f0b03d02_1_rcs-3Acss_0; Path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"Date: Thu, 08 Feb 2024 16:01:55 GMT\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Content-Length: 728\\r\\n\"\n-> \"Set-Cookie: visid_incap_1062257=eHvRBa+XQCW1gGR0YBPEY/P6xGUAAAAAQUIPAAAAAACnSZS9oi5gsXdpeLLAD5GF; expires=Fri, 07 Feb 2025 06:54:02 GMT; HttpOnly; path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"Set-Cookie: nlbi_1062257=dhZJMDyfcwOqd4xnV7L7rwAAAAC5FWzum6uW3m7ncs3yPd5v; path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"Set-Cookie: incap_ses_1431_1062257=KaP3NrSI5RQVmH3mPu/bE/P6xGUAAAAAjL9pVzaGFN+QxtEAMI1qbQ==; path=/; Domain=.1stpaygateway.net\\r\\n\"\n-> \"X-CDN: Imperva\\r\\n\"\n-> \"X-Iinfo: 12-32874223-32874361 NNNN CT(38 76 0) RT(1707408112989 881) q(0 0 1 -1) r(17 17) U24\\r\\n\"\n-> \"\\r\\n\"\nreading 728 bytes...\n-> \"{\\\"data\\\":{\\\"authResponse\\\":\\\"Approved 360176\\\",\\\"authCode\\\":\\\"360176\\\",\\\"referenceNumber\\\":\\\"31077352\\\",\\\"isPartial\\\":false,\\\"partialId\\\":\\\"\\\",\\\"originalFullAmount\\\":1.0,\\\"partialAmountApproved\\\":0.0,\\\"avsResponse\\\":\\\"Y\\\",\\\"cvv2Response\\\":\\\"\\\",\\\"orderId\\\":\\\"638430049144239976\\\",\\\"cardType\\\":\\\"Visa\\\",\\\"last4\\\":\\\"1111\\\",\\\"maskedPan\\\":\\\"411111******1111\\\",\\\"token\\\":\\\"1266392642841111\\\",\\\"cardExpMonth\\\":\\\"9\\\",\\\"cardExpYear\\\":\\\"25\\\",\\\"hasFee\\\":false,\\\"fee\\\":null,\\\"billi\"\n-> \"ngAddress\\\":{\\\"ownerName\\\":\\\"Jim Smith\\\",\\\"ownerStreet\\\":\\\"456 My Street\\\",\\\"ownerStreet2\\\":null,\\\"ownerCity\\\":\\\"Ottawa\\\",\\\"ownerState\\\":\\\"ON\\\",\\\"ownerZip\\\":\\\"K1C2N6\\\",\\\"ownerCountry\\\":\\\"CA\\\",\\\"ownerEmail\\\":null,\\\"ownerPhone\\\":null}},\\\"isError\\\":false,\\\"errorMessages\\\":[],\\\"validationHasFailed\\\":false,\\\"validationFailures\\\":[],\\\"isSuccess\\\":true,\\\"action\\\":\\\"Sale\\\"}\"\nread 728 bytes\nConn close\n"
    RESPONSE
  end
end
