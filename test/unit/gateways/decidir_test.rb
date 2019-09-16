require 'test_helper'

class DecidirTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway_for_purchase = DecidirGateway.new(api_key: 'api_key')
    @gateway_for_auth = DecidirGateway.new(api_key: 'api_key', preauth_mode: true)
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway_for_purchase.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 7719132, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_purchase_with_options
    options = {
      ip: '127.0.0.1',
      email: 'joe@example.com',
      card_holder_door_number: '1234',
      card_holder_birthday: '01011980',
      card_holder_identification_type: 'dni',
      card_holder_identification_number: '123456',
      installments: 12
    }

    response = stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, @credit_card, @options.merge(options))
    end.check_request do |method, endpoint, data, headers|
      assert data =~ /card_holder_door_number/, '1234'
      assert data =~ /card_holder_birthday/, '01011980'
      assert data =~ /type/, 'dni'
      assert data =~ /number/, '123456'
    end.respond_with(successful_purchase_response)

    assert_equal 7719132, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway_for_purchase.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'TARJETA INVALIDA', response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_failed_purchase_with_invalid_field
    @gateway_for_purchase.expects(:ssl_request).returns(failed_purchase_with_invalid_field_response)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options.merge(installments: -1))
    assert_failure response
    assert_equal 'invalid_param: installments', response.message
    assert_match 'invalid_request_error', response.error_code
  end

  def test_failed_purchase_with_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_auth.purchase(@amount, @credit_card, @options)
    end
  end

  def test_successful_authorize
    @gateway_for_auth.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway_for_auth.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 7720214, response.authorization
    assert_equal 'pre_approved', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway_for_auth.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway_for_auth.authorize(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 7719358, response.authorization
    assert_equal 'TARJETA INVALIDA', response.message
    assert response.test?
  end

  def test_failed_authorize_without_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_purchase.authorize(@amount, @credit_card, @options)
    end
  end

  def test_successful_capture
    @gateway_for_auth.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway_for_auth.capture(@amount, 7720214)
    assert_success response

    assert_equal 7720214, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_partial_capture
    @gateway_for_auth.expects(:ssl_request).returns(failed_partial_capture_response)

    response = @gateway_for_auth.capture(@amount, '')
    assert_failure response

    assert_nil response.authorization
    assert_equal 'amount: Amount out of ranges: 100 - 100', response.message
    assert_equal 'invalid_request_error', response.error_code
    assert response.test?
  end

  def test_failed_capture
    @gateway_for_auth.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway_for_auth.capture(@amount, '')
    assert_failure response

    assert_equal '', response.authorization
    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_failed_capture_without_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_purchase.capture(@amount, @credit_card, @options)
    end
  end

  def test_successful_refund
    @gateway_for_purchase.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway_for_purchase.refund(@amount, 81931, @options)
    assert_success response

    assert_equal 81931, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_partial_refund
    @gateway_for_purchase.expects(:ssl_request).returns(partial_refund_response)

    response = @gateway_for_purchase.refund(@amount-1, 81932, @options)
    assert_success response

    assert_equal 81932, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway_for_purchase.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway_for_purchase.refund(@amount, '')
    assert_failure response

    assert_equal '', response.authorization
    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_successful_void
    @gateway_for_auth.expects(:ssl_request).returns(successful_void_response)

    response = @gateway_for_auth.void(@amount, '')
    assert_success response

    assert_equal 82814, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway_for_auth.expects(:ssl_request).returns(failed_void_response)

    response = @gateway_for_auth.void('')
    assert_failure response

    assert_equal '', response.authorization
    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_successful_verify
    @gateway_for_auth.expects(:ssl_request).at_most(3).returns(successful_void_response)

    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_success response

    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway_for_auth.expects(:ssl_request).at_most(3).returns(failed_void_response)

    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_failure response

    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_failed_verify
    @gateway_for_auth.expects(:ssl_request).at_most(2).returns(failed_authorize_response)

    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_failure response

    assert_equal 'TARJETA INVALIDA', response.message
    assert response.test?
  end

  def test_failed_verify_for_without_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_purchase.verify(@amount, @credit_card, @options)
    end
  end

  def test_scrub
    assert @gateway_for_purchase.supports_scrubbing?
    assert_equal @gateway_for_purchase.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established
      <- "POST /api/v2/payments HTTP/1.1\r\nContent-Type: application/json\r\nApikey: 5df6b5764c3f4822aecdc82d56f26b9d\r\nCache-Control: no-cache\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: developers.decidir.com\r\nContent-Length: 414\r\n\r\n"
      <- "{\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"bin\":\"450799\",\"payment_type\":\"single\",\"installments\":1,\"description\":\"Store Purchase\",\"sub_payments\":[],\"amount\":100,\"currency\":\"ARS\",\"card_data\":{\"card_number\":\"4507990000004905\",\"card_expiration_month\":\"09\",\"card_expiration_year\":\"20\",\"security_code\":\"123\",\"card_holder_name\":\"Longbob Longsen\",\"card_holder_identification\":{}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Mon, 24 Jun 2019 18:38:42 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 659\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Kong-Upstream-Latency: 159\r\n"
      -> "X-Kong-Proxy-Latency: 0\r\n"
      -> "Via: kong/0.8.3\r\n"
      -> "\r\n"
      reading 659 bytes...
      -> "{\"id\":7721017,\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"card_brand\":\"Visa\",\"amount\":100,\"currency\":\"ars\",\"status\":\"approved\",\"status_details\":{\"ticket\":\"7297\",\"card_authorization_code\":\"153842\",\"address_validation_code\":\"VTE0011\",\"error\":null},\"date\":\"2019-06-24T15:38Z\",\"customer\":null,\"bin\":\"450799\",\"installments\":1,\"first_installment_expiration_date\":null,\"payment_type\":\"single\",\"sub_payments\":[],\"site_id\":\"99999999\",\"fraud_detection\":null,\"aggregate_data\":null,\"establishment_name\":null,\"spv\":null,\"confirmed\":null,\"pan\":\"345425f15b2c7c4584e0044357b6394d7e\",\"customer_token\":null,\"card_data\":\"/tokens/7721017\"}"
      read 659 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established
      <- "POST /api/v2/payments HTTP/1.1\r\nContent-Type: application/json\r\nApikey: [FILTERED]\r\nCache-Control: no-cache\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: developers.decidir.com\r\nContent-Length: 414\r\n\r\n"
      <- "{\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"bin\":\"450799\",\"payment_type\":\"single\",\"installments\":1,\"description\":\"Store Purchase\",\"sub_payments\":[],\"amount\":100,\"currency\":\"ARS\",\"card_data\":{\"card_number\":\"[FILTERED]\",\"card_expiration_month\":\"09\",\"card_expiration_year\":\"20\",\"security_code\":\"[FILTERED]\",\"card_holder_name\":\"Longbob Longsen\",\"card_holder_identification\":{}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Mon, 24 Jun 2019 18:38:42 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 659\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Kong-Upstream-Latency: 159\r\n"
      -> "X-Kong-Proxy-Latency: 0\r\n"
      -> "Via: kong/0.8.3\r\n"
      -> "\r\n"
      reading 659 bytes...
      -> "{\"id\":7721017,\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"card_brand\":\"Visa\",\"amount\":100,\"currency\":\"ars\",\"status\":\"approved\",\"status_details\":{\"ticket\":\"7297\",\"card_authorization_code\":\"153842\",\"address_validation_code\":\"VTE0011\",\"error\":null},\"date\":\"2019-06-24T15:38Z\",\"customer\":null,\"bin\":\"450799\",\"installments\":1,\"first_installment_expiration_date\":null,\"payment_type\":\"single\",\"sub_payments\":[],\"site_id\":\"99999999\",\"fraud_detection\":null,\"aggregate_data\":null,\"establishment_name\":null,\"spv\":null,\"confirmed\":null,\"pan\":\"345425f15b2c7c4584e0044357b6394d7e\",\"customer_token\":null,\"card_data\":\"/tokens/7721017\"}"
      read 659 bytes
      Conn close
    )
  end

  def successful_purchase_response
    %(
      {"id":7719132,"site_transaction_id":"ebcb2db7-7aab-4f33-a7d1-6617a5749fce","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"approved","status_details":{"ticket":"7156","card_authorization_code":"174838","address_validation_code":"VTE0011","error":null},"date":"2019-06-21T17:48Z","customer":null,"bin":"450799","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999999","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"345425f15b2c7c4584e0044357b6394d7e","customer_token":null,"card_data":"/tokens/7719132"}
    )
  end

  def failed_purchase_response
    %(
      {"id":7719351,"site_transaction_id":"73e3ed66-37b1-4c97-8f69-f9cb96422383","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"rejected","status_details":{"ticket":"7162","card_authorization_code":"","address_validation_code":null,"error":{"type":"invalid_number","reason":{"id":14,"description":"TARJETA INVALIDA","additional_description":""}}},"date":"2019-06-21T17:57Z","customer":null,"bin":"400030","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999999","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"11b076fbc8fa6a55783b2f5d03f6938d8a","customer_token":null,"card_data":"/tokens/7719351"}
    )
  end

  def failed_purchase_with_invalid_field_response
    %(
      {\"error_type\":\"invalid_request_error\",\"validation_errors\":[{\"code\":\"invalid_param\",\"param\":\"installments\"}]}    )
  end

  def successful_authorize_response
    %(
      {"id":7720214,"site_transaction_id":"0fcedc95-4fbc-4299-80dc-f77e9dd7f525","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"pre_approved","status_details":{"ticket":"8187","card_authorization_code":"180548","address_validation_code":"VTE0011","error":null},"date":"2019-06-21T18:05Z","customer":null,"bin":"450799","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999997","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"345425f15b2c7c4584e0044357b6394d7e","customer_token":null,"card_data":"/tokens/7720214"}
    )
  end

  def failed_authorize_response
    %(
      {"id":7719358,"site_transaction_id":"ff1c12c1-fb6d-4c1a-bc20-2e77d4322c61","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"rejected","status_details":{"ticket":"8189","card_authorization_code":"","address_validation_code":null,"error":{"type":"invalid_number","reason":{"id":14,"description":"TARJETA INVALIDA","additional_description":""}}},"date":"2019-06-21T18:07Z","customer":null,"bin":"400030","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999997","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"11b076fbc8fa6a55783b2f5d03f6938d8a","customer_token":null,"card_data":"/tokens/7719358"}
    )
  end

  def successful_capture_response
    %(
      {"id":7720214,"site_transaction_id":"0fcedc95-4fbc-4299-80dc-f77e9dd7f525","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"approved","status_details":{"ticket":"8187","card_authorization_code":"180548","address_validation_code":"VTE0011","error":null},"date":"2019-06-21T18:05Z","customer":null,"bin":"450799","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999997","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":{"id":78436,"origin_amount":100,"date":"2019-06-21T03:00Z"},"pan":"345425f15b2c7c4584e0044357b6394d7e","customer_token":null,"card_data":"/tokens/7720214"}
    )
  end

  def failed_partial_capture_response
    %(
      {"error_type":"invalid_request_error","validation_errors":[{"code":"amount","param":"Amount out of ranges: 100 - 100"}]}
    )
  end

  def failed_capture_response
    %(
      {"error_type":"not_found_error","entity_name":"","id":""}
    )
  end

  def successful_refund_response
    %(
      {"id":81931,"amount":100,"sub_payments":null,"error":null,"status":"approved"}
    )
  end

  def partial_refund_response
    %(
      {"id":81932,"amount":99,"sub_payments":null,"error":null,"status":"approved"}
    )
  end

  def failed_refund_response
    %(
      {"error_type":"not_found_error","entity_name":"","id":""}
    )
  end

  def successful_void_response
    %(
      {"id":82814,"amount":100,"sub_payments":null,"error":null,"status":"approved"}
    )
  end

  def failed_void_response
    %(
      {"error_type":"not_found_error","entity_name":"","id":""}
    )
  end
end
