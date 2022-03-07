require 'test_helper'

class SimetrikTest < Test::Unit::TestCase
  def setup
    SimetrikGateway.any_instance.stubs(:sign_access_token).returns('ACCESS_TOKEN')
    @token_acquirer = 'ea890fd1-49f3-4a34-a150-192bf9a59205'
    @datetime = Time.new.strftime('%Y-%m-%dT%H:%M:%S.%L%:z')
    @gateway = SimetrikGateway.new(
      client_id: 'client_id',
      client_secret: 'client_secret_key',
      audience: 'audience_url'
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
        installments: 1,
        amount: {
          currency: 'USD',
          vat: 19
        }
      },
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

    @authorize_capture__fail_options = {
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
        installments: 1,
        amount: {
          currency: 'USD',
          vat: 19
        }
      },
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
      "forward_route": {
        "trace_id": @trace_id,
        "psp_extra_fields": {}
      },
      "forward_payload": {
        "user": {
          "id": '123',
          "email": 's@example.com'
        },
        "order": {
          "id": @order_id,
          "description": 'a popsicle',
          "installments": 1,
          "datetime_local_transaction": @datetime,
          "amount": {
            "total_amount": 10.0,
            "currency": 'USD',
            "vat": 19
          }
        },
        "payment_method": {
          "card": {
            "number": '4551478422045511',
            "exp_month": 12,
            "exp_year": 2029,
            "security_code": '111',
            "type": 'visa',
            "holder_first_name": 'sergiod',
            "holder_last_name": 'lobob'
          }
        },
        "authentication": {
          "three_ds_fields": {
            "version": '2.1.0',
            "eci": '02',
            "cavv": 'jJ81HADVRtXfCBATEp01CJUAAAA',
            "ds_transaction_id": '97267598-FAE6-48F2-8083-C23433990FBC',
            "acs_transaction_id": '13c701a3-5a88-4c45-89e9-ef65e50a8bf9',
            "xid": '00000000000000000501',
            "enrolled": 'string',
            "cavv_algorithm": '1',
            "directory_response_status": 'Y',
            "authentication_response_status": 'Y',
            "three_ds_server_trans_id": '24f701e3-9a85-4d45-89e9-af67e70d8fg8'
          }
        },
        "sub_merchant": {
          "merchant_id": 'string',
          "extra_params": {},
          "mcc": 'string',
          "name": 'string',
          "address": 'string',
          "postal_code": 'string',
          "url": 'string',
          "phone_number": 'string'
        },
        "acquire_extra_options": {}
      }
    }.to_json.to_s
  end

  def test_successful_purchase
    @gateway.stubs(:timestamp_transaction).returns(@datetime)
    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/charge", @authorize_capture_expected_body, anything).returns(SuccessfulPurchaseResponse.new())

    response = @gateway.purchase(@amount, @credit_card, @authorize_capture_options)
    assert_success response
    assert_instance_of Response, response

    assert_equal response.message, 'successful charge'
    assert_equal response.error_code, nil, 'Should expected error code equal to nil '
    assert_equal response.avs_result['code'], 'G'
    assert_equal response.cvv_result['code'], 'P'
    assert response.test?
  end

  def test_failed_purchase
    @gateway.stubs(:timestamp_transaction).returns(@datetime)
    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/charge", @authorize_capture_expected_body, anything).returns(FailedPurchaseResponse.new())

    response = @gateway.purchase(@amount, @credit_card, @authorize_capture__fail_options)
    assert_failure response
    assert_instance_of Response, response
    assert response.test?
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_not_equal response.error_code, nil, 'Should expected error code not equal to nil '
    assert response.test?
  end

  def test_successful_authorize
    @gateway.stubs(:timestamp_transaction).returns(@datetime)
    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/authorize", @authorize_capture_expected_body, anything).returns(SuccessfulAuthorizeResponse.new())

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
    @gateway.stubs(:timestamp_transaction).returns(@datetime)
    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/authorize", @authorize_capture_expected_body, anything).returns(FailedAuthorizeResponse.new())

    response = @gateway.authorize(@amount, @credit_card, @authorize_capture__fail_options)
    assert_failure response
    assert_instance_of Response, response
    assert response.test?

    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_not_equal response.error_code, nil, 'Should expected error code not equal to nil '
    assert response.test?
  end

  def test_successful_capture
    expected_post_obj = {
      "forward_payload": {
        "amount": {
          "total_amount": 10.0,
          "vat": 19,
          "currency": 'USD'
        },
        "transaction": {
          "id": 'fdb52e6a0e794b039de097e815a982fd'
        },
        "acquire_extra_options": {}
      },
      "forward_route": {
        "trace_id": @trace_id,
        "psp_extra_fields": {}
      }
    }.to_json.to_s

    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/capture", expected_post_obj, anything).returns(SuccessfulCaptureResponse.new())

    response = @gateway.capture(@amount, 'fdb52e6a0e794b039de097e815a982fd', {
      vat: @authorize_capture_options[:order][:amount][:vat],
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
    expected_post_obj = {
      "forward_payload": {
        "amount": {
          "total_amount": 10.0,
          "vat": 19,
          "currency": 'USD'
        },
        "transaction": {
          "id": 'SI-226'
        },
        "acquire_extra_options": {}
      },
      "forward_route": {
        "trace_id": @trace_id,
        "psp_extra_fields": {}
      }
    }.to_json.to_s

    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/capture", expected_post_obj, anything).returns(FailedCaptureResponse.new())

    response = @gateway.capture(@amount, 'SI-226', {
      vat: 19,
      currency: 'USD',
      token_acquirer: @token_acquirer,
      trace_id: @trace_id
    })

    assert_failure response
    assert_instance_of Response, response
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_not_equal response.error_code, nil, 'Should expected error code not equal to nil '
    assert response.test?
  end

  def test_successful_refund
    expected_post_obj = {
      "forward_payload": {
        "amount": {
          "total_amount": 10.0,
          "currency": 'USD'
        },
        "transaction": {
          "id": 'SI-226',
          'comment': 'A Comment'
        },
        "acquire_extra_options": {
          'ruc': 123
        }
      },
      "forward_route": {
        "trace_id": @trace_id,
        "psp_extra_fields": {}
      }
    }.to_json.to_s

    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/refund", expected_post_obj, anything).returns(SuccessfulRefundResponse.new())

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
    expected_post_obj = {
      "forward_payload": {
        "amount": {
          "total_amount": 10.0,
          "currency": 'USD'
        },
        "transaction": {
          "id": 'SI-226',
          'comment': 'A Comment'
        },
        "acquire_extra_options": {}
      },
      "forward_route": {
        "trace_id": @trace_id,
        "psp_extra_fields": {}
      }
    }.to_json.to_s

    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/refund", expected_post_obj, anything).returns(FailedRefundResponse.new())
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
    assert_not_equal response.error_code, nil, 'Should expected error code not equal to nil'
    assert response.test?
  end

  def test_successful_void
    expected_post_obj = {
      "forward_payload": {
        "transaction": {
          "id": 'a17f70f9-82de-4c47-8d9c-7743dac6a561'
        },
          "acquire_extra_options": {}
      },
      "forward_route": {
        "trace_id": @trace_id,
          "psp_extra_fields": {}
      }
    }.to_json.to_s

    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/void", expected_post_obj, anything).returns(SuccessfulVoidResponse.new())
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
    expected_post_obj = {
      "forward_payload": {
        "transaction": {
          "id": 'a17f70f9-82de-4c47-8d9c-7743dac6a561'
        },
        "acquire_extra_options": {}
      },
      "forward_route": {
        "trace_id": @trace_id,
        "psp_extra_fields": {}
      }
    }.to_json.to_s

    @gateway.expects(:raw_ssl_request).with(:post, "https://payments.sta.simetrik.com/v1/#{@token_acquirer}/void", expected_post_obj, anything).returns(FailedVoidResponse.new())
    response = @gateway.void('a17f70f9-82de-4c47-8d9c-7743dac6a561', {
      token_acquirer: @token_acquirer,
      trace_id: @trace_id
    })
    assert_failure response
    assert_instance_of Response, response
    assert_equal response.avs_result['code'], 'I'
    assert_equal response.cvv_result['code'], 'P'
    assert_not_equal response.error_code, nil, 'Should expected error code not equal to nil '
    assert response.test?
  end

  def test_scrub
    transcript = @gateway.scrub(pre_scrubbed())
    assert @gateway.supports_scrubbing?
    assert_scrubbed('4551478422045511', transcript)
  end

  private

  def pre_scrubbed
    '{\"forward_route\":{\"trace_id\":\"eee174b7-c5aa-4b9a-b599-f2d8b2bdda94\",\"psp_extra_fields\":{}},\"forward_payload\":{\"user\":{\"id\":\"123\",\"email\":\"s@example.com\"},\"order\":{\"datetime_local_transaction\":\"2022-02-18T10:13:18.019-05:00\",\"id\":\"870559598225\",\"description\":\"apopsicle\",\"installments\":1,\"amount\":{\"total_amount\":1.0,\"currency\":\"USD\",\"vat\":19},\"shipping_address\":{\"name\":\"string\",\"company\":\"string\",\"address1\":\"string\",\"address2\":\"string\",\"city\":\"string\",\"state\":\"string\",\"country\":\"string\",\"zip\":\"string\",\"phone\":\"string\"}},\"payment_method\":{\"card\":{\"number\":\"4551478422045511\",\"exp_month\":12,\"exp_year\":2029,\"security_code\":\"111\",\"type\":\"001\",\"holder_first_name\":\"sergiod\",\"holder_last_name\":\"lobob\",\"billing_address\":{\"name\":\"string\",\"company\":\"string\",\"address1\":\"string\",\"address2\":\"string\",\"city\":\"string\",\"state\":\"string\",\"country\":\"string\",\"zip\":\"string\",\"phone\":\"string\"}}},\"authentication\":{\"three_ds_fields\":{\"version\":\"2.1.0\",\"eci\":\"05\",\"cavv\":\"jJ81HADVRtXfCBATEp01CJUAAAA\",\"ds_transaction_id\":\"97267598-FAE6-48F2-8083-C23433990FBC\",\"acs_transaction_id\":\"13c701a3-5a88-4c45-89e9-ef65e50a8bf9\",\"xid\":\"333333333\",\"enrolled\":\"test\",\"cavv_algorithm\":\"1\",\"directory_response_status\":\"Y\",\"authentication_response_status\":\"Y\",\"three_ds_server_trans_id\":\"24f701e3-9a85-4d45-89e9-af67e70d8fg8\"}},\"sub_merchant\":{\"merchant_id\":\"400000008\",\"extra_params\":{},\"mcc\":\"5816\",\"name\":\"885.519.237\",\"address\":\"None\",\"postal_code\":\"None\",\"url\":\"string\",\"phone_number\":\"3434343\"},\"acquire_extra_options\":{}}}'
  end

  class SuccessfulPurchaseResponse
    def code
      200
    end

    def body
      successful_purchase_response_body()
    end

    private

    def successful_purchase_response_body
      <<-RESPONSE
      {
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
      }
      RESPONSE
    end
  end

  class FailedPurchaseResponse
    def code
      400
    end

    def body
      failed_purchase_response_body()
    end

    private

    def failed_purchase_response_body
      <<-RESPONSE
      {
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
      }
      RESPONSE
    end
  end

  class SuccessfulAuthorizeResponse
    def code
      200
    end

    def body
      successful_authorize_response_body()
    end

    private

    def successful_authorize_response_body
      <<-RESPONSE
      {
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
      }

      RESPONSE
    end
  end

  class FailedAuthorizeResponse
    def code
      400
    end

    def body
      failed_authorize_response_body()
    end

    private

    def failed_authorize_response_body
      <<-RESPONSE
      {
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
      }

      RESPONSE
    end
  end

  class SuccessfulCaptureResponse
    def code
      200
    end

    def body
      successful_capture_response_body()
    end

    private

    def successful_capture_response_body
      <<~RESPONSE
            {
            "code": "S001",
            "message": "successful capture",
            "acquirer_body": {
                "dataMap": {
                    "ACTION_CODE": "000",
                    "AUTHORIZATION_CODE": "201518",
                    "ECI_DESCRIPTION": "Transaccion no autenticada pero enviada en canal seguro",
                    "ID_UNICO": "984220460015478",
                    "MERCHANT": "400000008",
                    "STATUS": "Confirmed",
                    "TRACE_NUMBER": "76363"
                },
                "order": {
                    "purchaseNumber": "56700002",
                    "amount": 1000.0,
                    "currency": "USD",
                    "authorizedAmount": 1000.0,
                    "authorizationCode": "201518",
                    "actionCode": "000",
                    "traceNumber": "76363",
                    "transactionId": "984220460015478",
                    "transactionDate": "220215201732"
                }
            },
            "trace_id": "6e85ff84cb3e4452b613ffa22af68e8f"
        }
      RESPONSE
    end
  end

  class FailedCaptureResponse
    def code
      400
    end

    def body
      failed_capture_response_body()
    end

    private

    def failed_capture_response_body
      <<-RESPONSE
      {
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
      }
      RESPONSE
    end
  end

  class SuccessfulRefundResponse
    def code
      200
    end

    def body
      successful_refund_response_body()
    end

    private

    def successful_refund_response_body
      <<-RESPONSE
      {
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
      }
      RESPONSE
    end
  end

  class FailedRefundResponse
    def code
      400
    end

    def body
      failed_refund_response_body()
    end

    private

    def failed_refund_response_body
      <<-RESPONSE
      {
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
      }
      RESPONSE
    end
  end

  class SuccessfulVoidResponse
    def code
      200
    end

    def body
      successful_void_response_body()
    end

    private

    def successful_void_response_body
      <<-RESPONSE
        {
          "trace_id": 50300,
          "code": "S001",
          "message": "successful void",
          "simetrik_authorization_id": "S-1205",
          "acquirer_body":  {}
        }
      RESPONSE
    end
  end

  class FailedVoidResponse
    def code
      400
    end

    def body
      failed_void_response_body()
    end

    private

    def failed_void_response_body
      <<-RESPONSE
      {
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
      }
      RESPONSE
    end
  end
end
