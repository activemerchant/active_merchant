require 'test_helper'

class CheckoutV2Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CheckoutV2Gateway.new(
      secret_key: '1111111111111'
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'charge_test_941CA9CE174U76BD29C8', response.authorization
    assert response.test?
  end

  def test_successful_purchase_includes_avs_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'X', response.avs_result['postal_match']
    assert_equal 'X', response.avs_result['street_match']
  end

  def test_successful_purchase_includes_cvv_result
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_equal 'Y', response.cvv_result['code']
  end

  def test_successful_authorize_includes_avs_result
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_equal 'S', response.avs_result['code']
    assert_equal 'U.S.-issuing bank does not support AVS.', response.avs_result['message']
    assert_equal 'X', response.avs_result['postal_match']
    assert_equal 'X', response.avs_result['street_match']
  end

  def test_successful_authorize_includes_cvv_result
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_equal 'Y', response.cvv_result['code']
  end

  def test_purchase_with_additional_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, {descriptor_city: 'london', descriptor_name: 'sherlock'})
    end.check_request do |endpoint, data, headers|
      assert_match(/"descriptor\":{\"name\":\"sherlock\",\"city\":\"london\"}/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'charge_test_AF1A29AD350Q748C7EA8', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_successful_authorize_and_capture_with_additional_options
    response = stub_comms do
      options = {
        card_on_file: true,
        transaction_indicator: 2,
        previous_charge_id: 'charge_123'
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match(%r{"cardOnFile":true}, data)
      assert_match(%r{"transactionIndicator":2}, data)
      assert_match(%r{"previousChargeId":"charge_123"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'charge_test_AF1A29AD350Q748C7EA8', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal 'Invalid Card Number', response.message
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, '')
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'charge_test_AF1A29AD350Q748C7EA8', response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void('5d53a33d960c46d00f5dc061947d998c')
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'charge_test_941CA9CE174U76BD29C8', response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, '')
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal 'Invalid Card Number', response.message
  end

  def test_transcript_scrubbing
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  def test_invalid_json
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(invalid_json_response)

    assert_failure response
    assert_match %r{Invalid JSON response}, response.message
  end

  def test_error_code_returned
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(error_code_response)

    assert_failure response
    assert_match(/70000: 70077/, response.error_code)
  end

  def test_supported_countries
    assert_equal ['AD', 'AE', 'AT', 'BE', 'BG', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FO', 'FI', 'FR', 'GB', 'GI', 'GL', 'GR', 'HR', 'HU', 'IE', 'IS', 'IL', 'IT', 'LI', 'LT', 'LU', 'LV', 'MC', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'SE', 'SI', 'SM', 'SK', 'SJ', 'TR', 'VA'], @gateway.supported_countries
  end

  private

  def pre_scrubbed
    %q(
      <- "POST /v2/charges/card HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: sk_test_ab12301d-e432-4ea7-97d1-569809518aaf\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api2.checkout.com\r\nContent-Length: 346\r\n\r\n"
      <- "{\"autoCapture\":\"n\",\"value\":\"200\",\"trackId\":\"1\",\"currency\":\"USD\",\"card\":{\"name\":\"Longbob Longsen\",\"number\":\"4242424242424242\",\"cvv\":\"100\",\"expiryYear\":\"2018\"
    )
  end

  def post_scrubbed
    %q(
      <- "POST /v2/charges/card HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api2.checkout.com\r\nContent-Length: 346\r\n\r\n"
      <- "{\"autoCapture\":\"n\",\"value\":\"200\",\"trackId\":\"1\",\"currency\":\"USD\",\"card\":{\"name\":\"Longbob Longsen\",\"number\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"expiryYear\":\"2018\"
    )
  end

  def successful_purchase_response
    %(
     {
       "id":"charge_test_941CA9CE174U76BD29C8",
       "liveMode":false,
       "created":"2015-05-27T20:45:58Z",
       "value":200.0,
       "currency":"USD",
       "trackId":"1",
       "description":null,
       "email":"longbob.longsen@gmail.com",
       "chargeMode":1,
       "transactionIndicator":1,
       "customerIp":null,
       "responseMessage":"Approved",
       "responseAdvancedInfo":"Approved",
       "responseCode":"10000",
       "card": {
         "cvvCheck":"Y",
         "avsCheck":"S"
       }
      }
    )
  end

  def failed_purchase_response
    %(
     {
       "id":"charge_test_941CA9CE174U76BD29C8",
       "liveMode":false,
       "created":"2015-05-27T20:45:58Z",
       "value":200.0,
       "currency":"USD",
       "trackId":"1",
       "description":null,
       "email":"longbob.longsen@gmail.com",
       "chargeMode":1,
       "transactionIndicator":1,
       "customerIp":null,
       "responseMessage":"Invalid Card Number",
       "responseAdvancedInfo":"If credit card number contains characters other digits, or bank does not recognize this number as a valid credit card number",
       "responseCode":"20014",
       "card": {
         "cvvCheck":"Y",
         "avsCheck":"S"
       }
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "id":"charge_test_AF1A29AD350Q748C7EA8",
        "liveMode":false,
        "created":"2017-11-13T14:05:27Z",
        "value":200,
        "currency":"USD",
        "trackId":"1",
        "description":null,
        "email":"longbob.longsen@example.com",
        "chargeMode":1,
        "transactionIndicator":1,
        "customerIp":null,
        "responseMessage":"Approved",
        "responseAdvancedInfo":"Approved",
        "responseCode":"10000",
        "status":"Authorised",
        "authCode":"923189",
        "isCascaded":false,
        "autoCapture":"N",
        "autoCapTime":0.0,
        "card":{"customerId":
        "cust_12DCEB24-ACEA-48AB-BEF2-35A3C09BE581",
        "expiryMonth":"06",
        "expiryYear":"2018",
        "billingDetails":{
          "addressLine1":"456 My Street",
          "addressLine2":"Apt 1",
          "postcode":"K1C2N6",
          "country":"CA",
          "city":"Ottawa",
          "state":"ON",
          "phone":{"number":"(555)555-5555"}
         },
        "id":"card_CFA314F4-388D-4CF4-BE6F-940D894C9E64",
        "last4":"4242",
        "bin":"424242",
        "paymentMethod":"Visa",
        "fingerprint":"F639CAB2745BEE4140BF86DF6B6D6E255C5945AAC3788D923FA047EA4C208622",
        "name":"Longbob Longsen",
        "cvvCheck":"Y",
        "avsCheck":"S"
      },
      "riskCheck":true,
      "customerPaymentPlans":null,
      "metadata":{},
      "shippingDetails":{
        "addressLine1":null,
        "addressLine2":null,
        "postcode":null,
        "country":null,
        "city":null,
        "state":null,
        "phone":{}
      },
      "products":[],
      "udf1":null,
      "udf2":null,
      "udf3":null,
      "udf4":null,
      "udf5":null
    }
  )
  end

  def failed_authorize_response
    %(
     {
       "id":"charge_test_941CA9CE174U76BD29C8",
       "liveMode":false,
       "created":"2015-05-27T20:45:58Z",
       "value":200.0,
       "currency":"USD",
       "trackId":"1",
       "description":null,
       "email":"longbob.longsen@gmail.com",
       "chargeMode":1,
       "transactionIndicator":1,
       "customerIp":null,
       "responseMessage":"Invalid Card Number",
       "responseAdvancedInfo":"If credit card number contains characters other digits, or bank does not recognize this number as a valid credit card number",
       "responseCode":"20014"
      }
    )
  end

  def successful_capture_response
    %(
     {
       "id":"charge_test_941CA9CE174U76BD29C8",
       "liveMode":false,
       "created":"2015-05-27T20:45:58Z",
       "value":200.0,
       "currency":"USD",
       "trackId":"1",
       "description":null,
       "email":"longbob.longsen@gmail.com",
       "chargeMode":1,
       "transactionIndicator":1,
       "customerIp":null,
       "responseMessage":"Captured",
       "responseAdvancedInfo":"Captured",
       "responseCode":"10000"
      }
    )
  end

  def failed_capture_response
    %(
    {
    "errorCode":"405",
    "message":"You tried to access the endpoint with an invalid method",
    }
    )
  end

  def successful_refund_response
    %(
     {
       "id":"charge_test_941CA9CE174U76BD29C8",
       "liveMode":false,
       "created":"2015-05-27T20:45:58Z",
       "value":200.0,
       "currency":"USD",
       "trackId":"1",
       "description":null,
       "email":"longbob.longsen@gmail.com",
       "chargeMode":1,
       "transactionIndicator":1,
       "customerIp":null,
       "responseMessage":"Refunded",
       "responseAdvancedInfo":"Refunded",
       "responseCode":"10000"
      }
    )
  end

  def failed_refund_response
    %(
    {
    "errorCode":"405",
    "message":"You tried to access the endpoint with an invalid method",
    }
    )
  end

  def successful_void_response
    %(
     {
       "id":"charge_test_941CA9CE174U76BD29C8",
       "liveMode":false,
       "created":"2015-05-27T20:45:58Z",
       "value":200.0,
       "currency":"USD",
       "trackId":"1",
       "description":null,
       "email":"longbob.longsen@gmail.com",
       "chargeMode":1,
       "transactionIndicator":1,
       "customerIp":null,
       "responseMessage":"Voided",
       "responseAdvancedInfo":"Voided",
       "responseCode":"10000"
      }
    )
  end

  def failed_void_response
    %(
    {
    "errorCode":"405",
    "message":"You tried to access the endpoint with an invalid method",
    }
    )
  end

  def invalid_json_response
    %(
    {
      "id": "charge_test_123456",
    )
  end

  def error_code_response
    %(
      {
        "eventId":"1b206f69-b4db-4259-9713-b72dfe0f19da","errorCode":"70000","message":"Validation error","errorMessageCodes":["70077"],"errors":["Expired Card"]
      }
    )
  end
end
