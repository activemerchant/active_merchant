require 'test_helper'

class TnsTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = TnsGateway.new(
      userid: 'userid',
      password: 'password'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).twice.returns(successful_authorize_response).then.returns(successful_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '2a79d859-8b23-4dd0-b319-201fe2373c50|ce61e06e-8c92-4a0f-a491-6eb473d883dd', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal 'FAILURE - DECLINED', response.message
    assert response.test?
  end

  def test_authorize_and_capture
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '91debbeb-d88f-42e9-a6ce-9b62c99d656b|f3d100a7-18d9-4609-aabc-8a710ad0e210', response.authorization

    capture = stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/f3d100a7-18d9-4609-aabc-8a710ad0e210/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_refund
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal '2a79d859-8b23-4dd0-b319-201fe2373c50|ce61e06e-8c92-4a0f-a491-6eb473d883dd', response.authorization

    refund = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/ce61e06e-8c92-4a0f-a491-6eb473d883dd/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal '2a79d859-8b23-4dd0-b319-201fe2373c50|ce61e06e-8c92-4a0f-a491-6eb473d883dd', response.authorization

    void = stub_comms(@gateway, :ssl_request) do
      @gateway.void(response.authorization)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/ce61e06e-8c92-4a0f-a491-6eb473d883dd/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_passing_alpha3_country_code
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, :billing_address => {country: "US"})
    end.check_request do |method, endpoint, data, headers|
      assert_match(/USA/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_non_existent_country
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, :billing_address => {country: "Blah"})
    end.check_request do |method, endpoint, data, headers|
      assert_match(/"country":null/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_passing_cvv
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/#{@credit_card.verification_value}/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_passing_billing_address
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, :billing_address => address)
    end.check_request do |method, endpoint, data, headers|
      parsed = JSON.parse(data)
      assert_equal('456 My Street', parsed['billing']['address']['street'])
      assert_equal('K1C2N6', parsed['billing']['address']['postcodeZip'])
    end.respond_with(successful_authorize_response)
  end

  def test_passing_shipping_name
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, :shipping_address => address)
    end.check_request do |method, endpoint, data, headers|
      parsed = JSON.parse(data)
      assert_equal('Jim', parsed['shipping']['firstName'])
      assert_equal('Smith', parsed['shipping']['lastName'])
    end.respond_with(successful_authorize_response)
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
    assert_equal "91debbeb-d88f-42e9-a6ce-9b62c99d656b", response.params['order']['id']
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_unsuccessful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "FAILURE - DECLINED", response.message
  end

  def test_north_america_region_url
    @gateway = TnsGateway.new(
      userid: 'userid',
      password: 'password',
      region: 'north_america'
    )

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/secure.na.tnspayments.com/, endpoint)
    end.respond_with(successful_capture_response)

    assert_success response
  end

  def test_asia_pacific_region_url
    @gateway = TnsGateway.new(
      userid: 'userid',
      password: 'password',
      region: 'asia_pacific'
    )

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/secure.ap.tnspayments.com/, endpoint)
    end.respond_with(successful_capture_response)

    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q[
      D, {"provided":{"card":{"expiry":{"year":"17","month":"09"},"number":"5123456789012346","securityCode":"123"}},"type":"CARD"}
      <- transaction/1 HTTP/1.1\r\nAuthorization: Basic bWVyY2hhbnQuVEVTVFNQUkVFRExZMDE6M2YzNGZlNTAzMzRmYmU2Y2JlMDRjMjgzNDExYTU4NjA=\r\nContent-Type:
      <- {\"order\":{\"amount\":\"1.00\",\"currency\":\"USD\"},\"sourceOfFunds\":{\"provided\":{\"card\":{\"expiry\":{\"year\":\"17\",\"month\":\"09\"},\"number\":\"5123456789012346\",\"securityCode\":\"123\"}},\"type\":\"CARD\"}
    ]
  end

  def post_scrubbed
    %q[
      D, {"provided":{"card":{"expiry":{"year":"17","month":"09"},"number":"[FILTERED]","securityCode":"[FILTERED]"}},"type":"CARD"}
      <- transaction/1 HTTP/1.1\r\nAuthorization: Basic [FILTERED]Content-Type:
      <- {\"order\":{\"amount\":\"1.00\",\"currency\":\"USD\"},\"sourceOfFunds\":{\"provided\":{\"card\":{\"expiry\":{\"year\":\"17\",\"month\":\"09\"},\"number\":\"[FILTERED]\",\"securityCode\":\"[FILTERED]\"}},\"type\":\"CARD\"}
    ]
  end

  def successful_authorize_response
    %(
      {"billing":{"address":{"city":"Ottawa","country":"USA","postcodeZip":"K1C2N6","stateProvince":"ON","street":"456 My Street, Apt 1"},"phone":"(555)555-5555"},"gatewayEntryPoint":"WEB_SERVICES_API","merchant":"TESTSPREEDLY01","order":{"amount":1.00,"creationTime":"2014-10-16T17:23:56.444Z","currency":"USD","id":"91debbeb-d88f-42e9-a6ce-9b62c99d656b","status":"CAPTURED","totalAuthorizedAmount":1.00,"totalCapturedAmount":1.00,"totalRefundedAmount":0.00},"response":{"acquirerCode":"0","acquirerMessage":"Transaction is approved","cardSecurityCode":{"acquirerCode":"N","gatewayCode":"NO_MATCH"},"gatewayCode":"APPROVED","risk":{"gatewayCode":"ACCEPTED","review":{"decision":"NOT_REQUIRED"},"rule":[{"data":"512345","name":"MERCHANT_BIN_RANGE","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"N","name":"MERCHANT_CSC","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"SUSPECT_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"TRUSTED_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"512345","name":"MSO_BIN_RANGE","recommendation":"NO_ACTION","type":"MSO_RULE"},{"data":"N","name":"MSO_CSC","recommendation":"NO_ACTION","type":"MSO_RULE"}]}},"result":"SUCCESS","sourceOfFunds":{"provided":{"card":{"brand":"MASTERCARD","expiry":{"month":"9","year":"15"},"fundingMethod":"CREDIT","number":"512345xxxxxx2346","scheme":"MASTERCARD"}},"type":"CARD"},"timeOfRecord":"2014-10-16T17:23:57.083Z","transaction":{"acquirer":{"batch":1,"id":"PAYMENTECH_TAMPA","merchantId":"1234678"},"amount":1.00,"authorizationCode":"005163","currency":"USD","frequency":"SINGLE","id":"f3d100a7-18d9-4609-aabc-8a710ad0e210","receipt":"428917000180","reference":"1","source":"INTERNET","terminal":"002","type":"CAPTURE"},"version":"22"}
    )
  end

  def successful_capture_response
    %(
      {"billing":{"address":{"city":"Ottawa","country":"USA","postcodeZip":"K1C2N6","stateProvince":"ON","street":"456 My Street, Apt 1"},"phone":"(555)555-5555"},"gatewayEntryPoint":"WEB_SERVICES_API","merchant":"TESTSPREEDLY01","order":{"amount":1.00,"creationTime":"2014-10-16T17:28:32.999Z","currency":"USD","id":"2a79d859-8b23-4dd0-b319-201fe2373c50","status":"CAPTURED","totalAuthorizedAmount":1.00,"totalCapturedAmount":1.00,"totalRefundedAmount":0.00},"response":{"acquirerCode":"0","acquirerMessage":"Transaction is approved","cardSecurityCode":{"acquirerCode":"N","gatewayCode":"NO_MATCH"},"gatewayCode":"APPROVED","risk":{"gatewayCode":"ACCEPTED","review":{"decision":"NOT_REQUIRED"},"rule":[{"data":"512345","name":"MERCHANT_BIN_RANGE","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"N","name":"MERCHANT_CSC","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"SUSPECT_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"TRUSTED_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"512345","name":"MSO_BIN_RANGE","recommendation":"NO_ACTION","type":"MSO_RULE"},{"data":"N","name":"MSO_CSC","recommendation":"NO_ACTION","type":"MSO_RULE"}]}},"result":"SUCCESS","sourceOfFunds":{"provided":{"card":{"brand":"MASTERCARD","expiry":{"month":"9","year":"15"},"fundingMethod":"CREDIT","number":"512345xxxxxx2346","scheme":"MASTERCARD"}},"type":"CARD"},"timeOfRecord":"2014-10-16T17:28:33.685Z","transaction":{"acquirer":{"batch":1,"id":"PAYMENTECH_TAMPA","merchantId":"1234678"},"amount":1.00,"authorizationCode":"005202","currency":"USD","frequency":"SINGLE","id":"ce61e06e-8c92-4a0f-a491-6eb473d883dd","receipt":"428917000182","reference":"1","source":"INTERNET","terminal":"002","type":"CAPTURE"},"version":"22"}
    )
  end

  def failed_purchase_response
    %(
      {"billing":{"address":{"city":"Ottawa","country":"USA","postcodeZip":"K1C2N6","stateProvince":"ON","street":"456 My Street, Apt 1"},"phone":"(555)555-5555"},"gatewayEntryPoint":"WEB_SERVICES_API","merchant":"TESTSPREEDLY01","order":{"amount":1.00,"creationTime":"2014-10-16T18:25:46.095Z","currency":"USD","id":"fb21987d-a646-48f1-aa6a-07028a74a956","status":"FAILED","totalAuthorizedAmount":0.00,"totalCapturedAmount":0.00,"totalRefundedAmount":0.00},"response":{"cardSecurityCode":{"acquirerCode":"N","gatewayCode":"NO_MATCH"},"gatewayCode":"DECLINED","risk":{"gatewayCode":"ACCEPTED","review":{"decision":"NOT_REQUIRED"},"rule":[{"data":"400030","name":"MERCHANT_BIN_RANGE","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"SUSPECT_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"TRUSTED_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"400030","name":"MSO_BIN_RANGE","recommendation":"NO_ACTION","type":"MSO_RULE"}]}},"result":"FAILURE","sourceOfFunds":{"provided":{"card":{"brand":"VISA","expiry":{"month":"9","year":"15"},"fundingMethod":"CREDIT","number":"400030xxxxxx2220","scheme":"VISA"}},"type":"CARD"},"timeOfRecord":"2014-10-16T18:25:46.095Z","transaction":{"acquirer":{"batch":1,"id":"PAYMENTECH_TAMPA","merchantId":"1234678"},"amount":1.00,"currency":"USD","frequency":"SINGLE","id":"1","receipt":"428918000183","source":"INTERNET","terminal":"002","type":"AUTHORIZATION"},"version":"22"}
    )
  end

  def successful_refund_response
    %(
      {"billing":{"address":{"city":"Ottawa","country":"USA","postcodeZip":"K1C2N6","stateProvince":"ON","street":"456 My Street, Apt 1"},"phone":"(555)555-5555"},"gatewayEntryPoint":"WEB_SERVICES_API","merchant":"TESTSPREEDLY01","order":{"amount":1.00,"creationTime":"2014-10-16T18:49:35.969Z","currency":"USD","id":"98619fc2-3f30-4f3a-9199-84e435dfa498","status":"REFUNDED","totalAuthorizedAmount":1.00,"totalCapturedAmount":1.00,"totalRefundedAmount":1.00},"response":{"acquirerCode":"0","acquirerMessage":"Transaction is approved","cardSecurityCode":{"acquirerCode":"N","gatewayCode":"NO_MATCH"},"gatewayCode":"APPROVED","risk":{"gatewayCode":"ACCEPTED","review":{"decision":"NOT_REQUIRED"},"rule":[{"data":"512345","name":"MERCHANT_BIN_RANGE","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"N","name":"MERCHANT_CSC","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"SUSPECT_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"TRUSTED_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"512345","name":"MSO_BIN_RANGE","recommendation":"NO_ACTION","type":"MSO_RULE"},{"data":"N","name":"MSO_CSC","recommendation":"NO_ACTION","type":"MSO_RULE"}]}},"result":"SUCCESS","sourceOfFunds":{"provided":{"card":{"brand":"MASTERCARD","expiry":{"month":"9","year":"15"},"fundingMethod":"CREDIT","number":"512345xxxxxx2346","scheme":"MASTERCARD"}},"type":"CARD"},"timeOfRecord":"2014-10-16T18:49:37.417Z","transaction":{"acquirer":{"batch":1,"id":"PAYMENTECH_TAMPA","merchantId":"1234678"},"amount":1.00,"currency":"USD","frequency":"SINGLE","id":"9f8a3bc9-9a00-40a7-98ea-8113fa53c018","receipt":"428918000186","reference":"1","source":"INTERNET","terminal":"002","type":"REFUND"},"version":"22"}
    )
  end

  def successful_void_response
    %(
      {"billing":{"address":{"city":"Ottawa","country":"USA","postcodeZip":"K1C2N6","stateProvince":"ON","street":"456 My Street, Apt 1"},"phone":"(555)555-5555"},"gatewayEntryPoint":"WEB_SERVICES_API","merchant":"TESTSPREEDLY01","order":{"amount":1.00,"creationTime":"2014-10-16T18:57:00.277Z","currency":"USD","id":"fb1125bd-b169-48a2-878d-18831639ec08","status":"CANCELLED","totalAuthorizedAmount":0.00,"totalCapturedAmount":0.00,"totalRefundedAmount":0.00},"response":{"acquirerCode":"000","acquirerMessage":"Approved","cardSecurityCode":{"acquirerCode":"N","gatewayCode":"NO_MATCH"},"gatewayCode":"APPROVED","risk":{"gatewayCode":"ACCEPTED","review":{"decision":"NOT_REQUIRED"},"rule":[{"data":"512345","name":"MERCHANT_BIN_RANGE","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"N","name":"MERCHANT_CSC","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"SUSPECT_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"TRUSTED_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"512345","name":"MSO_BIN_RANGE","recommendation":"NO_ACTION","type":"MSO_RULE"},{"data":"N","name":"MSO_CSC","recommendation":"NO_ACTION","type":"MSO_RULE"}]}},"result":"SUCCESS","sourceOfFunds":{"provided":{"card":{"brand":"MASTERCARD","expiry":{"month":"9","year":"15"},"fundingMethod":"CREDIT","number":"512345xxxxxx2346","scheme":"MASTERCARD"}},"type":"CARD"},"timeOfRecord":"2014-10-16T18:57:01.132Z","transaction":{"acquirer":{"batch":1,"id":"PAYMENTECH_TAMPA","merchantId":"1234678"},"amount":1.00,"currency":"USD","frequency":"SINGLE","id":"e648c580-9edf-4baa-b05e-5eeadab3f86e","receipt":"428918000188","source":"INTERNET","terminal":"002","type":"VOID_AUTHORIZATION"},"version":"22"}
    )
  end

  def failed_authorize_response
    %(
      {"billing":{"address":{"city":"Ottawa","country":"USA","postcodeZip":"K1C2N6","stateProvince":"ON","street":"456 My Street, Apt 1"},"phone":"(555)555-5555"},"gatewayEntryPoint":"WEB_SERVICES_API","merchant":"TESTSPREEDLY01","order":{"amount":1.00,"creationTime":"2014-10-17T12:44:15.432Z","currency":"USD","id":"1a0abf5e-3d1f-4c1b-bd0f-94a64aa9304c","status":"FAILED","totalAuthorizedAmount":0.00,"totalCapturedAmount":0.00,"totalRefundedAmount":0.00},"response":{"cardSecurityCode":{"acquirerCode":"N","gatewayCode":"NO_MATCH"},"gatewayCode":"DECLINED","risk":{"gatewayCode":"ACCEPTED","review":{"decision":"NOT_REQUIRED"},"rule":[{"data":"400030","name":"MERCHANT_BIN_RANGE","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"SUSPECT_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"name":"TRUSTED_CARD_LIST","recommendation":"NO_ACTION","type":"MERCHANT_RULE"},{"data":"400030","name":"MSO_BIN_RANGE","recommendation":"NO_ACTION","type":"MSO_RULE"}]}},"result":"FAILURE","sourceOfFunds":{"provided":{"card":{"brand":"VISA","expiry":{"month":"9","year":"15"},"fundingMethod":"CREDIT","number":"400030xxxxxx2220","scheme":"VISA"}},"type":"CARD"},"timeOfRecord":"2014-10-17T12:44:15.432Z","transaction":{"acquirer":{"batch":1,"id":"PAYMENTECH_TAMPA","merchantId":"1234678"},"amount":1.00,"currency":"USD","frequency":"SINGLE","id":"1","receipt":"429012000210","source":"INTERNET","terminal":"002","type":"AUTHORIZATION"},"version":"22"}
   )
  end

  def failed_void_response
    %(
      {\"error\":{\"cause\":\"INVALID_REQUEST\",\"explanation\":\"Value 'VOID' is invalid. There is no transaction to void.\",\"field\":\"apiOperation\",\"validationType\":\"INVALID\"},\"result\":\"ERROR\"}
    )
  end
end
