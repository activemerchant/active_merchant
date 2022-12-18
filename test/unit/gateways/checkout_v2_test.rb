require 'test_helper'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CheckoutV2Gateway
      def setup_access_token
        '12345678'
      end
    end
  end
end

class CheckoutV2Test < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CheckoutV2Gateway.new(
      secret_key: '1111111111111',
    )
    @gateway_oauth = CheckoutV2Gateway.new({ client_id: 'abcd', client_secret: '1234' })

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

  def test_successful_purchase_using_vts_network_token_without_eci
    network_token = network_tokenization_credit_card(
      '4242424242424242',
      { source: :network_token, brand: 'visa' }
    )
    response = stub_comms do
      @gateway.purchase(@amount, network_token)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)

      assert_equal(request_data['source']['type'], 'network_token')
      assert_equal(request_data['source']['token'], network_token.number)
      assert_equal(request_data['source']['token_type'], 'vts')
      assert_equal(request_data['source']['eci'], '05')
      assert_equal(request_data['source']['cryptogram'], network_token.payment_cryptogram)
    end.respond_with(successful_purchase_with_network_token_response)

    assert_success response
    assert_equal '2FCFE326D92D4C27EDD699560F484', response.params['source']['payment_account_reference']
    assert response.test?
  end

  def test_successful_passing_processing_channel_id
    stub_comms do
      @gateway.purchase(@amount, @credit_card, { processing_channel_id: '123456abcde' })
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)
      assert_equal(request_data['processing_channel_id'], '123456abcde')
    end.respond_with(successful_purchase_response)
  end

  def test_successful_passing_incremental_authorization
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, { incremental_authorization: 'abcd1234' })
    end.check_request do |endpoint, _data, _headers|
      assert_include endpoint, 'abcd1234'
    end.respond_with(successful_incremental_authorize_response)

    assert_success response
  end

  def test_successful_passing_authorization_type
    stub_comms do
      @gateway.purchase(@amount, @credit_card, { authorization_type: 'Estimated' })
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)
      assert_equal(request_data['authorization_type'], 'Estimated')
    end.respond_with(successful_purchase_response)
  end

  def test_successful_passing_exemption_and_challenge_indicator
    stub_comms do
      @gateway.purchase(@amount, @credit_card, { execute_threed: true, exemption: 'no_preference', challenge_indicator: 'trusted_listing' })
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)
      assert_equal(request_data['3ds']['exemption'], 'no_preference')
      assert_equal(request_data['3ds']['challenge_indicator'], 'trusted_listing')
    end.respond_with(successful_purchase_response)
  end

  def test_successful_passing_capture_type
    stub_comms do
      @gateway.capture(@amount, 'abc', { capture_type: 'NonFinal' })
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)
      assert_equal(request_data['capture_type'], 'NonFinal')
    end.respond_with(successful_capture_response)
  end

  def test_successful_purchase_using_vts_network_token_with_eci
    network_token = network_tokenization_credit_card(
      '4242424242424242',
      { source: :network_token, brand: 'visa', eci: '06' }
    )
    response = stub_comms do
      @gateway.purchase(@amount, network_token)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)

      assert_equal(request_data['source']['type'], 'network_token')
      assert_equal(request_data['source']['token'], network_token.number)
      assert_equal(request_data['source']['token_type'], 'vts')
      assert_equal(request_data['source']['eci'], '06')
      assert_equal(request_data['source']['cryptogram'], network_token.payment_cryptogram)
    end.respond_with(successful_purchase_with_network_token_response)

    assert_success response
    assert_equal '2FCFE326D92D4C27EDD699560F484', response.params['source']['payment_account_reference']
    assert response.test?
  end

  def test_successful_purchase_using_mdes_network_token
    network_token = network_tokenization_credit_card(
      '5436031030606378',
      { source: :network_token, brand: 'master' }
    )
    response = stub_comms do
      @gateway.purchase(@amount, network_token)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)

      assert_equal(request_data['source']['type'], 'network_token')
      assert_equal(request_data['source']['token'], network_token.number)
      assert_equal(request_data['source']['token_type'], 'mdes')
      assert_equal(request_data['source']['eci'], nil)
      assert_equal(request_data['source']['cryptogram'], network_token.payment_cryptogram)
    end.respond_with(successful_purchase_with_network_token_response)

    assert_success response
    assert_equal '2FCFE326D92D4C27EDD699560F484', response.params['source']['payment_account_reference']
    assert response.test?
  end

  def test_successful_purchase_using_apple_pay_network_token
    network_token = network_tokenization_credit_card(
      '4242424242424242',
      { source: :apple_pay, eci: '05', payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA' }
    )
    response = stub_comms do
      @gateway.purchase(@amount, network_token)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)

      assert_equal(request_data['source']['type'], 'network_token')
      assert_equal(request_data['source']['token'], network_token.number)
      assert_equal(request_data['source']['token_type'], 'applepay')
      assert_equal(request_data['source']['eci'], '05')
      assert_equal(request_data['source']['cryptogram'], network_token.payment_cryptogram)
    end.respond_with(successful_purchase_with_network_token_response)

    assert_success response
    assert_equal '2FCFE326D92D4C27EDD699560F484', response.params['source']['payment_account_reference']
    assert response.test?
  end

  def test_successful_purchase_using_android_pay_network_token
    network_token = network_tokenization_credit_card(
      '4242424242424242',
      { source: :android_pay, eci: '05', payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA' }
    )
    response = stub_comms do
      @gateway.purchase(@amount, network_token)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)

      assert_equal(request_data['source']['type'], 'network_token')
      assert_equal(request_data['source']['token'], network_token.number)
      assert_equal(request_data['source']['token_type'], 'googlepay')
      assert_equal(request_data['source']['eci'], '05')
      assert_equal(request_data['source']['cryptogram'], network_token.payment_cryptogram)
    end.respond_with(successful_purchase_with_network_token_response)

    assert_success response
    assert_equal '2FCFE326D92D4C27EDD699560F484', response.params['source']['payment_account_reference']
    assert response.test?
  end

  def test_successful_purchase_using_google_pay_network_token
    network_token = network_tokenization_credit_card(
      '4242424242424242',
      { source: :google_pay, eci: '05', payment_cryptogram: 'AgAAAAAAAIR8CQrXcIhbQAAAAAA' }
    )
    response = stub_comms do
      @gateway.purchase(@amount, network_token)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)

      assert_equal(request_data['source']['type'], 'network_token')
      assert_equal(request_data['source']['token'], network_token.number)
      assert_equal(request_data['source']['token_type'], 'googlepay')
      assert_equal(request_data['source']['eci'], '05')
      assert_equal(request_data['source']['cryptogram'], network_token.payment_cryptogram)
    end.respond_with(successful_purchase_with_network_token_response)

    assert_success response
    assert_equal '2FCFE326D92D4C27EDD699560F484', response.params['source']['payment_account_reference']
    assert response.test?
  end

  def test_successful_purchase_using_google_pay_pan_only_network_token
    network_token = network_tokenization_credit_card(
      '4242424242424242',
      { source: :google_pay }
    )
    response = stub_comms do
      @gateway.purchase(@amount, network_token)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)

      assert_equal(request_data['source']['type'], 'network_token')
      assert_equal(request_data['source']['token'], network_token.number)
      assert_equal(request_data['source']['token_type'], 'googlepay')
      assert_equal(request_data['source']['eci'], nil)
      assert_equal(request_data['source']['cryptogram'], nil)
    end.respond_with(successful_purchase_with_network_token_response)

    assert_success response
    assert_equal '2FCFE326D92D4C27EDD699560F484', response.params['source']['payment_account_reference']
    assert response.test?
  end

  def test_successful_render_for_oauth
    processing_channel_id = 'abcd123'
    response = stub_comms(@gateway_oauth, :ssl_request) do
      @gateway_oauth.purchase(@amount, @credit_card, { processing_channel_id: processing_channel_id })
    end.check_request do |_method, _endpoint, data, headers|
      request = JSON.parse(data)
      assert_equal headers['Authorization'], 'Bearer 12345678'
      assert_equal request['processing_channel_id'], processing_channel_id
    end.respond_with(successful_purchase_response)
    assert_success response
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
      @gateway.purchase(@amount, @credit_card, { descriptor_city: 'london', descriptor_name: 'sherlock' })
    end.check_request do |_endpoint, data, _headers|
      assert_match(/"billing_descriptor\":{\"name\":\"sherlock\",\"city\":\"london\"}/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_passing_metadata_with_mada_card_type
    @credit_card.brand = 'mada'

    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |_endpoint, data, _headers|
      request_data = JSON.parse(data)
      assert_equal(request_data['metadata']['udf1'], 'mada')
    end.respond_with(successful_purchase_response)
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
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

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
        previous_charge_id: 'pay_123',
        processing_channel_id: 'pc_123',
        marketplace: {
          sub_entity_id: 'ent_123'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"stored":"true"}, data)
      assert_match(%r{"payment_type":"Recurring"}, data)
      assert_match(%r{"previous_payment_id":"pay_123"}, data)
      assert_match(%r{"processing_channel_id":"pc_123"}, data)
      assert_match(/"marketplace\":{\"sub_entity_id\":\"ent_123\"}/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_successful_purchase_with_stored_credentials
    initial_response = stub_comms do
      initial_options = {
        stored_credential: {
          initial_transaction: true,
          reason_type: 'installment'
        }
      }
      @gateway.purchase(@amount, @credit_card, initial_options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"payment_type":"Recurring"}, data)
      assert_match(%r{"merchant_initiated":false}, data)
    end.respond_with(successful_purchase_initial_stored_credential_response)

    assert_success initial_response
    assert_equal 'pay_7jcf4ovmwnqedhtldca3fjli2y', initial_response.params['id']
    network_transaction_id = initial_response.params['id']

    response = stub_comms do
      options = {
        stored_credential: {
          initial_transaction: false,
          reason_type: 'recurring',
          network_transaction_id: network_transaction_id
        }
      }
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['previous_payment_id'], 'pay_7jcf4ovmwnqedhtldca3fjli2y'
      assert_equal request['source']['stored'], true
    end.respond_with(successful_purchase_using_stored_credential_response)

    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_stored_credentials_merchant_initiated_transaction_id
    response = stub_comms do
      options = {
        stored_credential: {
          initial_transaction: false
        },
        merchant_initiated_transaction_id: 'pay_7jcf4ovmwnqedhtldca3fjli2y'
      }
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['previous_payment_id'], 'pay_7jcf4ovmwnqedhtldca3fjli2y'
      assert_equal request['source']['stored'], true
    end.respond_with(successful_purchase_using_stored_credential_response)

    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_metadata
    response = stub_comms do
      options = {
        metadata: {
          coupon_code: 'NY2018',
          partner_id: '123989'
        }
      }
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"coupon_code":"NY2018"}, data)
      assert_match(%r{"partner_id":"123989"}, data)
    end.respond_with(successful_purchase_using_stored_credential_response)

    assert_success response
  end

  def test_successful_authorize_and_capture_with_metadata
    response = stub_comms do
      options = {
        metadata: {
          coupon_code: 'NY2018',
          partner_id: '123989'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"coupon_code":"NY2018"}, data)
      assert_match(%r{"partner_id":"123989"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_moto_transaction_is_properly_set
    response = stub_comms do
      options = {
        metadata: {
          manual_entry: true
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"payment_type":"MOTO"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_3ds_passed
    response = stub_comms do
      options = {
        execute_threed: true,
        callback_url: 'https://www.example.com'
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"success_url"}, data)
      assert_match(%r{"failure_url"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_verify_payment
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify_payment('testValue')
    end.respond_with(successful_verify_payment_response)

    assert_success response
  end

  def test_failed_verify_payment
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify_payment('testValue')
    end.respond_with(failed_verify_payment_response)

    assert_failure response
  end

  def test_successful_authorize_and_capture_with_3ds
    response = stub_comms do
      options = {
        execute_threed: true,
        attempt_n3d: true,
        three_d_secure: {
          version: '1.0.2',
          eci: '05',
          cryptogram: '1234',
          xid: '1234',
          authentication_response_status: 'Y'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_successful_authorize_and_capture_with_3ds2
    response = stub_comms do
      options = {
        execute_threed: true,
        three_d_secure: {
          version: '2.0.0',
          eci: '05',
          cryptogram: '1234',
          ds_transaction_id: '1234',
          authentication_response_status: 'Y'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

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
    assert_equal "Invalid Card Number", response.message
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "charge_test_941CA9CE174U76BD29C8", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_successful_void_with_metadata
    response = stub_comms do
      options = {
        metadata: {
          coupon_code: 'NY2018',
          partner_id: '123989'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"coupon_code":"NY2018"}, data)
      assert_match(%r{"partner_id":"123989"}, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal 'pay_fj3xswqe3emuxckocjx6td73ni', response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("5d53a33d960c46d00f5dc061947d998c")
    end.respond_with(failed_void_response)
    assert_failure response
  end

  def test_successfully_passes_fund_type_and_fields
    options = {
      funds_transfer_type: 'FD',
      source_type: 'currency_account',
      source_id: 'ca_spwmped4qmqenai7hcghquqle4',
      account_holder_type: 'individual'
    }
    response = stub_comms do
      @gateway.credit(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['instruction']['funds_transfer_type'], options[:funds_transfer_type]
      assert_equal request['source']['type'], options[:source_type]
      assert_equal request['source']['id'], options[:source_id]
      assert_equal request['destination']['account_holder']['type'], options[:account_holder_type]
      assert_equal request['destination']['account_holder']['first_name'], @credit_card.first_name
      assert_equal request['destination']['account_holder']['last_name'], @credit_card.last_name
    end.respond_with(successful_credit_response)
    assert_success response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "charge_test_941CA9CE174U76BD29C8", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_successful_refund_with_metadata
    response = stub_comms do
      options = {
        metadata: {
          coupon_code: 'NY2018',
          partner_id: '123989'
        }
      }
      @gateway.authorize(@amount, @credit_card, options)
    end.check_request do |_endpoint, data, _headers|
      assert_match(%r{"coupon_code":"NY2018"}, data)
      assert_match(%r{"partner_id":"123989"}, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal 'pay_bgv5tmah6fmuzcmcrcro6exe6m', response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "Invalid Card Number", response.message
  end

  def test_transcript_scrubbing
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  def test_network_transaction_scrubbing
    assert_equal network_transaction_post_scrubbed, @gateway.scrub(network_transaction_pre_scrubbed)
  end

  def test_invalid_json
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(invalid_json_response)

    assert_failure response
    assert_match %r{Invalid JSON response}, response.message
  end


  private

  def pre_scrubbed
    %q(
      <- "POST /v2/charges/card HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: sk_test_ab12301d-e432-4ea7-97d1-569809518aaf\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api2.checkout.com\r\nContent-Length: 346\r\n\r\n"
      <- "{\"autoCapture\":\"n\",\"value\":\"200\",\"trackId\":\"1\",\"currency\":\"USD\",\"card\":{\"name\":\"Longbob Longsen\",\"number\":\"4242424242424242\",\"cvv\":\"100\",\"expiryYear\":\"2018\"
    )
  end

  def network_transaction_pre_scrubbed
    %q(
      <- "POST /payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: sk_test_ab12301d-e432-4ea7-97d1-569809518aaf\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.checkout.com\r\nContent-Length: 346\r\n\r\n"
      <- "{\"amount\":\"100\",\"reference\":\"1\",\"currency\":\"USD\",\"metadata\":{\"udf5\":\"ActiveMerchant\"},\"source\":{\"type\":\"network_token\",\"token\":\"4242424242424242\",\"token_type\":\"applepay\",\"cryptogram\":\"AgAAAAAAAIR8CQrXcIhbQAAAAAA\",\"eci\":\"05\",\"expiry_year\":\"2025\",\"expiry_month\":\"10\",\"billing_address\":{\"address_line1\":\"456 My Street\",\"address_line2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\",\"zip\":\"K1C2N6\"}},\"customer\":{\"email\":\"longbob.longsen@example.com\"}}"
    )
  end

  def network_transaction_post_scrubbed
    %q(
      <- "POST /payments HTTP/1.1\r\nContent-Type: application/json;charset=UTF-8\r\nAuthorization: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.checkout.com\r\nContent-Length: 346\r\n\r\n"
      <- "{\"amount\":\"100\",\"reference\":\"1\",\"currency\":\"USD\",\"metadata\":{\"udf5\":\"ActiveMerchant\"},\"source\":{\"type\":\"network_token\",\"token\":\"[FILTERED]\",\"token_type\":\"applepay\",\"cryptogram\":\"[FILTERED]\",\"eci\":\"05\",\"expiry_year\":\"2025\",\"expiry_month\":\"10\",\"billing_address\":{\"address_line1\":\"456 My Street\",\"address_line2\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\",\"zip\":\"K1C2N6\"}},\"customer\":{\"email\":\"longbob.longsen@example.com\"}}"
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

  def successful_purchase_with_network_token_response
    purchase_response = JSON.parse(successful_purchase_response)
    purchase_response['source']['payment_account_reference'] = '2FCFE326D92D4C27EDD699560F484'
    purchase_response.to_json
  end

  def successful_purchase_initial_stored_credential_response
    %(
      {"id":"pay_7jcf4ovmwnqedhtldca3fjli2y","action_id":"act_7jcf4ovmwnqedhtldca3fjli2y","amount":200,"currency":"USD","approved":true,"status":"Authorized","auth_code":"587541","eci":"05","scheme_id":"776561034288791","response_code":"10000","response_summary":"Approved","risk":{"flagged":false},"source":{"id":"src_m2ooveyd2dxuzh277ft4obgkwm","type":"card","billing_address":{"address_line1":"456 My Street","address_line2":"Apt 1","city":"Ottawa","state":"ON","zip":"K1C2N6","country":"CA"},"expiry_month":6,"expiry_year":2025,"name":"Longbob Longsen","scheme":"Visa","last4":"4242","fingerprint":"9F3BAD2E48C6C8579F2F5DC0710B7C11A8ACD5072C3363A72579A6FB227D64BE","bin":"424242","card_type":"Credit","card_category":"Consumer","issuer":"JPMORGAN CHASE BANK NA","issuer_country":"US","product_id":"A","product_type":"Visa Traditional","avs_check":"S","cvv_check":"Y","payouts":true,"fast_funds":"d"},"customer":{"id":"cus_tr53e5z2dlmetpo2ehbsuk76yu","email":"longbob.longsen@example.com","name":"Longbob Longsen"},"processed_on":"2021-03-29T20:22:48Z","reference":"1","processing":{"acquirer_transaction_id":"8266949399","retrieval_reference_number":"731420439000"},"_links":{"self":{"href":"https://api.sandbox.checkout.com/payments/pay_7jcf4ovmwnqedhtldca3fjli2y"},"actions":{"href":"https://api.sandbox.checkout.com/payments/pay_7jcf4ovmwnqedhtldca3fjli2y/actions"},"capture":{"href":"https://api.sandbox.checkout.com/payments/pay_7jcf4ovmwnqedhtldca3fjli2y/captures"},"void":{"href":"https://api.sandbox.checkout.com/payments/pay_7jcf4ovmwnqedhtldca3fjli2y/voids"}}}
    )
  end

  def successful_purchase_using_stored_credential_response
    %(
      {"id":"pay_udodtu4ogljupp2jvy2cxf4jme","action_id":"act_udodtu4ogljupp2jvy2cxf4jme","amount":200,"currency":"USD","approved":true,"status":"Authorized","auth_code":"680745","eci":"05","scheme_id":"491049486700108","response_code":"10000","response_summary":"Approved","risk":{"flagged":false},"source":{"id":"src_m2ooveyd2dxuzh277ft4obgkwm","type":"card","billing_address":{"address_line1":"456 My Street","address_line2":"Apt 1","city":"Ottawa","state":"ON","zip":"K1C2N6","country":"CA"},"expiry_month":6,"expiry_year":2025,"name":"Longbob Longsen","scheme":"Visa","last4":"4242","fingerprint":"9F3BAD2E48C6C8579F2F5DC0710B7C11A8ACD5072C3363A72579A6FB227D64BE","bin":"424242","card_type":"Credit","card_category":"Consumer","issuer":"JPMORGAN CHASE BANK NA","issuer_country":"US","product_id":"A","product_type":"Visa Traditional","avs_check":"S","cvv_check":"Y","payouts":true,"fast_funds":"d"},"customer":{"id":"cus_tr53e5z2dlmetpo2ehbsuk76yu","email":"longbob.longsen@example.com","name":"Longbob Longsen"},"processed_on":"2021-03-29T20:22:49Z","reference":"1","processing":{"acquirer_transaction_id":"4026777708","retrieval_reference_number":"633985559433"},"_links":{"self":{"href":"https://api.sandbox.checkout.com/payments/pay_udodtu4ogljupp2jvy2cxf4jme"},"actions":{"href":"https://api.sandbox.checkout.com/payments/pay_udodtu4ogljupp2jvy2cxf4jme/actions"},"capture":{"href":"https://api.sandbox.checkout.com/payments/pay_udodtu4ogljupp2jvy2cxf4jme/captures"},"void":{"href":"https://api.sandbox.checkout.com/payments/pay_udodtu4ogljupp2jvy2cxf4jme/voids"}}}
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
       "responseMessage":"Authorised",
       "responseAdvancedInfo":"Authorised",
       "responseCode":"10000"
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

  def successful_incremental_authorize_response
    %(
      {
        "action_id": "act_q4dbxom5jbgudnjzjpz7j2z6uq",
        "amount": 50,
        "currency": "USD",
        "approved": true,
        "status": "Authorized",
        "auth_code": "503198",
        "expires_on": "2020-04-20T10:11:12Z",
        "eci": "05",
        "scheme_id": "511129554406717",
        "response_code": "10000",
        "response_summary": "Approved",
        "balances": {
          "total_authorized": 150,
          "total_voided": 0,
          "available_to_void": 150,
          "total_captured": 0,
          "available_to_capture": 150,
          "total_refunded": 0,
          "available_to_refund": 0
        },
        "processed_on": "2020-03-16T22:11:24Z",
        "reference": "ORD-752-814",
        "processing": {
          "acquirer_transaction_id": "8367314942",
          "retrieval_reference_number": "162588399162"
        },
        "_links": {
          "self": {
            "href": "https://api.sandbox.checkout.com/payments/pay_tqgk5c6k2nnexagtcuom5ktlua"
          },
          "actions": {
            "href": "https://api.sandbox.checkout.com/payments/pay_tqgk5c6k2nnexagtcuom5ktlua/actions"
          },
          "authorize": {
            "href": "https://api.sandbox.checkout.com/payments/pay_tqgk5c6k2nnexagtcuom5ktlua/authorizations"
          },
          "capture": {
            "href": "https://api.sandbox.checkout.com/payments/pay_tqgk5c6k2nnexagtcuom5ktlua/captures"
          },
          "void": {
            "href": "https://api.sandbox.checkout.com/payments/pay_tqgk5c6k2nnexagtcuom5ktlua/voids"
          }
        }
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

  def successful_credit_response
    %(
    {
      "id": "pay_jhzh3u7vxcgezlcek7ymzyy6be",
      "status": "Pending",
      "reference": "ORD-5023-4E89",
      "instruction": {
          "value_date": "2022-08-09T06:11:37.2306547+00:00"
      },
      "_links": {
          "self": {
              "href": "https://api.sandbox.checkout.com/payments/pay_jhzh3u7vxcgezlcek7ymzyy6be"
          },
          "actions": {
              "href": "https://api.sandbox.checkout.com/payments/pay_jhzh3u7vxcgezlcek7ymzyy6be/actions"
          }
      }
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


end
