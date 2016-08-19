require 'test_helper'

class VacaypayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = VacaypayGateway.new(
      :api_key => 'SGD0qydBXp58i0n5QHnTG38D-OOzvDu0KlVliOhZpyw',
      :account_uuid => '0b72d273-5caf-4a4d-aaf3-3c18267e213e',
      :publishable_key => 'pk_test_rIQe8LhRJGCutDnRGtJADcm2'
    )
    @gateway_without_publishable_key = VacaypayGateway.new(
      :api_key => 'SGD0qydBXp58i0n5QHnTG38D-OOzvDu0KlVliOhZpyw',
      :account_uuid => '0b72d273-5caf-4a4d-aaf3-3c18267e213e'
    )
    @credit_card = credit_card
    @amount = 10000

    @options = {
      :currency => "USD",
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com',
      :ip => '127.0.0.1',
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).twice.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '7f8228fe-090e-477f-a365-4dc5c5204ba2', response.authorization
    assert response.test?
  end

  def test_successful_purchase_without_publishable_key
    @gateway_without_publishable_key.expects(:ssl_get).returns(successful_account_details_response)
    @gateway_without_publishable_key.expects(:ssl_post).twice.returns(successful_purchase_response)

    assert response = @gateway_without_publishable_key.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '7f8228fe-090e-477f-a365-4dc5c5204ba2', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).twice.returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).twice.returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '7f8228fe-090e-477f-a365-4dc5c5204ba2', response.authorization
    assert_equal false, response.params['data']['captured']
    assert response.test?
  end

  def test_successful_authorize_with_publishable_key
    @gateway_without_publishable_key.expects(:ssl_get).returns(successful_account_details_response)
    @gateway_without_publishable_key.expects(:ssl_post).twice.returns(successful_authorize_response)

    assert response = @gateway_without_publishable_key.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '7f8228fe-090e-477f-a365-4dc5c5204ba2', response.authorization
    assert_equal false, response.params['data']['captured']
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).twice.returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '7f8228fe-090e-477f-a365-4dc5c5204ba2', @options)

    assert_equal '7f8228fe-090e-477f-a365-4dc5c5204ba2', response.authorization
    assert_equal true, response.params['data']['captured']
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '7f8228fe-090e-477f-a365-4dc5c5204ba2', @options)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'fbdff46c-893e-4498-8fe7-734903f40de2', @options)

    assert_equal 'fbdff46c-893e-4498-8fe7-734903f40de2', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '7f8228fe-090e-477f-a365-4dc5c5204ba2', @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('6cc5a2ab-41ab-47cb-b68f-b038188b4bab', @options)

    assert_equal '6cc5a2ab-41ab-47cb-b68f-b038188b4bab', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('bad-auth', @options)
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)

    assert_success response
    assert_equal 'tok_18oAlrE7T9LsrPBuR4e7UkVz', response.authorization
    assert response.test?
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
opening connection to www.procuro.io:443...
opened
starting SSL for www.procuro.io:443...
SSL established
<- "POST /api/v1/vacay-pay/accounts/0b72d273-5caf-4a4d-aaf3-3c18267e213e/payments HTTP/1.1\r\nContent-Type: application/json\r\nX-Auth-Token: SGD0qydBXp58i0n5QHnTG38D-OOzvDu0KlVliOhZpyw\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.procuro.io\r\nContent-Length: 404\r\n\r\n"
<- "{\"amount\":\"100.00\",\"currency\":\"USD\",\"card\":{\"name\":\"Longbob Longsen\",\"number\":\"4242424242424242\",\"cvv\":\"123\",\"expiryYear\":\"2017\",\"expiryMonth\":\"09\"},\"email\":\"wow@example.com\",\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"description\":\"ActiveMerchant Test Purchase\",\"externalPaymentReference\":\"\",\"externalBookingReference\":\"\",\"accessingIp\":\"127.0.0.1\",\"notes\":\"\",\"metadata\":{},\"sendEmailConfirmation\":false}"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Thu, 18 Aug 2016 12:04:20 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: __cfduid=d25328a3daf701746033da24edffb67ea1471521856; expires=Fri, 18-Aug-17 12:04:16 GMT; path=/; domain=.procuro.io; HttpOnly\r\n"
-> "Access-Control-Allow-Headers: origin, content-type, accept, x-auth-token, x-provider-token\r\n"
-> "Access-Control-Allow-Methods: POST, GET, PUT, DELETE, PATCH, OPTIONS\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Strict-Transport-Security: max-age=0; preload\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Server: cloudflare-nginx\r\n"
-> "CF-RAY: 2d453a35a6b7350c-LHR\r\n"
-> "Content-Encoding: gzip\r\n"
)
  end

  def post_scrubbed
    %q(
opening connection to www.procuro.io:443...
opened
starting SSL for www.procuro.io:443...
SSL established
<- "POST /api/v1/vacay-pay/accounts/0b72d273-5caf-4a4d-aaf3-3c18267e213e/payments HTTP/1.1\r\nContent-Type: application/json\r\nX-Auth-Token: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: www.procuro.io\r\nContent-Length: 404\r\n\r\n"
<- "{\"amount\":\"100.00\",\"currency\":\"USD\",\"card\":{\"name\":\"Longbob Longsen\",\[FILTERED],\[FILTERED],\"expiryYear\":\"2017\",\"expiryMonth\":\"09\"},\"email\":\"wow@example.com\",\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"description\":\"ActiveMerchant Test Purchase\",\"externalPaymentReference\":\"\",\"externalBookingReference\":\"\",\"accessingIp\":\"127.0.0.1\",\"notes\":\"\",\"metadata\":{},\"sendEmailConfirmation\":false}"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Thu, 18 Aug 2016 12:04:20 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "Connection: close\r\n"
-> "Set-Cookie: __cfduid=d25328a3daf701746033da24edffb67ea1471521856; expires=Fri, 18-Aug-17 12:04:16 GMT; path=/; domain=.procuro.io; HttpOnly\r\n"
-> "Access-Control-Allow-Headers: origin, content-type, accept, x-auth-token, x-provider-token\r\n"
-> "Access-Control-Allow-Methods: POST, GET, PUT, DELETE, PATCH, OPTIONS\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Cache-Control: no-cache\r\n"
-> "Strict-Transport-Security: max-age=0; preload\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Server: cloudflare-nginx\r\n"
-> "CF-RAY: 2d453a35a6b7350c-LHR\r\n"
-> "Content-Encoding: gzip\r\n"
)
  end

  def successful_account_details_response
    %q(
      {
        "appCode": 0,
        "appMessage": "",
        "meta": [],
        "data": {
          "uuid": "2760dd7a-34f4-4278-9e3c-d86f46041fbc",
          "accountName": "Example Account",
          "accountType": "vacaypay",
          "publishableKey": "pk_test_rIQe8LhRJGCutDnRGtJADcm2",
          "statementDescriptor": "JANE DOE RENTALS",
          "tradingName": "Jane Doe Rentals",
          "defaultCurrency": "GBP",
          "allowedCurrencies": ["GBP", "EUR"],
          "country": "GB",
          "email": "janedoe@gmail.com",
          "firstName": "Jane",
          "lastName": "Doe",
          "bookingTermsUrl": "https://www.procuro.io/terms-and-conditions",
          "enabled": true,
          "verified": true,
          "vacayPayApproved": true,
          "canTakePayments": true,
          "createdAt": "2015-05-20 09:30:10 UTC",
          "updatedAt": "2015-05-21 09:35:24 UTC"
        }
      }
    )
  end

  def successful_purchase_response
    %q(
      {
        "appCode":0,
        "appMessage":"",
        "meta":{
        },
        "data":{
          "paymentUuid":"7f8228fe-090e-477f-a365-4dc5c5204ba2",
          "accountUuid":"0b72d273-5caf-4a4d-aaf3-3c18267e213e",
          "amount":100,
          "currency":"USD",
          "financial":{
            "currency":"GBP",
            "total":74.66,
            "net":72.29,
            "fees":2.37
          },
          "refundedAmount":0,
          "status":"succeeded",
          "refunded":false,
          "captured":true,
          "paymentReference":"F364DB96",
          "externalPaymentReference":"",
          "externalBookingReference":"",
          "description":"ActiveMerchant Test Purchase",
          "email":"wow@example.com",
          "firstName":"Longbob",
          "lastName":"Longsen",
          "createdAt":"2016-08-19 09:34:13 UTC",
          "updatedAt":"2016-08-19 09:34:13 UTC",
          "meta":[
          ]
        }
      }
    )
  end

  def failed_purchase_response
    %q(
      {
        "appCode":6,
        "appMessage":"The request failed for some reason, check the errors in meta",
        "meta":{
          "errors":[
            "Your card was declined."
          ]
        },
        "data":{
          "code":"card_declined",
          "message":"Your card was declined."
        }
      }
    )
  end

  def successful_authorize_response
    %q(
      {
        "appCode":0,
        "appMessage":"",
        "meta":{
        },
        "data":{
          "paymentUuid":"7f8228fe-090e-477f-a365-4dc5c5204ba2",
          "accountUuid":"0b72d273-5caf-4a4d-aaf3-3c18267e213e",
          "amount":100,
          "currency":"USD",
          "financial":{
            "currency":"GBP",
            "total":74.66,
            "net":72.29,
            "fees":2.37
          },
          "refundedAmount":0,
          "status":"succeeded",
          "refunded":false,
          "captured":false,
          "paymentReference":"F364DB96",
          "externalPaymentReference":"",
          "externalBookingReference":"",
          "description":"ActiveMerchant Test Purchase",
          "email":"wow@example.com",
          "firstName":"Longbob",
          "lastName":"Longsen",
          "createdAt":"2016-08-19 09:34:13 UTC",
          "updatedAt":"2016-08-19 09:34:13 UTC",
          "meta":[
          ]
        }
      }
    )
  end

  def failed_authorize_response
    %q(
      {
        "appCode":6,
        "appMessage":"The request failed for some reason, check the errors in meta",
        "meta":{
          "errors":[
            "Your card was declined."
          ]
        },
        "data":{
          "code":"card_declined",
          "message":"Your card was declined."
        }
      }
    )
  end

  def successful_capture_response
    %q(
      {
        "appCode":0,
        "appMessage":"",
        "meta":{
        },
        "data":{
          "paymentUuid":"7f8228fe-090e-477f-a365-4dc5c5204ba2",
          "accountUuid":"0b72d273-5caf-4a4d-aaf3-3c18267e213e",
          "amount":100,
          "currency":"USD",
          "financial":{
            "currency":"GBP",
            "total":74.66,
            "net":72.29,
            "fees":2.37
          },
          "refundedAmount":0,
          "status":"succeeded",
          "refunded":false,
          "captured":true,
          "paymentReference":"F364DB96",
          "externalPaymentReference":"",
          "externalBookingReference":"",
          "description":"ActiveMerchant Test Purchase",
          "email":"wow@example.com",
          "firstName":"Longbob",
          "lastName":"Longsen",
          "createdAt":"2016-08-19 09:34:13 UTC",
          "updatedAt":"2016-08-19 09:34:13 UTC",
          "meta":[
          ]
        }
      }
    )
  end

  def failed_capture_response
    %q(
      {
        "appCode":2,
        "appMessage":"Specified resource not found",
        "meta":{
          "resource":"vacay-pay\/account\/payment"
        },
        "data":{
        }
      }
    )
  end

  def successful_refund_response
    %q(
      {
        "appCode":0,
        "appMessage":"",
        "meta":{
        },
        "data":{
          "paymentUuid":"fbdff46c-893e-4498-8fe7-734903f40de2",
          "accountUuid":"0b72d273-5caf-4a4d-aaf3-3c18267e213e",
          "amount":100,
          "currency":"USD",
          "financial":{
            "currency":"GBP",
            "total":74.7,
            "net":72.33,
            "fees":2.37
          },
          "refundedAmount":100,
          "status":"succeeded",
          "refunded":true,
          "captured":true,
          "paymentReference":"WYMQ1R2Q",
          "externalPaymentReference":"",
          "externalBookingReference":"",
          "description":"ActiveMerchant Test Purchase",
          "email":"wow@example.com",
          "firstName":"Longbob",
          "lastName":"Longsen",
          "createdAt":"2016-08-19 10:22:17 UTC",
          "updatedAt":"2016-08-19 10:18:01 UTC",
          "meta":[
          ]
        }
      }
    )
  end

  def failed_refund_response
    %q(
      {
        "appCode":6,
        "appMessage":"The request failed for some reason, check the errors in meta",
        "meta":{
          "errors":[
            "Cannot refund a value less than 0, or higher than the amount refundable (100)."
          ]
        },
        "data":{
        }
      }
    )
  end

  def successful_void_response
    %q(
      {
        "appCode":0,
        "appMessage":"",
        "meta":{
        },
        "data":{
          "paymentUuid":"6cc5a2ab-41ab-47cb-b68f-b038188b4bab",
          "accountUuid":"0b72d273-5caf-4a4d-aaf3-3c18267e213e",
          "amount":100,
          "currency":"USD",
          "financial":{
            "currency":"USD",
            "total":100,
            "net":0,
            "fees":0
          },
          "refundedAmount":100,
          "status":"succeeded",
          "refunded":true,
          "captured":false,
          "paymentReference":"PGD3M97R",
          "externalPaymentReference":"",
          "externalBookingReference":"",
          "description":"ActiveMerchant Test Purchase",
          "email":"wow@example.com",
          "firstName":"Longbob",
          "lastName":"Longsen",
          "createdAt":"2016-08-19 10:19:11 UTC",
          "updatedAt":"2016-08-19 10:23:33 UTC",
          "meta":[
          ]
        }
      }
    )
  end

  def failed_void_response
    %q(
      {
        "appCode":6,
        "appMessage":"The request failed for some reason, check the errors in meta",
        "meta":{
          "errors":[
            "Cannot refund a value less than 0, or higher than the amount refundable (100)."
          ]
        },
        "data":{
        }
      }
    )
  end

  def successful_store_response
    %q(
      {
        "id": "tok_18oAlrE7T9LsrPBuR4e7UkVz",
        "object": "token",
        "card": {
          "id": "card_18oAlrE7T9LsrPBuJZ6UJXNE",
          "object": "card",
          "address_city": null,
          "address_country": null,
          "address_line1": null,
          "address_line1_check": null,
          "address_line2": null,
          "address_state": null,
          "address_zip": null,
          "address_zip_check": null,
          "brand": "Visa",
          "country": "US",
          "cvc_check": "unchecked",
          "dynamic_last4": null,
          "exp_month": 9,
          "exp_year": 2017,
          "funding": "credit",
          "last4": "4242",
          "metadata": {},
          "name": null,
          "tokenization_method": null
        },
        "client_ip": "31.217.176.123",
        "created": 1472557875,
        "livemode": false,
        "type": "card",
        "used": false
      }
    )
  end

  def failed_store_response
    %q(
      {
        "error": {
          "message": "You must provide a value for 'cvc'.",
          "type": "card_error",
          "param": "cvc",
          "code": "invalid_cvc"
        }
      }
    )
  end
end
