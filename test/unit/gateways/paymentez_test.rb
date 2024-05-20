require 'test_helper'

class PaymentezTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaymentezGateway.new(application_code: 'foo', app_key: 'bar')
    @credit_card = credit_card
    @elo_credit_card = credit_card(
      '6362970000457013',
      month: 10,
      year: 2020,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'elo'
    )
    @amount = 100

    @options = {
      order_id: '1',
      user_id: '123',
      billing_address: address,
      description: 'Store Purchase',
      email: 'a@b.com'
    }

    @cavv = 'example-cavv-value'
    @xid = 'three-ds-v1-trans-id'
    @eci = '01'
    @three_ds_v1_version = '1.0.2'
    @three_ds_v2_version = '2.1.0'
    @authentication_response_status = 'Y'
    @directory_server_transaction_id = 'directory_server_transaction_id'

    @three_ds_v1_mpi = {
      cavv: @cavv,
      eci: @eci,
      version: @three_ds_v1_version,
      xid: @xid
    }

    @three_ds_v2_mpi = {
      cavv: @cavv,
      eci: @eci,
      version: @three_ds_v2_version,
      authentication_response_status: @authentication_response_status,
      ds_transaction_id: @directory_server_transaction_id
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'PR-926', response.authorization
    assert response.test?
  end

  def test_rejected_purchase
    @gateway.expects(:ssl_post).returns(purchase_rejected_status)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Fondos Insuficientes', response.message
  end

  def test_cancelled_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response_with_cancelled)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'ApprovedTimeOutReversal', response.message
  end

  def test_successful_purchase_with_elo
    @gateway.expects(:ssl_post).returns(successful_purchase_with_elo_response)

    response = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success response

    assert_equal 'CI-14952', response.authorization
    assert response.test?
  end

  def test_successful_capture_with_otp
    authorization = 'CI-14952'
    options = @options.merge({ type: 'BY_OTP', value: '012345' })
    response = stub_comms do
      @gateway.capture(nil, authorization, options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'BY_OTP', request['type']
      assert_equal '012345', request['value']
      assert_equal authorization, request['transaction']['id']
      assert_equal '123', request['user']['id']
    end.respond_with(successful_otp_capture_response)
    assert_success response
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, '123456789012345678901234567890', @options)
    assert_success response
    assert_equal 'PR-926', response.authorization
    assert response.test?
  end

  def test_purchase_3ds1_mpi_fields
    @options[:three_d_secure] = @three_ds_v1_mpi

    expected_auth_data = {
      cavv: @cavv,
      xid: @xid,
      eci: @eci,
      version: @three_ds_v1_version
    }

    @gateway.expects(:commit_transaction).with do |_, post_data|
      post_data['extra_params'][:auth_data] == expected_auth_data
    end

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_purchase_3ds2_mpi_fields
    @options[:three_d_secure] = @three_ds_v2_mpi

    expected_auth_data = {
      cavv: @cavv,
      eci: @eci,
      version: @three_ds_v2_version,
      reference_id: @directory_server_transaction_id,
      status: @authentication_response_status
    }

    @gateway.expects(:commit_transaction).with() do |_, post_data|
      post_data['extra_params'][:auth_data] == expected_auth_data
    end

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_expired_card
    @gateway.expects(:ssl_post).returns(expired_card_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert_equal 'Expired card', response.message
  end

  def test_successful_authorize
    @gateway.stubs(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'CI-635', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_elo
    @gateway.stubs(:ssl_post).returns(successful_authorize_with_elo_response)

    response = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_success response
    assert_equal 'CI-14953', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_token
    @gateway.stubs(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, '123456789012345678901234567890', @options)
    assert_success response
    assert_equal 'CI-635', response.authorization
    assert response.test?
  end

  def test_authorize_3ds1_mpi_fields
    @options[:three_d_secure] = @three_ds_v1_mpi

    expected_auth_data = {
      cavv: @cavv,
      xid: @xid,
      eci: @eci,
      version: @three_ds_v1_version
    }

    @gateway.expects(:commit_transaction).with() do |_, post_data|
      post_data['extra_params'][:auth_data] == expected_auth_data
    end

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_authorize_3ds2_mpi_fields
    @options.merge!(new_reference_id_field: true)
    @options[:three_d_secure] = @three_ds_v2_mpi

    expected_auth_data = {
      cavv: @cavv,
      eci: @eci,
      version: @three_ds_v2_version,
      reference_id: @directory_server_transaction_id,
      status: @authentication_response_status
    }

    @gateway.expects(:commit_transaction).with() do |_, post_data|
      post_data['extra_params'][:auth_data] == expected_auth_data
    end

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(nil, '1234', @options)
    assert_success response
    assert_equal 'CI-635', response.authorization
    assert response.test?
  end

  def test_successful_capture_with_elo
    @gateway.expects(:ssl_post).returns(successful_capture_with_elo_response)

    response = @gateway.capture(nil, '1234', @options)
    assert_success response
    assert_equal 'CI-14953', response.authorization
    assert response.test?
  end

  def test_successful_capture_with_amount
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount + 1, '1234', @options)
    assert_success response
    assert_equal 'CI-635', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '1234', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(nil, '1234', @options)
    assert_success response
    assert_equal 'Completed', response.message
  end

  def test_partial_refund
    response = stub_comms do
      @gateway.refund(@amount, '1234', @options)
    end.respond_with(pending_response_current_status_cancelled)
    assert_success response
    assert_equal 'Completed partial refunded with 1.9', response.message
  end

  def test_partial_refund_with_pending_request_status
    response = stub_comms do
      @gateway.refund(@amount, '1234', @options)
    end.respond_with(pending_response_with_pending_request_status)
    assert_success response
    assert_equal 'Waiting gateway confirmation for partial refund with 17480.0', response.message
  end

  def test_duplicate_partial_refund
    response = stub_comms do
      @gateway.refund(@amount, '1234', @options)
    end.respond_with(failed_pending_response_current_status)
    assert_failure response

    assert_equal 'Transaction already refunded', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '1234', @options)
    assert_failure response
    assert_equal 'Invalid Status', response.message
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('1234', @options)
    assert_success response
    assert_equal 'Completed', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void('1234', @options)
    assert_equal 'Invalid Status', response.message
    assert_failure response
  end

  def test_successful_void_with_more_info
    @gateway.expects(:ssl_post).returns(successful_void_response_with_more_info)

    response = @gateway.void('1234', @options.merge(more_info: true))
    assert_success response
    assert_equal 'Completed', response.message
    assert_equal '00', response.params['transaction']['carrier_code']
    assert_equal 'Reverse by mock', response.params['transaction']['message']
    assert response.test?
  end

  def test_simple_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '14436664108567261211', response.authorization
  end

  def test_simple_store_with_elo
    @gateway.expects(:ssl_post).returns(successful_store_with_elo_response)

    response = @gateway.store(@elo_credit_card, @options)
    assert_success response
    assert_equal '15550938907932827845', response.authorization
  end

  def test_complex_store
    @gateway.stubs(:ssl_post).returns(already_stored_response, successful_unstore_response, successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_paymentez_crashes_fail
    @gateway.stubs(:ssl_post).returns(crash_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_successful_inquire_with_transaction_id
    response = stub_comms(@gateway, :ssl_get) do
      @gateway.inquire('CI-635')
    end.check_request do |method, _endpoint, _data, _headers|
      assert_match('https://ccapi-stg.paymentez.com/v2/transaction/CI-635', method)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'CI-635', response.authorization
    assert response.test?
  end

  private

  def pre_scrubbed
    %q(
opening connection to ccapi-stg.paymentez.com:443...
opened
starting SSL for ccapi-stg.paymentez.com:443...
SSL established
<- "POST /v2/transaction/debit_cc HTTP/1.1\r\nContent-Type: application/json\r\nAuth-Token: U1BETFktTVgtU0VSVkVSOzE1MTM3MDU5OTc7M8I1MjQ1NT5yMWNlZWU0ZjFlYTdiZDBlOGE1MWIxZjBkYzBjZTMyYjZmN2RmNjE4ZGQ5MmNiODhjMTM5MWIyNg==\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ccapi-stg.paymentez.com\r\nContent-Length: 264\r\n\r\n"
<- "{\"order\":{\"amount\":1.0,\"vat\":0,\"dev_reference\":\"Testing\",\"description\":\"Store Purchase\"},\"card\":{\"number\":\"4111111111111111\",\"holder_name\":\"Longbob Longsen\",\"expiry_month\":9,\"expiry_year\":2018,\"cvc\":\"123\",\"type\":\"vi\"},\"user\":{\"id\":\"123\",\"email\":\"joe@example.com\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: nginx/1.12.1\r\n"
-> "Date: Tue, 19 Dec 2017 17:51:42 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 402\r\n"
-> "Connection: close\r\n"
-> "Vary: Accept-Language, Cookie\r\n"
-> "Content-Language: es\r\n"
-> "\r\n"
reading 402 bytes...
-> "{\"transaction\": {\"status\": \"success\", \"payment_date\": \"2017-12-19T17:51:39.985\", \"amount\": 1.0, \"authorization_code\": \"123456\", \"installments\": 1, \"dev_reference\": \"Testing\", \"message\": \"Response by mock\", \"carrier_code\": \"00\", \"id\": \"PR-871\", \"status_detail\": 3}, \"card\": {\"bin\": \"411111\", \"expiry_year\": \"2018\", \"expiry_month\": \"9\", \"transaction_reference\": \"PR-871\", \"type\": \"vi\", \"number\": \"1111\"}}"
read 402 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to ccapi-stg.paymentez.com:443...
opened
starting SSL for ccapi-stg.paymentez.com:443...
SSL established
<- "POST /v2/transaction/debit_cc HTTP/1.1\r\nContent-Type: application/json\r\nAuth-Token: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: ccapi-stg.paymentez.com\r\nContent-Length: 264\r\n\r\n"
<- "{\"order\":{\"amount\":1.0,\"vat\":0,\"dev_reference\":\"Testing\",\"description\":\"Store Purchase\"},\"card\":{\"number\":[FILTERED],\"holder_name\":\"Longbob Longsen\",\"expiry_month\":9,\"expiry_year\":2018,\"cvc\":[FILTERED],\"type\":\"vi\"},\"user\":{\"id\":\"123\",\"email\":\"joe@example.com\"}}"
-> "HTTP/1.1 200 OK\r\n"
-> "Server: nginx/1.12.1\r\n"
-> "Date: Tue, 19 Dec 2017 17:51:42 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 402\r\n"
-> "Connection: close\r\n"
-> "Vary: Accept-Language, Cookie\r\n"
-> "Content-Language: es\r\n"
-> "\r\n"
reading 402 bytes...
-> "{\"transaction\": {\"status\": \"success\", \"payment_date\": \"2017-12-19T17:51:39.985\", \"amount\": 1.0, \"authorization_code\": \"123456\", \"installments\": 1, \"dev_reference\": \"Testing\", \"message\": \"Response by mock\", \"carrier_code\": \"00\", \"id\": \"PR-871\", \"status_detail\": 3}, \"card\": {\"bin\": \"411111\", \"expiry_year\": \"2018\", \"expiry_month\": \"9\", \"transaction_reference\": \"PR-871\", \"type\": \"vi\", \"number\": \"1111\"}}"
read 402 bytes
Conn close
    )
  end

  def successful_purchase_response
    '
      {
        "transaction": {
          "status": "success",
          "current_status": "APPROVED",
          "payment_date": "2017-12-19T20:29:12.715",
          "amount": 1,
          "authorization_code": "123456",
          "installments": 1,
          "dev_reference": "Testing",
          "message": "Response by mock",
          "carrier_code": "00",
          "id": "PR-926",
          "status_detail": 3
        },
        "card": {
          "bin": "411111",
          "expiry_year": "2018",
          "expiry_month": "9",
          "transaction_reference": "PR-926",
          "type": "vi",
          "number": "1111"
        }
      }
    '
  end

  def successful_purchase_with_elo_response
    '
      {
        "transaction": {
          "status": "success",
          "current_status": "APPROVED",
          "payment_date": "2019-03-06T16:47:13.430",
          "amount": 1,
          "authorization_code": "TEST00",
          "installments": 1,
          "dev_reference": "Testing",
          "message": "Response by mock",
          "carrier_code": null,
          "id": "CI-14952",
          "status_detail": 3
        },
        "card": {
          "bin": "636297",
          "expiry_year": "2020",
          "expiry_month": "10",
          "transaction_reference": "CI-14952",
          "type": "el",
          "number": "7013",
          "origin": "Paymentez"
        }
      }
    '
  end

  def failed_purchase_response
    '
      {
        "transaction": {
          "status": "failure",
          "payment_date": null,
          "amount": 1,
          "authorization_code": null,
          "installments": 1,
          "dev_reference": "Testing",
          "message": "Response by mock",
          "carrier_code": "3",
          "id": "PR-945",
          "status_detail": 9
        },
        "card": {
          "bin": "424242",
          "expiry_year": "2018",
          "expiry_month": "9",
          "transaction_reference": "PR-945",
          "type": "vi",
          "number": "4242"
        }
      }
    '
  end

  def successful_authorize_response
    '
      {
        "transaction": {
          "status": "success",
          "current_status": "PENDING",
          "payment_date": "2017-12-21T18:04:42",
          "amount": 1,
          "authorization_code": "487897",
          "installments": 1,
          "dev_reference": "Testing",
          "message": "Operation Successful",
          "carrier_code": "4",
          "id": "CI-635",
          "status_detail": 0
        },
        "card": {
          "bin": "411111",
          "status": "valid",
          "token": "12032069702317830187",
          "expiry_year": "2018",
          "expiry_month": "9",
          "transaction_reference": "CI-635",
          "type": "vi",
          "number": "1111"
        }
      }
    '
  end

  def successful_authorize_with_elo_response
    '
      {
        "transaction": {
          "status": "success",
          "current_status": "PENDING",
          "payment_date": "2019-03-06T16:53:36.336",
          "amount": 1,
          "authorization_code": "TEST00",
          "installments": 1,
          "dev_reference": "Testing",
          "message": "Response by mock",
          "carrier_code": null,
          "id": "CI-14953",
          "status_detail": 0
        },
        "card": {
          "bin": "636297",
          "status": "",
          "token": "",
          "expiry_year": "2020",
          "expiry_month": "10",
          "transaction_reference": "CI-14953",
          "type": "el",
          "number": "7013",
          "origin": "Paymentez"
        }
      }
    '
  end

  def failed_authorize_response
    '
      {
        "transaction": {
          "status": "failure",
          "payment_date": null,
          "amount": 1.0,
          "authorization_code": null,
          "installments": 1,
          "dev_reference": "Testing",
          "message": null,
          "carrier_code": "3",
          "id": "CI-1223",
          "status_detail": 9
        },
        "card": {
          "bin": "424242",
          "status": null,
          "token": "6461587429110733892",
          "expiry_year": "2019",
          "expiry_month": "9",
          "transaction_reference": "CI-1223",
          "type": "vi",
          "number": "4242",
          "origin": "Paymentez"
        }
      }
    '
  end

  def successful_capture_response
    '
      {
        "transaction": {
          "status": "success",
          "current_status": "APPROVED",
          "payment_date": "2017-12-21T18:04:42",
          "amount": 1,
          "authorization_code": "487897",
          "installments": 1,
          "dev_reference": "Testing",
          "message": "Operation Successful",
          "carrier_code": "6",
          "id": "CI-635",
          "status_detail": 3
        },
        "card": {
          "bin": "411111",
          "status": "valid",
          "token": "12032069702317830187",
          "expiry_year": "2018",
          "expiry_month": "9",
          "transaction_reference": "CI-635",
          "type": "vi",
          "number": "1111"
        }
      }
    '
  end

  def successful_capture_with_elo_response
    '
      {
        "transaction": {
          "status": "success",
          "current_status": "APPROVED",
          "payment_date": "2019-03-06T16:53:36",
          "amount": 1,
          "authorization_code": "TEST00",
          "installments": 1,
          "dev_reference": "Testing",
          "message": "Response by mock",
          "carrier_code": null,
          "id": "CI-14953",
          "status_detail": 3
        },
        "card": {
          "bin": "636297",
          "status": "",
          "token": "",
          "expiry_year": "2020",
          "expiry_month": "10",
          "transaction_reference": "CI-14953",
          "type": "el",
          "number": "7013",
          "origin": "Paymentez"
        }
      }
    '
  end

  def successful_otp_capture_response
    '{
      "status": 1,
      "payment_date": "2017-09-26T21:16:00",
      "amount": 99.0,
      "transaction_id": "CI-14952",
      "status_detail": 3,
      "message": ""
    }'
  end

  def failed_capture_response
    '{"error": {"type": "Carrier not supported", "help": "", "description": "{}"}}'
  end

  def successful_void_response
    '{"status": "success", "detail": "Completed"}'
  end

  def failed_void_response
    '{"status": "failure", "detail": "Invalid Status"}'
  end

  def successful_void_response_with_more_info
    '{"status": "success", "detail": "Completed", "transaction": {"carrier_code": "00", "message": "Reverse by mock", "status_detail":7}}'
  end

  alias successful_refund_response successful_void_response
  alias failed_refund_response failed_void_response
  alias successful_refund_response_with_more_info successful_void_response_with_more_info

  def already_stored_response
    '{"error": {"type": "Card already added: 14436664108567261211", "help": "If you want to update the card, first delete it", "description": "{}"}}'
  end

  def successful_unstore_response
    '{"message": "card deleted"}'
  end

  def successful_store_response
    '{"card": {"bin": "411111", "status": "valid", "token": "14436664108567261211", "message": "", "expiry_year": "2018", "expiry_month": "9", "transaction_reference": "PR-959", "type": "vi", "number": "1111"}}'
  end

  def successful_store_with_elo_response
    '{"card": {"bin": "636297", "status": "valid", "token": "15550938907932827845", "message": "", "expiry_year": "2020", "expiry_month": "10", "transaction_reference": "CI-14956", "type": "el", "number": "7013", "origin": "Paymentez"}}'
  end

  def failed_store_response
    '
      {
        "card": {
          "bin": "424242",
          "status": "rejected",
          "token": "2026849624512750545",
          "message": "Not Authorized",
          "expiry_year": "2018",
          "expiry_month": "9",
          "transaction_reference": "CI-606",
          "type": "vi",
          "number": "4242"
        }
      }
    '
  end

  def expired_card_response
    '
      {
       "transaction":{
          "status":"failure",
          "payment_date":null,
          "amount":1.0,
          "authorization_code":null,
          "installments":1,
          "dev_reference":"ci123",
          "message":"Expired card",
          "carrier_code":"54",
          "id":"PR-25",
          "status_detail":9
       },
       "card":{
          "bin":"528851",
          "expiry_year":"2024",
          "expiry_month":"4",
          "transaction_reference":"PR-25",
          "type":"mc",
          "number":"9794",
          "origin":"Paymentez"
       }
      }
    '
  end

  def crash_response
    '
      <html>
        <head>
          <title>Internal Server Error</title>
        </head>
        <body>
          <h1><p>Internal Server Error</p></h1>

        </body>
      </html>
    '
  end

  def failed_purchase_response_with_cancelled
    '{"transaction": {"id": "PR-63850089", "status": "success", "current_status": "CANCELLED", "status_detail": 29, "payment_date": "2023-12-02T22:33:48.993", "amount": 385.9, "installments": 1, "carrier_code": "00", "message": "ApprovedTimeOutReversal", "authorization_code": "097097", "dev_reference": "Order_123456789", "carrier": "Test", "product_description": "test order 1234", "payment_method_type": "7", "trace_number": "407123", "installments_type": "Revolving credit"}, "card": {"number": "4111", "bin": "11111", "type": "mc", "transaction_reference": "PR-123456", "expiry_year": "2026", "expiry_month": "12", "origin": "Paymentez", "bank_name": "CITIBANAMEX"}}'
  end

  def pending_response_current_status_cancelled
    '{"status": "success", "detail": "Completed partial refunded with 1.9", "transaction": {"id": "CIBC-45678", "status": "success", "current_status": "CANCELLED", "status_detail": 34, "payment_date": "2024-04-10T21:06:00", "amount": 15.544518, "installments": 1, "carrier_code": "00", "message": "Transaction Successful", "authorization_code": "000111", "dev_reference": "Order_987654_1234567899876", "carrier": "CIBC", "product_description": "referencia", "payment_method_type": "0", "trace_number": 12444, "refund_amount": 1.9}, "card": {"number": "1234", "bin": "12345", "type": "mc", "transaction_reference": "CIBC-12345", "status": "", "token": "", "expiry_year": "2028", "expiry_month": "1", "origin": "Paymentez"}}'
  end

  def failed_pending_response_current_status
    '{"status": "failure", "detail": "Transaction already refunded", "transaction": {"id": "CIBC-45678", "status": "success", "current_status": "APPROVED", "status_detail": 34, "payment_date": "2024-04-10T21:06:00", "amount": 15.544518, "installments": 1, "carrier_code": "00", "message": "Transaction Successful", "authorization_code": "000111", "dev_reference": "Order_987654_1234567899876", "carrier": "CIBC", "product_description": "referencia", "payment_method_type": "0", "trace_number": 12444, "refund_amount": 1.9}, "card": {"number": "1234", "bin": "12345", "type": "mc", "transaction_reference": "CIBC-12345", "status": "", "token": "", "expiry_year": "2028", "expiry_month": "1", "origin": "Paymentez"}}'
  end

  def pending_response_with_pending_request_status
    '{"status": "pending", "detail": "Waiting gateway confirmation for partial refund with 17480.0"}'
  end

  def purchase_rejected_status
    '{"transaction": {"id": "RB-14573124", "status": "failure", "current_status": "REJECTED", "status_detail": 9, "payment_date": null, "amount": 25350.0, "installments": 1, "carrier_code": "51", "message": "Fondos Insuficientes", "authorization_code": null, "dev_reference": "Order_1222223333_44445555", "carrier": "TestTest", "product_description": "Test Transaction", "payment_method_type": "7"}, "card": {"number": "4433", "bin": "54354", "type": "mc", "transaction_reference": "TT-1593752", "expiry_year": "2027", "expiry_month": "4", "origin": "Paymentez", "bank_name": "Bantest S.B."}}'
  end
end
