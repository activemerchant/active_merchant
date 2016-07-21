require 'test_helper'

class PayuLatamTest < Test::Unit::TestCase
  def setup
    @gateway = PayuLatamGateway.new(merchant_id: 'merchant_id', account_id: 'account_id', api_login: 'api_login', api_key: 'api_key')

    @amount = 4000
    @credit_card = credit_card("4097440000000004", verification_value: "444", first_name: "APPROVED", last_name: "")
    @declined_card = credit_card("4097440000000004", verification_value: "333", first_name: "REJECTED", last_name: "")
    @pending_card = credit_card("4097440000000004", verification_value: "222", first_name: "PENDING", last_name: "")

    @options = {
      currency: "ARS",
      order_id: generate_unique_id,
      description: "Active Merchant Transaction",
      installments_number: 1,
      billing_address: address(
        address1: "Viamonte",
        address2: "1366",
        city: "Plata",
        state: "Buenos Aires",
        country: "AR",
        zip: "64000",
        phone: "7563126"
      )
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "ANTIFRAUD_REJECTED", response.message
    assert_equal "DECLINED", response.params["transactionResponse"]["state"]
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "APPROVED", response.message
    assert_match %r(^\d+\|(\w|-)+$), response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(pending_authorize_response)

    response = @gateway.authorize(@amount, @pending_card, @options)
    assert_failure response
    assert_equal "PENDING_TRANSACTION_REVIEW", response.message
    assert_equal "PENDING", response.params["transactionResponse"]["state"]
  end

  def test_verify_good_credentials
    @gateway.expects(:ssl_post).returns(credentials_are_legit_response)
    assert @gateway.verify_credentials
  end

  def test_verify_bad_credentials
    @gateway.expects(:ssl_post).returns(credentials_are_bogus_response)
    assert !@gateway.verify_credentials
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to sandbox.api.payulatam.com:443...
      opened
      starting SSL for sandbox.api.payulatam.com:443...
      SSL established
      <- "POST /payments-api/4.0/service.cgi HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.api.payulatam.com\r\nContent-Length: 985\r\n\r\n"
      <- "{\"test\":true,\"language\":\"en\",\"command\":\"SUBMIT_TRANSACTION\",\"merchant\":{\"apiLogin\":\"pRRXKOl8ikMmt9u\",\"apiKey\":\"4Vj8eK4rloUd272L48hsrarnUA\"},\"transaction\":{\"type\":\"AUTHORIZATION_AND_CAPTURE\",\"order\":{\"accountId\":\"512326\",\"referenceCode\":\"c540ae0d09ce1868070d21f69aa72873\",\"description\":\"unspecified\",\"language\":\"en\",\"buyer\":{\"emailAddress\":\"unspecified@example.com\",\"fullName\":\"APPROVED\",\"shippingAddress\":{\"street1\":\"Calle 93 B 17 \u{2013} 25 Apt 1\",\"city\":\"Panama\",\"state\":\"Panama\",\"country\":\"PA\",\"postalCode\":\"000000\",\"phone\":\"5582254\"}},\"additionalValues\":{\"TX_VALUE\":{\"value\":\"10.00\",\"currency\":\"USD\"}},\"signature\":\"8cf73cd8ac7760922deeb8d2b5a56689\"},\"creditCard\":{\"number\":\"5500000000000004\",\"securityCode\":\"444\",\"expirationDate\":\"2017/09\",\"name\":\"APPROVED\"},\"paymentMethod\":\"MASTERCARD\",\"paymentCountry\":\"PA\",\"payer\":{\"fullName\":\"APPROVED\",\"emailAddress\":\"unspecified@example.com\"},\"ipAddress\":\"127.0.0.1\",\"cookie\":\"n/a\",\"userAgent\":\"n/a\",\"extraParameters\":{\"INSTALLMENTS_NUMBER\":1}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Date: Fri, 13 May 2016 22:07:21 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Server: PayU server\r\n"
      -> "\r\n"
      -> "21b\r\n"
      reading 539 bytes...
      -> ""
      -> "{\"code\":\"SUCCESS\",\"error\":null,\"transactionResponse\":{\"orderId\":7348886,\"transactionId\":\"90944ffb-7376-46ae-97fd-b1fcb2d602c3\",\"state\":\"DECLINED\",\"paymentNetworkResponseCode\":null,\"paymentNetworkResponseErrorMessage\":null,\"trazabilityCode\":null,\"authorizationCode\":null,\"pendingReason\":null,\"responseCode\":\"INACTIVE_PAYMENT_PROVIDER\",\"errorCode\":null,\"responseMessage\":\"The payment network processor is not available\",\"transactionDate\":null,\"transactionTime\":null,\"operationDate\":null,\"referenceQuestionnaire\":null,\"extraParameters\":null}}"
      read 539 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to sandbox.api.payulatam.com:443...
      opened
      starting SSL for sandbox.api.payulatam.com:443...
      SSL established
      <- "POST /payments-api/4.0/service.cgi HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.api.payulatam.com\r\nContent-Length: 985\r\n\r\n"
      <- "{\"test\":true,\"language\":\"en\",\"command\":\"SUBMIT_TRANSACTION\",\"merchant\":{\"apiLogin\":\"pRRXKOl8ikMmt9u\",\"apiKey\":\"[FILTERED]\"},\"transaction\":{\"type\":\"AUTHORIZATION_AND_CAPTURE\",\"order\":{\"accountId\":\"512326\",\"referenceCode\":\"c540ae0d09ce1868070d21f69aa72873\",\"description\":\"unspecified\",\"language\":\"en\",\"buyer\":{\"emailAddress\":\"unspecified@example.com\",\"fullName\":\"APPROVED\",\"shippingAddress\":{\"street1\":\"Calle 93 B 17 \u{2013} 25 Apt 1\",\"city\":\"Panama\",\"state\":\"Panama\",\"country\":\"PA\",\"postalCode\":\"000000\",\"phone\":\"5582254\"}},\"additionalValues\":{\"TX_VALUE\":{\"value\":\"10.00\",\"currency\":\"USD\"}},\"signature\":\"8cf73cd8ac7760922deeb8d2b5a56689\"},\"creditCard\":{\"number\":\"[FILTERED]\",\"securityCode\":\"[FILTERED]\",\"expirationDate\":\"2017/09\",\"name\":\"APPROVED\"},\"paymentMethod\":\"MASTERCARD\",\"paymentCountry\":\"PA\",\"payer\":{\"fullName\":\"APPROVED\",\"emailAddress\":\"unspecified@example.com\"},\"ipAddress\":\"127.0.0.1\",\"cookie\":\"n/a\",\"userAgent\":\"n/a\",\"extraParameters\":{\"INSTALLMENTS_NUMBER\":1}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Date: Fri, 13 May 2016 22:07:21 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Server: PayU server\r\n"
      -> "\r\n"
      -> "21b\r\n"
      reading 539 bytes...
      -> ""
      -> "{\"code\":\"SUCCESS\",\"error\":null,\"transactionResponse\":{\"orderId\":7348886,\"transactionId\":\"90944ffb-7376-46ae-97fd-b1fcb2d602c3\",\"state\":\"DECLINED\",\"paymentNetworkResponseCode\":null,\"paymentNetworkResponseErrorMessage\":null,\"trazabilityCode\":null,\"authorizationCode\":null,\"pendingReason\":null,\"responseCode\":\"INACTIVE_PAYMENT_PROVIDER\",\"errorCode\":null,\"responseMessage\":\"The payment network processor is not available\",\"transactionDate\":null,\"transactionTime\":null,\"operationDate\":null,\"referenceQuestionnaire\":null,\"extraParameters\":null}}"
      read 539 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def successful_purchase_response
    <<-RESPONSE
    {
       "code": "SUCCESS",
       "error": null,
       "transactionResponse": {
          "orderId": 3018500,
          "transactionId": "b5369274-4b51-4cd3-a634-61db79b3eb9c",
          "state": "APPROVED",
          "paymentNetworkResponseCode": null,
          "paymentNetworkResponseErrorMessage": null,
          "trazabilityCode": "00000000",
          "authorizationCode": "00000000",
          "pendingReason": null,
          "responseCode": "APPROVED",
          "errorCode": null,
          "responseMessage": null,
          "transactionDate": null,
          "transactionTime": null,
          "operationDate": 1393966959622,
          "extraParameters": null
       }
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "code": "SUCCESS",
      "error": null,
      "transactionResponse": {
        "orderId": 7354347,
        "transactionId": "15b6cec0-9eec-4564-b6b9-c846b868203e",
        "state": "DECLINED",
        "paymentNetworkResponseCode": null,
        "paymentNetworkResponseErrorMessage": null,
        "trazabilityCode": null,
        "authorizationCode": null,
        "pendingReason": null,
        "responseCode": "ANTIFRAUD_REJECTED",
        "errorCode": null,
        "responseMessage": null,
        "transactionDate": null,
        "transactionTime": null,
        "operationDate": null,
        "referenceQuestionnaire": null,
        "extraParameters": null
      }
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
       "code": "SUCCESS",
       "error": null,
       "transactionResponse": {
          "orderId": 3018500,
          "transactionId": "b5369274-4b51-4cd3-a634-61db79b3eb9c",
          "state": "APPROVED",
          "paymentNetworkResponseCode": null,
          "paymentNetworkResponseErrorMessage": null,
          "trazabilityCode": "00000000",
          "authorizationCode": "00000000",
          "pendingReason": null,
          "responseCode": "APPROVED",
          "errorCode": null,
          "responseMessage": null,
          "transactionDate": null,
          "transactionTime": null,
          "operationDate": 1393966959622,
          "extraParameters": null
       }
    }
    RESPONSE
  end

  def pending_authorize_response
    <<-RESPONSE
    {
      "code": "SUCCESS",
      "error": null,
      "transactionResponse": {
        "orderId": 7354347,
        "transactionId": "15b6cec0-9eec-4564-b6b9-c846b868203e",
        "state": "PENDING",
        "paymentNetworkResponseCode": null,
        "paymentNetworkResponseErrorMessage": null,
        "trazabilityCode": null,
        "authorizationCode": null,
        "pendingReason": "PENDING_REVIEW",
        "responseCode": "PENDING_TRANSACTION_REVIEW",
        "errorCode": null,
        "responseMessage": null,
        "transactionDate": null,
        "transactionTime": null,
        "operationDate": null,
        "referenceQuestionnaire": null,
        "extraParameters": null
      }
    }
    RESPONSE
  end

  def credentials_are_legit_response
    <<-RESPONSE
    {
      "code": "SUCCESS",
      "error": null,
      "paymentMethods": null
    }
    RESPONSE
  end

  def credentials_are_bogus_response
    <<-RESPONSE
    {
      "code": "ERROR",
      "error": "Invalid credentials",
      "transactionResponse": null
    }
    RESPONSE
  end
end
