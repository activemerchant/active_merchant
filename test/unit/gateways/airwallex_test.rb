require 'test_helper'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AirwallexGateway
      def setup_access_token
        '12345678'
      end
    end
  end
end

class AirwallexTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AirwallexGateway.new(client_id: 'login', client_api_key: 'password')
    @credit_card = credit_card
    @declined_card = credit_card('2223 0000 1018 1375')
    @amount = 100
    @declined_amount = 8014

    @options = {
      billing_address: address,
      return_url: 'https://example.com'
    }

    @stored_credential_cit_options = { initial_transaction: true, initiator: 'cardholder', reason_type: 'recurring', network_transaction_id: nil }
    @stored_credential_mit_options = { initial_transaction: false, initiator: 'merchant', reason_type: 'recurring' }
  end

  def test_gateway_has_access_token
    assert @gateway.instance_variable_defined?(:@access_token)
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'int_hkdmtp6bpg79nn35u43', response.authorization
    assert response.test?
  end

  def test_failed_purchase_with_declined_card
    @gateway.expects(:ssl_post).times(2).returns(successful_payment_intent_response, failed_purchase_response)

    response = @gateway.purchase(@declined_amount, @declined_card, @options)
    assert_failure response
    assert_equal '14', response.error_code
    assert_equal 'The card issuer declined this transaction. Please refer to the original response code.', response.message
  end

  def test_purchase_without_return_url_raises_error
    assert_raise ArgumentError do
      @gateway.purchase(@amount, @credit_card, {})
    end
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options.merge(auto_capture: false))
    assert_success response

    assert_equal 'int_hkdmtp6bpg79nqimh2z', response.authorization
    assert response.test?
  end

  def test_failed_authorize_with_declined_card
    @gateway.expects(:ssl_post).times(2).returns(successful_payment_intent_response, failed_authorize_response)

    response = @gateway.authorize(@declined_amount, @declined_card, @options.merge(auto_capture: false))
    assert_failure response
    assert_equal '14', response.error_code
    assert_equal 'The card issuer declined this transaction. Please refer to the original response code.', response.message
  end

  def test_authorize_without_return_url_raises_error
    assert_raise ArgumentError do
      @gateway.authorize(@amount, @credit_card, { auto_capture: false })
    end
  end

  def test_successful_authorize_with_3ds_v1_options
    @options[:three_d_secure] = {
      version: '1',
      cavv: 'VGhpcyBpcyBhIHRlc3QgYmFzZTY=',
      eci: '02',
      xid: 'b2h3aDZrd3BJWXVCWEFMbzJqSGQ='
    }

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/\"version\":\"1.0.0\"/, data)
        assert_match(/\"cavv\":\"VGhpcyBpcyBhIHRlc3QgYmFzZTY=\"/, data)
        assert_match(/\"eci\":\"02\"/, data)
        assert_match(/\"xid\":\"b2h3aDZrd3BJWXVCWEFMbzJqSGQ=\"/, data)
      end
    end.respond_with(successful_authorize_response)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_authorize_with_3ds_v2_options
    @options[:three_d_secure] = {
      version: '2.2.0',
      cavv: 'MTIzNDU2Nzg5MDA5ODc2NTQzMjE=',
      ds_transaction_id: 'f25084f0-5b16-4c0a-ae5d-b24808a95e4b',
      eci: '02',
      three_ds_server_trans_id: 'df8b9557-e41b-4e17-87e9-2328694a2ea0'
    }

    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/\"version\":\"2.2.0\"/, data)
        assert_match(/\"authentication_value\":\"MTIzNDU2Nzg5MDA5ODc2NTQzMjE=\"/, data)
        assert_match(/\"ds_transaction_id\":\"f25084f0-5b16-4c0a-ae5d-b24808a95e4b\"/, data)
        assert_match(/\"eci\":\"02\"/, data)
        assert_match(/\"three_ds_server_transaction_id\":\"df8b9557-e41b-4e17-87e9-2328694a2ea0\"/, data)
      end
    end.respond_with(successful_authorize_response)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_purchase_with_3ds_version_formatting
    @options[:three_d_secure] = {
      version: '2.0',
      cavv: 'MTIzNDU2Nzg5MDA5ODc2NTQzMjE=',
      ds_transaction_id: 'f25084f0-5b16-4c0a-ae5d-b24808a95e4b',
      eci: '02',
      three_ds_server_trans_id: 'df8b9557-e41b-4e17-87e9-2328694a2ea0'
    }

    formatted_version = format_three_ds_version(@options[:three_d_secure][:version])

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, _headers|
      data = JSON.parse(data)
      assert_match(data['payment_method_options']['card']['external_three_ds']['version'], formatted_version) unless endpoint == setup_endpoint
    end.respond_with(successful_purchase_response)

    assert_success response
    assert response.test?
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'int_hkdmtp6bpg79nqimh2z', response.authorization
    assert response.test?
  end

  def test_failed_capture_with_declined_amount
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@declined_amount, '12345', @options)
    assert_failure response
    assert_equal 'not_found', response.error_code
    assert_equal 'The requested endpoint does not exist [/api/v1/pa/payment_intents/12345/capture]', response.message
  end

  def test_capture_without_auth_raises_error
    assert_raise ArgumentError do
      @gateway.capture(@amount, '', @options)
    end
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'RECEIVED', response.message
    assert response.test?
  end

  def test_failed_refund_with_declined_amount
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@declined_amount, '12345', @options)
    assert_failure response
    assert_equal 'resource_not_found', response.error_code
    assert_equal 'The PaymentIntent with ID 12345 cannot be found.', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('int_hkdm49cp4g7d5njedty', @options)
    assert_success response

    assert_equal 'CANCELLED', response.message
    assert response.test?
  end

  def test_void_without_auth_raises_error
    assert_raise ArgumentError do
      @gateway.void('', @options)
    end
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void('12345', @options)

    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(3).returns(successful_authorize_response, successful_void_response)
    response = @gateway.verify(credit_card('4111111111111111'), @options)

    assert_success response
    assert_equal 'CANCELLED', response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_payment_intent_response, failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_refund_passes_both_ids
    request_id = "request_#{(Time.now.to_f.round(2) * 100).to_i}"
    merchant_order_id = "order_#{(Time.now.to_f.round(2) * 100).to_i}"
    stub_comms do
      # merchant_order_id is only passed directly on refunds
      @gateway.refund(@amount, 'abc123', @options.merge(request_id: request_id, merchant_order_id: merchant_order_id))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/request_/, data)
      assert_match(/order_/, data)
    end.respond_with(successful_purchase_response, successful_refund_response)
  end

  def test_purchase_passes_appropriate_request_id_per_call
    request_id = "request_#{(Time.now.to_f.round(2) * 100).to_i}"
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(request_id: request_id))
    end.check_request do |_endpoint, data, _headers|
      if data.include?('payment_method')
        # check for this on the purchase call
        assert_match(/\"request_id\":\"#{request_id}\"/, data)
      else
        # check for this on the create_payment_intent calls
        assert_match(/\"request_id\":\"#{request_id}_setup\"/, data)
      end
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_passes_appropriate_merchant_order_id_per_call
    merchant_order_id = "order_#{(Time.now.to_f.round(2) * 100).to_i}"
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(merchant_order_id: merchant_order_id))
    end.check_request do |_endpoint, data, _headers|
      if data.include?('payment_method')
        # check for this on the purchase call
        assert_match(/\"merchant_order_id\":\"#{merchant_order_id}\"/, data)
      else
        # check for this on the create_payment_intent calls
        assert_match(/\"merchant_order_id\":\"#{merchant_order_id}_setup\"/, data)
      end
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_passes_currency_code
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(currency: 'USD'))
    end.check_request do |_endpoint, data, _headers|
      # only look for currency code on the create_payment_intent request
      assert_match(/USD/, data) if data.include?('_setup')
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_passes_referrer_data
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      # only look for referrer data on the create_payment_intent request
      assert_match(/\"referrer_data\":{\"type\":\"spreedly\"}/, data) if data.include?('_setup')
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_passes_descriptor
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(description: 'a simple test'))
    end.check_request do |_endpoint, data, _headers|
      assert_match(/a simple test/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_invalid_login
    assert_raise ArgumentError do
      AirwallexGateway.new(login: '', password: '')
    end
  end

  def test_successful_cit_with_stored_credential
    auth = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_cit_options }))
    end.check_request do |endpoint, data, _headers|
      # This conditional runs assertions after the initial setup call is made
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"scheduled\"/, data)
        assert_match(/"original_transaction_id\":null,/, data)
        assert_match(/"triggered_by\":\"customer\"/, data)
      end
    end.respond_with(successful_authorize_response)
    assert_success auth
  end

  def test_successful_mit_with_recurring_stored_credential
    auth = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_cit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"scheduled\"/, data)
        assert_match(/"original_transaction_id\":null,/, data)
        assert_match(/"triggered_by\":\"customer\"/, data)
      end
    end.respond_with(successful_authorize_response)
    assert_success auth

    add_cit_network_transaction_id_to_stored_credential(auth)

    purchase = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_mit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"scheduled\"/, data)
        assert_match(/"original_transaction_id\":\"123456789012345\"/, data)
        assert_match(/"triggered_by\":\"merchant\"/, data)
      end
    end.respond_with(successful_purchase_response)
    assert_success purchase
  end

  def test_successful_mit_with_unscheduled_stored_credential
    @stored_credential_cit_options[:reason_type] = 'unscheduled'
    @stored_credential_mit_options[:reason_type] = 'unscheduled'

    auth = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_cit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"unscheduled\"/, data)
        assert_match(/"original_transaction_id\":null,/, data)
        assert_match(/"triggered_by\":\"customer\"/, data)
      end
    end.respond_with(successful_authorize_response)
    assert_success auth

    add_cit_network_transaction_id_to_stored_credential(auth)

    purchase = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_mit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"unscheduled\"/, data)
        assert_match(/"original_transaction_id\":\"123456789012345\"/, data)
        assert_match(/"triggered_by\":\"merchant\"/, data)
      end
    end.respond_with(successful_purchase_response)
    assert_success purchase
  end

  def test_successful_mit_with_installment_stored_credential
    @stored_credential_cit_options[:reason_type] = 'installment'
    @stored_credential_mit_options[:reason_type] = 'installment'

    auth = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_cit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"scheduled\"/, data)
        assert_match(/"original_transaction_id\":null,/, data)
        assert_match(/"triggered_by\":\"customer\"/, data)
      end
    end.respond_with(successful_authorize_response)
    assert_success auth

    add_cit_network_transaction_id_to_stored_credential(auth)

    purchase = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_mit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"scheduled\"/, data)
        assert_match(/"original_transaction_id\":\"123456789012345\"/, data)
        assert_match(/"triggered_by\":\"merchant\"/, data)
      end
    end.respond_with(successful_purchase_response)
    assert_success purchase
  end

  def test_successful_network_transaction_id_override_with_mastercard
    mastercard = credit_card('2223 0000 1018 1375', { brand: 'master' })

    auth = stub_comms do
      @gateway.authorize(@amount, mastercard, @options.merge!({ stored_credential: @stored_credential_cit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"scheduled\"/, data)
        assert_match(/"original_transaction_id\":null,/, data)
        assert_match(/"triggered_by\":\"customer\"/, data)
      end
    end.respond_with(successful_authorize_response)
    assert_success auth

    add_cit_network_transaction_id_to_stored_credential(auth)

    purchase = stub_comms do
      @gateway.purchase(@amount, mastercard, @options.merge!({ stored_credential: @stored_credential_mit_options }))
    end.check_request do |endpoint, data, _headers|
      unless endpoint == setup_endpoint
        assert_match(/"external_recurring_data\"/, data)
        assert_match(/"merchant_trigger_reason\":\"scheduled\"/, data)
        assert_match(/"original_transaction_id\":\"MCC123ABC0101\"/, data)
        assert_match(/"triggered_by\":\"merchant\"/, data)
      end
    end.respond_with(successful_purchase_response)
    assert_success purchase
  end

  def test_failed_mit_with_unapproved_visa_ntid
    @gateway.expects(:ssl_post).returns(failed_ntid_response)
    assert_raise ArgumentError do
      @gateway.authorize(@amount, @credit_card, @options.merge!({ stored_credential: @stored_credential_cit_options }))
    end
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def format_three_ds_version(version)
    version = version.split('.')

    version.push('0') until version.length == 3
    version.join('.')
  end

  private

  def pre_scrubbed
    <<~TRANSCRIPT
      opening connection to api-demo.airwallex.com:443...\nopened\nstarting SSL for api-demo.airwallex.com:443...\nSSL established\n<- \"POST /api/v1/pa/payment_intents/create HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAuthorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxNWU1OGQzOS02MWIxLTQ3NzgtYjkzMC1iZWNiYmY3NmMxZjIiLCJzdWIiOiIxZDcyZmI4MC1hMThlLTQyNGEtODFjMC01NGEwZThiZDQzYTQiLCJpYXQiOjE2NDYxMTAxMjMsImV4cCI6MTY0NjEyMjEyMywiYWNjb3VudF9pZCI6IjBhMWE4NzQ3LWM4M2YtNGUwNC05MGQyLTNjZmFjNDkzNTNkYSIsImRhdGFfY2VudGVyX3JlZ2lvbiI6IkhLIiwidHlwZSI6ImNsaWVudCIsImRjIjoiSEsiLCJpc3NkYyI6IlVTIn0.peXgGLfxzJcAxzDpej5fgJqFDEMraF0gh--8s4sUmis\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: api-demo.airwallex.com\\r\\nContent-Length: 101\\r\\n\\r\\n\"\n<- \"{\\\"amount\\\":\\\"1.00\\\",\\\"currency\\\":\\\"AUD\\\",\\\"request_id\\\":\\\"164611012286\\\",\\\"merchant_order_id\\\":\\\"mid_164611012286\\\"}\"\n-> \"HTTP/1.1 201 Created\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"Content-Length: 618\\r\\n\"\n-> \"Date: Tue, 01 Mar 2022 04:48:44 GMT\\r\\n\"\n-> \"x-awx-traceid: ac5e1e9927434d751368bda3d37b89fb\\r\\n\"\n-> \"vary: Origin,Access-Control-Request-Method,Access-Control-Request-Headers\\r\\n\"\n-> \"x-envoy-upstream-service-time: 82\\r\\n\"\n-> \"x-envoy-decorator-operation: patokeninterceptor.airwallex.svc.cluster.local:80/*\\r\\n\"\n-> \"Server: APISIX\\r\\n\"\n-> \"X-B3-TraceId: ac5e1e9927434d751368bda3d37b89fb\\r\\n\"\n-> \"Via: 1.1 google\\r\\n\"\n-> \"Alt-Svc: h3=\\\":443\\\"; ma=2592000,h3-29=\\\":443\\\"; ma=2592000\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"\\r\\n\"\nreading 618 bytes...\n-> \"{\\\"id\\\":\\\"int_hkdmnnq47g7hwjukwk7\\\",\\\"request_id\\\":\\\"164611012286\\\",\\\"amount\\\":1,\\\"currency\\\":\\\"AUD\\\",\\\"merchant_order_id\\\":\\\"mid_164611012286\\\",\\\"status\\\":\\\"REQUIRES_PAYMENT_METHOD\\\",\\\"captured_amount\\\":0,\\\"created_at\\\":\\\"2022-03-01T04:48:44+0000\\\",\\\"updated_at\\\":\\\"2022-03-01T04:48:44+0000\\\",\\\"available_payment_method_types\\\":[\\\"wechatpay\\\",\\\"card\\\"],\\\"client_secret\\\":\\\"eyJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE2NDYxMTAxMjQsImV4cCI6MTY0NjExMzcyNCwiYWNjb3VudF9pZCI6IjBhMWE4NzQ3LWM4M2YtNGUwNC05MGQyLTNjZmFjNDkzNTNkYSIsImRhdGFfY2VudGVyX3JlZ2lvbiI6IkhLIiwiaW50ZW50X2lkIjoiaW50X2hrZG1ubnE0N2c3aHdqdWt3azciLCJwYWRjIjoiSEsifQ.gjWFNQjss2fW0F_afg_Yx0fku-NhzhgERxT0J0he9wU\\\"}\"\nread 618 bytes\nConn close\nopening connection to api-demo.airwallex.com:443...\nopened\nstarting SSL for api-demo.airwallex.com:443...\nSSL established\n<- \"POST /api/v1/pa/payment_intents/int_hkdmnnq47g7hwjukwk7/confirm HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAuthorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxNWU1OGQzOS02MWIxLTQ3NzgtYjkzMC1iZWNiYmY3NmMxZjIiLCJzdWIiOiIxZDcyZmI4MC1hMThlLTQyNGEtODFjMC01NGEwZThiZDQzYTQiLCJpYXQiOjE2NDYxMTAxMjMsImV4cCI6MTY0NjEyMjEyMywiYWNjb3VudF9pZCI6IjBhMWE4NzQ3LWM4M2YtNGUwNC05MGQyLTNjZmFjNDkzNTNkYSIsImRhdGFfY2VudGVyX3JlZ2lvbiI6IkhLIiwidHlwZSI6ImNsaWVudCIsImRjIjoiSEsiLCJpc3NkYyI6IlVTIn0.peXgGLfxzJcAxzDpej5fgJqFDEMraF0gh--8s4sUmis\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: api-demo.airwallex.com\\r\\nContent-Length: 278\\r\\n\\r\\n\"\n<- \"{\\\"request_id\\\":\\\"164611012286_purchase\\\",\\\"return_url\\\":\\\"https://example.com\\\",\\\"payment_method\\\":{\\\"type\\\":\\\"card\\\",\\\"card\\\":{\\\"expiry_month\\\":\\\"09\\\",\\\"expiry_year\\\":\\\"2023\\\",\\\"number\\\":\\\"4000100011112224\\\",\\\"name\\\":\\\"Longbob Longsen\\\",\\\"cvc\\\":\\\"123\\\",\\\"billing\\\":{\\\"first_name\\\":\\\"Longbob\\\",\\\"last_name\\\":\\\"Longsen\\\"}}}}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"Date: Tue, 01 Mar 2022 04:48:46 GMT\\r\\n\"\n-> \"Vary: Accept-Encoding\\r\\n\"\n-> \"x-awx-traceid: c6bf7d6b1612a8e32c999d3d6ff379a1\\r\\n\"\n-> \"vary: Origin,Access-Control-Request-Method,Access-Control-Request-Headers\\r\\n\"\n-> \"x-envoy-upstream-service-time: 1279\\r\\n\"\n-> \"x-envoy-decorator-operation: patokeninterceptor.airwallex.svc.cluster.local:80/*\\r\\n\"\n-> \"Content-Encoding: gzip\\r\\n\"\n-> \"Server: APISIX\\r\\n\"\n-> \"X-B3-TraceId: c6bf7d6b1612a8e32c999d3d6ff379a1\\r\\n\"\n-> \"Via: 1.1 google\\r\\n\"\n-> \"Alt-Svc: h3=\\\":443\\\"; ma=2592000,h3-29=\\\":443\\\"; ma=2592000\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Transfer-Encoding: chunked\\r\\n\"\n-> \"\\r\\n\"\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x1F\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x8B\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\b\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x03\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\xAC\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"S\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"]\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"o\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\xDA\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"0\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x14\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"000001\\r\\n\"\nreading 1 bytes...\n-> \"\\xFD\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"264\\r\\n\"\nreading 612 bytes...\n-> \"+S^\\xD7jNpB@\\xDAC\\xD5\\xB2\\xAD\\xD2\\xA6U-L\\xDD^\\\"c\\e\\xE2\\x92\\xD8\\xA9?B\\xA1\\xE2\\xBF\\xF7\\xDE\\x04\\x18\\xD5\\xA6i\\x0F}rr?\\x8E\\xCF9\\xF7\\xFA9R\\\"\\x1AGJ\\xFB\\xA2\\\\\\x89Z\\xEBG:\\\\\\x0E\\xCB\\xF5CX\\xADW\\xC3\\xE8,\\xB2\\xF21H\\xE7\\x8B\\xAE,\\xCEh\\x16\\xC7$N\\x92<+\\x9A`y\\xC9\\x9C\\x84\\\"V\\x9B\\xA0}4\\x8E\\xCF\\\"\\x1E\\xAC\\x95\\x9Ao\\xA0\\xFAbv\\x05\\xB9Zb\\x19\\xE0\\e+\\xA4\\xEDqj%\\x8AS,(\\x13\\xD2q\\xAB\\x1Ao,\\xE4\\x85\\\\\\xB0Py\\b;\\xCF|p\\x10\\xBA\\x9B]^N&W\\x13\\x84\\xE4\\xAC\\xF1\\xC1JQ\\x9C\\xDC[1\\x8F4\\e\\xB6\\xA9%\\\\\\xC6\\xBC\\x97u\\x03\\xA9\\xE7^ \\xFCw\\x02\\xE7s\\xAA\\xAB^\\xE0\\xB6\\xCDMq\\xD4y\\x02u\\xC0\\xA8\\xA5/\\x8D8B\\xD4^\\xFC\\x01\\xF1Xm\\xA1\\xD7o\\x1A\\t\\x05\\x9CY\\xD1\\xB1\\xB3]\\x93|j\\x94\\xDD\\x14\\xB5\\xD1\\xBE\\x84,\\x19An\\x1F\\xDBH\\x862\\x13\\x92\\f \\xA8Y\\x8D\\xED_\\x8D^\\xCE\\xCD\\xFC\\x1D\\x9ENjH\\xCC\\x95\\x868%\\x84\\xC4$B\\x89\\xCESlK\\x12\\x8AY\\xCB4\\xF2j\\x95c\\xF0\\xAB\\x9C\\v\\xE0/G\\x19p\\x057\\x02Agw{F\\xC5\\x81$\\xF8\\xA6\\xD0\\xD9\\x85\\xD2Ki\\e\\xABPut}{\\xDF\\x92\\xF6CZ\\xFE\\xA8\\xB2\\xF5\\xE7\\xA7\\xFC\\xD3\\x83\\xBEw7\\xEB{\\xB5Y\\x7FD\\x84\\x96\\x17\\xBC\\x94|\\x05\\xA5\\rs\\xAE#WU\\x00\\x81J\\x17\\xCA\\x82\\xF5\\xAFe\\xEC\\xF9\\x9EFQ\\xD4nw2\\xD3\\xCB\\xDB\\xC9\\xC5\\xB4\\x9F\\xA8\\x950?\\x18\\xA8\\xEFmI\\xCE\\xC9\\xE0\\x9C\\xC4SB\\xC74\\x1FS\\xFA\\x1E<@\\vB#\\xFE\\xA3n\\xF7{\\x86\\xA0\\xAE;\\xFE\\xBD\\xE4GF\\x17\\xB3\\xE9\\x97\\xEF\\xB7\\xD7\\xBF:R\\x8D5\\xAD\\xC2\\x9D\\xF5\\xE0\\xB4c\\xDC+\\xA3{$\\x9A\\xA4\\xA34\\e&C\\n\\xEF \\xA5Y\\x16S\\x92\\xE6y\\x16\\x0FF\\xF9i\\xA3\\xB1j\\xA94\\xAB\\n+]c\\xB4\\x93\\x87\\xB1tbX\\x80\\xFD\\xB2j\\xCB:\\xE0}f0L\\xB3\\xC1\\xE8oKN\\xF01.\\x82\\x16\\xAFcod]z\\xA8s\\xD2\\xFBJ\\x16\\xADb\\xF8l\\x94]\\xB3\\xAA\\x92O{\\xBA\\xE0\\xA5\\xE2=_@c8|\\xE1\\x0E\\x9F`\\xFB\\xC2\\xB2 \\x8E\\xA9\\xDE2\\xB4\\x15\\xDE\\xEE\\xCD\\x14\\xC1\\xB9\\xB1\\xA82\\xC6\\x19\\xB1\\xD6\\xA11\\xF8\\xD0aQ\\xF7[v\\f\\xFC<\\xAC]\\xEF\\xCB\\xB7nu\\xDEV\\xEC\"\n-> \"\\xEE\\x05\\x00\\x00\\xFF\\xFF\\x03\\x00;d\\xC0x\\xFE\\x04\\x00\\x00\"\nread 612 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"0\\r\\n\"\n-> \"\\r\\n\"\nConn close\n
    TRANSCRIPT
  end

  def post_scrubbed
    <<~TRANSCRIPT
      opening connection to api-demo.airwallex.com:443...\nopened\nstarting SSL for api-demo.airwallex.com:443...\nSSL established\n<- \"POST /api/v1/pa/payment_intents/create HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAuthorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxNWU1OGQzOS02MWIxLTQ3NzgtYjkzMC1iZWNiYmY3NmMxZjIiLCJzdWIiOiIxZDcyZmI4MC1hMThlLTQyNGEtODFjMC01NGEwZThiZDQzYTQiLCJpYXQiOjE2NDYxMTAxMjMsImV4cCI6MTY0NjEyMjEyMywiYWNjb3VudF9pZCI6IjBhMWE4NzQ3LWM4M2YtNGUwNC05MGQyLTNjZmFjNDkzNTNkYSIsImRhdGFfY2VudGVyX3JlZ2lvbiI6IkhLIiwidHlwZSI6ImNsaWVudCIsImRjIjoiSEsiLCJpc3NkYyI6IlVTIn0.peXgGLfxzJcAxzDpej5fgJqFDEMraF0gh--8s4sUmis\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: api-demo.airwallex.com\\r\\nContent-Length: 101\\r\\n\\r\\n\"\n<- \"{\\\"amount\\\":\\\"1.00\\\",\\\"currency\\\":\\\"AUD\\\",\\\"request_id\\\":\\\"164611012286\\\",\\\"merchant_order_id\\\":\\\"mid_164611012286\\\"}\"\n-> \"HTTP/1.1 201 Created\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"Content-Length: 618\\r\\n\"\n-> \"Date: Tue, 01 Mar 2022 04:48:44 GMT\\r\\n\"\n-> \"x-awx-traceid: ac5e1e9927434d751368bda3d37b89fb\\r\\n\"\n-> \"vary: Origin,Access-Control-Request-Method,Access-Control-Request-Headers\\r\\n\"\n-> \"x-envoy-upstream-service-time: 82\\r\\n\"\n-> \"x-envoy-decorator-operation: patokeninterceptor.airwallex.svc.cluster.local:80/*\\r\\n\"\n-> \"Server: APISIX\\r\\n\"\n-> \"X-B3-TraceId: ac5e1e9927434d751368bda3d37b89fb\\r\\n\"\n-> \"Via: 1.1 google\\r\\n\"\n-> \"Alt-Svc: h3=\\\":443\\\"; ma=2592000,h3-29=\\\":443\\\"; ma=2592000\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"\\r\\n\"\nreading 618 bytes...\n-> \"{\\\"id\\\":\\\"int_hkdmnnq47g7hwjukwk7\\\",\\\"request_id\\\":\\\"164611012286\\\",\\\"amount\\\":1,\\\"currency\\\":\\\"AUD\\\",\\\"merchant_order_id\\\":\\\"mid_164611012286\\\",\\\"status\\\":\\\"REQUIRES_PAYMENT_METHOD\\\",\\\"captured_amount\\\":0,\\\"created_at\\\":\\\"2022-03-01T04:48:44+0000\\\",\\\"updated_at\\\":\\\"2022-03-01T04:48:44+0000\\\",\\\"available_payment_method_types\\\":[\\\"wechatpay\\\",\\\"card\\\"],\\\"client_secret\\\":\\\"eyJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE2NDYxMTAxMjQsImV4cCI6MTY0NjExMzcyNCwiYWNjb3VudF9pZCI6IjBhMWE4NzQ3LWM4M2YtNGUwNC05MGQyLTNjZmFjNDkzNTNkYSIsImRhdGFfY2VudGVyX3JlZ2lvbiI6IkhLIiwiaW50ZW50X2lkIjoiaW50X2hrZG1ubnE0N2c3aHdqdWt3azciLCJwYWRjIjoiSEsifQ.gjWFNQjss2fW0F_afg_Yx0fku-NhzhgERxT0J0he9wU\\\"}\"\nread 618 bytes\nConn close\nopening connection to api-demo.airwallex.com:443...\nopened\nstarting SSL for api-demo.airwallex.com:443...\nSSL established\n<- \"POST /api/v1/pa/payment_intents/int_hkdmnnq47g7hwjukwk7/confirm HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAuthorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIxNWU1OGQzOS02MWIxLTQ3NzgtYjkzMC1iZWNiYmY3NmMxZjIiLCJzdWIiOiIxZDcyZmI4MC1hMThlLTQyNGEtODFjMC01NGEwZThiZDQzYTQiLCJpYXQiOjE2NDYxMTAxMjMsImV4cCI6MTY0NjEyMjEyMywiYWNjb3VudF9pZCI6IjBhMWE4NzQ3LWM4M2YtNGUwNC05MGQyLTNjZmFjNDkzNTNkYSIsImRhdGFfY2VudGVyX3JlZ2lvbiI6IkhLIiwidHlwZSI6ImNsaWVudCIsImRjIjoiSEsiLCJpc3NkYyI6IlVTIn0.peXgGLfxzJcAxzDpej5fgJqFDEMraF0gh--8s4sUmis\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: api-demo.airwallex.com\\r\\nContent-Length: 278\\r\\n\\r\\n\"\n<- \"{\\\"request_id\\\":\\\"164611012286_purchase\\\",\\\"return_url\\\":\\\"https://example.com\\\",\\\"payment_method\\\":{\\\"type\\\":\\\"card\\\",\\\"card\\\":{\\\"expiry_month\\\":\\\"09\\\",\\\"expiry_year\\\":\\\"2023\\\",\\\"number\\\":\\\"[REDACTED]\\\",\\\"name\\\":\\\"Longbob Longsen\\\",\\\"cvc\\\":\\\"[REDACTED]\\\",\\\"billing\\\":{\\\"first_name\\\":\\\"Longbob\\\",\\\"last_name\\\":\\\"Longsen\\\"}}}}\"\n-> \"HTTP/1.1 200 OK\\r\\n\"\n-> \"Content-Type: application/json\\r\\n\"\n-> \"Date: Tue, 01 Mar 2022 04:48:46 GMT\\r\\n\"\n-> \"Vary: Accept-Encoding\\r\\n\"\n-> \"x-awx-traceid: c6bf7d6b1612a8e32c999d3d6ff379a1\\r\\n\"\n-> \"vary: Origin,Access-Control-Request-Method,Access-Control-Request-Headers\\r\\n\"\n-> \"x-envoy-upstream-service-time: 1279\\r\\n\"\n-> \"x-envoy-decorator-operation: patokeninterceptor.airwallex.svc.cluster.local:80/*\\r\\n\"\n-> \"Content-Encoding: gzip\\r\\n\"\n-> \"Server: APISIX\\r\\n\"\n-> \"X-B3-TraceId: c6bf7d6b1612a8e32c999d3d6ff379a1\\r\\n\"\n-> \"Via: 1.1 google\\r\\n\"\n-> \"Alt-Svc: h3=\\\":443\\\"; ma=2592000,h3-29=\\\":443\\\"; ma=2592000\\r\\n\"\n-> \"Connection: close\\r\\n\"\n-> \"Transfer-Encoding: chunked\\r\\n\"\n-> \"\\r\\n\"\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x1F\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x8B\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\b\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x00\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x03\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\xAC\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"S\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"]\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"o\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\xDA\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"0\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"00000001\\r\\n\"\nreading 1 bytes...\n-> \"\\x14\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"000001\\r\\n\"\nreading 1 bytes...\n-> \"\\xFD\"\nread 1 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"264\\r\\n\"\nreading 612 bytes...\n-> \"+S^\\xD7jNpB@\\xDAC\\xD5\\xB2\\xAD\\xD2\\xA6U-L\\xDD^\\\"c\\e\\xE2\\x92\\xD8\\xA9?B\\xA1\\xE2\\xBF\\xF7\\xDE\\x04\\x18\\xD5\\xA6i\\x0F}rr?\\x8E\\xCF9\\xF7\\xFA9R\\\"\\x1AGJ\\xFB\\xA2\\\\\\x89Z\\xEBG:\\\\\\x0E\\xCB\\xF5CX\\xADW\\xC3\\xE8,\\xB2\\xF21H\\xE7\\x8B\\xAE,\\xCEh\\x16\\xC7$N\\x92<+\\x9A`y\\xC9\\x9C\\x84\\\"V\\x9B\\xA0}4\\x8E\\xCF\\\"\\x1E\\xAC\\x95\\x9Ao\\xA0\\xFAbv\\x05\\xB9Zb\\x19\\xE0\\e+\\xA4\\xEDqj%\\x8AS,(\\x13\\xD2q\\xAB\\x1Ao,\\xE4\\x85\\\\\\xB0Py\\b;\\xCF|p\\x10\\xBA\\x9B]^N&W\\x13\\x84\\xE4\\xAC\\xF1\\xC1JQ\\x9C\\xDC[1\\x8F4\\e\\xB6\\xA9%\\\\\\xC6\\xBC\\x97u\\x03\\xA9\\xE7^ \\xFCw\\x02\\xE7s\\xAA\\xAB^\\xE0\\xB6\\xCDMq\\xD4y\\x02u\\xC0\\xA8\\xA5/\\x8D8B\\xD4^\\xFC\\x01\\xF1Xm\\xA1\\xD7o\\x1A\\t\\x05\\x9CY\\xD1\\xB1\\xB3]\\x93|j\\x94\\xDD\\x14\\xB5\\xD1\\xBE\\x84,\\x19An\\x1F\\xDBH\\x862\\x13\\x92\\f \\xA8Y\\x8D\\xED_\\x8D^\\xCE\\xCD\\xFC\\x1D\\x9ENjH\\xCC\\x95\\x868%\\x84\\xC4$B\\x89\\xCESlK\\x12\\x8AY\\xCB4\\xF2j\\x95c\\xF0\\xAB\\x9C\\v\\xE0/G\\x19p\\x057\\x02Agw{F\\xC5\\x81$\\xF8\\xA6\\xD0\\xD9\\x85\\xD2Ki\\e\\xABPut}{\\xDF\\x92\\xF6CZ\\xFE\\xA8\\xB2\\xF5\\xE7\\xA7\\xFC\\xD3\\x83\\xBEw7\\xEB{\\xB5Y\\x7FD\\x84\\x96\\x17\\xBC\\x94|\\x05\\xA5\\rs\\xAE#WU\\x00\\x81J\\x17\\xCA\\x82\\xF5\\xAFe\\xEC\\xF9\\x9EFQ\\xD4nw2\\xD3\\xCB\\xDB\\xC9\\xC5\\xB4\\x9F\\xA8\\x950?\\x18\\xA8\\xEFmI\\xCE\\xC9\\xE0\\x9C\\xC4SB\\xC74\\x1FS\\xFA\\x1E<@\\vB#\\xFE\\xA3n\\xF7{\\x86\\xA0\\xAE;\\xFE\\xBD\\xE4GF\\x17\\xB3\\xE9\\x97\\xEF\\xB7\\xD7\\xBF:R\\x8D5\\xAD\\xC2\\x9D\\xF5\\xE0\\xB4c\\xDC+\\xA3{$\\x9A\\xA4\\xA34\\e&C\\n\\xEF \\xA5Y\\x16S\\x92\\xE6y\\x16\\x0FF\\xF9i\\xA3\\xB1j\\xA94\\xAB\\n+]c\\xB4\\x93\\x87\\xB1tbX\\x80\\xFD\\xB2j\\xCB:\\xE0}f0L\\xB3\\xC1\\xE8oKN\\xF01.\\x82\\x16\\xAFcod]z\\xA8s\\xD2\\xFBJ\\x16\\xADb\\xF8l\\x94]\\xB3\\xAA\\x92O{\\xBA\\xE0\\xA5\\xE2=_@c8|\\xE1\\x0E\\x9F`\\xFB\\xC2\\xB2 \\x8E\\xA9\\xDE2\\xB4\\x15\\xDE\\xEE\\xCD\\x14\\xC1\\xB9\\xB1\\xA82\\xC6\\x19\\xB1\\xD6\\xA11\\xF8\\xD0aQ\\xF7[v\\f\\xFC<\\xAC]\\xEF\\xCB\\xB7nu\\xDEV\\xEC\"\n-> \"\\xEE\\x05\\x00\\x00\\xFF\\xFF\\x03\\x00;d\\xC0x\\xFE\\x04\\x00\\x00\"\nread 612 bytes\nreading 2 bytes...\n-> \"\\r\\n\"\nread 2 bytes\n-> \"0\\r\\n\"\n-> \"\\r\\n\"\nConn close\n
    TRANSCRIPT
  end

  def successful_payment_intent_response
    %(
      {"id":"int_hkdmvldq5g8h5qequao","request_id":"164887285684","amount":1,"currency":"AUD","merchant_order_id":"mid_164887285684","status":"REQUIRES_PAYMENT_METHOD","captured_amount":0,"created_at":"2022-04-02T04:14:17+0000","updated_at":"2022-04-02T04:14:17+0000","available_payment_method_types":["wechatpay","card"],"client_secret":"eyJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE2NDg4NzI4NTcsImV4cCI6MTY0ODg3NjQ1NywiYWNjb3VudF9pZCI6IjBhMWE4NzQ3LWM4M2YtNGUwNC05MGQyLTNjZmFjNDkzNTNkYSIsImRhdGFfY2VudGVyX3JlZ2lvbiI6IkhLIiwiaW50ZW50X2lkIjoiaW50X2hrZG12bGRxNWc4aDVxZXF1YW8iLCJwYWRjIjoiSEsiLCJidXNpbmVzc19uYW1lIjoiU3ByZWVkbHkgRGVtbyBBY2NvdW50In0.kcaBXnCAsIinOUw6iJ0tyTOa3Mv03JsuoyLZWWbmNnI"}
    )
  end

  def successful_purchase_response
    %(
      {"id":"int_hkdmtp6bpg79nn35u43","request_id":"164546381445_purchase","amount":1,"currency":"AUD","merchant_order_id":"mid_164546381445","descriptor":"default","status":"SUCCEEDED","captured_amount":1,"latest_payment_attempt":{"id":"att_hkdmb6rw6g79nn3k7ld_n35u43","amount":1,"payment_method":{"id":"mtd_hkdmb6rw6g79nn3k7lc","type":"card","card":{"expiry_month":"09","expiry_year":"2023","name":"Longbob Longsen","bin":"400010","last4":"2224","brand":"visa","issuer_country_code":"US","card_type":"credit","fingerprint":"IRXv0v/5hVl6wGx8FjnXsPwXiyw=","cvc_check":"pass","billing":{"first_name":"Longbob","last_name":"Longsen"}},"status":"CREATED","created_at":"2022-02-21T17:16:56+0000","updated_at":"2022-02-21T17:16:56+0000"},"payment_intent_id":"int_hkdmtp6bpg79nn35u43","status":"AUTHORIZED","provider_transaction_id":"184716548151_265868712794696","provider_original_response_code":"00","authorization_code":"803478","captured_amount":0,"refunded_amount":0,"created_at":"2022-02-21T17:16:56+0000","updated_at":"2022-02-21T17:16:57+0000","settle_via":"airwallex","authentication_data":{"ds_data":{},"fraud_data":{"action":"ACCEPT","score":"1"},"avs_result":"U","cvc_result":"Y","cvc_code":"M"}},"created_at":"2022-02-21T17:16:55+0000","updated_at":"2022-02-21T17:16:57+0000"}
      )
  end

  def failed_purchase_response
    %({"code":"issuer_declined","message":"The card issuer declined this transaction. Please refer to the original response code.","provider_original_response_code":"14"})
  end

  def successful_authorize_response
    %({"id":"int_hkdmtp6bpg79nqimh2z","request_id":"164546402207_purchase","amount":1,"currency":"AUD","merchant_order_id":"mid_164546402207","descriptor":"default","status":"REQUIRES_CAPTURE","captured_amount":0,"latest_payment_attempt":{"id":"att_hkdmtp6bpg79nqj30rk_qimh2z","amount":1,"payment_method":{"id":"mtd_hkdmtp6bpg79nqj30rj","type":"card","card":{"expiry_month":"09","expiry_year":"2023","name":"Longbob Longsen","bin":"400010","last4":"2224","brand":"visa","issuer_country_code":"US","card_type":"credit","fingerprint":"IRXv0v/5hVl6wGx8FjnXsPwXiyw=","cvc_check":"pass","billing":{"first_name":"Longbob","last_name":"Longsen"}},"status":"CREATED","created_at":"2022-02-21T17:20:23+0000","updated_at":"2022-02-21T17:20:23+0000"},"payment_intent_id":"int_hkdmtp6bpg79nqimh2z","status":"AUTHORIZED","provider_transaction_id":"648365447295_129943849335300","provider_original_response_code":"00","authorization_code":"676405","captured_amount":0,"refunded_amount":0,"created_at":"2022-02-21T17:20:23+0000","updated_at":"2022-02-21T17:20:24+0000","settle_via":"airwallex","authentication_data":{"ds_data":{},"fraud_data":{"action":"ACCEPT","score":"1"},"avs_result":"U","cvc_result":"Y","cvc_code":"M"}},"created_at":"2022-02-21T17:20:22+0000","updated_at":"2022-02-21T17:20:24+0000"})
  end

  def failed_authorize_response
    %({"code":"issuer_declined","message":"The card issuer declined this transaction. Please refer to the original response code.","provider_original_response_code":"14"})
  end

  def successful_capture_response
    %({"id":"int_hkdmtp6bpg79nqimh2z","request_id":"164546402207_purchase_capture","amount":1,"currency":"AUD","merchant_order_id":"mid_164546402207","descriptor":"default","status":"SUCCEEDED","captured_amount":1,"latest_payment_attempt":{"id":"att_hkdmtp6bpg79nqj30rk_qimh2z","amount":1,"payment_method":{"id":"mtd_hkdmtp6bpg79nqj30rj","type":"card","card":{"expiry_month":"09","expiry_year":"2023","name":"Longbob Longsen","bin":"400010","last4":"2224","brand":"visa","issuer_country_code":"US","card_type":"credit","fingerprint":"IRXv0v/5hVl6wGx8FjnXsPwXiyw=","cvc_check":"pass","billing":{"first_name":"Longbob","last_name":"Longsen"}},"status":"CREATED","created_at":"2022-02-21T17:20:23+0000","updated_at":"2022-02-21T17:20:23+0000"},"payment_intent_id":"int_hkdmtp6bpg79nqimh2z","status":"CAPTURE_REQUESTED","provider_transaction_id":"648365447295_129943849335300","provider_original_response_code":"00","authorization_code":"676405","captured_amount":1,"refunded_amount":0,"created_at":"2022-02-21T17:20:23+0000","updated_at":"2022-02-21T17:20:25+0000","settle_via":"airwallex","authentication_data":{"ds_data":{},"fraud_data":{"action":"ACCEPT","score":"1"},"avs_result":"U","cvc_result":"Y","cvc_code":"M"}},"created_at":"2022-02-21T17:20:22+0000","updated_at":"2022-02-21T17:20:25+0000"})
  end

  def failed_capture_response
    %({"code":"not_found","message":"The requested endpoint does not exist [/api/v1/pa/payment_intents/12345/capture]"})
  end

  def successful_refund_response
    %({"id":"rfd_hkdmb6rw6g79o84j2nr_82v60s","request_id":"164546508364_purchase_refund","payment_intent_id":"int_hkdmb6rw6g79o82v60s","payment_attempt_id":"att_hkdmtp6bpg79o839j89_82v60s","amount":1,"currency":"AUD","status":"RECEIVED","created_at":"2022-02-21T17:38:07+0000","updated_at":"2022-02-21T17:38:07+0000"})
  end

  def failed_refund_response
    %({"code":"resource_not_found","message":"The PaymentIntent with ID 12345 cannot be found."})
  end

  def successful_void_response
    %({"id":"int_hkdm49cp4g7d5njedty","request_id":"164573811628_purchase_void","amount":1,"currency":"AUD","merchant_order_id":"mid_164573811628","descriptor":"default","status":"CANCELLED","captured_amount":0,"latest_payment_attempt":{"id":"att_hkdm8kd2fg7d5njty2v_njedty","amount":1,"payment_method":{"id":"mtd_hkdm8kd2fg7d5njtxb2","type":"card","card":{"expiry_month":"09","expiry_year":"2023","name":"Longbob Longsen","bin":"400010","last4":"2224","brand":"visa","issuer_country_code":"US","card_type":"credit","fingerprint":"IRXv0v/5hVl6wGx8FjnXsPwXiyw=","cvc_check":"pass","billing":{"first_name":"Longbob","last_name":"Longsen"}},"status":"CREATED","created_at":"2022-02-24T21:28:38+0000","updated_at":"2022-02-24T21:28:38+0000"},"payment_intent_id":"int_hkdm49cp4g7d5njedty","status":"CANCELLED","provider_transaction_id":"157857893548_031662842463902","provider_original_response_code":"00","authorization_code":"775572","captured_amount":0,"refunded_amount":0,"created_at":"2022-02-24T21:28:38+0000","updated_at":"2022-02-24T21:28:40+0000","settle_via":"airwallex","authentication_data":{"ds_data":{},"fraud_data":{"action":"ACCEPT","score":"1"},"avs_result":"U","cvc_result":"Y","cvc_code":"M"}},"created_at":"2022-02-24T21:28:37+0000","updated_at":"2022-02-24T21:28:40+0000","cancelled_at":"2022-02-24T21:28:40+0000"})
  end

  def failed_void_response
    %({"code":"not_found","message":"The requested endpoint does not exist [/api/v1/pa/payment_intents/12345/cancel]"})
  end

  def failed_ntid_response
    %({"code":"validation_error","source":"external_recurring_data.original_transaction_id","message":"external_recurring_data.original_transaction_id should be 13-15 characters long"})
  end

  def add_cit_network_transaction_id_to_stored_credential(auth)
    @stored_credential_mit_options[:network_transaction_id] = auth.params['latest_payment_attempt']['provider_transaction_id']
  end

  def setup_endpoint
    'https://api-demo.airwallex.com/api/v1/pa/payment_intents/create'
  end
end
