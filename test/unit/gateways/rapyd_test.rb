require 'test_helper'

class RapydTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = RapydGateway.new(secret_key: 'secret_key', access_key: 'access_key')
    @gateway_payment_redirect = RapydGateway.new(secret_key: 'secret_key', access_key: 'access_key', url_override: 'payment_redirect')
    @credit_card = credit_card
    @check = check
    @amount = 100
    @authorization = 'cus_9e1b5a357b2b7f25f8dd98827fbc4f22|card_cf105df9e77462deb34ffef33c3e3d05'

    @options = {
      pm_type: 'in_amex_card',
      currency: 'USD',
      complete_payment_url: 'www.google.com',
      error_payment_url: 'www.google.com',
      description: 'Describe this transaction',
      statement_descriptor: 'Statement Descriptor',
      email: 'test@example.com',
      billing_address: address(name: 'Jim Reynolds'),
      order_id: '987654321',
      idempotency_key: '123'
    }

    @metadata = {
      array_of_objects: [
        { name: 'John Doe' },
        { type: 'customer' }
      ],
      array_of_strings: %w[
        color
        size
      ],
      number: 1234567890,
      object: {
        string: 'person'
      },
      string: 'preferred',
      Boolean: true
    }

    @ewallet_id = 'ewallet_1a867a32b47158b30a8c17d42f12f3f1'

    @address_object = address(line_1: '123 State Street', line_2: 'Apt. 34', phone_number: '12125559999')
  end

  def test_request_headers_building
    @options.merge!(idempotency_key: '123')

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, _data, headers|
      assert_equal 'application/json', headers['Content-Type']
      assert_equal '123', headers['idempotency']
      assert_equal 'access_key', headers['access_key']
      assert headers['salt']
      assert headers['signature']
      assert headers['timestamp']
    end
  end

  def test_successful_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(billing_address: address(name: 'Joe John-ston')))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_equal JSON.parse(data)['address']['name'], 'Joe John-ston'
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'payment_716ce0efc63aa8d91579e873d29d9d5e', response.authorization.split('|')[0]
  end

  def test_successful_purchase_without_address
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(billing_address: { phone_number: '12125559999' }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_equal JSON.parse(data)['phone_number'], '12125559999'
      assert_nil JSON.parse(data)['address']
      assert_nil JSON.parse(data)['customer']['addresses']
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'payment_716ce0efc63aa8d91579e873d29d9d5e', response.authorization.split('|')[0]
  end

  def test_send_month_and_year_with_two_digits
    credit_card = credit_card('4242424242424242', month: '9', year: '30')
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      assert_match(/"number":"4242424242424242","expiration_month":"09","expiration_year":"30","name":"Longbob Longsen/, data)
    end
  end

  def test_successful_purchase_without_cvv
    @credit_card.verification_value = nil
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"number":"4242424242424242","expiration_month":"09","expiration_year":"#{(Time.now.year + 1).to_s.slice(-2, 2)}","name":"Longbob Longsen/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
    assert_equal 'payment_716ce0efc63aa8d91579e873d29d9d5e', response.authorization.split('|')[0]
  end

  def test_successful_purchase_with_ach
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @check, @options.merge(billing_address: address(name: 'Joe John-ston')))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_nil JSON.parse(data)['capture']
    end.respond_with(successful_ach_purchase_response)

    assert_success response
    assert_equal 'ACT', response.params['data']['status']
  end

  def test_successful_purchase_with_token
    @options[:customer_id] = 'cus_9e1b5a357b2b7f25f8dd98827fbc4f22'
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @authorization, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['payment_method'], @authorization.split('|')[1]
      assert_equal request['customer'], @options[:customer_id]
    end.respond_with(successful_purchase_with_options_response)

    assert_success response
    assert_equal @metadata, response.params['data']['metadata'].deep_transform_keys(&:to_sym)
  end

  def test_successful_purchase_with_payment_options
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"complete_payment_url":"www.google.com"/, data)
      assert_match(/"error_payment_url":"www.google.com"/, data)
      assert_match(/"description":"Describe this transaction"/, data)
      assert_match(/"statement_descriptor":"Statement Descriptor"/, data)
      assert_match(/"merchant_reference_id":"987654321"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_purchase_with_explicit_merchant_reference_id
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ merchant_reference_id: '99988877776' }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"complete_payment_url":"www.google.com"/, data)
      assert_match(/"error_payment_url":"www.google.com"/, data)
      assert_match(/"description":"Describe this transaction"/, data)
      assert_match(/"statement_descriptor":"Statement Descriptor"/, data)
      assert_match(/"merchant_reference_id":"99988877776"/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credential
    @options[:stored_credential] = {
      reason_type: 'recurring',
      network_transaction_id: '12345'
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['payment_method']['fields']['network_reference_id'], @options[:stored_credential][:network_transaction_id]
      assert_equal request['initiation_type'], @options[:stored_credential][:reason_type]
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_network_transaction_id_and_initiation_type_fields
    @options[:network_transaction_id] = '54321'
    @options[:initiation_type] = 'customer_present'

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['payment_method']['fields']['network_reference_id'], @options[:network_transaction_id]
      assert_equal request['initiation_type'], @options[:initiation_type]
    end.respond_with(successful_purchase_response)
  end

  def test_success_purchase_with_recurrence_type
    @options[:recurrence_type] = 'recurring'

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['payment_method']['fields']['recurrence_type'], @options[:recurrence_type]
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_save_payment_method
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ save_payment_method: true }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"save_payment_method":true/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_purchase_with_3ds_global
    @options[:three_d_secure] = {
      required: true,
      version: '2.1.0'
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['payment_method_options']['3d_required'], true
      assert_equal request['payment_method_options']['3d_version'], '2.1.0'
      assert request['complete_payment_url']
      assert request['error_payment_url']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_3ds_gateway_specific
    @options.merge!(execute_threed: true, force_3d_secure: true)

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['payment_method_options']['3d_required'], true
      assert_nil request['payment_method_options']['3d_version']
    end.respond_with(successful_purchase_response)
  end

  def test_does_not_send_3ds_version_if_not_required
    false_values = [false, nil, 'false', '']
    @options[:execute_threed] = true

    false_values.each do |value|
      @options[:force_3d_secure] = value

      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, @credit_card, @options)
      end.check_request do |_method, _endpoint, data, _headers|
        request = JSON.parse(data)
        assert_nil request['payment_method_options']
      end.respond_with(successful_purchase_response)
    end
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'ERROR_PROCESSING_CARD - [05]', response.error_code
  end

  def test_successful_authorize
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, _data, headers|
      assert_equal '123', headers['idempotency']
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Do Not Honor', response.message
  end

  def test_successful_capture
    transaction_id = 'payment_e0979a1c6843e5d7bf0c18335794cccb'
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, transaction_id, @options)
    end.check_request do |_method, _endpoint, _data, headers|
      assert_equal '123', headers['idempotency']
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal 'The request tried to retrieve a payment, but the payment was not found. The request was rejected. Corrective action: Use a valid payment ID.', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)
    transaction_id = 'refund_2a575991bee3b010f44e438f7f6a6d5f'

    response = @gateway.refund(@amount, transaction_id, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_equal 'The request tried to retrieve a payment, but the payment was not found. The request was rejected. Corrective action: Use a valid payment ID.', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    authorization = 'payment_a29a73f09d6f55defddc779dbb2d1089'

    response = @gateway.void(authorization)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
    assert_equal 'UNAUTHORIZED_API_CALL', response.message
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.check_request do |_method, _endpoint, _data, headers|
      assert_equal '123', headers['idempotency']
    end.respond_with(successful_verify_response)

    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal 'Do Not Honor', response.message
  end

  def test_successful_store_and_unstore
    store = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.check_request do |_method, _endpoint, _data, headers|
      assert_match '123', headers['idempotency']
    end.respond_with(successful_store_response)

    assert_success store
    assert customer_id = store.params.dig('data', 'id')

    unstore = stub_comms(@gateway, :ssl_request) do
      @gateway.unstore(store.authorization)
    end.respond_with(successful_unstore_response)

    assert_success unstore
    assert_equal true, unstore.params.dig('data', 'deleted')
    assert_equal customer_id, unstore.params.dig('data', 'id')
  end

  def test_unstore
    stub_comms(@gateway, :ssl_request) do
      @gateway.unstore('123456')
    end.check_request do |_method, _endpoint, _data, headers|
      assert_not_match '123', headers['idempotency']
    end.respond_with(successful_unstore_response)
  end

  def test_send_receipt_email_and_customer_id_for_purchase
    store = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.respond_with(successful_store_response)

    assert customer_id = store.params.dig('data', 'id')
    assert card_id = store.params.dig('data', 'default_payment_method')

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, store.authorization, @options.merge(customer_id:))
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['receipt_email'], @options[:email]
      assert_equal request['customer'], customer_id
      assert_equal request['payment_method'], card_id
    end.respond_with(successful_purchase_response)
  end

  def test_send_email_with_customer_object_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request_body = JSON.parse(data)
      assert request_body['customer']
      assert_equal request_body['customer']['email'], @options[:email]
    end
  end

  def test_failed_purchase_without_customer_object
    @options[:pm_type] = 'us_debit_visa_card'
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'ERROR_PROCESSING_CARD - [05]', response.params['status']['error_code']
  end

  def test_successful_purchase_with_customer_object
    stub_comms(@gateway, :ssl_request) do
      @options[:pm_type] = 'us_debit_mastercard_card'
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      assert_match(/"name":"Jim Reynolds"/, data)
      assert_match(/"email":"test@example.com"/, data)
      assert_match(/"phone_number":"5555555555"/, data)
      assert_match(/"customer":/, data)
    end
  end

  def test_successful_purchase_with_billing_address_phone_variations
    stub_comms(@gateway, :ssl_request) do
      @options[:pm_type] = 'us_debit_mastercard_card'
      @gateway.purchase(@amount, @credit_card, { billing_address: { phone_number: '919.123.1234' } })
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      assert_match(/"phone_number":"9191231234"/, data)
    end

    stub_comms(@gateway, :ssl_request) do
      @options[:pm_type] = 'us_debit_mastercard_card'
      @gateway.purchase(@amount, @credit_card, { billing_address: { phone: '919.123.1234' } })
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      assert_match(/"phone_number":"9191231234"/, data)
    end
  end

  def test_successful_store_with_customer_object
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"name":"Jim Reynolds"/, data)
      assert_match(/"email":"test@example.com"/, data)
      assert_match(/"phone_number":"5555555555"/, data)
    end.respond_with(successful_store_response)

    assert_success response
  end

  def test_payment_urls_correctly_nested_by_operation
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request_body = JSON.parse(data)
      assert_equal @options[:complete_payment_url], request_body['payment_method']['complete_payment_url']
      assert_equal @options[:error_payment_url], request_body['payment_method']['error_payment_url']
    end.respond_with(successful_store_response)

    assert_success response

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request_body = JSON.parse(data)
      assert_equal @options[:complete_payment_url], request_body['complete_payment_url']
      assert_equal @options[:error_payment_url], request_body['error_payment_url']
    end.respond_with(successful_store_response)

    assert_success response
  end

  def test_purchase_with_customer_and_card_id
    store = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.respond_with(successful_store_response)

    assert customer_id = store.params.dig('data', 'id')
    assert card_id = store.params.dig('data', 'default_payment_method')

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, store.authorization, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request_body = JSON.parse(data)
      assert_equal request_body['customer'], customer_id
      assert_equal request_body['payment_method'], card_id
    end.respond_with(successful_purchase_response)
  end

  def test_three_d_secure
    options = {
      three_d_secure: {
        cavv: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
        eci: '5',
        xid: 'TTBCSkVTa1ZpbDI1bjRxbGk5ODE='
      }
    }

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"cavv":"EHuWW9PiBkWvqE5juRwDzAUFBAk="/, data)
      assert_match(/"eci":"5"/, data)
      assert_match(/"xid":"TTBCSkVTa1ZpbDI1bjRxbGk5ODE="/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_not_send_cvv_with_empty_value
    @credit_card.verification_value = ''
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['payment_method']['fields']['cvv']
    end
  end

  def test_not_send_cvv_with_nil_value
    @credit_card.verification_value = nil
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['payment_method']['fields']['cvv']
    end
  end

  def test_not_send_cvv_for_recurring_transactions
    @options[:stored_credential] = {
      reason_type: 'recurring',
      network_transaction_id: '12345'
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['payment_method']['fields']['cvv']
    end
  end

  def test_not_send_network_reference_id_for_recurring_transactions
    @options[:stored_credential] = {
      reason_type: 'recurring',
      network_transaction_id: nil
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['payment_method']['fields']['network_reference_id']
    end
  end

  def test_not_send_customer_object_for_recurring_transactions
    @options[:stored_credential] = {
      reason_type: 'recurring',
      network_transaction_id: '12345'
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['customer']
    end
  end

  def test_successful_purchase_for_payment_redirect_url
    @gateway_payment_redirect.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway_payment_redirect.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_use_proper_url_for_payment_redirect_url
    url = @gateway_payment_redirect.send(:url, 'payments', 'payment_redirect')
    assert_equal url, 'https://sandboxpayment-redirect.rapyd.net/v1/payments'
  end

  def test_use_proper_url_for_default_url
    url = @gateway_payment_redirect.send(:url, 'payments')
    assert_equal url, 'https://sandboxapi.rapyd.net/v1/payments'
  end

  def test_wrong_url_for_payment_redirect_url
    url = @gateway_payment_redirect.send(:url, 'refund', 'payment_redirect')
    assert_no_match %r{https://sandboxpayment-redirect.rapyd.net/v1/}, url
  end

  def test_add_extra_fields_for_fx_transactions
    @options[:requested_currency] = 'EUR'
    @options[:fixed_side] = 'buy'

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'EUR', request['requested_currency']
      assert_equal 'buy', request['fixed_side']
    end
  end

  def test_not_add_extra_fields_for_non_fx_transactions
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['requested_currency']
      assert_nil request['fixed_side']
    end
  end

  def test_implicit_expire_unix_time
    @options[:requested_currency] = 'EUR'
    @options[:fixed_side] = 'buy'

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_in_delta 7.to_i.days.from_now.to_i, request['expiration'], 60
    end
  end

  def test_sending_explicitly_expire_time
    @options[:requested_currency] = 'EUR'
    @options[:fixed_side] = 'buy'
    @options[:expiration_days] = 2

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_in_delta @options[:expiration_days].to_i.days.from_now.to_i, request['expiration'], 60
    end
  end

  def test_handling_500_errors
    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(response_500)

    assert_failure response
    assert_equal 'some_error_message', response.message
    assert_equal 'ERROR_PAYMENT_METHODS_GET', response.error_code
  end

  def test_handling_500_errors_with_blank_message
    response_without_message = response_500
    response_without_message.body = response_without_message.body.gsub('some_error_message', '')

    response = stub_comms(@gateway, :raw_ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(response_without_message)

    assert_failure response
    assert_equal 'ERROR_PAYMENT_METHODS_GET', response.message
    assert_equal 'ERROR_PAYMENT_METHODS_GET', response.error_code
  end

  def test_version_functionality
    # Test that version is set correctly
    assert_equal 'v1', @gateway.fetch_version

    # Test that URLs are built with correct version
    assert_equal 'https://sandboxapi.rapyd.net/v1/', @gateway.test_url
    assert_equal 'https://api.rapyd.net/v1/', @gateway.live_url
    assert_equal 'https://sandboxpayment-redirect.rapyd.net/v1/', @gateway.payment_redirect_test
    assert_equal 'https://payment-redirect.rapyd.net/v1/', @gateway.payment_redirect_live

    # Test that commit method uses version in relative path
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, _data, _headers|
      # Verify the request was made to the correct versioned URL
      assert_match %r{/v1/payments$}, endpoint
    end.respond_with(successful_purchase_response)

    # Test that headers method receives correct versioned relative path
    rel_path = @gateway.send(:headers, 'post/v1/payments', '{}')
    assert rel_path.has_key?('signature')
    assert rel_path.has_key?('access_key')
  end

  private

  def response_500
    OpenStruct.new(
      code: 500,
      body:  {
        status: {
          error_code: 'ERROR_PAYMENT_METHODS_GET',
          status: 'ERROR',
          message: 'some_error_message',
          response_code: 'ERROR_PAYMENT_METHODS_GET',
          operation_id: '77703d8c-6636-48fc-bc2f-1154b5d29857'
        }
      }.to_json
    )
  end

  def pre_scrubbed
    '
    opening connection to sandboxapi.rapyd.net:443...
    opened
    starting SSL for sandboxapi.rapyd.net:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
    <- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json\r\nAccess_key: A6E93651174B48E0EF1E\r\nSalt: +3mM6dOjHsOwF/VQ\r\nTimestamp: 1647870006\r\nSignature: YjY4NTA1NDY3ZTUxMWUyNzk0NjFkOTJhZjIwYWUzZTA5YzYyMzUzZDE1ZjY2NWFmM2NhZTlmZDY2ZDZjNjEwYQ==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandboxapi.rapyd.net\r\nContent-Length: 212\r\n\r\n"
    <- "{\"amount\":\"1.0\",\"currency\":\"USD\",\"payment_method\":{\"type\":\"in_amex_card\",\"fields\":{\"number\":\"4111111111111111\",\"expiration_month\":\"12\",\"expiration_year\":\"2035\",\"cvv\":\"345\",\"name\":\"Ryan Reynolds\"}},\"capture\":true}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Mon, 21 Mar 2022 13:40:08 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "Connection: close\r\n"
    -> "Vary: X-HTTP-Method-Override, Accept-Encoding\r\n"
    -> "Strict-Transport-Security: max-age=8640000; includeSubDomains\r\n"
    -> "ETag: W/\"7d1-tsdr4eAZn2y+2my4kMxz2w\"\r\n"
    -> "Content-Encoding: gzip\r\n"
    -> "\r\n"
    -> "a\r\n"
    -> "0\r\n"
    -> "\r\n"
    Conn close
    '
  end

  def post_scrubbed
    '
    opening connection to sandboxapi.rapyd.net:443...
    opened
    starting SSL for sandboxapi.rapyd.net:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
    <- "POST /v1/payments HTTP/1.1\r\nContent-Type: application/json\r\nAccess_key: [FILTERED]\r\nSalt: +3mM6dOjHsOwF/VQ\r\nTimestamp: 1647870006\r\nSignature: YjY4NTA1NDY3ZTUxMWUyNzk0NjFkOTJhZjIwYWUzZTA5YzYyMzUzZDE1ZjY2NWFmM2NhZTlmZDY2ZDZjNjEwYQ==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandboxapi.rapyd.net\r\nContent-Length: 212\r\n\r\n"
    <- "{\"amount\":\"1.0\",\"currency\":\"USD\",\"payment_method\":{\"type\":\"in_amex_card\",\"fields\":{\"number\":\"[FILTERED]\",\"expiration_month\":\"12\",\"expiration_year\":\"2035\",\"cvv\":\"[FILTERED]\",\"name\":\"Ryan Reynolds\"}},\"capture\":true}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Mon, 21 Mar 2022 13:40:08 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "Connection: close\r\n"
    -> "Vary: X-HTTP-Method-Override, Accept-Encoding\r\n"
    -> "Strict-Transport-Security: max-age=8640000; includeSubDomains\r\n"
    -> "ETag: W/\"7d1-tsdr4eAZn2y+2my4kMxz2w\"\r\n"
    -> "Content-Encoding: gzip\r\n"
    -> "\r\n"
    -> "a\r\n"
    -> "0\r\n"
    -> "\r\n"
    Conn close
    '
  end

  def successful_purchase_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"99571e34-f236-4f86-9040-5e0f256d6f64"},"data":{"id":"payment_716ce0efc63aa8d91579e873d29d9d5e","amount":1,"original_amount":1,"is_partial":false,"currency_code":"USD","country_code":"in","status":"CLO","description":"","merchant_reference_id":"","customer_token":"cus_f991c9a9f0cc7abdad64f9f7aea13f31","payment_method":"card_652d9fef3ec0089689fcaf0154340c64","payment_method_data":{"id":"card_652d9fef3ec0089689fcaf0154340c64","type":"in_amex_card","category":"card","metadata":null,"image":"","webhook_url":"","supporting_documentation":"","next_action":"not_applicable","name":"Ryan Reynolds","last4":"1111","acs_check":"unchecked","cvv_check":"unchecked","bin_details":{"type":null,"brand":null,"country":null,"bin_number":"411111"},"expiration_year":"35","expiration_month":"12","fingerprint_token":"ocfp_eb9edd24a3f3f59651aee0bd3d16201e"},"expiration":1648237659,"captured":true,"refunded":false,"refunded_amount":0,"receipt_email":"","redirect_url":"","complete_payment_url":"","error_payment_url":"","receipt_number":"","flow_type":"","address":null,"statement_descriptor":"N/A","transaction_id":"","created_at":1647632859,"metadata":{},"failure_code":"","failure_message":"","paid":true,"paid_at":1647632859,"dispute":null,"refunds":null,"order":null,"outcome":null,"visual_codes":{},"textual_codes":{},"instructions":{},"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","ewallets":[{"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","amount":1,"percent":100,"refunded_amount":0}],"payment_method_options":{},"payment_method_type":"in_amex_card","payment_method_type_category":"card","fx_rate":1,"merchant_requested_currency":null,"merchant_requested_amount":null,"fixed_side":"","payment_fees":null,"invoice":"","escrow":null,"group_payment":"","cancel_reason":null,"initiation_type":"customer_present","mid":"","next_action":"not_applicable","error_code":"","remitter_information":{}}}
    )
  end

  def successful_purchase_with_options_response
    %(
      {"status":{"error_code":"", "status":"SUCCESS", "message":"", "response_code":"", "operation_id":"2852540b-ffa4-4547-9260-26f101f649ad"}, "data":{"id":"payment_6b00756cfefb0fdf6fb295fa507594d3", "amount":1000, "original_amount":1000, "is_partial":false, "currency_code":"USD", "country_code":"US", "status":"CLO", "description":"", "merchant_reference_id":"", "customer_token":"cus_9cb7908aec8a75a95846f1b3759ad1ef", "payment_method":"card_a838c23ef7be1ece86aa27a330167737", "payment_method_data":{"id":"card_a838c23ef7be1ece86aa27a330167737", "type":"us_visa_card", "category":"card", "metadata":null, "image":"", "webhook_url":"", "supporting_documentation":"", "next_action":"not_applicable", "name":"Ryan Reynolds", "last4":"1111", "acs_check":"unchecked", "cvv_check":"unchecked", "bin_details":{"type":null, "brand":null, "country":null, "bin_number":"411111"}, "expiration_year":"35", "expiration_month":"12", "fingerprint_token":"ocfp_eb9edd24a3f3f59651aee0bd3d16201e"}, "expiration":1649955834, "captured":true, "refunded":false, "refunded_amount":0, "receipt_email":"", "redirect_url":"", "complete_payment_url":"", "error_payment_url":"", "receipt_number":"", "flow_type":"", "address":null, "statement_descriptor":"N/A", "transaction_id":"", "created_at":1649351034, "metadata":{"number":1234567890, "object":{"string":"person"}, "string":"preferred", "Boolean":true, "array_of_objects":[{"name":"John Doe"}, {"type":"customer"}], "array_of_strings":["color", "size"]}, "failure_code":"", "failure_message":"", "paid":true, "paid_at":1649351034, "dispute":null, "refunds":null, "order":null, "outcome":null, "visual_codes":{}, "textual_codes":{}, "instructions":[], "ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77", "ewallets":[{"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77", "amount":1000, "percent":100, "refunded_amount":0}], "payment_method_options":{}, "payment_method_type":"us_visa_card", "payment_method_type_category":"card", "fx_rate":1, "merchant_requested_currency":null, "merchant_requested_amount":null, "fixed_side":"", "payment_fees":null, "invoice":"", "escrow":null, "group_payment":"", "cancel_reason":null, "initiation_type":"customer_present", "mid":"", "next_action":"not_applicable", "error_code":"", "remitter_information":{}}}
    )
  end

  def successful_ach_purchase_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"7362425c-06ef-4a31-b50c-234e84352bb9"},"data":{"id":"payment_59daaa8786d9120a8487dc0b86d32a9e","amount":0,"original_amount":2100,"is_partial":false,"currency_code":"USD","country_code":"US","status":"ACT","description":"","merchant_reference_id":"","customer_token":"cus_99ed3308f30dd5b14c2f2cde40fac98e","payment_method":"other_73b2e0fcd0ddb3200c1fcc5a4aeaeebf","payment_method_data":{"id":"other_73b2e0fcd0ddb3200c1fcc5a4aeaeebf","type":"us_ach_bank","category":"bank_transfer","metadata":{},"image":"","webhook_url":"","supporting_documentation":"","next_action":"not_applicable","last_name":"Smith","first_name":"Jim","account_number":"15378535","routing_number":"244183602","payment_purpose":"Testing Purpose","proof_of_authorization":true},"expiration":1649093215,"captured":true,"refunded":false,"refunded_amount":0,"receipt_email":"","redirect_url":"","complete_payment_url":"","error_payment_url":"","receipt_number":"","flow_type":"","address":null,"statement_descriptor":"N/A","transaction_id":"","created_at":1647883616,"metadata":{},"failure_code":"","failure_message":"","paid":false,"paid_at":0,"dispute":null,"refunds":null,"order":null,"outcome":null,"visual_codes":{},"textual_codes":{},"instructions":{"name":"instructions","steps":[{"step1":"Provide your routing and account number to process the transaction"},{"step2":"Once completed, the transaction will take approximately 2-3 days to process"}]},"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","ewallets":[{"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","amount":2100,"percent":100,"refunded_amount":0}],"payment_method_options":{},"payment_method_type":"us_ach_bank","payment_method_type_category":"bank_transfer","fx_rate":1,"merchant_requested_currency":null,"merchant_requested_amount":null,"fixed_side":"","payment_fees":null,"invoice":"","escrow":null,"group_payment":"","cancel_reason":null,"initiation_type":"customer_present","mid":"","next_action":"pending_confirmation","error_code":"","remitter_information":{}}}
    )
  end

  def failed_purchase_response
    %(
      {"status":{"error_code":"ERROR_PROCESSING_CARD - [05]","status":"ERROR","message":"Do Not Honor","response_code":"ERROR_PROCESSING_CARD - [05]","operation_id":"5486c9f2-2c11-47eb-adec-993fc3a8c302"}}
    )
  end

  def successful_authorize_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"4ac3438d-8afe-4fdd-bc93-38f78a2a52ba"},"data":{"id":"payment_e0979a1c6843e5d7bf0c18335794cccb","amount":0,"original_amount":1,"is_partial":false,"currency_code":"USD","country_code":"in","status":"ACT","description":"","merchant_reference_id":"","customer_token":"cus_bcf45118ae3e8bf45abf01aaae8bfd5b","payment_method":"card_23db2eb985533e23cf56de4a46cee312","payment_method_data":{"id":"card_23db2eb985533e23cf56de4a46cee312","type":"in_amex_card","category":"card","metadata":null,"image":"","webhook_url":"","supporting_documentation":"","next_action":"not_applicable","name":"Ryan Reynolds","last4":"1111","acs_check":"unchecked","cvv_check":"unchecked","bin_details":{"type":null,"brand":null,"country":null,"bin_number":"411111"},"expiration_year":"35","expiration_month":"12","fingerprint_token":"ocfp_eb9edd24a3f3f59651aee0bd3d16201e"},"expiration":1648242162,"captured":false,"refunded":false,"refunded_amount":0,"receipt_email":"","redirect_url":"","complete_payment_url":"","error_payment_url":"","receipt_number":"","flow_type":"","address":null,"statement_descriptor":"N/A","transaction_id":"","created_at":1647637362,"metadata":{},"failure_code":"","failure_message":"","paid":false,"paid_at":0,"dispute":null,"refunds":null,"order":null,"outcome":null,"visual_codes":{},"textual_codes":{},"instructions":{},"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","ewallets":[{"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","amount":1,"percent":100,"refunded_amount":0}],"payment_method_options":{},"payment_method_type":"in_amex_card","payment_method_type_category":"card","fx_rate":1,"merchant_requested_currency":null,"merchant_requested_amount":null,"fixed_side":"","payment_fees":null,"invoice":"","escrow":null,"group_payment":"","cancel_reason":null,"initiation_type":"customer_present","mid":"","next_action":"pending_capture","error_code":"","remitter_information":{}}}
    )
  end

  def failed_authorize_response
    %(
      {"status":{"error_code":"ERROR_PROCESSING_CARD - [05]","status":"ERROR","message":"Do Not Honor","response_code":"ERROR_PROCESSING_CARD - [05]","operation_id":"410488ba-523f-480a-a497-053ca2327866"}}
    )
  end

  def successful_capture_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"015c41d0-f11a-4a91-9518-dc4117d8017b"},"data":{"id":"payment_e0979a1c6843e5d7bf0c18335794cccb","amount":1,"original_amount":1,"is_partial":false,"currency_code":"USD","country_code":"in","status":"CLO","description":"","merchant_reference_id":"","customer_token":"cus_bcf45118ae3e8bf45abf01aaae8bfd5b","payment_method":"card_23db2eb985533e23cf56de4a46cee312","payment_method_data":{"id":"card_23db2eb985533e23cf56de4a46cee312","type":"in_amex_card","category":"card","metadata":null,"image":"","webhook_url":"","supporting_documentation":"","next_action":"not_applicable","name":"Ryan Reynolds","last4":"1111","acs_check":"unchecked","cvv_check":"unchecked","bin_details":{"type":null,"brand":null,"country":null,"bin_number":"411111"},"expiration_year":"35","expiration_month":"12","fingerprint_token":"ocfp_eb9edd24a3f3f59651aee0bd3d16201e"},"expiration":1648242162,"captured":true,"refunded":false,"refunded_amount":0,"receipt_email":"","redirect_url":"","complete_payment_url":"","error_payment_url":"","receipt_number":"","flow_type":"","address":null,"statement_descriptor":"N/A","transaction_id":"","created_at":1647637362,"metadata":{},"failure_code":"","failure_message":"","paid":true,"paid_at":1647637363,"dispute":null,"refunds":null,"order":null,"outcome":null,"visual_codes":{},"textual_codes":{},"instructions":{},"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","ewallets":[{"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","amount":1,"percent":100,"refunded_amount":0}],"payment_method_options":{},"payment_method_type":"in_amex_card","payment_method_type_category":"card","fx_rate":1,"merchant_requested_currency":null,"merchant_requested_amount":null,"fixed_side":"","payment_fees":null,"invoice":"","escrow":null,"group_payment":"","cancel_reason":null,"initiation_type":"customer_present","mid":"","next_action":"not_applicable","error_code":"","remitter_information":{}}}
    )
  end

  def failed_capture_response
    %(
      {"status":{"error_code":"ERROR_GET_PAYMENT","status":"ERROR","message":"The request tried to retrieve a payment, but the payment was not found. The request was rejected. Corrective action: Use a valid payment ID.","response_code":"ERROR_GET_PAYMENT","operation_id":"a836ca9b-def8-4e4e-a4e8-a249b0c0e0ff"}}
    )
  end

  def successful_refund_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"5bfa30c5-c698-4e43-861c-e6fe5e82b324"},"data":{"id":"refund_2a575991bee3b010f44e438f7f6a6d5f","amount":1,"payment":"payment_c861474086bd50305f51ee7855d65eb5","currency":"USD","failure_reason":"","metadata":{},"reason":"","status":"Completed","receipt_number":0,"created_at":1647637499,"updated_at":1647637499,"merchant_reference_id":"","payment_created_at":1647637498,"payment_method_type":"in_amex_card","ewallets":[{"ewallet":"ewallet_1936682fdca7a188c49eb9f9817ade77","amount":1}],"proportional_refund":true,"merchant_debited_amount":null,"merchant_debited_currency":null,"fx_rate":null,"fixed_side":null}}
    )
  end

  def failed_refund_response
    %(
      {"status":{"error_code":"ERROR_GET_PAYMENT","status":"ERROR","message":"The request tried to retrieve a payment, but the payment was not found. The request was rejected. Corrective action: Use a valid payment ID.","response_code":"ERROR_GET_PAYMENT","operation_id":"29a59e7c-8e82-4abe-ad9e-bf47eb72f6c1"}}
    )
  end

  def successful_void_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"af46ead1-8b34-48c5-903d-07eefef6cbbd"},"data":{"id":"payment_a29a73f09d6f55defddc779dbb2d1089","amount":0,"original_amount":1,"is_partial":false,"currency_code":"USD","country_code":"in","status":"CAN","description":"","merchant_reference_id":"","customer_token":"cus_256d8f8a97f252f32210a27a97b855a5","payment_method":"card_e42d1d0bdca84661f0b62640330c4c65","payment_method_data":{},"expiration":1648242349,"captured":false,"refunded":false,"refunded_amount":0,"receipt_email":"","redirect_url":"","complete_payment_url":"","error_payment_url":"","receipt_number":"","flow_type":"","address":null,"statement_descriptor":"N/A","transaction_id":"","created_at":1647637549,"metadata":{},"failure_code":"","failure_message":"","paid":false,"paid_at":0,"dispute":null,"refunds":null,"order":null,"outcome":null,"visual_codes":{},"textual_codes":{},"instructions":{},"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","ewallets":[{"ewallet_id":"ewallet_1936682fdca7a188c49eb9f9817ade77","amount":1,"percent":100,"refunded_amount":0}],"payment_method_options":{},"payment_method_type":"in_amex_card","payment_method_type_category":"card","fx_rate":1,"merchant_requested_currency":null,"merchant_requested_amount":null,"fixed_side":"","payment_fees":null,"invoice":"","escrow":null,"group_payment":"","cancel_reason":null,"initiation_type":"customer_present","mid":"","next_action":"not_applicable","error_code":"","remitter_information":{}}}
    )
  end

  def failed_void_response
    %(
      {"status":{"error_code":"UNAUTHORIZED_API_CALL","status":"ERROR","message":"","response_code":"UNAUTHORIZED_API_CALL","operation_id":"12e59804-b742-44eb-aa49-4b722629faa8"}}
    )
  end

  def successful_verify_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"27385814-fc69-46fc-bbcc-2a5e0aac442d"},"data":{"id":"payment_2736748fec92a96c7c1280f7e46e2876","amount":0,"original_amount":0,"is_partial":false,"currency_code":"USD","country_code":"US","status":"ACT","description":"","merchant_reference_id":"","customer_token":"cus_c99aab5dae41102b0bb4276ab32e7777","payment_method":"card_5a07af7ff5c038eef4802ffb200fffa6","payment_method_data":{"id":"card_5a07af7ff5c038eef4802ffb200fffa6","type":"us_visa_card","category":"card","metadata":null,"image":"","webhook_url":"","supporting_documentation":"","next_action":"3d_verification","name":"Ryan Reynolds","last4":"1111","acs_check":"unchecked","cvv_check":"unchecked","bin_details":{"type":null,"brand":null,"level":null,"country":null,"bin_number":"411111"},"expiration_year":"35","expiration_month":"12","fingerprint_token":"ocfp_eb9edd24a3f3f59651aee0bd3d16201e"},"expiration":1653942478,"captured":false,"refunded":false,"refunded_amount":0,"receipt_email":"","redirect_url":"https://sandboxcheckout.rapyd.net/3ds-payment?token=payment_2736748fec92a96c7c1280f7e46e2876","complete_payment_url":"","error_payment_url":"","receipt_number":"","flow_type":"","address":null,"statement_descriptor":"N/A","transaction_id":"","created_at":1653337678,"metadata":{},"failure_code":"","failure_message":"","paid":false,"paid_at":0,"dispute":null,"refunds":null,"order":null,"outcome":null,"visual_codes":{},"textual_codes":{},"instructions":[],"ewallet_id":null,"ewallets":[],"payment_method_options":{},"payment_method_type":"us_visa_card","payment_method_type_category":"card","fx_rate":1,"merchant_requested_currency":null,"merchant_requested_amount":null,"fixed_side":"","payment_fees":null,"invoice":"","escrow":null,"group_payment":"","cancel_reason":null,"initiation_type":"customer_present","mid":"","next_action":"3d_verification","error_code":"","remitter_information":{}}}
    )
  end

  def successful_store_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"47e8bbbc-baa5-43c6-9395-df8a01645e91"},"data":{"id":"cus_4d8509d0997c7ce8aa1f63c19c1b6870","delinquent":false,"discount":null,"name":"Ryan Reynolds","default_payment_method":"card_94a3a70510109163a4eb438f06d82f78","description":"","email":"","phone_number":"","invoice_prefix":"","addresses":[],"payment_methods":{"data":[{"id":"card_94a3a70510109163a4eb438f06d82f78","type":"us_visa_card","category":"card","metadata":null,"image":"https://iconslib.rapyd.net/checkout/us_visa_card.png","webhook_url":"","supporting_documentation":"","next_action":"3d_verification","name":"Ryan Reynolds","last4":"1111","acs_check":"unchecked","cvv_check":"unchecked","bin_details":{"type":null,"brand":null,"level":null,"country":null,"bin_number":"411111"},"expiration_year":"35","expiration_month":"12","fingerprint_token":"ocfp_eb9edd24a3f3f59651aee0bd3d16201e","redirect_url":"https://sandboxcheckout.rapyd.net/3ds-payment?token=payment_f4ab1b25a09cbd769df05b30a29f71a4"}],"has_more":false,"total_count":1,"url":"/v1/customers/cus_4d8509d0997c7ce8aa1f63c19c1b6870/payment_methods"},"subscriptions":null,"created_at":1653487824,"metadata":{},"business_vat_id":"","ewallet":""}}
    )
  end

  def successful_unstore_response
    %(
      {"status":{"error_code":"","status":"SUCCESS","message":"","response_code":"","operation_id":"6f7857f4-e063-4edb-ab93-da60c8563c52"},"data":{"deleted":true,"id":"cus_4d8509d0997c7ce8aa1f63c19c1b6870"}}
    )
  end
end
