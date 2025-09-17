require 'test_helper'

class SimetrikTest < Test::Unit::TestCase
  def setup
    @token_acquirer = 'ea890fd1-49f3-4a34-a150-192bf9a59205'
    @datetime = Time.new.strftime('%Y-%m-%dT%H:%M:%S.%L%:z')
    @gateway = SimetrikGateway.new(
      client_id: 'client_id',
      client_secret: 'client_secret_key',
      audience: 'audience_url',
      access_token: { expires_at: Time.new.to_i }
    )
    @credit_card = CreditCard.new(
      first_name: 'sergiod',
      last_name: 'lobob',
      number: '4551478422045511',
      month: 12,
      year: 2029,
      verification_value: '111'
    )
    @amount = 1000
    @trace_id = SecureRandom.uuid
    @order_id = SecureRandom.uuid[0..7]

    @sub_merchant = {
      address: 'string',
      extra_params: {},
      mcc: 'string',
      merchant_id: 'string',
      name: 'string',
      phone_number: 'string',
      postal_code: 'string',
      url: 'string'
    }

    @authorize_capture_options = {
      acquire_extra_options: {},
      trace_id: @trace_id,
      user: {
        id: '123',
        email: 's@example.com'
      },
      order: {
        id: @order_id,
        datetime_local_transaction: @datetime,
        description: 'a popsicle',
        installments: 1
      },
      currency: 'USD',
      vat: 190,
      three_ds_fields: {
        version: '2.1.0',
        eci: '02',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        acs_transaction_id: '13c701a3-5a88-4c45-89e9-ef65e50a8bf9',
        xid: '00000000000000000501',
        enrolled: 'string',
        cavv_algorithm: '1',
        directory_response_status: 'Y',
        authentication_response_status: 'Y',
        three_ds_server_trans_id: '24f701e3-9a85-4d45-89e9-af67e70d8fg8'
      },
      sub_merchant: @sub_merchant,
      token_acquirer: @token_acquirer
    }

    @authorize_capture_expected_body = {
      forward_route: {
        trace_id: @trace_id,
        psp_extra_fields: {}
      },
      forward_payload: {
        user: {
          id: '123',
          email: 's@example.com'
        },
        order: {
          id: @order_id,
          description: 'a popsicle',
          installments: 1,
          datetime_local_transaction: @datetime,
          amount: {
            total_amount: 10.0,
            currency: 'USD',
            vat: 1.9
          }
        },
        payment_method: {
          card: {
            number: '4551478422045511',
            exp_month: 12,
            exp_year: 2029,
            security_code: '111',
            type: 'visa',
            holder_first_name: 'sergiod',
            holder_last_name: 'lobob'
          }
        },
        authentication: {
          three_ds_fields: {
            version: '2.1.0',
            eci: '02',
            cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA',
            ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
            acs_transaction_id: '13c701a3-5a88-4c45-89e9-ef65e50a8bf9',
            xid: '00000000000000000501',
            enrolled: 'string',
            cavv_algorithm: '1',
            directory_response_status: 'Y',
            authentication_response_status: 'Y',
            three_ds_server_trans_id: '24f701e3-9a85-4d45-89e9-af67e70d8fg8'
          }
        },
        sub_merchant: {
          merchant_id: 'string',
          extra_params: {},
          mcc: 'string',
          name: 'string',
          address: 'string',
          postal_code: 'string',
          url: 'string',
          phone_number: 'string'
        },
        acquire_extra_options: {}
      }
    }.to_json.to_s
  end

  def test_endpoint
    assert_equal 'https://payments.sta.simetrik.com/v1', @gateway.test_url
    assert_equal 'https://payments.simetrik.com/v1', @gateway.live_url
  end

  def test_audience_endpoint
    assert_equal 'https://tenant-payments-dev.us.auth0.com/api/v2/', @gateway.test_audience
    assert_equal 'https://tenant-payments-prod.us.auth0.com/api/v2/', @gateway.live_audience
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response_body)

    response = @gateway.purchase(@amount, @credit_card, @authorize_capture_options)
    assert_success response
    assert_instance_of Response, response

    assert_equal response.message, 'successful charge'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil '
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_success_purchase_with_billing_address
    expected_body = JSON.parse(@authorize_capture_expected_body.dup)
    expected_body['forward_payload']['payment_method']['card']['billing_address'] = address

    @gateway.expects(:ssl_request).returns(successful_purchase_response_body)

    options = @authorize_capture_options.clone()
    options[:billing_address] = address

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_instance_of Response, response

    assert_equal response.message, 'successful charge'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil '
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_fetch_access_token_should_rise_an_exception_under_bad_request
    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      @gateway.expects(:raw_ssl_request).returns(Net::HTTPBadRequest.new(1.0, 401, 'Unauthorized'))
      @gateway.send(:fetch_access_token)
    end

    assert_match(/Failed with 401 Unauthorized/, error.message)
  end

  def test_success_purchase_with_shipping_address
    expected_body = JSON.parse(@authorize_capture_expected_body.dup)
    expected_body['forward_payload']['order']['shipping_address'] = address

    @gateway.expects(:ssl_request).returns(successful_purchase_response_body)

    options = @authorize_capture_options.clone()
    options[:shipping_address] = address

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_instance_of Response, response

    assert_equal response.message, 'successful charge'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil '
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response_body)

    response = @gateway.purchase(@amount, @credit_card, @authorize_capture_options)
    assert_failure response
    assert_instance_of Response, response
    assert response.test?
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_equal response.error_code, 'incorrect_number'
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response_body)

    response = @gateway.authorize(@amount, @credit_card, @authorize_capture_options)
    assert_success response
    assert_instance_of Response, response
    assert_equal response.message, 'successful authorize'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil '
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response_body)

    response = @gateway.authorize(@amount, @credit_card, @authorize_capture_options)
    assert_failure response
    assert_instance_of Response, response
    assert response.test?

    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_equal response.error_code, 'incorrect_number'
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response_body)

    response = @gateway.capture(@amount, 'fdb52e6a0e794b039de097e815a982fd', {
      vat: @authorize_capture_options[:vat],
      currency: 'USD',
      transaction_id: 'fdb52e6a0e794b039de097e815a982fd',
      token_acquirer: @token_acquirer,
      trace_id: @trace_id
    })

    assert_success response
    assert_instance_of Response, response
    assert response.test?
    assert_equal 'successful capture', response.message
    assert_equal response.message, 'successful capture'
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response_body)

    response = @gateway.capture(@amount, 'SI-226', {
      vat: 190,
      currency: 'USD',
      token_acquirer: @token_acquirer,
      trace_id: @trace_id
    })

    assert_failure response
    assert_instance_of Response, response
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_equal response.error_code, 'processing_error'
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response_body)

    response = @gateway.refund(@amount, 'SI-226', {
      amount: {
        currency: 'USD'
      },
      token_acquirer: @token_acquirer,
      comment: 'A Comment',
      acquire_extra_options: {
        ruc: 123
      },
      trace_id: @trace_id
    })

    assert_success response
    assert_instance_of Response, response
    assert response.test?

    assert_equal 'successful refund', response.message
    assert_equal response.message, 'successful refund'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil'
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response_body)
    response = @gateway.refund(@amount, 'SI-226', {
      amount: {
        currency: 'USD'
      },
      token_acquirer: @token_acquirer,
      comment: 'A Comment',
      trace_id: @trace_id
    })
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_equal response.error_code, 'processing_error'
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response_body)
    response = @gateway.void('a17f70f9-82de-4c47-8d9c-7743dac6a561', {
      token_acquirer: @token_acquirer,
      trace_id: @trace_id

    })

    assert_success response
    assert_instance_of Response, response
    assert response.test?
    assert_equal 'successful void', response.message
    assert_equal response.message, 'successful void'
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response_body)
    response = @gateway.void('a17f70f9-82de-4c47-8d9c-7743dac6a561', {
      token_acquirer: @token_acquirer,
      trace_id: @trace_id
    })
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_equal response.error_code, 'processing_error'
    assert response.test?
  end

  # no assertion for client_secret because it is included in a private method, if there
  # is refactoring of sign_access_token method ensure that it is properly scrubbed
  def test_scrub
    transcript = @gateway.scrub(pre_scrubbed())
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
    assert_scrubbed('4551478422045511', transcript)
  end

  private

  def pre_scrubbed
    <<-PRESCRUBBED
      opening connection to payments.sta.simetrik.com:443...
      opened
      starting SSL for payments.sta.simetrik.com:443...
      SSL established
      <- "POST /v1/bc4c0f26-a357-4294-9b9e-a90e6c868c6e/charge HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer      eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InYwZ0ZNM1QwY1BpZ3J2OTBrS1dEZSJ9.     eyJpc3MiOiJodHRwczovL3RlbmFudC1wYXltZW50cy1kZXYudXMuYXV0aDAuY29tLyIsInN1YiI6IndOaEpCZHJLRGszdlRta1FNQVdpNXpXTjd5MjFhZE8zQGNsaWVudHMiL   CJhdWQiOiJodHRwczovL3RlbmFudC1wYXltZW50cy1kZXYudXMuYXV0aDAuY29tL2FwaS92Mi8iLCJpYXQiOjE2NTExNjk1OTYsImV4cCI6MTY1MTI1NTk5NiwiYXpwIjoid0      5oSkJkcktEazN2VG1rUU1BV2k1eldON3kyMWFkTzMiLCJzY29wZSI6InJlYWQ6Y2xpZW50X2dyYW50cyIsImd0eSI6ImNsaWVudC1jcmVkZW50aWFscyJ9.     mAaWcAiq0t_UnXQGMv2uHcOfFoxclfPBU9Wa_Tmzmps3jIZnCggGxptAjaxn_Hj7Mteni4u9t7QVDUA6pQ1nVT4hfuFbFiC3CcvB8AKb6_PgIYLHuZ1i0VKyS6VtdB04_Sl8u     kbBcnXXt2GrRps23OPwwBjdJOKzXhz0pLeiDeBA_0SkF6LXqmbMuFB5PPGC2hyQUOOlkrqBjXH8meIMfnBh4GooF3AnsuhDT3hSu8t0gpQAVmQatxqPQwce8WXkD6qnCM6Q81   LnZCBjfzyF2T_LN4q9GmFkcy3NGkEXXNC1UigPxqbgDmf448biCKiMv1NnXyMhfknxH_kR2f6QdQ\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,      deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: payments.sta.simetrik.com\r\nContent-Length: 720\r\n\r\n"
      <- "{\"forward_route\":{\"trace_id\":\"ce4091cf-3656-4c78-b835-f9fcf2b2cb11\",\"psp_extra_fields\":{}},\"forward_payload\":{\"user\":     {\"id\":\"123\",\"email\":\"s@example.com\"},\"order\":{\"id\":\"191885304068\",\"description\":\"apopsicle\",\"installments\":1,     \"datetime_local_transaction\":\"2022-04-28T14:13:16.117-04:00\",\"amount\":{\"total_amount\":1.0,\"currency\":\"USD\",\"vat\":19.0}}   ,\"payment_method\":{\"card\":{\"number\":\"4551708161768059\",\"exp_month\":7,\"exp_year\":2022,\"security_code\":\"111\",      \"type\":\"visa\",\"holder_first_name\":\"Joe\",\"holder_last_name\":\"Doe\"}},\"sub_merchant\":{\"merchant_id\":\"400000008\",     \"extra_params\":{},\"mcc\":\"5816\",\"name\":\"885.519.237\",\"address\":\"None\",\"postal_code\":\"None\",\"url\":\"string\",     \"phone_number\":\"3434343\"},\"acquire_extra_options\":{}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Thu, 28 Apr 2022 18:13:34 GMT\r\n"
      -> "Content-Type: text/plain; charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Apigw-Requestid: RTbhkj7GoAMETbA=\r\n"
      -> "Via: 1.1 reverse-proxy-02-797bd8c84-8jv96\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "VGS-Request-Id: 8cdb14abe5f9fb04b3d3a5690930a418\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "235\r\n"
      reading 565 bytes...
      read 565 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRESCRUBBED
  end

  def post_scrubbed
    <<-POSTSCRUBBED
      opening connection to payments.sta.simetrik.com:443...
      opened
      starting SSL for payments.sta.simetrik.com:443...
      SSL established
      <- "POST /v1/bc4c0f26-a357-4294-9b9e-a90e6c868c6e/charge HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,      deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: payments.sta.simetrik.com\r\nContent-Length: 720\r\n\r\n"
      <- "{\"forward_route\":{\"trace_id\":\"ce4091cf-3656-4c78-b835-f9fcf2b2cb11\",\"psp_extra_fields\":{}},\"forward_payload\":{\"user\":     {\"id\":\"123\",\"email\":\"s@example.com\"},\"order\":{\"id\":\"191885304068\",\"description\":\"apopsicle\",\"installments\":1,     \"datetime_local_transaction\":\"2022-04-28T14:13:16.117-04:00\",\"amount\":{\"total_amount\":1.0,\"currency\":\"USD\",\"vat\":19.0}}   ,\"payment_method\":{\"card\":{\"number\":\"[FILTERED]\",\"exp_month\":7,\"exp_year\":2022,\"security_code\":\"[FILTERED]\",      \"type\":\"visa\",\"holder_first_name\":\"Joe\",\"holder_last_name\":\"Doe\"}},\"sub_merchant\":{\"merchant_id\":\"400000008\",     \"extra_params\":{},\"mcc\":\"5816\",\"name\":\"885.519.237\",\"address\":\"None\",\"postal_code\":\"None\",\"url\":\"string\",     \"phone_number\":\"3434343\"},\"acquire_extra_options\":{}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Thu, 28 Apr 2022 18:13:34 GMT\r\n"
      -> "Content-Type: text/plain; charset=utf-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Apigw-Requestid: RTbhkj7GoAMETbA=\r\n"
      -> "Via: 1.1 reverse-proxy-02-797bd8c84-8jv96\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "VGS-Request-Id: 8cdb14abe5f9fb04b3d3a5690930a418\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "\r\n"
      -> "235\r\n"
      reading 565 bytes...
      read 565 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POSTSCRUBBED
  end

  def successful_purchase_response_body
    '{
      "code": "S001",
      "message": "successful charge",
      "acquirer_body": {
          "dataMap": {
              "ACTION_CODE": "000",
              "MERCHANT": "400000008",
              "STATUS": "Authorized",
              "CARD": "455170******8059",
              "INSTALLMENTS_INFO": "03000000000",
              "QUOTA_NUMBER": "03",
              "QUOTA_AMOUNT": "0.00",
              "QUOTA_DEFERRED": "0"
          },
          "order": {
              "purchaseNumber": "56700001",
              "amount": 1000.0,
              "currency": "USD",
              "authorizedAmount": 1000.0,
              "authorizationCode": "105604",
              "actionCode": "000",
              "traceNumber": "75763",
              "transactionId": "984220460014549",
              "transactionDate": "220215105559"
          },
          "fulfillment": {
              "merchantId": "400000008",
              "captureType": "manual",
              "countable": false,
              "signature": "6168ebd4-9798-477c-80d4-b80971820b51"
          }
      },
      "avs_result": "G",
      "cvv_result": "P",
      "simetrik_authorization_id": "a870eeca1b1c46b39b6fd76fde7c32b6",
      "trace_id": "00866583c3c24a36b0270f1e38568c77"
    }'
  end

  def failed_purchase_response_body
    '{
      "trace_id": 50300,
      "code": "R101",
      "message": "incorrect_number",
      "simetrik_authorization_id": "S-1205",
      "avs_result": "I",
      "cvv_result": "P",
      "acquirer_body":  {
        "header": {
          "ecoreTransactionUUID": "8d2dfc73-ec1f-43af-aa0f-b2c123fd25ea",
          "ecoreTransactionDate": 1603054418778,
          "millis": 4752
        },
        "fulfillment": {
          "channel": "web",
          "merchantId": "341198210",
          "terminalId": "1",
          "captureType": "manual",
          "countable": true,
          "fastPayment": false,
          "signature": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73"
        },
        "order": {
          "tokenId": "99E9BF92C69A4799A9BF92C69AF79979",
          "purchaseNumber": "2020100901",
          "amount": 10.5,
          "installment": 2,
          "currency": "PEN",
          "authorizedAmount": 10.5,
          "authorizationCode": "173424",
          "actionCode": "000",
          "traceNumber": "177159",
          "transactionDate": "201010173430",
          "transactionId": "993202840246052"
        },
        "token": {
          "tokenId": "7000010038706267",
          "ownerId": "abc@mail.com",
          "expireOn": "240702123548"
        },
        "dataMap": {
          "TERMINAL": "00000001",
          "TRACE_NUMBER": "177159",
          "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
          "SIGNATURE": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73",
          "CARD": "455170******8329",
          "MERCHANT": "341198210",
          "STATUS": "Authorized",
          "INSTALLMENTS_INFO": "02000000000",
          "ACTION_DESCRIPTION": "Aprobado y completado con exito",
          "ID_UNICO": "993202840246052",
          "AMOUNT": "10.50",
          "QUOTA_NUMBER": "02",
          "AUTHORIZATION_CODE": "173424",
          "CURRENCY": "0604",
          "TRANSACTION_DATE": "201010173430",
          "ACTION_CODE": "000",
          "CARD_TOKEN": "7000010038706267",
          "ECI": "07",
          "BRAND": "visa",
          "ADQUIRENTE": "570002",
          "QUOTA_AMOUNT": "0.00",
          "PROCESS_CODE": "000000",
          "VAULT_BLOCK": "abc@mail.com",
          "TRANSACTION_ID": "993202840246052",
          "QUOTA_DEFERRED": "0"
        }
      }
    }'
  end

  def successful_authorize_response_body
    '{
      "trace_id": 50300,
      "code": "S001",
      "message": "successful authorize",
      "simetrik_authorization_id": "S-1205",
      "avs_result": "G",
      "cvv_result": "P",
      "acquirer_body":  {
        "header": {
          "ecoreTransactionUUID": "8d2dfc73-ec1f-43af-aa0f-b2c123fd25ea",
          "ecoreTransactionDate": 1603054418778,
          "millis": 4752
        },
        "fulfillment": {
          "channel": "web",
          "merchantId": "341198210",
          "terminalId": "1",
          "captureType": "manual",
          "countable": true,
          "fastPayment": false,
          "signature": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73"
        },
        "order": {
          "tokenId": "99E9BF92C69A4799A9BF92C69AF79979",
          "purchaseNumber": "2020100901",
          "amount": 10.5,
          "installment": 2,
          "currency": "PEN",
          "authorizedAmount": 10.5,
          "authorizationCode": "173424",
          "actionCode": "000",
          "traceNumber": "177159",
          "transactionDate": "201010173430",
          "transactionId": "993202840246052"
        },
        "token": {
          "tokenId": "7000010038706267",
          "ownerId": "abc@mail.com",
          "expireOn": "240702123548"
        },
        "dataMap": {
          "TERMINAL": "00000001",
          "TRACE_NUMBER": "177159",
          "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
          "SIGNATURE": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73",
          "CARD": "455170******8329",
          "MERCHANT": "341198210",
          "STATUS": "Authorized",
          "INSTALLMENTS_INFO": "02000000000",
          "ACTION_DESCRIPTION": "Aprobado y completado con exito",
          "ID_UNICO": "993202840246052",
          "AMOUNT": "10.50",
          "QUOTA_NUMBER": "02",
          "AUTHORIZATION_CODE": "173424",
          "CURRENCY": "0604",
          "TRANSACTION_DATE": "201010173430",
          "ACTION_CODE": "000",
          "CARD_TOKEN": "7000010038706267",
          "ECI": "07",
          "BRAND": "visa",
          "ADQUIRENTE": "570002",
          "QUOTA_AMOUNT": "0.00",
          "PROCESS_CODE": "000000",
          "VAULT_BLOCK": "abc@mail.com",
          "TRANSACTION_ID": "993202840246052",
          "QUOTA_DEFERRED": "0"
        }
      }
    }'
  end

  def failed_authorize_response_body
    '{
      "trace_id": 50300,
      "code": "R101",
      "message": "incorrect_number",
      "simetrik_authorization_id": "S-1205",
      "avs_result": "I",
      "cvv_result": "P",
      "acquirer_body":  {
        "header": {
          "ecoreTransactionUUID": "8d2dfc73-ec1f-43af-aa0f-b2c123fd25ea",
          "ecoreTransactionDate": 1603054418778,
          "millis": 4752
        },
        "fulfillment": {
          "channel": "web",
          "merchantId": "341198210",
          "terminalId": "1",
          "captureType": "manual",
          "countable": true,
          "fastPayment": false,
          "signature": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73"
        },
        "order": {
          "tokenId": "99E9BF92C69A4799A9BF92C69AF79979",
          "purchaseNumber": "2020100901",
          "amount": 10.5,
          "installment": 2,
          "currency": "PEN",
          "authorizedAmount": 10.5,
          "authorizationCode": "173424",
          "actionCode": "000",
          "traceNumber": "177159",
          "transactionDate": "201010173430",
          "transactionId": "993202840246052"
        },
        "token": {
          "tokenId": "7000010038706267",
          "ownerId": "abc@mail.com",
          "expireOn": "240702123548"
        },
        "dataMap": {
          "TERMINAL": "00000001",
          "TRACE_NUMBER": "177159",
          "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
          "SIGNATURE": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73",
          "CARD": "455170******8329",
          "MERCHANT": "341198210",
          "STATUS": "Authorized",
          "INSTALLMENTS_INFO": "02000000000",
          "ACTION_DESCRIPTION": "Aprobado y completado con exito",
          "ID_UNICO": "993202840246052",
          "AMOUNT": "10.50",
          "QUOTA_NUMBER": "02",
          "AUTHORIZATION_CODE": "173424",
          "CURRENCY": "0604",
          "TRANSACTION_DATE": "201010173430",
          "ACTION_CODE": "000",
          "CARD_TOKEN": "7000010038706267",
          "ECI": "07",
          "BRAND": "visa",
          "ADQUIRENTE": "570002",
          "QUOTA_AMOUNT": "0.00",
          "PROCESS_CODE": "000000",
          "VAULT_BLOCK": "abc@mail.com",
          "TRANSACTION_ID": "993202840246052",
          "QUOTA_DEFERRED": "0"
        }
      }
    }'
  end

  def successful_capture_response_body
    '{"code": "S001", "message": "successful capture", "acquirer_body": {"dataMap": {"ACTION_CODE": "000", "AUTHORIZATION_CODE": "121742", "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro", "ID_UNICO": "984221100087087", "MERCHANT": "400000008", "STATUS": "Confirmed", "TRACE_NUMBER": "134626", "ACTION_DESCRIPTION": "Aprobado y completado con exito"}, "order": {"purchaseNumber": "112226091072", "amount": 1.0, "currency": "USD", "authorizedAmount": 1.0, "authorizationCode": "121742", "actionCode": "000", "traceNumber": "134626", "transactionId": "984221100087087", "transactionDate": "220420121813"}}, "simetrik_authorization_id": "0ef9f1f07e304bd7969d8282d230f072", "trace_id": "5273214580359436090"}'
  end

  def failed_capture_response_body
    '{
      "trace_id": 50300,
      "code": "R302",
      "message": "processing_error",
      "simetrik_authorization_id": "S-1205",
      "avs_result": "I",
      "cvv_result": "P",
      "acquirer_body":  {
        "header": {
          "ecoreTransactionUUID": "8d2dfc73-ec1f-43af-aa0f-b2c123fd25ea",
          "ecoreTransactionDate": 1603054418778,
          "millis": 4752
        },
        "fulfillment": {
          "channel": "web",
          "merchantId": "341198210",
          "terminalId": "1",
          "captureType": "manual",
          "countable": true,
          "fastPayment": false,
          "signature": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73"
        },
        "order": {
          "tokenId": "99E9BF92C69A4799A9BF92C69AF79979",
          "purchaseNumber": "2020100901",
          "amount": 10.5,
          "installment": 2,
          "currency": "PEN",
          "authorizedAmount": 10.5,
          "authorizationCode": "173424",
          "actionCode": "000",
          "traceNumber": "177159",
          "transactionDate": "201010173430",
          "transactionId": "993202840246052"
        },
        "token": {
          "tokenId": "7000010038706267",
          "ownerId": "abc@mail.com",
          "expireOn": "240702123548"
        },
        "dataMap": {
          "TERMINAL": "00000001",
          "TRACE_NUMBER": "177159",
          "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
          "SIGNATURE": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73",
          "CARD": "455170******8329",
          "MERCHANT": "341198210",
          "STATUS": "Authorized",
          "INSTALLMENTS_INFO": "02000000000",
          "ACTION_DESCRIPTION": "Aprobado y completado con exito",
          "ID_UNICO": "993202840246052",
          "AMOUNT": "10.50",
          "QUOTA_NUMBER": "02",
          "AUTHORIZATION_CODE": "173424",
          "CURRENCY": "0604",
          "TRANSACTION_DATE": "201010173430",
          "ACTION_CODE": "000",
          "CARD_TOKEN": "7000010038706267",
          "ECI": "07",
          "BRAND": "visa",
          "ADQUIRENTE": "570002",
          "QUOTA_AMOUNT": "0.00",
          "PROCESS_CODE": "000000",
          "VAULT_BLOCK": "abc@mail.com",
          "TRANSACTION_ID": "993202840246052",
          "QUOTA_DEFERRED": "0"
        }
      }
    }'
  end

  def successful_refund_response_body
    '{
      "trace_id": 50300,
      "code": "S001",
      "message": "successful refund",
      "simetrik_authorization_id": "S-1205",
      "acquirer_body":  {
        "header": {
          "ecoreTransactionUUID": "8d2dfc73-ec1f-43af-aa0f-b2c123fd25ea",
          "ecoreTransactionDate": 1603054418778,
          "millis": 4752
        },
        "fulfillment": {
          "channel": "web",
          "merchantId": "341198210",
          "terminalId": "1",
          "captureType": "manual",
          "countable": true,
          "fastPayment": false,
          "signature": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73"
        },
        "order": {
          "tokenId": "99E9BF92C69A4799A9BF92C69AF79979",
          "purchaseNumber": "2020100901",
          "amount": 10.5,
          "installment": 2,
          "currency": "PEN",
          "authorizedAmount": 10.5,
          "authorizationCode": "173424",
          "actionCode": "000",
          "traceNumber": "177159",
          "transactionDate": "201010173430",
          "transactionId": "993202840246052"
        },
        "token": {
          "tokenId": "7000010038706267",
          "ownerId": "abc@mail.com",
          "expireOn": "240702123548"
        },
        "dataMap": {
          "TERMINAL": "00000001",
          "TRACE_NUMBER": "177159",
          "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
          "SIGNATURE": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73",
          "CARD": "455170******8329",
          "MERCHANT": "341198210",
          "STATUS": "Authorized",
          "INSTALLMENTS_INFO": "02000000000",
          "ACTION_DESCRIPTION": "Aprobado y completado con exito",
          "ID_UNICO": "993202840246052",
          "AMOUNT": "10.50",
          "QUOTA_NUMBER": "02",
          "AUTHORIZATION_CODE": "173424",
          "CURRENCY": "0604",
          "TRANSACTION_DATE": "201010173430",
          "ACTION_CODE": "000",
          "CARD_TOKEN": "7000010038706267",
          "ECI": "07",
          "BRAND": "visa",
          "ADQUIRENTE": "570002",
          "QUOTA_AMOUNT": "0.00",
          "PROCESS_CODE": "000000",
          "VAULT_BLOCK": "abc@mail.com",
          "TRANSACTION_ID": "993202840246052",
          "QUOTA_DEFERRED": "0"
        }
      }
    }'
  end

  def failed_refund_response_body
    '{
      "trace_id": 50300,
      "code": "R302",
      "message": "processing_error",
      "simetrik_authorization_id": "S-1205",
      "avs_result": "I",
      "cvv_result": "P",
      "acquirer_body":  {
        "header": {
          "ecoreTransactionUUID": "8d2dfc73-ec1f-43af-aa0f-b2c123fd25ea",
          "ecoreTransactionDate": 1603054418778,
          "millis": 4752
        },
        "fulfillment": {
          "channel": "web",
          "merchantId": "341198210",
          "terminalId": "1",
          "captureType": "manual",
          "countable": true,
          "fastPayment": false,
          "signature": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73"
        },
        "order": {
          "tokenId": "99E9BF92C69A4799A9BF92C69AF79979",
          "purchaseNumber": "2020100901",
          "amount": 10.5,
          "installment": 2,
          "currency": "PEN",
          "authorizedAmount": 10.5,
          "authorizationCode": "173424",
          "actionCode": "000",
          "traceNumber": "177159",
          "transactionDate": "201010173430",
          "transactionId": "993202840246052"
        },
        "token": {
          "tokenId": "7000010038706267",
          "ownerId": "abc@mail.com",
          "expireOn": "240702123548"
        },
        "dataMap": {
          "TERMINAL": "00000001",
          "TRACE_NUMBER": "177159",
          "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
          "SIGNATURE": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73",
          "CARD": "455170******8329",
          "MERCHANT": "341198210",
          "STATUS": "Authorized",
          "INSTALLMENTS_INFO": "02000000000",
          "ACTION_DESCRIPTION": "Aprobado y completado con exito",
          "ID_UNICO": "993202840246052",
          "AMOUNT": "10.50",
          "QUOTA_NUMBER": "02",
          "AUTHORIZATION_CODE": "173424",
          "CURRENCY": "0604",
          "TRANSACTION_DATE": "201010173430",
          "ACTION_CODE": "000",
          "CARD_TOKEN": "7000010038706267",
          "ECI": "07",
          "BRAND": "visa",
          "ADQUIRENTE": "570002",
          "QUOTA_AMOUNT": "0.00",
          "PROCESS_CODE": "000000",
          "VAULT_BLOCK": "abc@mail.com",
          "TRANSACTION_ID": "993202840246052",
          "QUOTA_DEFERRED": "0"
        }
      }
    }'
  end

  def successful_void_response_body
    '{
      "trace_id": 50300,
      "code": "S001",
      "message": "successful void",
      "simetrik_authorization_id": "S-1205",
      "acquirer_body":  {}
    }'
  end

  def failed_void_response_body
    '{
      "trace_id": 50300,
      "code": "R302",
      "message": "processing_error",
      "simetrik_authorization_id": "S-1205",
      "avs_result": "I",
      "cvv_result": "P",
      "acquirer_body":  {
        "header": {
          "ecoreTransactionUUID": "8d2dfc73-ec1f-43af-aa0f-b2c123fd25ea",
          "ecoreTransactionDate": 1603054418778,
          "millis": 4752
        },
        "fulfillment": {
          "channel": "web",
          "merchantId": "341198210",
          "terminalId": "1",
          "captureType": "manual",
          "countable": true,
          "fastPayment": false,
          "signature": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73"
        },
        "order": {
          "tokenId": "99E9BF92C69A4799A9BF92C69AF79979",
          "purchaseNumber": "2020100901",
          "amount": 10.5,
          "installment": 2,
          "currency": "PEN",
          "authorizedAmount": 10.5,
          "authorizationCode": "173424",
          "actionCode": "000",
          "traceNumber": "177159",
          "transactionDate": "201010173430",
          "transactionId": "993202840246052"
        },
        "token": {
          "tokenId": "7000010038706267",
          "ownerId": "abc@mail.com",
          "expireOn": "240702123548"
        },
        "dataMap": {
          "TERMINAL": "00000001",
          "TRACE_NUMBER": "177159",
          "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
          "SIGNATURE": "2e2cba40-a914-4e79-b4d3-8a2f2737eb73",
          "CARD": "455170******8329",
          "MERCHANT": "341198210",
          "STATUS": "Authorized",
          "INSTALLMENTS_INFO": "02000000000",
          "ACTION_DESCRIPTION": "Aprobado y completado con exito",
          "ID_UNICO": "993202840246052",
          "AMOUNT": "10.50",
          "QUOTA_NUMBER": "02",
          "AUTHORIZATION_CODE": "173424",
          "CURRENCY": "0604",
          "TRANSACTION_DATE": "201010173430",
          "ACTION_CODE": "000",
          "CARD_TOKEN": "7000010038706267",
          "ECI": "07",
          "BRAND": "visa",
          "ADQUIRENTE": "570002",
          "QUOTA_AMOUNT": "0.00",
          "PROCESS_CODE": "000000",
          "VAULT_BLOCK": "abc@mail.com",
          "TRANSACTION_ID": "993202840246052",
          "QUOTA_DEFERRED": "0"
        }
      }
    }'
  end
end
