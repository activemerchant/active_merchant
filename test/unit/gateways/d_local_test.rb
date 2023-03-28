require 'test_helper'

class DLocalTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = DLocalGateway.new(login: 'login', trans_key: 'password', secret_key: 'shhhhh_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address
    }
    @three_ds_secure = {
      version: '1.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      xid: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y'
    }
  end

  def test_supported_countries
    assert_equal %w[AR BD BO BR CL CM CN CO CR DO EC EG GH GT IN ID JP KE MY MX MA NG PA PY PE PH SN SV TH TR TZ UG UY VN ZA], DLocalGateway.supported_countries
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'D-15104-05b0ec0c-5a1e-470a-b342-eb5f20758ef7', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '300', response.error_code
  end

  def test_purchase_with_installments
    installments = '6'
    installments_id = 'INS54434'

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(installments: installments, installments_id: installments_id))
    end.check_request do |_endpoint, data, _headers|
      assert_equal installments, JSON.parse(data)['card']['installments']
      assert_equal installments_id, JSON.parse(data)['card']['installments_id']
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_network_tokens
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    stub_comms do
      @gateway.purchase(@amount, credit_card)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'BwABB4JRdgAAAAAAiFF2AAAAAAA=', JSON.parse(data)['card']['cryptogram']
      assert_equal '4242424242424242', JSON.parse(data)['card']['network_token']
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_network_tokens_and_store_credential_type_subscription
    options = @options.merge!(stored_credential: stored_credential(:merchant, :recurring, ntid: 'abc123'))
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    stub_comms do
      @gateway.purchase(@amount, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'BwABB4JRdgAAAAAAiFF2AAAAAAA=', JSON.parse(data)['card']['cryptogram']
      assert_equal '4242424242424242', JSON.parse(data)['card']['network_token']
      assert_equal 'SUBSCRIPTION', JSON.parse(data)['card']['stored_credential_type']
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_network_tokens_and_store_credential_type_uneschedule
    options = @options.merge!(stored_credential: stored_credential(:merchant, :unscheduled, ntid: 'abc123'))
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    stub_comms do
      @gateway.purchase(@amount, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'BwABB4JRdgAAAAAAiFF2AAAAAAA=', JSON.parse(data)['card']['cryptogram']
      assert_equal '4242424242424242', JSON.parse(data)['card']['network_token']
      assert_equal 'UNSCHEDULED_CARD_ON_FILE', JSON.parse(data)['card']['stored_credential_type']
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_network_tokens_and_store_credential_usage_first
    options = @options.merge!(stored_credential: stored_credential(:cardholder, :initial))
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    stub_comms do
      @gateway.purchase(@amount, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'BwABB4JRdgAAAAAAiFF2AAAAAAA=', JSON.parse(data)['card']['cryptogram']
      assert_equal '4242424242424242', JSON.parse(data)['card']['network_token']
      assert_equal 'FIRST', JSON.parse(data)['card']['stored_credential_usage']
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_network_tokens_and_store_credential_type_card_on_file_and_credential_usage_used
    options = @options.merge!(stored_credential: stored_credential(:cardholder, :unscheduled, ntid: 'abc123'))
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    stub_comms do
      @gateway.purchase(@amount, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'BwABB4JRdgAAAAAAiFF2AAAAAAA=', JSON.parse(data)['card']['cryptogram']
      assert_equal '4242424242424242', JSON.parse(data)['card']['network_token']
      assert_equal 'CARD_ON_FILE', JSON.parse(data)['card']['stored_credential_type']
      assert_equal 'USED', JSON.parse(data)['card']['stored_credential_usage']
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_network_tokens_and_store_credential_usage
    options = @options.merge!(stored_credential: stored_credential(:cardholder, :recurring, ntid: 'abc123'))
    credit_card = network_tokenization_credit_card('4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    stub_comms do
      @gateway.purchase(@amount, credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'BwABB4JRdgAAAAAAiFF2AAAAAAA=', JSON.parse(data)['card']['cryptogram']
      assert_equal '4242424242424242', JSON.parse(data)['card']['network_token']
      assert_equal 'USED', JSON.parse(data)['card']['stored_credential_usage']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_additional_data
    additional_data = { 'submerchant' => { 'name' => 'socks' } }

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(additional_data: additional_data))
    end.check_request do |_endpoint, data, _headers|
      assert_equal additional_data, JSON.parse(data)['additional_risk_data']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_force_type
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(force_type: 'debit'))
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'DEBIT', JSON.parse(data)['card']['force_type']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_original_order_id
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(original_order_id: '123ABC'))
    end.check_request do |_endpoint, data, _headers|
      assert_equal '123ABC', JSON.parse(data)['original_order_id']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', response.authorization
  end

  def test_successful_authorize_without_address
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options.delete(:billing_address))
    assert_success response

    assert_equal 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', response.authorization
  end

  def test_passing_billing_address
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"state\":\"ON\"/, data)
      assert_match(/"city\":\"Ottawa\"/, data)
      assert_match(/"zip_code\":\"K1C2N6\"/, data)
      assert_match(/"street\":\"My Street\"/, data)
      assert_match(/"number\":\"456\"/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_passing_incomplete_billing_address
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options.merge(billing_address: address(address1: 'Just a Street')))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"state\":\"ON\"/, data)
      assert_match(/"city\":\"Ottawa\"/, data)
      assert_match(/"zip_code\":\"K1C2N6\"/, data)
      assert_match(/"street\":\"Just a Street\"/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_passing_nil_address_1
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options.merge(billing_address: address(address1: nil)))
    end.check_request do |_method, _endpoint, data, _headers|
      refute_match(/"street\"/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_successful_inquire_with_payment_id
    stub_comms(@gateway, :ssl_request) do
      @gateway.inquire('D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f', {})
    end.check_request do |_method, endpoint, data, _headers|
      refute_match(/"https:\/\/sandbox.dlocal.com\/payments\/D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f\/status\/"/, endpoint)
      refute_match(nil, data)
    end.respond_with(successful_payment_status_response)
  end

  def test_successful_inquire_with_order_id
    stub_comms(@gateway, :ssl_request) do
      @gateway.inquire(nil, { order_id: '62595c5db10fdf7b5d5bb3a16d130992' })
    end.check_request do |_method, endpoint, data, _headers|
      refute_match(/"https:\/\/sandbox.dlocal.com\/orders\/62595c5db10fdf7b5d5bb3a16d130992\/"/, endpoint)
      refute_match(nil, data)
    end.respond_with(successful_orders_response)
  end

  def test_passing_country_as_string
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"country\":\"CA\"/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_invalid_country
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options.merge(billing_address: address(country: 'INVALID')))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/\"country\":null/, data)
    end.respond_with(successful_authorize_response)
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '309', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'D-15104-5a914b68-afb8-44f8-a849-8cf09ab6c246', response.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_failure response
    assert_equal '4000', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570', response.authorization
  end

  def test_pending_refund
    @gateway.expects(:ssl_post).returns(pending_refund_response)

    response = @gateway.refund(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_failure response
    assert_equal '5007', response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'D-15104-c147279d-14ab-4537-8ba6-e3e1cde0f8d2', response.authorization
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_failure response

    assert_equal '5002', response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'T-15104-bb204de6-2708-4398-955f-2b16cf633687', response.authorization
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal '315', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_api_version_param_header
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, _data, headers|
      assert_equal '2.1', headers['X-Version']
    end.respond_with(successful_purchase_response)
  end

  def test_idempotency_header
    options = @options.merge(idempotency_key: '12345')
    stub_comms do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, _data, headers|
      assert_equal '12345', headers['X-Idempotency-Key']
    end.respond_with(successful_purchase_response)
  end

  def test_three_ds_v1_object_construction
    post = {}
    @options[:three_d_secure] = @three_ds_secure

    @gateway.send(:add_three_ds, post, @options)

    assert post[:three_dsecure]
    ds_data = post[:three_dsecure]
    ds_options = @options[:three_d_secure]

    assert_equal ds_options[:version], ds_data[:three_dsecure_version]
    assert_equal ds_options[:cavv], ds_data[:cavv]
    assert_equal ds_options[:eci], ds_data[:eci]
    assert_equal ds_options[:xid], ds_data[:xid]
    assert_equal nil, ds_data[:ds_transaction_id]
    assert_equal 'Y', ds_data[:enrollment_response]
    assert_equal ds_options[:authentication_response_status], ds_data[:authentication_response]
  end

  def test_three_ds_v2_object_construction
    post = {}
    @three_ds_secure[:ds_transaction_id] = 'ODUzNTYzOTcwODU5NzY3Qw=='
    @three_ds_secure[:version] = '2.2.0'
    @options[:three_d_secure] = @three_ds_secure

    @gateway.send(:add_three_ds, post, @options)

    assert post[:three_dsecure]
    ds_data = post[:three_dsecure]
    ds_options = @options[:three_d_secure]

    assert_equal ds_options[:version], ds_data[:three_dsecure_version]
    assert_equal ds_options[:cavv], ds_data[:cavv]
    assert_equal ds_options[:eci], ds_data[:eci]
    assert_equal nil, ds_data[:xid]
    assert_equal ds_options[:ds_transaction_id], ds_data[:ds_transaction_id]
    assert_equal 'Y', ds_data[:enrollment_response]
    assert_equal ds_options[:authentication_response_status], ds_data[:authentication_response]
  end

  def test_three_ds_version_validation
    post = {}
    @options[:three_d_secure] = @three_ds_secure
    @gateway.send(:add_three_ds, post, @options)
    resp = @gateway.send(:validate_three_ds_params, post[:three_dsecure])

    assert_equal nil, resp
    post[:three_dsecure][:three_dsecure_version] = '4.0'
    resp = @gateway.send(:validate_three_ds_params, post[:three_dsecure])

    assert_equal 'ThreeDs data is invalid', resp.message
    assert_equal 'ThreeDs version not supported', resp.params['three_ds_version']
  end

  def test_three_ds_enrollment_validation
    post = {}
    @options[:three_d_secure] = @three_ds_secure
    @gateway.send(:add_three_ds, post, @options)
    post[:three_dsecure][:enrollment_response] = 'P'
    resp = @gateway.send(:validate_three_ds_params, post[:three_dsecure])

    assert_equal 'ThreeDs data is invalid', resp.message
    assert_equal 'Enrollment value not supported', resp.params['enrollment']
  end

  def test_three_ds_auth_response_validation
    post = {}
    @options[:three_d_secure] = @three_ds_secure
    @gateway.send(:add_three_ds, post, @options)
    post[:three_dsecure][:authentication_response] = 'P'
    resp = @gateway.send(:validate_three_ds_params, post[:three_dsecure])

    assert_equal 'ThreeDs data is invalid', resp.message
    assert_equal 'Authentication response value not supported', resp.params['auth_response']
  end

  def test_purchase_with_three_ds
    @options[:three_d_secure] = @three_ds_secure
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      three_ds_params = JSON.parse(data)['three_dsecure']
      assert_equal '1.0', three_ds_params['three_dsecure_version']
      assert_equal '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=', three_ds_params['cavv']
      assert_equal '05', three_ds_params['eci']
      assert_equal 'ODUzNTYzOTcwODU5NzY3Qw==', three_ds_params['xid']
      assert_equal 'Y', three_ds_params['enrollment_response']
      assert_equal 'Y', three_ds_params['authentication_response']
    end.respond_with(successful_purchase_response)
  end

  def test_unsuccessfully_purchase_with_wrong_three_ds_data
    @three_ds_secure.delete(:version)
    @options[:three_d_secure] = @three_ds_secure
    resp = @gateway.purchase(@amount, @credit_card, @options)

    assert_equal 'ThreeDs data is invalid', resp.message
    assert_equal 'ThreeDs version not supported', resp.params['three_ds_version']
  end

  def test_formatted_enrollment
    assert_equal 'Y', @gateway.send('formatted_enrollment', 'Y')
    assert_equal 'Y', @gateway.send('formatted_enrollment', 'true')
    assert_equal 'Y', @gateway.send('formatted_enrollment', true)

    assert_equal 'N', @gateway.send('formatted_enrollment', 'N')
    assert_equal 'N', @gateway.send('formatted_enrollment', 'false')
    assert_equal 'N', @gateway.send('formatted_enrollment', false)

    assert_equal 'U', @gateway.send('formatted_enrollment', 'U')
  end

  private

  def pre_scrubbed
    %q(
      <- "POST /secure_payments/ HTTP/1.1\r\nContent-Type: application/json\r\nX-Date: 2018-12-04T18:24:21Z\r\nX-Login: aeaf9bbfa1\r\nX-Trans-Key: 9de3769b7e\r\nAuthorization: V2-HMAC-SHA256, Signature: d58d0e87a59af50ff974dfeea176c067354682aa74a8ac115912576d4214a776\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.dlocal.com\r\nContent-Length: 441\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"payer\":{\"name\":\"Longbob Longsen\",\"phone\":\"(555)555-5555\",\"document\":\"42243309114\",\"address\":null},\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"number\":\"4111111111111111\",\"cvv\":\"123\",\"capture\":true},\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\",\"description\":\"200\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: Reblaze Secure Web Gateway\r\n"
      -> "Date: Tue, 04 Dec 2018 18:24:22 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 565\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Via: 1.1 google\r\n"
      -> "Alt-Svc: clear\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 565 bytes...
      -> "{\"id\":\"D-15104-9f5246d5-34e2-4f63-9d29-380ab1567ec9\",\"amount\":1.00,\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"brand\":\"VI\",\"last4\":\"1111\",\"card_id\":\"CV-434cb5d1-aece-4878-8ce2-24f887fc7ff5\"},\"created_date\":\"2018-12-04T18:24:21.000+0000\",\"approved_date\":\"2018-12-04T18:24:22.000+0000\",\"status\":\"PAID\",\"status_detail\":\"The payment was paid\",\"status_code\":\"200\",\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\"}"
    )
  end

  def post_scrubbed
    %q(
      <- "POST /secure_payments/ HTTP/1.1\r\nContent-Type: application/json\r\nX-Date: 2018-12-04T18:24:21Z\r\nX-Login: aeaf9bbfa1\r\nX-Trans-Key: [FILTERED]\r\nAuthorization: V2-HMAC-SHA256, Signature: d58d0e87a59af50ff974dfeea176c067354682aa74a8ac115912576d4214a776\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.dlocal.com\r\nContent-Length: 441\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"payer\":{\"name\":\"Longbob Longsen\",\"phone\":\"(555)555-5555\",\"document\":\"42243309114\",\"address\":null},\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"number\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"capture\":true},\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\",\"description\":\"200\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: Reblaze Secure Web Gateway\r\n"
      -> "Date: Tue, 04 Dec 2018 18:24:22 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 565\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Via: 1.1 google\r\n"
      -> "Alt-Svc: clear\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 565 bytes...
      -> "{\"id\":\"D-15104-9f5246d5-34e2-4f63-9d29-380ab1567ec9\",\"amount\":1.00,\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"brand\":\"VI\",\"last4\":\"1111\",\"card_id\":\"CV-434cb5d1-aece-4878-8ce2-24f887fc7ff5\"},\"created_date\":\"2018-12-04T18:24:21.000+0000\",\"approved_date\":\"2018-12-04T18:24:22.000+0000\",\"status\":\"PAID\",\"status_detail\":\"The payment was paid\",\"status_code\":\"200\",\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\"}"
    )
  end

  def successful_purchase_response
    '{"id":"D-15104-05b0ec0c-5a1e-470a-b342-eb5f20758ef7","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-993903e4-0b33-48fd-8d9b-99fd6c3f0d1a"},"created_date":"2018-12-06T20:20:41.000+0000","approved_date":"2018-12-06T20:20:42.000+0000","status":"PAID","status_detail":"The payment was paid","status_code":"200","order_id":"15940ef43d39331bc64f31341f8ccd93"}'
  end

  def successful_purchase_with_installments_response
    '{"id":"D-4-e2227981-8ec8-48fd-8e9a-19fedb08d73a","amount":1000,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Thiago Gabriel","expiration_month":10,"expiration_year":2040,"brand":"VI","last4":"1111"},"created_date":"2019-02-06T21:04:43.000+0000","approved_date":"2019-02-06T21:04:44.000+0000","status":"PAID","status_detail":"The payment was paid.","status_code":"200","order_id":"657434343","notification_url":"http://merchant.com/notifications"}'
  end

  def failed_purchase_response
    '{"id":"D-15104-c3027e67-21f8-4308-8c94-06c44ffcea67","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-529b0bb1-8b8a-42f4-b5e4-d358ffb2c978"},"created_date":"2018-12-06T20:22:40.000+0000","status":"REJECTED","status_detail":"The payment was rejected.","status_code":"300","order_id":"7aa5cd3200f287fbac51dcee32184260"}'
  end

  def successful_authorize_response
    '{"id":"D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-ecd897ac-5361-45a1-a407-aaab044ce87e"},"created_date":"2018-12-06T20:24:46.000+0000","approved_date":"2018-12-06T20:24:46.000+0000","status":"AUTHORIZED","status_detail":"The payment was authorized","status_code":"600","order_id":"5694b51b79df484578158d7790b4aacf"}'
  end

  def failed_authorize_response
    '{"id":"D-15104-e6ed3df3-1380-46c6-92d4-29f0f567f799","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-a6326a1d-b706-4e89-9dff-091d73d85b26"},"created_date":"2018-12-06T20:26:57.000+0000","status":"REJECTED","status_detail":"Card expired.","status_code":"309","order_id":"8ecd3101ba7a9a2d6ccb6465d33ff10d"}'
  end

  def successful_capture_response
    '{"id":"D-15104-5a914b68-afb8-44f8-a849-8cf09ab6c246","amount":1.00,"currency":"BRL","payment_method_id":"VI","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","created_date":"2018-12-06T20:26:17.000+0000","approved_date":"2018-12-06T20:26:18.000+0000","status":"PAID","status_detail":"The payment was paid","status_code":"200","order_id":"f8276e468120faf3e7252e33ac5f9a73"}'
  end

  def failed_capture_response
    '{"code":4000,"message":"Payment not found"}'
  end

  def successful_verify_response
    '{"id":"T-15104-bb204de6-2708-4398-955f-2b16cf633687","amount":0,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen", "expiration_month":9, "expiration_year":2022, "brand":"VI", "last4":"1111", "verify":true},"three_dsecure":{},"created_date":"2021-11-05T19:54:34.000+0000","approved_date":"2021-11-05T19:54:35.000+0000","status":"VERIFIED","status_detail":"The payment was verified.","status_code":"700","order_id":"e3ec1f40e9cb06b2d9c61f35bd5115e9"}'
  end

  def failed_verify_response
    '{"id":"T-15104-585b4fb0-8fc5-4ae2-bb87-41218b744ca0","amount":0,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen", "expiration_month":9, "expiration_year":2022, "brand":"VI", "last4":"1111", "verify":true},"three_dsecure":{},"created_date":"2021-11-05T19:54:34.000+0000","status":"REJECTED","status_detail":"Invalid security code.","status_code":"315","order_id":"e013030bd5a7330a5d490247a9ca2bf47","description":"315"}'
  end

  def successful_refund_response
    '{"id":"REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570","payment_id":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f","status":"SUCCESS","currency":"BRL","created_date":"2018-12-06T20:28:37.000+0000","amount":1.00,"status_code":200,"status_detail":"The refund was paid","notification_url":"http://example.com","amount_refunded":1.00,"id_payment":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f"}'
  end

  def successful_payment_status_response
    '{"code":100,"message":"The payment is pending."}'
  end

  def successful_orders_response
    '{"order_id":"b809a1aa481b88aaa858144798da656d","payment_id":"T-15104-15f4044d-c4b1-4a38-9b47-bb8be126491d","currency":"BRL","amount":2.0,"created_date":"2022-09-19T13:16:22.000+0000","approved_date":"2022-09-19T13:16:22.000+0000","status":"PAID","status_detail":"The payment was paid.","status_code":"200"}'
  end

  # I can't invoke a pending response and there is no example in docs, so this response is speculative
  def pending_refund_response
    '{"id":"REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570","payment_id":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f","status":"PENDING","currency":"BRL","created_date":"2018-12-06T20:28:37.000+0000","amount":1.00,"status_code":100,"status_detail":"The refund is pending","notification_url":"http://example.com","amount_refunded":1.00,"id_payment":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f"}'
  end

  def failed_refund_response
    '{"code":5007,"message":"Amount exceeded"}'
  end

  def successful_void_response
    '{"id":"D-15104-c147279d-14ab-4537-8ba6-e3e1cde0f8d2","amount":1.00,"currency":"BRL","payment_method_id":"VI","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","created_date":"2018-12-06T20:38:01.000+0000","approved_date":"2018-12-06T20:38:01.000+0000","status":"CANCELLED","status_detail":"The payment was cancelled","status_code":"400","order_id":"46d8978863be935d892cfa3e992f65f3"}'
  end

  def failed_void_response
    '{"code":5002,"message":"Invalid transaction status"}'
  end
end
