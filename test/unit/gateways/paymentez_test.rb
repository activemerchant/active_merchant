require 'test_helper'

class PaymentezTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaymentezGateway.new(application_code: 'foo', app_key: 'bar')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      user_id: '123',
      billing_address: address,
      description: 'Store Purchase',
      email: 'a@b.com'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'PR-926', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, '123456789012345678901234567890', @options)
    assert_success response

    assert_equal 'PR-926', response.authorization
    assert response.test?
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

  def test_successful_authorize_with_token
    @gateway.stubs(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, '123456789012345678901234567890', @options)
    assert_success response
    assert_equal 'CI-635', response.authorization
    assert response.test?
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
    assert response.test?
  end

  def test_partial_refund
    response = stub_comms do
      @gateway.refund(@amount, '1234', @options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"amount":1.0/, data)
    end.respond_with(successful_refund_response)
    assert_success response
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '1234', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('1234', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('1234', @options)
    assert_failure response
  end

  def test_simple_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '14436664108567261211', response.authorization
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

  def failed_capture_response
    '{"error": {"type": "Carrier not supported", "help": "", "description": "{}"}}'
  end

  def successful_void_response
    '{"status": "success", "detail": "Completed"}'
  end

  def failed_void_response
    '{"error": {"type": "Carrier not supported", "help": "", "description": "{}"}}'
  end

  alias_method :successful_refund_response, :successful_void_response
  alias_method :failed_refund_response, :failed_void_response

  def already_stored_response
    '{"error": {"type": "Card already added: 14436664108567261211", "help": "If you want to update the card, first delete it", "description": "{}"}}'
  end

  def successful_unstore_response
    '{"message": "card deleted"}'
  end

  def successful_store_response
    '{"card": {"bin": "411111", "status": "valid", "token": "14436664108567261211", "message": "", "expiry_year": "2018", "expiry_month": "9", "transaction_reference": "PR-959", "type": "vi", "number": "1111"}}'
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
end
