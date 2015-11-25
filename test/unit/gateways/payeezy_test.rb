require 'test_helper'
require 'yaml'

class PayeezyGateway < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PayeezyGateway.new(
      apikey: "45234543524353",
      apisecret: "4235423325",
      token: "rewrt-23543543542353542"
    )

    @credit_card = credit_card
    @amount = 100
    @options = {
      :billing_address => address
    }
    @authorization = "ET1700|106625152|credit_card|4738"
  end

  def test_invalid_credentials
    @gateway.expects(:ssl_post).raises(bad_credentials_response)

    assert response = @gateway.authorize(100, @credit_card, {})
    assert_failure response
    assert response.test?
    assert_equal '||credit_card|', response.authorization
    assert_equal 'HMAC validation Failure', response.message
  end

  def test_invalid_token
    @gateway.expects(:ssl_post).raises(invalid_token_response)

    assert response = @gateway.authorize(100, @credit_card, {})
    assert_failure response
    assert response.test?
    assert_equal '||credit_card|', response.authorization
    assert_equal 'Access denied', response.message
  end

  def test_invalid_token_on_integration
    @gateway.expects(:ssl_post).raises(invalid_token_response_integration)

    assert response = @gateway.authorize(100, @credit_card, {})
    assert_failure response
    assert response.test?
    assert_equal '||credit_card|', response.authorization
    assert_equal 'Invalid ApiKey for given resource', response.message
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'ET114541|55083431|credit_card|1', response.authorization
    assert response.test?
    assert_equal 'Transaction Normal - Approved', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void(@authorization, @options)
    assert_success response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount, @authorization)
    assert_success response
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).raises(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal response.error_code, "card_expired"
  end

  def test_invalid_transaction_tag
    @gateway.expects(:ssl_post).raises(failed_capture_response)

    assert response = @gateway.capture(@amount, @authorization)
    assert_instance_of Response, response
    assert_failure response
    assert_equal response.error_code, "server_error"
    assert_equal response.message, "ProcessedBad Request (69) - Invalid Transaction Tag"
  end

  def test_supported_countries
    assert_equal ['CA', 'US'].sort, PayeezyGateway.supported_countries.sort
  end

  def test_supported_cardtypes
    assert_equal [:visa, :master, :american_express, :discover, :jcb, :diners_club], PayeezyGateway.supported_cardtypes
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal '4', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'I', response.cvv_result['code']
  end

  def test_requests_include_verification_string
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      json_address = '{"street":"456 My Street","city":"Ottawa","state_province":"ON","zip_postal_code":"K1C2N6","country":"CA"}'
      assert_match json_address, data
    end.respond_with(successful_purchase_response)
  end

  def test_card_type
    assert_equal 'Visa', PayeezyGateway::CREDIT_CARD_BRAND['visa']
    assert_equal 'Mastercard', PayeezyGateway::CREDIT_CARD_BRAND['master']
    assert_equal 'American Express', PayeezyGateway::CREDIT_CARD_BRAND['american_express']
    assert_equal 'JCB', PayeezyGateway::CREDIT_CARD_BRAND['jcb']
    assert_equal 'Discover', PayeezyGateway::CREDIT_CARD_BRAND['discover']
  end

  private

  def successful_purchase_response
    <<-RESPONSE
    {\"method\":\"credit_card\",\"amount\":\"1\",\"currency\":\"USD\",\"avs\":\"4\",\"card\":{\"type\":\"Visa\",\"cardholder_name\":\"Bobsen 995\",\"card_number\":\"4242\",\"exp_date\":\"0816\"},\"token\":{\"token_type\":\"transarmor\",\"token_data\":{\"value\":\"0152552999534242\"}},\"transaction_status\":\"approved\",\"validation_status\":\"success\",\"transaction_type\":\"purchase\",\"transaction_id\":\"ET114541\",\"transaction_tag\":\"55083431\",\"bank_resp_code\":\"100\",\"bank_message\":\"Approved\",\"gateway_resp_code\":\"00\",\"gateway_message\":\"Transaction Normal\",\"correlation_id\":\"124.1433862672836\"}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {\"method\":\"credit_card\",\"amount\":\"1\",\"currency\":\"USD\",\"cvv2\":\"I\",\"token\":{\"token_type\":\"transarmor\",\"token_data\":{\"value\":\"9968749582724242\"}},\"transaction_status\":\"approved\",\"validation_status\":\"success\",\"transaction_type\":\"refund\",\"transaction_id\":\"55084328\",\"transaction_tag\":\"55084328\",\"bank_resp_code\":\"100\",\"bank_message\":\"Approved\",\"gateway_resp_code\":\"00\",\"gateway_message\":\"Transaction Normal\",\"correlation_id\":\"124.1433864648126\"}
    RESPONSE
  end

  def failed_purchase_response
    yamlexcep = <<-RESPONSE
--- !ruby/exception:ActiveMerchant::ResponseError
response: !ruby/object:Net::HTTPBadRequest
  http_version: '1.1'
  code: '400'
  message: Bad Request
  header:
    content-language:
    - en-US
    content-type:
    - application/json
    date:
    - Tue, 09 Jun 2015 15:46:44 GMT
    optr_cxt:
    - 0100010000eb11d301-785c-449b-b060-6d0b4638d54d00000000-0000-0000-0000-000000000000-1                                  HTTP    ;
    x-archived-client-ip:
    - 10.174.197.250
    x-backside-transport:
    - FAIL FAIL,FAIL FAIL
    x-client-ip:
    - 10.174.197.250,54.236.202.5
    x-powered-by:
    - Servlet/3.0
    content-length:
    - '384'
    connection:
    - Close
  body: '{"method":"credit_card","amount":"10000000","currency":"USD","card":{"type":"Visa","cvv":"000","cardholder_name":"Bobsen
    5675","card_number":"4242","exp_date":"0810"},"transaction_status":"Not Processed","validation_status":"failed","transaction_type":"purchase","Error":{"messages":[{"code":"card_expired","description":"The
    card has expired"}]},"correlation_id":"124.1433864804381"}'
  read: true
  uri:
  decode_content: true
  socket:
  body_exist: true
message:
    RESPONSE
    YAML.load(yamlexcep)
  end

  def invalid_token_response
    yamlexcep = <<-RESPONSE
--- !ruby/exception:ActiveMerchant::ResponseError
response: !ruby/object:Net::HTTPUnauthorized
  http_version: '1.1'
  code: '401'
  message: Unauthorized
  header:
    content-language:
    - en-US
    content-type:
    - application/json;charset=utf-8
    date:
    - Tue, 23 Jun 2015 15:13:02 GMT
    optr_cxt:
    - 435543224354-37b2-4369-9cfe-26543635465346346-0000-0000-0000-000000000000-1                                  HTTP    ;
    x-archived-client-ip:
    - 10.180.205.250
    x-backside-transport:
    - FAIL FAIL,FAIL FAIL
    x-client-ip:
    - 10.180.205.250,107.23.55.229
    x-powered-by:
    - Servlet/3.0
    content-length:
    - '25'
    connection:
    - Close
  body: '{"error":"Access denied"}'
  read: true
  uri:
  decode_content: true
  socket:
  body_exist: true
message:
    RESPONSE
    YAML.load(yamlexcep)
  end

  def invalid_token_response_integration
    yamlexcep = <<-RESPONSE
--- !ruby/exception:ActiveMerchant::ResponseError
response: !ruby/object:Net::HTTPUnauthorized
  http_version: '1.1'
  code: '401'
  message: Unauthorized
  header:
    content-type:
    - application/json
    content-length:
    - '125'
    connection:
    - Close
  body: '{\"fault\":{\"faultstring\":\"Invalid ApiKey for given resource\",\"detail\":{\"errorcode\":\"oauth.v2.InvalidApiKeyForGivenResource\"}}}'
  read: true
  uri:
  decode_content: true
  socket:
  body_exist: true
message:
    RESPONSE
    YAML.load(yamlexcep)
  end

  def bad_credentials_response
    yamlexcep = <<-RESPONSE
--- !ruby/exception:ActiveMerchant::ResponseError
response: !ruby/object:Net::HTTPForbidden
  http_version: '1.1'
  code: '403'
  message: Forbidden
  header:
    content-type:
    - application/json
    content-length:
    - '51'
    connection:
    - Close
  body: '{"code":"403", "message":"HMAC validation Failure"}'
  read: true
  uri:
  decode_content: true
  socket:
  body_exist: true
message:
    RESPONSE
    YAML.load(yamlexcep)
  end

  def successful_void_response
    <<-RESPONSE
    {\"method\":\"credit_card\",\"amount\":\"1\",\"currency\":\"USD\",\"cvv2\":\"I\",\"token\":{\"token_type\":\"transarmor\",\"token_data\":{\"value\":\"9594258319174242\"}},\"transaction_status\":\"approved\",\"validation_status\":\"success\",\"transaction_type\":\"void\",\"transaction_id\":\"ET196233\",\"transaction_tag\":\"55083674\",\"bank_resp_code\":\"100\",\"bank_message\":\"Approved\",\"gateway_resp_code\":\"00\",\"gateway_message\":\"Transaction Normal\",\"correlation_id\":\"124.1433863576596\"}
RESPONSE
  end

  def failed_capture_response
    yamlexcep = <<-RESPONSE
--- !ruby/exception:ActiveMerchant::ResponseError
response: !ruby/object:Net::HTTPBadRequest
  http_version: '1.1'
  code: '400'
  message: Bad Request
  header:
    content-language:
    - en-US
    content-type:
    - application/json
    date:
    - Tue, 09 Jun 2015 17:33:50 GMT
    optr_cxt:
    - 0100010000d084138f-24f3-4686-8a51-3c17406a572500000000-0000-0000-0000-000000000000-1                                  HTTP    ;
    x-archived-client-ip:
    - 10.174.197.250
    x-backside-transport:
    - FAIL FAIL,FAIL FAIL
    x-client-ip:
    - 10.174.197.250,107.23.55.229
    x-powered-by:
    - Servlet/3.0
    content-length:
    - '190'
    connection:
    - Close
  body: '{"transaction_status":"Not Processed","Error":{"messages":[{"code":"server_error","description":"ProcessedBad
    Request (69) - Invalid Transaction Tag"}]},"correlation_id":"124.1433871231542"}'
  read: true
  uri:
  decode_content: true
  socket:
  body_exist: true
message:
RESPONSE
    YAML.load(yamlexcep)
  end
end
