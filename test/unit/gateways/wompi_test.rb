require 'test_helper'

class WompiTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = WompiGateway.new(test_public_key: 'pub_test_1234', test_private_key: 'priv_test_5678')
    @prod_gateway = WompiGateway.new(prod_public_key: 'pub_prod_1234', prod_private_key: 'priv_prod_5678')
    @ambidextrous_gateway = WompiGateway.new(prod_public_key: 'pub_prod_1234', prod_private_key: 'priv_prod_5678', test_public_key: 'pub_test_1234', test_private_key: 'priv_test_5678')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_ambidextrous_gateway_behaves_accordingly
    response = stub_comms(@ambidextrous_gateway) do
      @ambidextrous_gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, _data, headers|
      assert_match(/priv_test_5678/, headers[:Authorization])
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal '113879-1635300853-71494', response.authorization
    assert response.test?
  end

  def test_gateway_without_creds_raises_useful_error
    assert_raise ArgumentError, 'Gateway requires both test_private_key and test_public_key, or both prod_private_key and prod_public_key' do
      WompiGateway.new()
    end
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '113879-1635300853-71494', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'La transacción fue rechazada (Sandbox)', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 19930, response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, '113879-1638483506-80282', @options)
    assert_success response

    assert_equal '113879-1638483506-80282', response.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, '')
    assert_failure response

    assert_equal 'La transacción fue rechazada (Sandbox)', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_success response

    assert_equal '113879-1635301011-28454', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    message = JSON.parse(response.message)
    assert_equal 'transaction_id Debe ser completado', message['transaction_id'].first
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@amount, @options)
    assert_success response

    assert_equal '113879-1635301067-17128', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@amount, @options)
    assert_failure response
    assert_equal 'La entidad solicitada no existe', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~TRANSCRIPT
      "opening connection to sandbox.wompi.co:443...\nopened\nstarting SSL for sandbox.wompi.co:443...\nSSL established\n<- \"POST /v1/transactions_sync HTTP/1.1\\r\\nContent-Type: application/x-www-form-urlencoded\\r\\nAuthorization: Bearer prv_test_apOk1L1TV4qPqrZkfsPsJz5PBABQSI7F\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: sandbox.wompi.co\\r\\nContent-Length: 282\\r\\n\\r\\n\"\n<- \"{\\\"reference\\\":\\\"rk6PBsDIxaBH\\\",\\\"public_key\\\":\\\"pub_test_RGehkiIXU3opWWryDE6jByz4W9kq6Hdk\\\",\\\"amount_in_cents\\\":150000,\\\"currency\\\":\\\"COP\\\",\\\"payment_method\\\":{\\\"type\\\":\\\"CARD\\\",\\\"number\\\":\\\"4242424242424242\\\",\\\"exp_month\\\":\\\"09\\\",\\\"exp_year\\\":\\\"22\\\",\\\"installments\\\":2,\\\"cvc\\\":\\\"123\\\",\\\"card_holder\\\":\\\"Longbob Longsen\\\"}}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"Content-Length: 621\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Date: Wed, 27 Oct 2021 03:48:17 GMT\\r\\n\"\n-> \"x-amzn-RequestId: 9a64471b-b1ab-4835-9ef0-70b3d6a838fc\\r\\n\"\n-> \"x-amz-apigw-id: H2TOPERIoAMF0kA=\\r\\n\"\n-> \"X-Amzn-Trace-Id: Root=1-6178cbf4-2ba684d62e9bd4bd04017a4b;Sampled=0\\r\\n\"\n-> \"X-Cache: Miss from cloudfront\\r\\n\"\n-> \"Via: 1.1 ee9de9e6182ae0c8e8f119177e905245.cloudfront.net (CloudFront)\\r\\n\"\n-> \"X-Amz-Cf-Pop: DEN50-C2\\r\\n\"\n-> \"X-Amz-Cf-Id: QJH1Iy_rtMcjnWs4FI44anx5cX6RNZbk6JnHd6wvxqlDZnKl5j4W5g==\\r\\n\"\n-> \"\\r\\n\"\nreading 621 bytes...\n-> \"{\\\"data\\\":{\\\"id\\\":\\\"113879-1635306496-65846\\\",\\\"created_at\\\":\\\"2021-10-27T03:48:17.706Z\\\",\\\"amount_in_cents\\\":150000,\\\"reference\\\":\\\"rk6PBsDIxaBH\\\",\\\"currency\\\":\\\"COP\\\",\\\"payment_method_type\\\":\\\"CARD\\\",\\\"payment_method\\\":{\\\"type\\\":\\\"CARD\\\",\\\"extra\\\":{\\\"name\\\":\\\"VISA-4242\\\",\\\"brand\\\":\\\"VISA\\\",\\\"last_four\\\":\\\"4242\\\",\\\"external_identifier\\\":\\\"JdGjsAGDPQ\\\"},\\\"installments\\\":2},\\\"redirect_url\\\":null,\\\"status\\\":\\\"APPROVED\\\",\\\"status_message\\\":null,\\\"merchant\\\":{\\\"name\\\":\\\"Spreedly MV\\\",\\\"legal_name\\\":\\\"Longbob Longsen\\\",\\\"contact_name\\\":\\\"Longbob Longsen\\\",\\\"phone_number\\\":\\\"+573017654567\\\",\\\"logo_url\\\":null,\\\"legal_id_type\\\":\\\"CC\\\",\\\"email\\\":\\\"longbob@example.com\\\",\\\"legal_id\\\":\\\"14671275\\\"},\\\"taxes\\\":[]}}\"\nread 621 bytes\nConn close\n"
    TRANSCRIPT
  end

  def post_scrubbed
    <<~SCRUBBED
      "opening connection to sandbox.wompi.co:443...\nopened\nstarting SSL for sandbox.wompi.co:443...\nSSL established\n<- \"POST /v1/transactions_sync HTTP/1.1\\r\\nContent-Type: application/x-www-form-urlencoded\\r\\nAuthorization: Bearer [REDACTED]\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: sandbox.wompi.co\\r\\nContent-Length: 282\\r\\n\\r\\n\"\n<- \"{\\\"reference\\\":\\\"rk6PBsDIxaBH\\\",\\\"public_key\\\":\\\"pub_test_RGehkiIXU3opWWryDE6jByz4W9kq6Hdk\\\",\\\"amount_in_cents\\\":150000,\\\"currency\\\":\\\"COP\\\",\\\"payment_method\\\":{\\\"type\\\":\\\"CARD\\\",\\\"number\\\":\\\"[REDACTED]\\\",\\\"exp_month\\\":\\\"09\\\",\\\"exp_year\\\":\\\"22\\\",\\\"installments\\\":2,\\\"cvc\\\":\\\"[REDACTED]\\\",\\\"card_holder\\\":\\\"Longbob Longsen\\\"}}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"Content-Length: 621\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Date: Wed, 27 Oct 2021 03:48:17 GMT\\r\\n\"\n-> \"x-amzn-RequestId: 9a64471b-b1ab-4835-9ef0-70b3d6a838fc\\r\\n\"\n-> \"x-amz-apigw-id: H2TOPERIoAMF0kA=\\r\\n\"\n-> \"X-Amzn-Trace-Id: Root=1-6178cbf4-2ba684d62e9bd4bd04017a4b;Sampled=0\\r\\n\"\n-> \"X-Cache: Miss from cloudfront\\r\\n\"\n-> \"Via: 1.1 ee9de9e6182ae0c8e8f119177e905245.cloudfront.net (CloudFront)\\r\\n\"\n-> \"X-Amz-Cf-Pop: DEN50-C2\\r\\n\"\n-> \"X-Amz-Cf-Id: QJH1Iy_rtMcjnWs4FI44anx5cX6RNZbk6JnHd6wvxqlDZnKl5j4W5g==\\r\\n\"\n-> \"\\r\\n\"\nreading 621 bytes...\n-> \"{\\\"data\\\":{\\\"id\\\":\\\"113879-1635306496-65846\\\",\\\"created_at\\\":\\\"2021-10-27T03:48:17.706Z\\\",\\\"amount_in_cents\\\":150000,\\\"reference\\\":\\\"rk6PBsDIxaBH\\\",\\\"currency\\\":\\\"COP\\\",\\\"payment_method_type\\\":\\\"CARD\\\",\\\"payment_method\\\":{\\\"type\\\":\\\"CARD\\\",\\\"extra\\\":{\\\"name\\\":\\\"VISA-4242\\\",\\\"brand\\\":\\\"VISA\\\",\\\"last_four\\\":\\\"4242\\\",\\\"external_identifier\\\":\\\"JdGjsAGDPQ\\\"},\\\"installments\\\":2},\\\"redirect_url\\\":null,\\\"status\\\":\\\"APPROVED\\\",\\\"status_message\\\":null,\\\"merchant\\\":{\\\"name\\\":\\\"Spreedly MV\\\",\\\"legal_name\\\":\\\"Longbob Longsen\\\",\\\"contact_name\\\":\\\"Longbob Longsen\\\",\\\"phone_number\\\":\\\"[REDACTED]\\\",\\\"logo_url\\\":null,\\\"legal_id_type\\\":\\\"CC\\\",\\\"email\\\":\\\"[REDACTED]\\\",\\\"legal_id\\\":\\\"[REDACTED]\\\"},\\\"taxes\\\":[]}}\"\nread 621 bytes\nConn close\n"
    SCRUBBED
  end

  def successful_purchase_response
    %(
      {"data":{"id":"113879-1635300853-71494","created_at":"2021-10-27T02:14:16.181Z","amount_in_cents":150000,"reference":"b4DxpcrtsvRs","currency":"COP","payment_method_type":"CARD","payment_method":{"type":"CARD","extra":{"name":"VISA-4242","brand":"VISA","last_four":"4242","external_identifier":"fOYBYDRGuP"},"installments":2},"redirect_url":null,"status":"APPROVED","status_message":null,"merchant":{"name":"Spreedly MV","legal_name":"Longbob Longsen","contact_name":"Longbob Longsen","phone_number":"+573017654567","logo_url":null,"legal_id_type":"CC","email":"longbob@example.com","legal_id":"14671275"},"taxes":[]}}
      )
  end

  def failed_purchase_response
    %(
      {"data":{"id":"113879-1635300920-47863","created_at":"2021-10-27T02:15:21.455Z","amount_in_cents":150000,"reference":"sljAsra9maeh","currency":"COP","payment_method_type":"CARD","payment_method":{"type":"CARD","extra":{"name":"VISA-1111","brand":"VISA","last_four":"1111","external_identifier":"liEZAwoiCD"},"installments":2},"redirect_url":null,"status":"DECLINED","status_message":"La transacción fue rechazada (Sandbox)","merchant":{"name":"Spreedly MV","legal_name":"Longbob Longsen","contact_name":"Longbob Longsen","phone_number":"+573017654567","logo_url":null,"legal_id_type":"CC","email":"longbob@example.com","legal_id":"14671275"},"taxes":[]}}
    )
  end

  def successful_authorize_response
    %(
      {"data":{"id":19930,"public_data":{"type":"CARD","financial_operation":"PREAUTHORIZATION","amount_in_cents":1500,"number_of_installments":1,"currency":"COP"},"token":"tok_test_13879_29dbd1E75A7dc06e42bE08dbad959771","type":"CARD","status":"AVAILABLE","customer_email":null}}
    )
  end

  def successful_capture_response
    %(
      {"data":{"id":"113879-1638483506-80282","created_at":"2021-12-02T22:18:27.877Z","amount_in_cents":160000,"reference":"larenciadediana3","currency":"COP","payment_method_type":"CARD","payment_method":{"type":"CARD","extra":{"name":"VISA-4242","brand":"VISA","last_four":"4242","external_identifier":"N4Dup17YZn"}},"redirect_url":null,"status":"APPROVED","status_message":null,"merchant":{"name":"Spreedly MV","legal_name":"Miguel Valencia","contact_name":"Miguel Valencia","phone_number":"+573117654567","logo_url":null,"legal_id_type":"CC","email":"mvalencia@spreedly.com","legal_id":"14671275"},"taxes":[]}}
    )
  end

  def failed_capture_response
    %(
      {"data":{"id":"113879-1638802203-50693","created_at":"2021-12-06T14:50:04.497Z","amount_in_cents":160000,"reference":"larencia987diana37","currency":"COP","payment_method_type":"CARD","payment_method":{"type":"CARD","extra":{"name":"VISA-1111","brand":"VISA","last_four":"1111","external_identifier":"1cAREQ60RX"}},"redirect_url":null,"status":"DECLINED","status_message":"La transacción fue rechazada (Sandbox)","merchant":{"name":"Spreedly MV","legal_name":"Miguel Valencia","contact_name":"Miguel Valencia","phone_number":"+573117654567","logo_url":null,"legal_id_type":"CC","email":"mvalencia@spreedly.com","legal_id":"14671275"},"taxes":[]}}
    )
  end

  def successful_refund_response
    %(
      {"data":{"id":61,"created_at":"2021-10-27T02:16:55.333Z","transaction_id":"113879-1635301011-28454","status":"APPROVED","amount_in_cents":150000}}
    )
  end

  def failed_refund_response
    %(
      {"error":{"type":"INPUT_VALIDATION_ERROR","messages":{"transaction_id":["transaction_id Debe ser completado"]}}}
    )
  end

  def successful_void_response
    %(
      {"data":{"status":"APPROVED","status_message":null,"transaction":{"id":"113879-1635301067-17128","created_at":"2021-10-27T02:17:48.368Z","finalized_at":"2021-10-27T02:17:48.000Z","amount_in_cents":150000,"reference":"89BFPG90NHAY","customer_email":null,"currency":"COP","payment_method_type":"CARD","payment_method":{"type":"CARD","extra":{"bin":"424242","name":"VISA-4242","brand":"VISA","exp_year":"22","exp_month":"09","last_four":"4242","card_holder":"Longbob Longsen","external_identifier":"hRd7HK6Euo"},"installments":2},"status":"APPROVED","status_message":null,"billing_data":null,"shipping_address":null,"redirect_url":null,"payment_source_id":null,"payment_link_id":null,"customer_data":null,"bill_id":null,"taxes":[]}},"meta":{"trace_id":"03951732b922897303397336c99e2523"}}
    )
  end

  def failed_void_response
    %(
      {"error":{"type":"NOT_FOUND_ERROR","reason":"La entidad solicitada no existe"},"meta":{"trace_id":"f9a18f00e69e61c14bf0abe507d8d110"}}
    )
  end
end
