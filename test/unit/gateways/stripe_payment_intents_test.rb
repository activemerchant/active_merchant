require 'test_helper'

class StripePaymentIntentsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = StripePaymentIntentsGateway.new(login: 'sk_test_login')

    @credit_card = credit_card()
    @threeds_2_card = credit_card('4000000000003220')
    @visa_token = 'pm_card_visa'

    @three_ds_authentication_required_setup_for_off_session = 'pm_card_authenticationRequiredSetupForOffSession'
    @three_ds_off_session_credit_card = credit_card(
      '4000002500003155',
      verification_value: '737',
      month: 10,
      year: 2022
    )

    @amount = 2020
    @update_amount = 2050

    @options = {
      currency: 'GBP',
      confirmation_method: 'manual'
    }

    @google_pay = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: 'dGVzdGNyeXB0b2dyYW1YWFhYWFhYWFhYWFg9PQ==',
      source: :google_pay,
      brand: 'visa',
      eci: '05',
      month: '09',
      year: '2030'
    )

    @apple_pay = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: 'dGVzdGNyeXB0b2dyYW1YWFhYWFhYWFhYWFg9PQ==',
      source: :apple_pay,
      brand: 'visa',
      eci: '05',
      month: '09',
      year: '2030',
      first_name: 'Longbob',
      last_name: 'Longsen'
    )

    @network_token_credit_card = network_tokenization_credit_card(
      '4000056655665556',
      verification_value: '123',
      payment_cryptogram: 'dGVzdGNyeXB0b2dyYW1YWFhYWFhYWFhYWFg9PQ==',
      source: :network_token,
      brand: 'visa',
      month: '09',
      year: '2030',
      first_name: 'Longbob',
      last_name: 'Longsen'
    )
  end

  def test_successful_create_and_confirm_intent
    @gateway.expects(:ssl_request).times(3).returns(successful_create_3ds2_payment_method, successful_create_3ds2_intent_response, successful_confirm_3ds2_intent_response)

    assert create = @gateway.create_intent(@amount, @threeds_2_card, @options.merge(return_url: 'https://www.example.com', capture_method: 'manual'))
    assert_instance_of MultiResponse, create
    assert_success create

    assert_equal 'pi_1F1wpFAWOtgoysog8nTulYGk', create.authorization
    assert_equal 'requires_confirmation', create.params['status']
    assert create.test?

    assert confirm = @gateway.confirm_intent(create.params['id'], nil, @options.merge(return_url: 'https://example.com/return-to-me', payment_method_types: 'card'))
    assert_equal 'redirect_to_url', confirm.params.dig('next_action', 'type')
    assert_equal 'card', confirm.params.dig('payment_method_types')[0]
  end

  def test_successful_create_and_capture_intent
    options = @options.merge(capture_method: 'manual', confirm: true)
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_response, successful_capture_response)
    assert create = @gateway.create_intent(@amount, @visa_token, options)
    assert_success create
    assert_equal 'requires_capture', create.params['status']

    assert capture = @gateway.capture(@amount, create.params['id'], options)
    assert_success capture
    assert_equal 'succeeded', capture.params['status']
    assert_equal 'Payment complete.', capture.params.dig('charges', 'data')[0].dig('outcome', 'seller_message')
  end

  def test_successful_create_and_capture_intent_with_network_token
    options = @options.merge(capture_method: 'manual', confirm: true)
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_manual_capture_response_with_network_token_fields, successful_manual_capture_of_payment_intent_response_with_network_token_fields)
    assert create = @gateway.create_intent(@amount, @network_token_credit_card, options)
    assert_success create
    assert_equal 'requires_capture', create.params['status']

    assert capture = @gateway.capture(@amount, create.params['id'], options)
    assert_success capture
    assert_equal 'succeeded', capture.params['status']
    assert_equal 'Payment complete.', capture.params.dig('charges', 'data')[0].dig('outcome', 'seller_message')
  end

  def test_successful_create_and_update_intent
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_response, successful_update_intent_response)
    assert create = @gateway.create_intent(@amount, @visa_token, @options.merge(capture_method: 'manual'))

    assert update = @gateway.update_intent(@update_amount, create.params['id'], nil, @options.merge(capture_method: 'manual'))
    assert_equal @update_amount, update.params['amount']
    assert_equal 'requires_confirmation', update.params['status']
  end

  def test_contains_statement_descriptor_suffix
    options = @options.merge(capture_method: 'manual', statement_descriptor_suffix: 'suffix')

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/statement_descriptor_suffix=suffix/, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_create_and_void_intent
    @gateway.expects(:ssl_request).twice.returns(successful_create_intent_response, successful_void_response)
    assert create = @gateway.create_intent(@amount, @visa_token, @options.merge(capture_method: 'manual', confirm: true))

    assert cancel = @gateway.void(create.params['id'])
    assert_equal @amount, cancel.params.dig('charges', 'data')[0].dig('amount_refunded')
    assert_equal 'canceled', cancel.params['status']
  end

  def test_create_intent_with_optional_idempotency_key_header
    idempotency_key = 'test123'
    options = @options.merge(idempotency_key: idempotency_key)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, _data, headers|
      assert_equal idempotency_key, headers['Idempotency-Key']
    end.respond_with(successful_create_intent_response)
  end

  def test_request_three_d_secure
    request_three_d_secure = 'any'
    options = @options.merge(request_three_d_secure: request_three_d_secure)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/\[request_three_d_secure\]=any/, data)
    end.respond_with(successful_request_three_d_secure_response)

    request_three_d_secure = 'automatic'
    options = @options.merge(request_three_d_secure: request_three_d_secure)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/\[request_three_d_secure\]=automatic/, data)
    end.respond_with(successful_request_three_d_secure_response)

    request_three_d_secure = true
    options = @options.merge(request_three_d_secure: request_three_d_secure)

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      refute_match(/\[request_three_d_secure\]/, data)
    end.respond_with(successful_request_three_d_secure_response)
  end

  def test_external_three_d_secure_auth_data
    options = @options.merge(
      three_d_secure: {
        eci: '05',
        cavv: '4BQwsg4yuKt0S1LI1nDZTcO9vUM=',
        xid: 'd+NEBKSpEMauwleRhdrDY06qj4A='
      }
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/payment_method_options\[card\]\[three_d_secure\]/, data)
      assert_match(/three_d_secure\]\[version\]=1.0.2/, data)
      assert_match(/three_d_secure\]\[electronic_commerce_indicator\]=05/, data)
      assert_match(/three_d_secure\]\[cryptogram\]=4BQwsg4yuKt0S1LI1nDZTcO9vUM%3D/, data)
      assert_match(/three_d_secure\]\[transaction_id\]=d%2BNEBKSpEMauwleRhdrDY06qj4A%3D/, data)
    end.respond_with(successful_request_three_d_secure_response)

    options = @options.merge(
      three_d_secure: {
        version: '2.1.0',
        eci: '02',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        ds_transaction_id: 'f879ea1c-aa2c-4441-806d-e30406466d79'
      }
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/payment_method_options\[card\]\[three_d_secure\]/, data)
      assert_match(/three_d_secure\]\[version\]=2.1.0/, data)
      assert_match(/three_d_secure\]\[electronic_commerce_indicator\]=02/, data)
      assert_match(/three_d_secure\]\[cryptogram\]=jJ81HADVRtXfCBATEp01CJUAAAA%3D/, data)
      assert_match(/three_d_secure\]\[transaction_id\]=f879ea1c-aa2c-4441-806d-e30406466d79/, data)
    end.respond_with(successful_request_three_d_secure_response)
  end

  def test_failed_capture_after_creation
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    assert create = @gateway.create_intent(@amount, 'pm_card_chargeDeclined', @options.merge(confirm: true))
    assert_equal 'requires_payment_method', create.params.dig('error', 'payment_intent', 'status')
    assert_equal false, create.params.dig('error', 'payment_intent', 'charges', 'data')[0].dig('captured')
    assert_equal 'ch_1F2MB6AWOtgoysogAIvNV32Z', create.authorization
  end

  def test_failed_void_after_capture
    @gateway.expects(:ssl_request).twice.returns(successful_capture_response, failed_cancel_response)
    assert create = @gateway.create_intent(@amount, @visa_token, @options.merge(confirm: true))
    assert_equal 'succeeded', create.params['status']
    intent_id = create.params['id']

    assert cancel = @gateway.void(intent_id, cancellation_reason: 'requested_by_customer')
    assert_equal 'You cannot cancel this PaymentIntent because ' \
      'it has a status of succeeded. Only a PaymentIntent with ' \
      'one of the following statuses may be canceled: ' \
      'requires_payment_method, requires_capture, requires_confirmation, requires_action.', cancel.message
  end

  def test_failed_verify
    @gateway.expects(:add_payment_method_token).returns(@visa_token)
    @gateway.expects(:ssl_request).returns(failed_verify_response)

    assert create = @gateway.verify(@credit_card)
    assert_equal "seti_nhtadoeunhtaobjntaheodu", create.authorization
  end

  def test_connected_account
    destination = 'account_27701'
    amount = 8000
    on_behalf_of = 'account_27704'
    transfer_group = 'TG1000'
    application_fee_amount = 100

    options = @options.merge(
      transfer_destination: destination,
      transfer_amount: amount,
      on_behalf_of: on_behalf_of,
      transfer_group: transfer_group,
      application_fee: application_fee_amount
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/transfer_data\[destination\]=#{destination}/, data)
      assert_match(/transfer_data\[amount\]=#{amount}/, data)
      assert_match(/on_behalf_of=#{on_behalf_of}/, data)
      assert_match(/transfer_group=#{transfer_group}/, data)
      assert_match(/application_fee_amount=#{application_fee_amount}/, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_on_behalf_of
    on_behalf_of = 'account_27704'

    options = @options.merge(
      on_behalf_of: on_behalf_of
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.create_intent(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_no_match(/transfer_data\[destination\]/, data)
      assert_no_match(/transfer_data\[amount\]/, data)
      assert_match(/on_behalf_of=#{on_behalf_of}/, data)
      assert_no_match(/transfer_group/, data)
      assert_no_match(/application_fee_amount/, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_failed_payment_methods_post
    @gateway.expects(:ssl_request).returns(failed_payment_method_response)

    assert create = @gateway.create_intent(@amount, 'pm_failed', @options)
    assert_equal 'validation_error', create.params.dig('error', 'code')
    assert_equal 'You must verify a phone number on your Stripe account before you can send raw credit card numbers to the Stripe API. You can avoid this requirement by using Stripe.js, the Stripe mobile bindings, or Stripe Checkout. For more information, see https://dashboard.stripe.com/phone-verification.', create.params.dig('error', 'message')
    assert_equal 'invalid_request_error', create.params.dig('error', 'type')
  end

  def test_invalid_test_login_for_sk_key
    gateway = StripePaymentIntentsGateway.new(login: 'sk_live_3422')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Invalid API Key provided', response.message
  end

  def test_invalid_test_login_for_rk_key
    gateway = StripePaymentIntentsGateway.new(login: 'rk_live_3422')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Invalid API Key provided', response.message
  end

  def test_successful_purchase
    gateway = StripePaymentIntentsGateway.new(login: '3422e230423s')

    stub_comms(gateway, :ssl_request) do
      gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_create_intent_response)
  end

  def test_failed_error_on_requires_action
    @gateway.expects(:ssl_request).returns(failed_with_set_error_on_requires_action_response)

    assert create = @gateway.create_intent(@amount, 'pm_failed', @options)
    assert_equal 'This payment required an authentication action to complete, but `error_on_requires_action` was set. When you\'re ready, you can upgrade your integration to handle actions at https://stripe.com/docs/payments/payment-intents/upgrade-to-handle-actions.', create.params.dig('error', 'message')
    assert_equal 'card_error', create.params.dig('error', 'type')
  end

  def test_failed_refund_due_to_service_unavailability
    @gateway.expects(:ssl_request).returns(failed_service_response)

    assert refund = @gateway.refund(@amount, 'pi_123')
    assert_failure refund
    assert_match(/Error while communicating with one of our backends/, refund.params.dig('error', 'message'))
  end

  def test_failed_refund_due_to_pending_3ds_auth
    @gateway.expects(:ssl_request).returns(successful_confirm_3ds2_intent_response)

    assert refund = @gateway.refund(@amount, 'pi_123')
    assert_failure refund
    assert_equal 'requires_action', refund.params['status']
    assert_match(/payment_intent has a status of requires_action/, refund.message)
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_verify_response)
    assert verify = @gateway.verify(@visa_token)
    assert_success verify
    assert_equal 'succeeded', verify.params['status']
  end

  def test_successful_purchase_with_level3_data
    @options[:merchant_reference] = 123
    @options[:customer_reference] = 456
    @options[:shipping_address_zip] = 98765
    @options[:shipping_from_zip] = 54321
    @options[:shipping_amount] = 40
    @options[:line_items] = [
      {
        'product_code' => 1234,
        'product_description' => 'An item',
        'unit_cost' => 60,
        'quantity' => 7,
        'tax_amount' => 0
      },
      {
        'product_code' => 999,
        'tax_amount' => 888
      }
    ]

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('level3[merchant_reference]=123', data)
      assert_match('level3[customer_reference]=456', data)
      assert_match('level3[shipping_address_zip]=98765', data)
      assert_match('level3[shipping_amount]=40', data)
      assert_match('level3[shipping_from_zip]=54321', data)
      assert_match('level3[line_items][0][product_description]=An+item', data)
      assert_match('level3[line_items][1][product_code]=999', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_purchase_with_card_brand
    @options[:card_brand] = 'cartes_bancaires'

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('payment_method_options[card][network]=cartes_bancaires', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_succesful_purchase_with_stored_credentials_without_sending_ntid
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      network_transaction_id = '1098510912210968'
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD',
          execute_threed: true,
          confirm: true,
          off_session: true,
          stored_credential_transaction_type: true,
          stored_credential: {
            initiator: 'cardholder',
            reason_type: 'installment',
            initial_transaction: true,
            network_transaction_id: network_transaction_id, # TEST env seems happy with any value :/
            ds_transaction_id: 'null' # this is optional and can be null if not available.
          }
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_no_match(%r{payment_method_options\[card\]\[mit_exemption\]\[network_transaction_id\]=}, data)
        assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[ds_transaction_id\]=null}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_succesful_purchase_with_ntid_when_off_session
    # don't send NTID if setup_future_usage == off_session
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      network_transaction_id = '1098510912210968'
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD',
          execute_threed: true,
          confirm: true,
          off_session: true,
          setup_future_usage: 'off_session',
          stored_credential: {
            initiator: 'cardholder',
            reason_type: 'installment',
            initial_transaction: true,
            network_transaction_id: network_transaction_id, # TEST env seems happy with any value :/
            ds_transaction_id: 'null' # this is optional and can be null if not available.
          }
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_no_match(%r{payment_method_options\[card\]\[mit_exemption\]\[network_transaction_id\]=}, data)
        assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[ds_transaction_id\]=null}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_succesful_purchase_with_stored_credentials
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      network_transaction_id = '1098510912210968'
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD',
          execute_threed: true,
          confirm: true,
          off_session: true,
          stored_credential: {
            network_transaction_id: network_transaction_id, # TEST env seems happy with any value :/
            ds_transaction_id: 'null' # this is optional and can be null if not available.
          }
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[network_transaction_id\]=#{network_transaction_id}}, data)
        assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[ds_transaction_id\]=null}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_succesful_purchase_with_stored_credentials_without_optional_ds_transaction_id
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      network_transaction_id = '1098510912210968'
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD',
          execute_threed: true,
          confirm: true,
          off_session: true,
          stored_credential: {
            network_transaction_id: network_transaction_id # TEST env seems happy with any value :/
          }
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[network_transaction_id\]=#{network_transaction_id}}, data)
        assert_no_match(%r{payment_method_options\[card\]\[mit_exemption\]\[ds_transaction_id\]=null}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_succesful_purchase_without_stored_credentials_introduces_no_exemption_fields
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD'
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_no_match(%r{payment_method_options\[card\]\[mit_exemption\]\[network_transaction_id\]=}, data)
        assert_no_match(%r{payment_method_options\[card\]\[mit_exemption\]\[ds_transaction_id\]=null}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_sends_network_transaction_id_separate_from_stored_creds
    network_transaction_id = '1098510912210968'
    options = @options.merge(
      network_transaction_id: network_transaction_id
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[network_transaction_id\]=#{network_transaction_id}}, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_sends_expand_balance_transaction
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('expand[0]=charges.data.balance_transaction', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_purchase_with_google_pay
    options = {
      currency: 'GBP'
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @google_pay, options)
    end.check_request do |_method, endpoint, data, _headers|
      assert_match('card[tokenization_method]=android_pay', data) if %r{/tokens}.match?(endpoint)
      assert_match('payment_method=pi_', data) if %r{/payment_intents}.match?(endpoint)
    end.respond_with(successful_create_intent_response)
  end

  def test_purchase_with_google_pay_with_billing_address
    options = {
      currency: 'GBP',
      billing_address: address
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @google_pay, options)
    end.check_request do |_method, endpoint, data, _headers|
      if %r{/tokens}.match?(endpoint)
        assert_match('card[name]=Jim+Smith', data)
        assert_match('card[tokenization_method]=android_pay', data)
        assert_match('card[address_line1]=456+My+Street', data)
      end
      assert_match('wallet[type]=google_pay', data) if %r{/wallet}.match?(endpoint)
      assert_match('payment_method=pi_', data) if %r{/payment_intents}.match?(endpoint)
    end.respond_with(successful_create_intent_response_with_google_pay_and_billing_address)
  end

  def test_purchase_with_network_token_card
    options = {
      currency: 'USD',
      last_4: '4242'
    }

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @network_token_credit_card, options)
    end.check_request do |_method, endpoint, data, _headers|
      assert_match(%r{/payment_intents}, endpoint)
      assert_match('confirm=true', data)
      assert_match('payment_method_data[type]=card', data)
      assert_match('[card][exp_month]=9', data)
      assert_match('[card][exp_year]=2030', data)
      assert_match('[card][last4]=4242', data)
      assert_match('[card][network_token][number]=4000056655665556', data)
      assert_match("[card][network_token][cryptogram]=#{URI.encode_www_form_component('dGVzdGNyeXB0b2dyYW1YWFhYWFhYWFhYWFg9PQ==')}", data)
      assert_match('[card][network_token][exp_month]=9', data)
      assert_match('[card][network_token][exp_year]=2030', data)
    end.respond_with(successful_create_intent_response_with_network_token_fields)
  end

  def test_purchase_with_shipping_options
    options = {
      currency: 'GBP',
      customer: 'abc123',
      shipping_address: {
        name: 'John Adam',
        phone_number: '+0018313818368',
        city: 'San Diego',
        country: 'USA',
        address1: 'block C',
        address2: 'street 48',
        zip: '22400',
        state: 'California',
        email: 'test@email.com'
      }
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('shipping[address][city]=San+Diego', data)
      assert_match('shipping[address][country]=USA', data)
      assert_match('shipping[address][line1]=block+C', data)
      assert_match('shipping[address][line2]=street+48', data)
      assert_match('shipping[address][postal_code]=22400', data)
      assert_match('shipping[address][state]=California', data)
      assert_match('shipping[name]=John+Adam', data)
      assert_match('shipping[phone]=%2B0018313818368', data)
      assert_no_match(/shipping[email]/, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_purchase_with_shipping_carrier_and_tracking_number
    options = {
      currency: 'GBP',
      shipping_address: {
        name: 'John Adam',
        address1: 'block C'
      },
      shipping_tracking_number: 'TXNABC123',
      shipping_carrier: 'FEDEX'
    }
    options[:customer] = @customer if defined?(@customer)
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('shipping[address][line1]=block+C', data)
      assert_match('shipping[name]=John+Adam', data)
      assert_match('shipping[carrier]=FEDEX', data)
      assert_match('shipping[tracking_number]=TXNABC123', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_authorize_with_apple_pay
    options = {
      currency: 'GBP'
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @apple_pay, options)
    end.check_request do |_method, endpoint, data, _headers|
      assert_match('card[tokenization_method]=apple_pay', data) if %r{/tokens}.match?(endpoint)
      assert_match('payment_method=pi_', data) if %r{/payment_intents}.match?(endpoint)
    end.respond_with(successful_create_intent_response)
  end

  def test_authorize_with_apple_pay_with_billing_address
    options = {
      currency: 'GBP',
      billing_address: address
    }
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @apple_pay, options)
    end.check_request do |_method, endpoint, data, _headers|
      assert_match('card[tokenization_method]=apple_pay', data) if %r{/tokens}.match?(endpoint)
      assert_match('card[address_line1]=456+My+Street', data) if %r{/tokens}.match?(endpoint)
      assert_match('payment_method=pi_', data) if %r{/payment_intents}.match?(endpoint)
    end.respond_with(successful_create_intent_response_with_apple_pay_and_billing_address)
  end

  def test_stored_credentials_does_not_override_ntid_field
    network_transaction_id = '1098510912210968'
    sc_network_transaction_id = '1078784111114777'
    options = @options.merge(
      network_transaction_id: network_transaction_id,
      stored_credential: {
        network_transaction_id: sc_network_transaction_id,
        ds_transaction_id: 'null'
      }
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[network_transaction_id\]=#{network_transaction_id}}, data)
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_off_session_intent_creation_when_claim_without_transaction_id_present
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD',
          execute_threed: true,
          confirm: true,
          off_session: true,
          claim_without_transaction_id: true
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_match(%r{payment_method_options\[card\]\[mit_exemption\]\[claim_without_transaction_id\]=true}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_successful_off_session_intent_creation_when_claim_without_transaction_id_is_false
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD',
          execute_threed: true,
          confirm: true,
          off_session: true,
          claim_without_transaction_id: false
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_no_match(%r{payment_method_options\[card\]\[mit_exemption\]\[claim_without_transaction_id\]}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_successful_off_session_intent_creation_without_claim_without_transaction_id
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      stub_comms(@gateway, :ssl_request) do
        @gateway.purchase(@amount, card_to_use, {
          currency: 'USD',
          execute_threed: true,
          confirm: true,
          off_session: true
        })
      end.check_request do |_method, _endpoint, data, _headers|
        assert_no_match(%r{payment_method_options\[card\]\[mit_exemption\]\[claim_without_transaction_id\]}, data)
      end.respond_with(successful_create_intent_response)
    end
  end

  def test_store_does_not_pass_validation_to_attach_by_default
    stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card)
    end.check_request do |_method, endpoint, data, _headers|
      assert_no_match(/validate=/, data) if /attach/.match?(endpoint)
    end.respond_with(successful_payment_method_response, successful_create_customer_response, successful_payment_method_attach_response)
  end

  def test_store_sets_validation_on_attach_to_false_when_false_in_options
    options = @options.merge(
      validate: false
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, options)
    end.check_request do |_method, endpoint, data, _headers|
      assert_match(/validate=false/, data) if /attach/.match?(endpoint)
    end.respond_with(successful_payment_method_response, successful_create_customer_response, successful_payment_method_attach_response)
  end

  def test_store_sets_validationon_attach_to_true_when_true_in_options
    options = @options.merge(
      validate: true
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, options)
    end.check_request do |_method, endpoint, data, _headers|
      assert_match(/validate=true/, data) if /attach/.match?(endpoint)
    end.respond_with(successful_payment_method_response, successful_create_customer_response, successful_payment_method_attach_response)
  end

  def test_succesful_purchase_with_radar_session
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, {
        radar_session_id: 'test_radar_session_id'
      })
    end.check_request do |_method, endpoint, data, _headers|
      assert_match(/radar_options\[session\]=test_radar_session_id/, data) if /payment_intents/.match?(endpoint)
    end.respond_with(successful_create_intent_response)
  end

  def test_succesful_authorize_with_radar_session
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, {
        radar_session_id: 'test_radar_session_id'
      })
    end.check_request do |_method, endpoint, data, _headers|
      assert_match(/radar_options\[session\]=test_radar_session_id/, data) if /payment_intents/.match?(endpoint)
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_authorize_with_skip_radar_rules
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, {
        skip_radar_rules: true
      })
    end.check_request do |_method, endpoint, data, _headers|
      assert_match(/radar_options\[skip_rules\]\[0\]=all/, data) if /payment_intents/.match?(endpoint)
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_authorization_with_event_type_metadata
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, {
        email: 'wow@example.com',
        event_type: 'concert'
      })
    end.check_request do |_method, endpoint, data, _headers|
      if /payment_intents/.match?(endpoint)
        assert_match(/metadata\[email\]=wow%40example.com/, data)
        assert_match(/metadata\[event_type\]=concert/, data)
      end
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_setup_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.setup_purchase(@amount, { payment_method_types: %w[afterpay_clearpay card] })
    end.check_request do |_method, endpoint, data, _headers|
      assert_match(/payment_method_types\[0\]=afterpay_clearpay&payment_method_types\[1\]=card/, data) if /payment_intents/.match?(endpoint)
    end.respond_with(successful_setup_purchase)
  end

  def test_supported_countries
    countries = %w(AE AT AU BE BG BR CA CH CY CZ DE DK EE ES FI FR GB GR HK HU IE IN IT JP LT LU LV MT MX MY NL NO NZ PL PT RO SE SG SI SK US)
    assert_equal countries.sort, StripePaymentIntentsGateway.supported_countries.sort
  end

  def test_scrub_filter_token
    assert_equal @gateway.scrub(pre_scrubbed), scrubbed
  end

  def test_succesful_purchase_with_initial_cit_unscheduled
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, {
        currency: 'USD',
        confirm: true,
        stored_credential_transaction_type: true,
        stored_credential: {
          initial_transaction: true,
          initiator: 'cardholder',
          reason_type: 'unscheduled'
        }
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('payment_method_options[card][stored_credential_transaction_type]=setup_off_session_unscheduled', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_succesful_purchase_with_initial_cit_recurring
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, {
        currency: 'USD',
        confirm: true,
        stored_credential_transaction_type: true,
        stored_credential: {
          initial_transaction: true,
          initiator: 'cardholder',
          reason_type: 'recurring'
        }
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('payment_method_options[card][stored_credential_transaction_type]=setup_off_session_recurring', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_succesful_purchase_with_initial_cit_installment
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, {
        currency: 'USD',
        confirm: true,
        stored_credential_transaction_type: true,
        stored_credential: {
          initial_transaction: true,
          initiator: 'cardholder',
          reason_type: 'installment'
        }
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('payment_method_options[card][stored_credential_transaction_type]=setup_on_session', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_succesful_purchase_with_subsequent_cit
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, {
        currency: 'USD',
        confirm: true,
        stored_credential_transaction_type: true,
        stored_credential: {
          initial_transaction: false,
          initiator: 'cardholder',
          reason_type: 'installment'
        }
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('payment_method_options[card][stored_credential_transaction_type]=stored_on_session', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_succesful_purchase_with_mit_recurring
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, {
        currency: 'USD',
        confirm: true,
        stored_credential_transaction_type: true,
        stored_credential: {
          initial_transaction: false,
          initiator: 'merchant',
          reason_type: 'recurring'
        }
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('payment_method_options[card][stored_credential_transaction_type]=stored_off_session_recurring', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_succesful_purchase_with_mit_unscheduled
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @visa_token, {
        currency: 'USD',
        confirm: true,
        stored_credential_transaction_type: true,
        stored_credential: {
          initial_transaction: false,
          initiator: 'merchant',
          reason_type: 'unscheduled'
        }
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match('payment_method_options[card][stored_credential_transaction_type]=stored_off_session_unscheduled', data)
    end.respond_with(successful_create_intent_response)
  end

  def test_successful_avs_and_cvc_check
    @gateway.expects(:ssl_request).returns(successful_purchase_avs_pass)
    options = {}
    assert purchase = @gateway.purchase(@amount, @visa_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert_equal 'M', purchase.cvv_result.dig('code')
    assert_equal 'CVV matches', purchase.cvv_result.dig('message')
    assert_equal 'Y', purchase.avs_result.dig('code')
  end

  private

  def successful_setup_purchase
    <<-RESPONSE
    {
      "id": "pi_3Jr0wXAWOtgoysog2Sp0iKjo",
      "object": "payment_intent",
      "amount": 2000,
      "amount_capturable": 0,
      "amount_received": 0,
      "application": null,
      "application_fee_amount": null,
      "canceled_at": null,
      "cancellation_reason": null,
      "capture_method": "automatic",
      "charges": {
        "object": "list",
        "data": [

        ],
        "has_more": false,
        "total_count": 0,
        "url": "/v1/charges?payment_intent=pi_3Jr0wXAWOtgoysog2Sp0iKjo"
      },
      "client_secret": "pi_3Jr0wXAWOtgoysog2Sp0iKjo_secret_1l5cE3MskZ8AMOZaNdpmgZDCn",
      "confirmation_method": "automatic",
      "created": 1635774777,
      "currency": "usd",
      "customer": null,
      "description": null,
      "invoice": null,
      "last_payment_error": null,
      "livemode": false,
      "metadata": {
      },
      "next_action": null,
      "on_behalf_of": null,
      "payment_method": null,
      "payment_method_options": {
        "afterpay_clearpay": {
          "reference": null
        },
        "card": {
          "installments": null,
          "network": null,
          "request_three_d_secure": "automatic"
        }
      },
      "payment_method_types": [
        "afterpay_clearpay",
        "card"
      ],
      "receipt_email": null,
      "review": null,
      "setup_future_usage": null,
      "shipping": null,
      "source": null,
      "statement_descriptor": null,
      "statement_descriptor_suffix": null,
      "status": "requires_payment_method",
      "transfer_data": null,
      "transfer_group": null
    }
    RESPONSE
  end

  def successful_create_intent_response
    <<-RESPONSE
      {"id":"pi_1F1xauAWOtgoysogIfHO8jGi","object":"payment_intent","amount":2020,"amount_capturable":2020,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"manual","charges":{"object":"list","data":[{"id":"ch_1F1xavAWOtgoysogxrtSiCu4","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":null,"billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":false,"created":1564501833,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":58,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F1xauAWOtgoysogIfHO8jGi","payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F1xavAWOtgoysogxrtSiCu4/rcpt_FX1eGdFRi8ssOY8Fqk4X6nEjNeGV5PG","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F1xavAWOtgoysogxrtSiCu4/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F1xauAWOtgoysogIfHO8jGi"},"client_secret":"pi_1F1xauAWOtgoysogIfHO8jGi_secret_ZrXvfydFv0BelaMQJgHxjts5b","confirmation_method":"manual","created":1564501832,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"requires_capture","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_create_intent_response_with_network_token_fields
    <<~RESPONSE
      {
        "id": "pi_3NfRruAWOtgoysog1FxgDwtf",
        "object": "payment_intent",
        "amount": 2000,
        "amount_capturable": 0,
        "amount_details": {
          "tip": {
          }
        },
        "amount_received": 2000,
        "application": null,
        "application_fee_amount": null,
        "automatic_payment_methods": null,
        "canceled_at": null,
        "cancellation_reason": null,
        "capture_method": "automatic",
        "charges": {
          "object": "list",
          "data": [
            {
              "id": "ch_3NfRruAWOtgoysog1ptwVNHx",
              "object": "charge",
              "amount": 2000,
              "amount_captured": 2000,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_3NfRruAWOtgoysog1mtFHzZr",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": "Longbob Longsen",
                "phone": null
              },
              "calculated_statement_descriptor": "SPREEDLY",
              "captured": true,
              "created": 1692123686,
              "currency": "usd",
              "customer": null,
              "description": null,
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {
              },
              "invoice": null,
              "livemode": false,
              "metadata": {
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 34,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": "pi_3NfRruAWOtgoysog1FxgDwtf",
              "payment_method": "pm_1NfRruAWOtgoysogjdx336vt",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": "pass"
                  },
                  "country": "US",
                  "ds_transaction_id": null,
                  "exp_month": 9,
                  "exp_year": 2030,
                  "fingerprint": null,
                  "funding": "debit",
                  "installments": null,
                  "last4": "4242",
                  "mandate": null,
                  "moto": null,
                  "network": "visa",
                  "network_token": {
                    "exp_month": 9,
                    "exp_year": 2030,
                    "fingerprint": "OdTRtGskBulROtqa",
                    "last4": "5556",
                    "used": false
                  },
                  "network_transaction_id": "791008482116711",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcaFwoVYWNjdF8xNjBEWDZBV090Z295c29nKKeE76YGMgbjse9I0TM6LBZ6z9Y1XXMETb-LDQ5oyLVXQhIMltBU0qwDkNKpNvrIGvXOhYmhorDkkE36",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_3NfRruAWOtgoysog1ptwVNHx/refunds"
              },
              "review": null,
              "shipping": null,
              "source": null,
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          ],
          "has_more": false,
          "total_count": 1,
          "url": "/v1/charges?payment_intent=pi_3NfRruAWOtgoysog1FxgDwtf"
        },
        "client_secret": "pi_3NfRruAWOtgoysog1FxgDwtf_secret_f4ke",
        "confirmation_method": "automatic",
        "created": 1692123686,
        "currency": "usd",
        "customer": null,
        "description": null,
        "invoice": null,
        "last_payment_error": null,
        "latest_charge": "ch_3NfRruAWOtgoysog1ptwVNHx",
        "level3": null,
        "livemode": false,
        "metadata": {
        },
        "next_action": null,
        "on_behalf_of": null,
        "payment_method": "pm_1NfRruAWOtgoysogjdx336vt",
        "payment_method_options": {
          "card": {
            "installments": null,
            "mandate_options": null,
            "network": null,
            "request_three_d_secure": "automatic"
          }
        },
        "payment_method_types": [
          "card"
        ],
        "processing": null,
        "receipt_email": null,
        "review": null,
        "setup_future_usage": null,
        "shipping": null,
        "source": null,
        "statement_descriptor": null,
        "statement_descriptor_suffix": null,
        "status": "succeeded",
        "transfer_data": null,
        "transfer_group": null
      }
    RESPONSE
  end

  def successful_create_intent_manual_capture_response_with_network_token_fields
    <<~RESPONSE
      {
        "id": "pi_3NfTpgAWOtgoysog1SqST5dL",
        "object": "payment_intent",
        "amount": 2000,
        "amount_capturable": 2000,
        "amount_details": {
          "tip": {
          }
        },
        "amount_received": 0,
        "application": null,
        "application_fee_amount": null,
        "automatic_payment_methods": null,
        "canceled_at": null,
        "cancellation_reason": null,
        "capture_method": "manual",
        "charges": {
          "object": "list",
          "data": [
            {
              "id": "ch_3NfTpgAWOtgoysog1ZcuSdwZ",
              "object": "charge",
              "amount": 2000,
              "amount_captured": 0,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": null,
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": "Longbob Longsen",
                "phone": null
              },
              "calculated_statement_descriptor": "SPREEDLY",
              "captured": false,
              "created": 1692131237,
              "currency": "gbp",
              "customer": "cus_OSOcijtQkDdBbF",
              "description": null,
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {
              },
              "invoice": null,
              "livemode": false,
              "metadata": {
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 24,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": "pi_3NfTpgAWOtgoysog1SqST5dL",
              "payment_method": "pm_1NfTpgAWOtgoysogHnl1rNCf",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": "pass"
                  },
                  "country": "US",
                  "ds_transaction_id": null,
                  "exp_month": 9,
                  "exp_year": 2030,
                  "fingerprint": null,
                  "funding": "debit",
                  "installments": null,
                  "last4": "4242",
                  "mandate": null,
                  "moto": null,
                  "network": "visa",
                  "network_token": {
                    "exp_month": 9,
                    "exp_year": 2030,
                    "fingerprint": "OdTRtGskBulROtqa",
                    "last4": "5556",
                    "used": false
                  },
                  "network_transaction_id": "791008482116711",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcaFwoVYWNjdF8xNjBEWDZBV090Z295c29nKKW_76YGMgZFk46uT_Y6LBZ51LZOrwdCQ0w176ShWIhNs2CXEh-L6A9pDYW33I_z6C6SenKNrWasw9Ie",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_3NfTpgAWOtgoysog1ZcuSdwZ/refunds"
              },
              "review": null,
              "shipping": null,
              "source": null,
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          ],
          "has_more": false,
          "total_count": 1,
          "url": "/v1/charges?payment_intent=pi_3NfTpgAWOtgoysog1SqST5dL"
        },
        "client_secret": "pi_3NfRruAWOtgoysog1FxgDwtf_secret_f4ke",
        "confirmation_method": "manual",
        "created": 1692131236,
        "currency": "gbp",
        "customer": "cus_OSOcijtQkDdBbF",
        "description": null,
        "invoice": null,
        "last_payment_error": null,
        "latest_charge": "ch_3NfTpgAWOtgoysog1ZcuSdwZ",
        "level3": null,
        "livemode": false,
        "metadata": {
        },
        "next_action": null,
        "on_behalf_of": null,
        "payment_method": "pm_1NfTpgAWOtgoysogHnl1rNCf",
        "payment_method_options": {
          "card": {
            "installments": null,
            "mandate_options": null,
            "network": null,
            "request_three_d_secure": "automatic"
          }
        },
        "payment_method_types": [
          "card"
        ],
        "processing": null,
        "receipt_email": null,
        "review": null,
        "setup_future_usage": null,
        "shipping": null,
        "source": null,
        "statement_descriptor": null,
        "statement_descriptor_suffix": null,
        "status": "requires_capture",
        "transfer_data": null,
        "transfer_group": null
      }
    RESPONSE
  end

  def successful_manual_capture_of_payment_intent_response_with_network_token_fields
    <<-RESPONSE
      {
        "id": "pi_3NfTpgAWOtgoysog1SqST5dL",
        "object": "payment_intent",
        "amount": 2000,
        "amount_capturable": 0,
        "amount_details": {
          "tip": {
          }
        },
        "amount_received": 2000,
        "application": null,
        "application_fee_amount": null,
        "automatic_payment_methods": null,
        "canceled_at": null,
        "cancellation_reason": null,
        "capture_method": "manual",
        "charges": {
          "object": "list",
          "data": [
            {
              "id": "ch_3NfTpgAWOtgoysog1ZcuSdwZ",
              "object": "charge",
              "amount": 2000,
              "amount_captured": 2000,
              "amount_refunded": 0,
              "application": null,
              "application_fee": null,
              "application_fee_amount": null,
              "balance_transaction": "txn_3NfTpgAWOtgoysog1ZTZXCvO",
              "billing_details": {
                "address": {
                  "city": null,
                  "country": null,
                  "line1": null,
                  "line2": null,
                  "postal_code": null,
                  "state": null
                },
                "email": null,
                "name": "Longbob Longsen",
                "phone": null
              },
              "calculated_statement_descriptor": "SPREEDLY",
              "captured": true,
              "created": 1692131237,
              "currency": "gbp",
              "customer": "cus_OSOcijtQkDdBbF",
              "description": null,
              "destination": null,
              "dispute": null,
              "disputed": false,
              "failure_balance_transaction": null,
              "failure_code": null,
              "failure_message": null,
              "fraud_details": {
              },
              "invoice": null,
              "livemode": false,
              "metadata": {
              },
              "on_behalf_of": null,
              "order": null,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 24,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": "pi_3NfTpgAWOtgoysog1SqST5dL",
              "payment_method": "pm_1NfTpgAWOtgoysogHnl1rNCf",
              "payment_method_details": {
                "card": {
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": null,
                    "address_postal_code_check": null,
                    "cvc_check": "pass"
                  },
                  "country": "US",
                  "ds_transaction_id": null,
                  "exp_month": 9,
                  "exp_year": 2030,
                  "fingerprint": null,
                  "funding": "debit",
                  "installments": null,
                  "last4": "4242",
                  "mandate": null,
                  "moto": null,
                  "network": "visa",
                  "network_token": {
                    "exp_month": 9,
                    "exp_year": 2030,
                    "fingerprint": "OdTRtGskBulROtqa",
                    "last4": "5556",
                    "used": false
                  },
                  "network_transaction_id": "791008482116711",
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_email": null,
              "receipt_number": null,
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcaFwoVYWNjdF8xNjBEWDZBV090Z295c29nKKa_76YGMgZZ4Fl_Etg6LBYGcD6D2xFTlgp69zLDZz1ZToBrKKjxhRCpYcnLWInSmJZHcjcBdrhyAKGv",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [
                ],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_3NfTpgAWOtgoysog1ZcuSdwZ/refunds"
              },
              "review": null,
              "shipping": null,
              "source": null,
              "source_transfer": null,
              "statement_descriptor": null,
              "statement_descriptor_suffix": null,
              "status": "succeeded",
              "transfer_data": null,
              "transfer_group": null
            }
          ],
          "has_more": false,
          "total_count": 1,
          "url": "/v1/charges?payment_intent=pi_3NfTpgAWOtgoysog1SqST5dL"
        },
         "client_secret": "pi_3NfRruAWOtgoysog1FxgDwtf_secret_f4ke",
        "confirmation_method": "manual",
        "created": 1692131236,
        "currency": "gbp",
        "customer": "cus_OSOcijtQkDdBbF",
        "description": null,
        "invoice": null,
        "last_payment_error": null,
        "latest_charge": "ch_3NfTpgAWOtgoysog1ZcuSdwZ",
        "level3": null,
        "livemode": false,
        "metadata": {
        },
        "next_action": null,
        "on_behalf_of": null,
        "payment_method": "pm_1NfTpgAWOtgoysogHnl1rNCf",
        "payment_method_options": {
          "card": {
            "installments": null,
            "mandate_options": null,
            "network": null,
            "request_three_d_secure": "automatic"
          }
        },
        "payment_method_types": [
          "card"
        ],
        "processing": null,
        "receipt_email": null,
        "review": null,
        "setup_future_usage": null,
        "shipping": null,
        "source": null,
        "statement_descriptor": null,
        "statement_descriptor_suffix": null,
        "status": "succeeded",
        "transfer_data": null,
        "transfer_group": null
        }
    RESPONSE
  end

  def successful_create_intent_response_with_apple_pay_and_billing_address
    <<-RESPONSE
      {"id"=>"pi_3N0mqdAWOtgoysog1IQeiLiz", "object"=>"payment_intent", "amount"=>2000, "amount_capturable"=>0, "amount_details"=>{"tip"=>{}}, "amount_received"=>2000, "application"=>nil, "application_fee_amount"=>nil, "automatic_payment_methods"=>nil, "canceled_at"=>nil, "cancellation_reason"=>nil, "capture_method"=>"automatic", "charges"=>{"object"=>"list", "data"=>[{"id"=>"ch_3N0mqdAWOtgoysog1HddFSKg", "object"=>"charge", "amount"=>2000, "amount_captured"=>2000, "amount_refunded"=>0, "application"=>nil, "application_fee"=>nil, "application_fee_amount"=>nil, "balance_transaction"=>"txn_3N0mqdAWOtgoysog1EpiFDCD", "billing_details"=>{"address"=>{"city"=>"Ottawa", "country"=>"CA", "line1"=>"456 My Street", "line2"=>"Apt 1", "postal_code"=>"K1C2N6", "state"=>"ON"}, "email"=>nil, "name"=>nil, "phone"=>nil}, "calculated_statement_descriptor"=>"SPREEDLY", "captured"=>true, "created"=>1682432883, "currency"=>"gbp", "customer"=>nil, "description"=>nil, "destination"=>nil, "dispute"=>nil, "disputed"=>false, "failure_balance_transaction"=>nil, "failure_code"=>nil, "failure_message"=>nil, "fraud_details"=>{}, "invoice"=>nil, "livemode"=>false, "metadata"=>{}, "on_behalf_of"=>nil, "order"=>nil, "outcome"=>{"network_status"=>"approved_by_network", "reason"=>nil, "risk_level"=>"normal", "risk_score"=>15, "seller_message"=>"Payment complete.", "type"=>"authorized"}, "paid"=>true, "payment_intent"=>"pi_3N0mqdAWOtgoysog1IQeiLiz", "payment_method"=>"pm_1N0mqdAWOtgoysogloANIhUF", "payment_method_details"=>{"card"=>{"brand"=>"visa", "checks"=>{"address_line1_check"=>"pass", "address_postal_code_check"=>"pass", "cvc_check"=>nil}, "country"=>"US", "ds_transaction_id"=>nil, "exp_month"=>9, "exp_year"=>2030, "fingerprint"=>"hfaVNMiXc0dYSiC5", "funding"=>"credit", "installments"=>nil, "last4"=>"0000", "mandate"=>nil, "moto"=>nil, "network"=>"visa", "network_token"=>{"used"=>false}, "network_transaction_id"=>"104102978678771", "three_d_secure"=>nil, "wallet"=>{"apple_pay"=>{"type"=>"apple_pay"}, "dynamic_last4"=>"4242", "type"=>"apple_pay"}}, "type"=>"card"}, "receipt_email"=>nil, "receipt_number"=>nil, "receipt_url"=>"https://pay.stripe.com/receipts/payment/CAcaFwoVYWNjdF8xNjBEWDZBV090Z295c29nKPTGn6IGMgZMGrHHLa46LBY0n2_9_Yar0wPTNukle4t28eKG0ZDZnxGYr6GyKn8VsKIEVjU4NkW8NHTL", "refunded"=>false, "refunds"=>{"object"=>"list", "data"=>[], "has_more"=>false, "total_count"=>0, "url"=>"/v1/charges/ch_3N0mqdAWOtgoysog1HddFSKg/refunds"}, "review"=>nil, "shipping"=>nil, "source"=>nil, "source_transfer"=>nil, "statement_descriptor"=>nil, "statement_descriptor_suffix"=>nil, "status"=>"succeeded", "transfer_data"=>nil, "transfer_group"=>nil}], "has_more"=>false, "total_count"=>1, "url"=>"/v1/charges?payment_intent=pi_3N0mqdAWOtgoysog1IQeiLiz"}, "client_secret"=>"pi_3N0mqdAWOtgoysog1IQeiLiz_secret_laDLUM6rVleLRqz0nMus9HktB", "confirmation_method"=>"automatic", "created"=>1682432883, "currency"=>"gbp", "customer"=>nil, "description"=>nil, "invoice"=>nil, "last_payment_error"=>nil, "latest_charge"=>"ch_3N0mqdAWOtgoysog1HddFSKg", "level3"=>nil, "livemode"=>false, "metadata"=>{}, "next_action"=>nil, "on_behalf_of"=>nil, "payment_method"=>"pm_1N0mqdAWOtgoysogloANIhUF", "payment_method_options"=>{"card"=>{"installments"=>nil, "mandate_options"=>nil, "network"=>nil, "request_three_d_secure"=>"automatic"}}, "payment_method_types"=>["card"], "processing"=>nil, "receipt_email"=>nil, "review"=>nil, "setup_future_usage"=>nil, "shipping"=>nil, "source"=>nil, "statement_descriptor"=>nil, "statement_descriptor_suffix"=>nil, "status"=>"succeeded", "transfer_data"=>nil, "transfer_group"=>nil}
    RESPONSE
  end

  def successful_create_intent_response_with_google_pay_and_billing_address
    <<-RESPONSE
      {"id"=>"pi_3N0nKLAWOtgoysog3cRTGUqD", "object"=>"payment_intent", "amount"=>2000, "amount_capturable"=>0, "amount_details"=>{"tip"=>{}}, "amount_received"=>2000, "application"=>nil, "application_fee_amount"=>nil, "automatic_payment_methods"=>nil, "canceled_at"=>nil, "cancellation_reason"=>nil, "capture_method"=>"automatic", "charges"=>{"object"=>"list", "data"=>[{"id"=>"ch_3N0nKLAWOtgoysog3npJdWNI", "object"=>"charge", "amount"=>2000, "amount_captured"=>2000, "amount_refunded"=>0, "application"=>nil, "application_fee"=>nil, "application_fee_amount"=>nil, "balance_transaction"=>"txn_3N0nKLAWOtgoysog3ZAmtAMT", "billing_details"=>{"address"=>{"city"=>"Ottawa", "country"=>"CA", "line1"=>"456 My Street", "line2"=>"Apt 1", "postal_code"=>"K1C2N6", "state"=>"ON"}, "email"=>nil, "name"=>nil, "phone"=>nil}, "calculated_statement_descriptor"=>"SPREEDLY", "captured"=>true, "created"=>1682434726, "currency"=>"gbp", "customer"=>nil, "description"=>nil, "destination"=>nil, "dispute"=>nil, "disputed"=>false, "failure_balance_transaction"=>nil, "failure_code"=>nil, "failure_message"=>nil, "fraud_details"=>{}, "invoice"=>nil, "livemode"=>false, "metadata"=>{}, "on_behalf_of"=>nil, "order"=>nil, "outcome"=>{"network_status"=>"approved_by_network", "reason"=>nil, "risk_level"=>"normal", "risk_score"=>61, "seller_message"=>"Payment complete.", "type"=>"authorized"}, "paid"=>true, "payment_intent"=>"pi_3N0nKLAWOtgoysog3cRTGUqD", "payment_method"=>"pm_1N0nKLAWOtgoysoglKSvcZz9", "payment_method_details"=>{"card"=>{"brand"=>"visa", "checks"=>{"address_line1_check"=>"pass", "address_postal_code_check"=>"pass", "cvc_check"=>nil}, "country"=>"US", "ds_transaction_id"=>nil, "exp_month"=>9, "exp_year"=>2030, "fingerprint"=>"hfaVNMiXc0dYSiC5", "funding"=>"credit", "installments"=>nil, "last4"=>"0000", "mandate"=>nil, "moto"=>nil, "network"=>"visa", "network_token"=>{"used"=>false}, "network_transaction_id"=>"104102978678771", "three_d_secure"=>nil, "wallet"=>{"dynamic_last4"=>"4242", "google_pay"=>{}, "type"=>"google_pay"}}, "type"=>"card"}, "receipt_email"=>nil, "receipt_number"=>nil, "receipt_url"=>"https://pay.stripe.com/receipts/payment/CAcaFwoVYWNjdF8xNjBEWDZBV090Z295c29nKKbVn6IGMgbEjx6eavI6LBZciyBuj3wwsvIi6Fdr1gNyM807fxUBTGDg2j_1c42EB8vLZl4KcSJA0otk", "refunded"=>false, "refunds"=>{"object"=>"list", "data"=>[], "has_more"=>false, "total_count"=>0, "url"=>"/v1/charges/ch_3N0nKLAWOtgoysog3npJdWNI/refunds"}, "review"=>nil, "shipping"=>nil, "source"=>nil, "source_transfer"=>nil, "statement_descriptor"=>nil, "statement_descriptor_suffix"=>nil, "status"=>"succeeded", "transfer_data"=>nil, "transfer_group"=>nil}], "has_more"=>false, "total_count"=>1, "url"=>"/v1/charges?payment_intent=pi_3N0nKLAWOtgoysog3cRTGUqD"}, "client_secret"=>"pi_3N0nKLAWOtgoysog3cRTGUqD_secret_L4UFErMf6H4itOcZrZRqTwsuA", "confirmation_method"=>"automatic", "created"=>1682434725, "currency"=>"gbp", "customer"=>nil, "description"=>nil, "invoice"=>nil, "last_payment_error"=>nil, "latest_charge"=>"ch_3N0nKLAWOtgoysog3npJdWNI", "level3"=>nil, "livemode"=>false, "metadata"=>{}, "next_action"=>nil, "on_behalf_of"=>nil, "payment_method"=>"pm_1N0nKLAWOtgoysoglKSvcZz9", "payment_method_options"=>{"card"=>{"installments"=>nil, "mandate_options"=>nil, "network"=>nil, "request_three_d_secure"=>"automatic"}}, "payment_method_types"=>["card"], "processing"=>nil, "receipt_email"=>nil, "review"=>nil, "setup_future_usage"=>nil, "shipping"=>nil, "source"=>nil, "statement_descriptor"=>nil, "statement_descriptor_suffix"=>nil, "status"=>"succeeded", "transfer_data"=>nil, "transfer_group"=>nil}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {"id":"pi_1F1xauAWOtgoysogIfHO8jGi","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":2020,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"manual","charges":{"object":"list","data":[{"id":"ch_1F1xavAWOtgoysogxrtSiCu4","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":"txn_1F1xawAWOtgoysog27xGBjM6","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":true,"created":1564501833,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":58,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F1xauAWOtgoysogIfHO8jGi","payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F1xavAWOtgoysogxrtSiCu4/rcpt_FX1eGdFRi8ssOY8Fqk4X6nEjNeGV5PG","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F1xavAWOtgoysogxrtSiCu4/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F1xauAWOtgoysogIfHO8jGi"},"client_secret":"pi_1F1xauAWOtgoysogIfHO8jGi_secret_ZrXvfydFv0BelaMQJgHxjts5b","confirmation_method":"manual","created":1564501832,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1xauAWOtgoysog00COoKIU","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      {"id":"pi_1F1yBVAWOtgoysogearamRvl","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":1564504103,"cancellation_reason":"requested_by_customer","capture_method":"manual","charges":{"object":"list","data":[{"id":"ch_1F1yBWAWOtgoysog1MQfDpJH","object":"charge","amount":2020,"amount_refunded":2020,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":null,"billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":false,"created":1564504102,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":46,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F1yBVAWOtgoysogearamRvl","payment_method":"pm_1F1yBVAWOtgoysogddy4E3hL","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F1yBWAWOtgoysog1MQfDpJH/rcpt_FX2Go3YHBqAYQPJuKGMeab3nyCU0Kks","refunded":true,"refunds":{"object":"list","data":[{"id":"re_1F1yBXAWOtgoysog0PU371Yz","object":"refund","amount":2020,"balance_transaction":null,"charge":"ch_1F1yBWAWOtgoysog1MQfDpJH","created":1564504103,"currency":"gbp","metadata":{},"reason":"requested_by_customer","receipt_number":null,"source_transfer_reversal":null,"status":"succeeded","transfer_reversal":null}],"has_more":false,"total_count":1,"url":"/v1/charges/ch_1F1yBWAWOtgoysog1MQfDpJH/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F1yBVAWOtgoysogearamRvl"},"client_secret":"pi_1F1yBVAWOtgoysogearamRvl_secret_oCnlR2t0GPclqACgHt2rst4gM","confirmation_method":"manual","created":1564504101,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1yBVAWOtgoysogddy4E3hL","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"canceled","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_update_intent_response
    <<-RESPONSE
      {"id":"pi_1F1yBbAWOtgoysog52J88BuO","object":"payment_intent","amount":2050,"amount_capturable":0,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"manual","charges":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges?payment_intent=pi_1F1yBbAWOtgoysog52J88BuO"},"client_secret":"pi_1F1yBbAWOtgoysog52J88BuO_secret_olw5rmbtm7cd72S9JfbKjTJJv","confirmation_method":"manual","created":1564504107,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F1yBbAWOtgoysoguJQsDdYj","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"requires_confirmation","transfer_data":null,"transfer_group":null}
    RESPONSE
  end

  def successful_create_3ds2_payment_method
    <<-RESPONSE
      {
        "id": "pm_1F1xK0AWOtgoysogfPuRKN1d",
        "object": "payment_method",
        "billing_details": {
          "address": {"city": null,
            "country": null,
            "line1": null,
            "line2": null,
            "postal_code": null,
            "state": null},
          "email": null,
          "name": null,
          "phone": null},
        "card": {
          "brand": "visa",
          "checks": {"address_line1_check": null,
            "address_postal_code_check": null,
            "cvc_check": "unchecked"},
          "country": null,
          "exp_month": 10,
          "exp_year": 2020,
          "fingerprint": "l3J0NJaGgv0jAGLV",
          "funding": "credit",
          "generated_from": null,
          "last4": "3220",
          "three_d_secure_usage": {"supported": true},
          "wallet": null},
        "created": 1564500784,
        "customer": null,
        "livemode": false,
        "metadata": {},
        "type": "card"
      }
    RESPONSE
  end

  def successful_create_3ds2_intent_response
    <<-RESPONSE
      {
        "id": "pi_1F1wpFAWOtgoysog8nTulYGk",
        "object": "payment_intent",
        "amount": 2020,
        "amount_capturable": 0,
        "amount_received": 0,
        "application": null,
        "application_fee_amount": null,
        "canceled_at": null,
        "cancellation_reason": null,
        "capture_method": "manual",
        "charges": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/charges?payment_intent=pi_1F1wpFAWOtgoysog8nTulYGk"
          },
        "client_secret": "pi_1F1wpFAWOtgoysog8nTulYGk_secret_75qf7rjBDsTTz279LfS1feXUj",
        "confirmation_method": "manual",
        "created": 1564498877,
        "currency": "gbp",
        "customer": "cus_7s22nNueP2Hjj6",
        "description": null,
        "invoice": null,
        "last_payment_error": null,
        "livemode": false,
        "metadata": {},
        "next_action": null,
        "on_behalf_of": null,
        "payment_method": "pm_1F1wpFAWOtgoysogJ8zQ8K07",
        "payment_method_options": {
          "card": {"request_three_d_secure": "automatic"}
          },
        "payment_method_types": ["card"],
        "receipt_email": null,
        "review": null,
        "setup_future_usage": null,
        "shipping": null,
        "source": null,
        "statement_descriptor": null,
        "status": "requires_confirmation",
        "transfer_data": null,
        "transfer_group": null
      }
    RESPONSE
  end

  def successful_confirm_3ds2_intent_response
    <<-RESPONSE
      {
        "id": "pi_1F1wpFAWOtgoysog8nTulYGk",
        "object": "payment_intent",
        "amount": 2020,
        "amount_capturable": 0,
        "amount_received": 0,
        "application": null,
        "application_fee_amount": null,
        "canceled_at": null,
        "cancellation_reason": null,
        "capture_method": "manual",
        "charges": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/charges?payment_intent=pi_1F1wpFAWOtgoysog8nTulYGk"},
          "client_secret": "pi_1F1wpFAWOtgoysog8nTulYGk_secret_75qf7rjBDsTTz279LfS1feXUj",
          "confirmation_method": "manual",
          "created": 1564498877,
          "currency": "gbp",
          "customer": "cus_7s22nNueP2Hjj6",
          "description": null,
          "invoice": null,
          "last_payment_error": null,
          "livemode": false,
          "metadata": {},
          "next_action": {
            "redirect_to_url": {
              "return_url": "https://example.com/return-to-me",
              "url": "https://hooks.stripe.com/3d_secure_2_eap/begin_test/src_1F1wpGAWOtgoysog4f00umCp/src_client_secret_FX0qk3uQ04woFWgdJbN3pnHD"},
            "type": "redirect_to_url"},
          "on_behalf_of": null,
          "payment_method": "pm_1F1wpFAWOtgoysogJ8zQ8K07",
          "payment_method_options": {
            "card": {"request_three_d_secure": "automatic"}
            },
          "payment_method_types": ["card"],
          "receipt_email": null,
          "review": null,
          "setup_future_usage": null,
          "shipping": null,
          "source": null,
          "statement_descriptor": null,
          "status": "requires_action",
          "transfer_data": null,
          "transfer_group": null
        }
    RESPONSE
  end

  def successful_request_three_d_secure_response
    <<-RESPONSE
    {"id"=>"pi_1HZJGPAWOtgoysogrKURP11Q",
      "object"=>"payment_intent",
      "amount"=>2000,
      "amount_capturable"=>0,
      "amount_received"=>2000,
      "application"=>nil,
      "application_fee_amount"=>nil,
      "canceled_at"=>nil,
      "cancellation_reason"=>nil,
      "capture_method"=>"automatic",
      "charges"=>
       {"object"=>"list",
        "data"=>
         [{"id"=>"ch_1HZJGQAWOtgoysogEpbZTGIl",
           "object"=>"charge",
           "amount"=>2000,
           "amount_captured"=>2000,
           "amount_refunded"=>0,
           "application"=>nil,
           "application_fee"=>nil,
           "application_fee_amount"=>nil,
           "balance_transaction"=>"txn_1HZJGQAWOtgoysogEKwV2r5N",
           "billing_details"=>
            {"address"=>{"city"=>nil, "country"=>nil, "line1"=>nil, "line2"=>nil, "postal_code"=>nil, "state"=>nil}, "email"=>nil, "name"=>nil, "phone"=>nil},
           "calculated_statement_descriptor"=>"SPREEDLY",
           "captured"=>true,
           "created"=>1602002626,
           "currency"=>"gbp",
           "customer"=>nil,
           "description"=>nil,
           "destination"=>nil,
           "dispute"=>nil,
           "disputed"=>false,
           "failure_code"=>nil,
           "failure_message"=>nil,
           "fraud_details"=>{},
           "invoice"=>nil,
           "livemode"=>false,
           "metadata"=>{},
           "on_behalf_of"=>nil,
           "order"=>nil,
           "outcome"=>
            {"network_status"=>"approved_by_network",
             "reason"=>nil,
             "risk_level"=>"normal",
             "risk_score"=>16,
             "seller_message"=>"Payment complete.",
             "type"=>"authorized"},
           "paid"=>true,
           "payment_intent"=>"pi_1HZJGPAWOtgoysogrKURP11Q",
           "payment_method"=>"pm_1HZJGOAWOtgoysogvnMsnnG1",
           "payment_method_details"=>
            {"card"=>
              {"brand"=>"visa",
               "checks"=>{"address_line1_check"=>nil, "address_postal_code_check"=>nil, "cvc_check"=>"pass"},
               "country"=>"US",
               "ds_transaction_id"=>nil,
               "exp_month"=>10,
               "exp_year"=>2020,
               "fingerprint"=>"hfaVNMiXc0dYSiC5",
               "funding"=>"credit",
               "installments"=>nil,
               "last4"=>"4242",
               "moto"=>nil,
               "network"=>"visa",
               "network_transaction_id"=>"1041029786787710",
               "three_d_secure"=>
                {"authenticated"=>false,
                 "authentication_flow"=>nil,
                 "electronic_commerce_indicator"=>"06",
                 "result"=>"attempt_acknowledged",
                 "result_reason"=>nil,
                 "succeeded"=>true,
                 "transaction_id"=>"d1VlRVF6a1BVNXN1cjMzZVl0RU0=",
                 "version"=>"1.0.2"},
               "wallet"=>nil},
             "type"=>"card"},
           "receipt_email"=>nil,
           "receipt_number"=>nil,
           "receipt_url"=>"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1HZJGQAWOtgoysogEpbZTGIl/rcpt_I9cVpN9xAeS39FhMqTS33Fj8gHsjjuX",
           "refunded"=>false,
           "refunds"=>{"object"=>"list", "data"=>[], "has_more"=>false, "total_count"=>0, "url"=>"/v1/charges/ch_1HZJGQAWOtgoysogEpbZTGIl/refunds"},
           "review"=>nil,
           "shipping"=>nil,
           "source"=>nil,
           "source_transfer"=>nil,
           "statement_descriptor"=>nil,
           "statement_descriptor_suffix"=>nil,
           "status"=>"succeeded",
           "transfer_data"=>nil,
           "transfer_group"=>nil}],
        "has_more"=>false,
        "total_count"=>1,
        "url"=>"/v1/charges?payment_intent=pi_1HZJGPAWOtgoysogrKURP11Q"},
      "client_secret"=>"pi_1HZJGPAWOtgoysogrKURP11Q_secret_dJNY00dYXC22Fc9nPscAmhFMt",
      "confirmation_method"=>"automatic",
      "created"=>1602002625,
      "currency"=>"gbp",
      "customer"=>nil,
      "description"=>nil,
      "invoice"=>nil,
      "last_payment_error"=>nil,
      "livemode"=>false,
      "metadata"=>{},
      "next_action"=>nil,
      "on_behalf_of"=>nil,
      "payment_method"=>"pm_1HZJGOAWOtgoysogvnMsnnG1",
      "payment_method_options"=>{"card"=>{"installments"=>nil, "network"=>nil, "request_three_d_secure"=>"any"}},
      "payment_method_types"=>["card"],
      "receipt_email"=>nil,
      "review"=>nil,
      "setup_future_usage"=>nil,
      "shipping"=>nil,
      "source"=>nil,
      "statement_descriptor"=>nil,
      "statement_descriptor_suffix"=>nil,
      "status"=>"succeeded",
      "transfer_data"=>nil,
      "transfer_group"=>nil
      }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {"error":{"charge":"ch_1F2MB6AWOtgoysogAIvNV32Z","code":"card_declined","decline_code":"generic_decline","doc_url":"https://stripe.com/docs/error-codes/card-declined","message":"Your card was declined.","payment_intent":{"id":"pi_1F2MB5AWOtgoysogCMt8BaxR","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":0,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"automatic","charges":{"object":"list","data":[{"id":"ch_1F2MB6AWOtgoysogAIvNV32Z","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":null,"billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":false,"created":1564596332,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":"card_declined","failure_message":"Your card was declined.","fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"declined_by_network","reason":"generic_decline","risk_level":"normal","risk_score":41,"seller_message":"The bank did not return any further details with this decline.","type":"issuer_declined"},"paid":false,"payment_intent":"pi_1F2MB5AWOtgoysogCMt8BaxR","payment_method":"pm_1F2MB5AWOtgoysogq3yXZ98h","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"1VUoWMvHnqtngyrD","funding":"credit","last4":"0002","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F2MB6AWOtgoysogAIvNV32Z/rcpt_FXR3PjBGluHmHsnLmp0S2KQiHl3yg6W","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F2MB6AWOtgoysogAIvNV32Z/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"failed","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F2MB5AWOtgoysogCMt8BaxR"},"client_secret":"pi_1F2MB5AWOtgoysogCMt8BaxR_secret_fOHryjtjBE4gACiHTcREraXSQ","confirmation_method":"manual","created":1564596331,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":{"charge":"ch_1F2MB6AWOtgoysogAIvNV32Z","code":"card_declined","decline_code":"generic_decline","doc_url":"https://stripe.com/docs/error-codes/card-declined","message":"Your card was declined.","payment_method":{"id":"pm_1F2MB5AWOtgoysogq3yXZ98h","object":"payment_method","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"1VUoWMvHnqtngyrD","funding":"credit","generated_from":null,"last4":"0002","three_d_secure_usage":{"supported":true},"wallet":null},"created":1564596331,"customer":null,"livemode":false,"metadata":{},"type":"card"},"type":"card_error"},"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":null,"payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"requires_payment_method","transfer_data":null,"transfer_group":null},"payment_method":{"id":"pm_1F2MB5AWOtgoysogq3yXZ98h","object":"payment_method","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"1VUoWMvHnqtngyrD","funding":"credit","generated_from":null,"last4":"0002","three_d_secure_usage":{"supported":true},"wallet":null},"created":1564596331,"customer":null,"livemode":false,"metadata":{},"type":"card"},"type":"card_error"}}
    RESPONSE
  end

  def failed_cancel_response
    <<-RESPONSE
      {"error":{"code":"payment_intent_unexpected_state","doc_url":"https://stripe.com/docs/error-codes/payment-intent-unexpected-state","message":"You cannot cancel this PaymentIntent because it has a status of succeeded. Only a PaymentIntent with one of the following statuses may be canceled: requires_payment_method, requires_capture, requires_confirmation, requires_action.","payment_intent":{"id":"pi_1F2McmAWOtgoysoglFLDRWab","object":"payment_intent","amount":2020,"amount_capturable":0,"amount_received":2020,"application":null,"application_fee_amount":null,"canceled_at":null,"cancellation_reason":null,"capture_method":"automatic","charges":{"object":"list","data":[{"id":"ch_1F2McmAWOtgoysogQgUS1YtH","object":"charge","amount":2020,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":"txn_1F2McmAWOtgoysog8uxBEJ30","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":null,"state":null},"email":null,"name":null,"phone":null},"captured":true,"created":1564598048,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":null,"livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":53,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":"pi_1F2McmAWOtgoysoglFLDRWab","payment_method":"pm_1F2MclAWOtgoysogq80GBBMO","payment_method_details":{"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":null,"cvc_check":null},"country":"US","exp_month":7,"exp_year":2020,"fingerprint":"hfaVNMiXc0dYSiC5","funding":"credit","last4":"4242","three_d_secure":null,"wallet":null},"type":"card"},"receipt_email":null,"receipt_number":null,"receipt_url":"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_1F2McmAWOtgoysogQgUS1YtH/rcpt_FXRVzyFnf7aCS1r13N3uym1u8AaboOJ","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_1F2McmAWOtgoysogQgUS1YtH/refunds"},"review":null,"shipping":null,"source":null,"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"total_count":1,"url":"/v1/charges?payment_intent=pi_1F2McmAWOtgoysoglFLDRWab"},"client_secret":"pi_1F2McmAWOtgoysoglFLDRWab_secret_z4faDF0Cv0JZJ6pxK3bdIodkD","confirmation_method":"manual","created":1564598048,"currency":"gbp","customer":"cus_7s22nNueP2Hjj6","description":null,"invoice":null,"last_payment_error":null,"livemode":false,"metadata":{},"next_action":null,"on_behalf_of":null,"payment_method":"pm_1F2MclAWOtgoysogq80GBBMO","payment_method_options":{"card":{"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"receipt_email":null,"review":null,"setup_future_usage":null,"shipping":null,"source":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null},"type":"invalid_request_error"}}
    RESPONSE
  end

  def failed_verify_response
    <<-RESPONSE
      {"error":{"code":"incorrect_cvc","doc_url":"https://stripe.com/docs/error-codes/incorrect-cvc","message":"Yourcard'ssecuritycodeisincorrect.","param":"cvc","payment_method":{"id":"pm_11111111111111111111","object":"payment_method","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":"12345","state":null},"email":null,"name":"Andrew Earl","phone":null},"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":"pass","cvc_check":"fail"},"country":"US","description":null,"display_brand":{"label":"Visa","logo_url":"https://b.stripecdn.com/cards-metadata/logos/card-visa.svg","type":"visa"},"exp_month":11,"exp_year":2027,"fingerprint":"SuqLiaoeuthnaomyEJhqjSl","funding":"credit","generated_from":null,"iin":"4111111","issuer":"StripeTest(multi-country)","last4":"1111","networks":{"available":["visa"],"preferred":null},"three_d_secure_usage":{"supported":true},"wallet":null},"created":1706803138,"customer":null,"livemode":false,"metadata":{},"type":"card"},"request_log_url":"https://dashboard.stripe.com/acct_1EzHCMD9l2v51lHE/test/logs/req_7bcL8JaztST1Ho?t=1706803138","setup_intent":{"id":"seti_nhtadoeunhtaobjntaheodu","object":"setup_intent","application":"ca_aotnheudnaoethud","automatic_payment_methods":null,"cancellation_reason":null,"client_secret":"seti_nhtadoeunhtaobjntaheodu_secret_aoentuhaosneutkmanotuheidna","created":1706803138,"customer":null,"description":null,"flow_directions":null,"last_setup_error":{"code":"incorrect_cvc","doc_url":"https://stripe.com/docs/error-codes/incorrect-cvc","message":"Your cards security code is incorrect.","param":"cvc","payment_method":{"id":"pm_11111111111111111111","object":"payment_method","billing_details":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":"12345","state":null},"email":null,"name":"AndrewEarl","phone":null},"card":{"brand":"visa","checks":{"address_line1_check":null,"address_postal_code_check":"pass","cvc_check":"fail"},"country":"US","description":null,"display_brand":{"label":"Visa","logo_url":"https://b.stripecdn.com/cards-metadata/logos/card-visa.svg","type":"visa"},"exp_month":11,"exp_year":2027,"fingerprint":"anotehjbnaroetug","funding":"credit","generated_from":null,"iin":"411111111","issuer":"StripeTest(multi-country)","last4":"1111","networks":{"available":["visa"],"preferred":null},"three_d_secure_usage":{"supported":true},"wallet":null},"created":1706803138,"customer":null,"livemode":false,"metadata":{},"type":"card"},"type":"card_error"},"latest_attempt":"setatt_ansotheuracogeudna","livemode":false,"mandate":null,"metadata":{"transaction_token":"ntahodejrcagoedubntha","order_id":"ntahodejrcagoedubntha","connect_agent":"Spreedly"},"next_action":null,"on_behalf_of":null,"payment_method":null,"payment_method_configuration_details":null,"payment_method_options":{"card":{"mandate_options":null,"network":null,"request_three_d_secure":"automatic"}},"payment_method_types":["card"],"single_use_mandate":null,"status":"requires_payment_method","usage":"off_session"},"type":"card_error"}}
    RESPONSE
  end

  def failed_payment_method_response
    <<-RESPONSE
      {"error": {"code": "validation_error", "message": "You must verify a phone number on your Stripe account before you can send raw credit card numbers to the Stripe API. You can avoid this requirement by using Stripe.js, the Stripe mobile bindings, or Stripe Checkout. For more information, see https://dashboard.stripe.com/phone-verification.", "type": "invalid_request_error"}}
    RESPONSE
  end

  def failed_service_response
    <<-RESPONSE
      {"error": {"message": "Error while communicating with one of our backends.  Sorry about that!  We have been notified of the problem.  If you have any questions, we can help at https://support.stripe.com/.", "type": "api_error"  }}
    RESPONSE
  end

  def failed_with_set_error_on_requires_action_response
    <<-RESPONSE
      {"error": {"message": "This payment required an authentication action to complete, but `error_on_requires_action` was set. When you're ready, you can upgrade your integration to handle actions at https://stripe.com/docs/payments/payment-intents/upgrade-to-handle-actions.", "type": "card_error"  }}
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
      {
        "id": "seti_1Gsw0aAWOtgoysog0XjSBPVX",
        "object": "setup_intent",
        "application": null,
        "cancellation_reason": null,
        "client_secret": "seti_1Gsw0aAWOtgoysog0XjSBPVX_secret_HRpfHkvewAdYQJgee27ihJfm4E4zWmW",
        "created": 1591903456,
        "customer": "cus_GkjsDZC58SgUcY",
        "description": null,
        "last_setup_error": null,
        "livemode": false,
        "mandate": null,
        "metadata": {
        },
        "next_action": null,
        "on_behalf_of": null,
        "payment_method": "pm_1Gsw0aAWOtgoysog304wX4J9",
        "payment_method_options": {
          "card": {
            "request_three_d_secure": "automatic"
          }
        },
        "payment_method_types": [
          "card"
        ],
        "single_use_mandate": null,
        "status": "succeeded",
        "usage": "off_session"
      }
    RESPONSE
  end

  def successful_payment_method_response
    <<-RESPONSE
      {
        "id": "pm_1IQ3OhAWOtgoysogUkVwJ5MT",
        "object": "payment_method",
        "billing_details": {
          "address": {
            "city": null,
            "country": null,
            "line1": null,
            "line2": null,
            "postal_code": null,
            "state": null
          },
          "email": null,
          "name": null,
          "phone": null
        },
        "card": {
          "brand": "visa",
          "checks": {
            "address_line1_check": null,
            "address_postal_code_check": null,
            "cvc_check": "unchecked"
          },
          "country": "US",
          "exp_month": 10,
          "exp_year": 2021,
          "fingerprint": "hfaVNMiXc0dYSiC5",
          "funding": "credit",
          "generated_from": null,
          "last4": "4242",
          "networks": {
            "available": [
              "visa"
            ],
            "preferred": null
          },
          "three_d_secure_usage": {
            "supported": true
          },
          "wallet": null
        },
        "created": 1614573020,
        "customer": null,
        "livemode": false,
        "metadata": {
        },
        "type": "card"
      }
    RESPONSE
  end

  def successful_create_customer_response
    <<-RESPONSE
      {
        "id": "cus_J27e2tthifSmpm",
        "object": "customer",
        "account_balance": 0,
        "address": null,
        "balance": 0,
        "created": 1614573020,
        "currency": null,
        "default_source": null,
        "delinquent": false,
        "description": null,
        "discount": null,
        "email": null,
        "invoice_prefix": "B0C3D1B5",
        "invoice_settings": {
          "custom_fields": null,
          "default_payment_method": null,
          "footer": null
        },
        "livemode": false,
        "metadata": {
        },
        "name": null,
        "next_invoice_sequence": 1,
        "phone": null,
        "preferred_locales": [],
        "shipping": null,
        "sources": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/customers/cus_J27e2tthifSmpm/sources"
        },
        "subscriptions": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/customers/cus_J27e2tthifSmpm/subscriptions"
        },
        "tax_exempt": "none",
        "tax_ids": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/customers/cus_J27e2tthifSmpm/tax_ids"
        },
        "tax_info": null,
        "tax_info_verification": null
      }
    RESPONSE
  end

  def successful_payment_method_attach_response
    <<-RESPONSE
      {
        "id": "pm_1IQ3AYAWOtgoysogcvbllgNa",
        "object": "payment_method",
        "billing_details": {
          "address": {
            "city": null,
            "country": null,
            "line1": null,
            "line2": null,
            "postal_code": null,
            "state": null
          },
          "email": null,
          "name": null,
          "phone": null
        },
        "card": {
          "brand": "visa",
          "checks": {
            "address_line1_check": null,
            "address_postal_code_check": null,
            "cvc_check": "unchecked"
          },
          "country": "US",
          "exp_month": 10,
          "exp_year": 2021,
          "fingerprint": "hfaVNMiXc0dYSiC5",
          "funding": "credit",
          "generated_from": null,
          "last4": "4242",
          "networks": {
            "available": [
              "visa"
            ],
            "preferred": null
          },
          "three_d_secure_usage": {
            "supported": true
          },
          "wallet": null
        },
        "created": 1614572142,
        "customer": "cus_J27PL9krZlnw82",
        "livemode": false,
        "metadata": {
        },
        "type": "card"
      }
    RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic c2tfdGVzdF9oQkwwTXF6ZGZ6Rnk3OXU0cFloUmVhQlo6\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.45.0\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.45.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.3 p242 (2014-09-19)\",\"platform\":\"x86_64-linux\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 270\r\n\r\n"
      <- "amount=100&currency=usd&card[number]=4242424242424242&card[exp_month]=9&card[exp_year]=2015&card[tokenization_method]=android_pay&card[eci]=07&capture_method=automatic&card[name]=Longbob+Longsen&description=ActiveMerchant+Test+Purchase&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.45.0&metadata[email]=wow%40example.com&card[cryptogram]=sensitive_data&payment_method_types[0]=card&payment_method_data[type]=card&payment_method_data[card][token]=tok_1KHrnVAWOtgoysogWbF1jrM9&metadata[connect_agent]=placeholder&metadata[transaction_token]=Coe7nlopnvhfcNRXhJMH5DTVusU&metadata[email]=john.smith%40example.com&metadata[order_id]=order_id-xxxxxx-x&confirm=true&return_url=http%3A%2F%2Fexaple.com%2Ftransaction%transaction_idxxxx%2Fredirect"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Fri, 14 Jan 2022 15:34:39 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 5204\r\n"
      -> "Connection: close\r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "access-control-allow-methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "access-control-expose-headers: Request-Id, Stripe-Manage-Version, X-Stripe-External-Auth-Required, X-Stripe-Privileged-Session-Required\r\n"
      -> "access-control-max-age: 300\r\n"
      -> "cache-control: no-cache, no-store\r\n"
      -> "idempotency-key: 87bd1ae5-1cf2-4735-85e0-c8cdafb25fff\r\n"
      -> "original-request: req_VkIqZgctQBI9yo\r\n"
      -> "request-id: req_VkIqZgctQBI9yo\r\n"
      -> "stripe-should-retry: false\r\n"
      -> "stripe-version: 2020-08-27\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains; preload\r\n"
      -> "\r\n"
      reading 5204 bytes...
      -> "{\n  \"id\": \"pi_3KHrnWAWOtgoysog1Y5qMLqc\",\n  \"object\": \"payment_intent\",\n  \"amount\": 100,\n  \"amount_capturable\": 0,\n  \"amount_received\": 100,\n  \"application\": null,\n  \"application_fee_amount\": null,\n  \"automatic_payment_methods\": null,\n  \"canceled_at\": null,\n  \"cancellation_reason\": null,\n  \"capture_method\": \"automatic\",\n  \"charges\": {\n    \"object\": \"list\",\n    \"data\": [\n      {\n        \"id\": \"ch_3KHrnWAWOtgoysog1noj1iU9\",\n        \"object\": \"charge\",\n        \"amount\": 100,\n        \"amount_captured\": 100,\n        \"amount_refunded\": 0,\n        \"application\": null,\n        \"application_fee\": null,\n        \"application_fee_amount\": null,\n        \"balance_transaction\": \"txn_3KHrnWAWOtgoysog1vy6pmxk\",\n        \"billing_details\": {\n          \"address\": {\n            \"city\": null,\n            \"country\": null,\n            \"line1\": null,\n            \"line2\": null,\n            \"postal_code\": null,\n            \"state\": null\n          },\n          \"email\": null,\n          \"name\": null,\n          \"phone\": null\n        },\n        \"calculated_statement_descriptor\": \"SPREEDLY\",\n        \"captured\": true,\n        \"created\": 1642174478,\n        \"currency\": \"usd\",\n        \"customer\": null,\n        \"description\": null,\n        \"destination\": null,\n        \"dispute\": null,\n        \"disputed\": false,\n        \"failure_code\": null,\n        \"failure_message\": null,\n        \"fraud_details\": {\n        },\n        \"invoice\": null,\n        \"livemode\": false,\n        \"metadata\": {\n          \"connect_agent\": \"placeholder\",\n          \"transaction_token\": \"Coe7nlopnvhfcNRXhJMH5DTVusU\",\n          \"email\": \"john.smith@example.com\",\n          \"order_id\": \"AH2EjtfMGoZkWNEwLU90sq7VzcDlzWH_KugIYT4aVWEtJF9AwmqiXqsBs2l9q6F2Ruq9WKkUBbuLWNmA3P22ShFXFCZosTwkoflaDeTD2xeiMvmYv29VPINEDtLdSAoJ-DDlRKnsxa-n\"\n        },\n        \"on_behalf_of\": null,\n        \"order\": null,\n        \"outcome\": {\n          \"network_status\": \"approved_by_network\",\n          \"reason\": null,\n          \"risk_level\": \"normal\",\n          \"risk_score\": 36,\n          \"seller_message\": \"Payment complete.\",\n          \"type\": \"authorized\"\n        },\n        \"paid\": true,\n        \"payment_intent\": \"pi_3KHrnWAWOtgoysog1Y5qMLqc\",\n        \"payment_method\": \"pm_1KHrnWAWOtgoysogqXkTXrCb\",\n        \"payment_method_details\": {\n          \"card\": {\n            \"brand\": \"visa\",\n            \"checks\": {\n              \"address_line1_check\": null,\n              \"address_postal_code_check\": null,\n              \"cvc_check\": null\n            },\n            \"country\": \"US\",\n            \"ds_transaction_id\": null,\n            \"exp_month\": 12,\n            \"exp_year\": 2027,\n            \"fingerprint\": \"sUdMrygQwzOKqwSm\",\n            \"funding\": \"debit\",\n            \"installments\": null,\n            \"last4\": \"0000\",\n            \"mandate\": null,\n            \"moto\": null,\n            \"network\": \"visa\",\n            \"network_transaction_id\": \"1158510077114121\",\n            \"three_d_secure\": null,\n            \"wallet\": {\n              \"dynamic_last4\": \"3478\",\n              \"google_pay\": {\n              },\n              \"type\": \"google_pay\"\n            }\n          },\n          \"type\": \"card\"\n        },\n        \"receipt_email\": null,\n        \"receipt_number\": null,\n        \"receipt_url\": \"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_3KHrnWAWOtgoysog1noj1iU9/rcpt_KxnOefAivglRgWZmxp0PLOJUQg0VhS9\",\n        \"refunded\": false,\n        \"refunds\": {\n          \"object\": \"list\",\n          \"data\": [\n\n          ],\n          \"has_more\": false,\n          \"total_count\": 0,\n          \"url\": \"/v1/charges/ch_3KHrnWAWOtgoysog1noj1iU9/refunds\"\n        },\n        \"review\": null,\n        \"shipping\": null,\n        \"source\": null,\n        \"source_transfer\": null,\n        \"statement_descriptor\": null,\n        \"statement_descriptor_suffix\": null,\n        \"status\": \"succeeded\",\n        \"transfer_data\": null,\n        \"transfer_group\": null\n      }\n    ],\n    \"has_more\": false,\n    \"total_count\": 1,\n    \"url\": \"/v1/charges?payment_intent=pi_3KHrnWAWOtgoysog1Y5qMLqc\"\n  },\n  \"client_secret\": \"pi_3KHrnWAWOtgoysog1Y5qMLqc_secret_5ZEt4fzM7YCi1zdMzs4iQXLjC\",\n  \"confirmation_method\": \"automatic\",\n  \"created\": 1642174478,\n  \"currency\": \"usd\",\n  \"customer\": null,\n  \"description\": null,\n  \"invoice\": null,\n  \"last_payment_error\": null,\n  \"livemode\": false,\n  \"metadata\": {\n    \"connect_agent\": \"placeholder\",\n    \"transaction_token\": \"Coe7nlopnvhfcNRXhJMH5DTVusU\",\n    \"email\": \"john.smith@example.com\",\n    \"order_id\": \"AH2EjtfMGoZkWNEwLU90sq7VzcDlzWH_KugIYT4aVWEtJF9AwmqiXqsBs2l9q6F2Ruq9WKkUBbuLWNmA3P22ShFXFCZosTwkoflaDeTD2xeiMvmYv29VPINEDtLdSAoJ-DDlRKnsxa-n\"\n  },\n  \"next_action\": null,\n  \"on_behalf_of\": null,\n  \"payment_method\": \"pm_1KHrnWAWOtgoysogqXkTXrCb\",\n  \"payment_method_options\": {\n    \"card\": {\n      \"installments\": null,\n      \"mandate_options\": null,\n      \"network\": null,\n      \"request_three_d_secure\": \"automatic\"\n    }\n  },\n  \"payment_method_types\": [\n    \"card\"\n  ],\n  \"processing\": null,\n  \"receipt_email\": null,\n  \"review\": null,\n  \"setup_future_usage\": null,\n  \"shipping\": null,\n  \"source\": null,\n  \"statement_descriptor\": null,\n  \"statement_descriptor_suffix\": null,\n  \"status\": \"succeeded\",\n  \"transfer_data\": null,\n  \"transfer_group\": null\n}\n"
      read 5204 bytes
      Conn close
    PRE_SCRUBBED
  end

  def scrubbed
    <<-SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.45.0\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.45.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.3 p242 (2014-09-19)\",\"platform\":\"x86_64-linux\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 270\r\n\r\n"
      <- "amount=100&currency=usd&card[number]=[FILTERED]&card[exp_month]=9&card[exp_year]=2015&card[tokenization_method]=android_pay&card[eci]=07&capture_method=automatic&card[name]=Longbob+Longsen&description=ActiveMerchant+Test+Purchase&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.45.0&metadata[email]=wow%40example.com&card[cryptogram]=[FILTERED]&payment_method_types[0]=card&payment_method_data[type]=card&payment_method_data[card][token]=[FILTERED]&metadata[connect_agent]=placeholder&metadata[transaction_token]=Coe7nlopnvhfcNRXhJMH5DTVusU&metadata[email]=john.smith%40example.com&metadata[order_id]=order_id-xxxxxx-x&confirm=true&return_url=http%3A%2F%2Fexaple.com%2Ftransaction%transaction_idxxxx%2Fredirect"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Fri, 14 Jan 2022 15:34:39 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 5204\r\n"
      -> "Connection: close\r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "access-control-allow-methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "access-control-expose-headers: Request-Id, Stripe-Manage-Version, X-Stripe-External-Auth-Required, X-Stripe-Privileged-Session-Required\r\n"
      -> "access-control-max-age: 300\r\n"
      -> "cache-control: no-cache, no-store\r\n"
      -> "idempotency-key: 87bd1ae5-1cf2-4735-85e0-c8cdafb25fff\r\n"
      -> "original-request: req_VkIqZgctQBI9yo\r\n"
      -> "request-id: req_VkIqZgctQBI9yo\r\n"
      -> "stripe-should-retry: false\r\n"
      -> "stripe-version: 2020-08-27\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains; preload\r\n"
      -> "\r\n"
      reading 5204 bytes...
      -> "{\n  \"id\": \"pi_3KHrnWAWOtgoysog1Y5qMLqc\",\n  \"object\": \"payment_intent\",\n  \"amount\": 100,\n  \"amount_capturable\": 0,\n  \"amount_received\": 100,\n  \"application\": null,\n  \"application_fee_amount\": null,\n  \"automatic_payment_methods\": null,\n  \"canceled_at\": null,\n  \"cancellation_reason\": null,\n  \"capture_method\": \"automatic\",\n  \"charges\": {\n    \"object\": \"list\",\n    \"data\": [\n      {\n        \"id\": \"ch_3KHrnWAWOtgoysog1noj1iU9\",\n        \"object\": \"charge\",\n        \"amount\": 100,\n        \"amount_captured\": 100,\n        \"amount_refunded\": 0,\n        \"application\": null,\n        \"application_fee\": null,\n        \"application_fee_amount\": null,\n        \"balance_transaction\": \"txn_3KHrnWAWOtgoysog1vy6pmxk\",\n        \"billing_details\": {\n          \"address\": {\n            \"city\": null,\n            \"country\": null,\n            \"line1\": null,\n            \"line2\": null,\n            \"postal_code\": null,\n            \"state\": null\n          },\n          \"email\": null,\n          \"name\": null,\n          \"phone\": null\n        },\n        \"calculated_statement_descriptor\": \"SPREEDLY\",\n        \"captured\": true,\n        \"created\": 1642174478,\n        \"currency\": \"usd\",\n        \"customer\": null,\n        \"description\": null,\n        \"destination\": null,\n        \"dispute\": null,\n        \"disputed\": false,\n        \"failure_code\": null,\n        \"failure_message\": null,\n        \"fraud_details\": {\n        },\n        \"invoice\": null,\n        \"livemode\": false,\n        \"metadata\": {\n          \"connect_agent\": \"placeholder\",\n          \"transaction_token\": \"Coe7nlopnvhfcNRXhJMH5DTVusU\",\n          \"email\": \"john.smith@example.com\",\n          \"order_id\": \"AH2EjtfMGoZkWNEwLU90sq7VzcDlzWH_KugIYT4aVWEtJF9AwmqiXqsBs2l9q6F2Ruq9WKkUBbuLWNmA3P22ShFXFCZosTwkoflaDeTD2xeiMvmYv29VPINEDtLdSAoJ-DDlRKnsxa-n\"\n        },\n        \"on_behalf_of\": null,\n        \"order\": null,\n        \"outcome\": {\n          \"network_status\": \"approved_by_network\",\n          \"reason\": null,\n          \"risk_level\": \"normal\",\n          \"risk_score\": 36,\n          \"seller_message\": \"Payment complete.\",\n          \"type\": \"authorized\"\n        },\n        \"paid\": true,\n        \"payment_intent\": \"pi_3KHrnWAWOtgoysog1Y5qMLqc\",\n        \"payment_method\": \"pm_1KHrnWAWOtgoysogqXkTXrCb\",\n        \"payment_method_details\": {\n          \"card\": {\n            \"brand\": \"visa\",\n            \"checks\": {\n              \"address_line1_check\": null,\n              \"address_postal_code_check\": null,\n              \"cvc_check\": null\n            },\n            \"country\": \"US\",\n            \"ds_transaction_id\": null,\n            \"exp_month\": 12,\n            \"exp_year\": 2027,\n            \"fingerprint\": \"sUdMrygQwzOKqwSm\",\n            \"funding\": \"debit\",\n            \"installments\": null,\n            \"last4\": \"0000\",\n            \"mandate\": null,\n            \"moto\": null,\n            \"network\": \"visa\",\n            \"network_transaction_id\": \"1158510077114121\",\n            \"three_d_secure\": null,\n            \"wallet\": {\n              \"dynamic_last4\": \"3478\",\n              \"google_pay\": {\n              },\n              \"type\": \"google_pay\"\n            }\n          },\n          \"type\": \"card\"\n        },\n        \"receipt_email\": null,\n        \"receipt_number\": null,\n        \"receipt_url\": \"https://pay.stripe.com/receipts/acct_160DX6AWOtgoysog/ch_3KHrnWAWOtgoysog1noj1iU9/rcpt_KxnOefAivglRgWZmxp0PLOJUQg0VhS9\",\n        \"refunded\": false,\n        \"refunds\": {\n          \"object\": \"list\",\n          \"data\": [\n\n          ],\n          \"has_more\": false,\n          \"total_count\": 0,\n          \"url\": \"/v1/charges/ch_3KHrnWAWOtgoysog1noj1iU9/refunds\"\n        },\n        \"review\": null,\n        \"shipping\": null,\n        \"source\": null,\n        \"source_transfer\": null,\n        \"statement_descriptor\": null,\n        \"statement_descriptor_suffix\": null,\n        \"status\": \"succeeded\",\n        \"transfer_data\": null,\n        \"transfer_group\": null\n      }\n    ],\n    \"has_more\": false,\n    \"total_count\": 1,\n    \"url\": \"/v1/charges?payment_intent=pi_3KHrnWAWOtgoysog1Y5qMLqc\"\n  },\n  \"client_secret\": \"pi_3KHrnWAWOtgoysog1Y5qMLqc_secret_5ZEt4fzM7YCi1zdMzs4iQXLjC\",\n  \"confirmation_method\": \"automatic\",\n  \"created\": 1642174478,\n  \"currency\": \"usd\",\n  \"customer\": null,\n  \"description\": null,\n  \"invoice\": null,\n  \"last_payment_error\": null,\n  \"livemode\": false,\n  \"metadata\": {\n    \"connect_agent\": \"placeholder\",\n    \"transaction_token\": \"Coe7nlopnvhfcNRXhJMH5DTVusU\",\n    \"email\": \"john.smith@example.com\",\n    \"order_id\": \"AH2EjtfMGoZkWNEwLU90sq7VzcDlzWH_KugIYT4aVWEtJF9AwmqiXqsBs2l9q6F2Ruq9WKkUBbuLWNmA3P22ShFXFCZosTwkoflaDeTD2xeiMvmYv29VPINEDtLdSAoJ-DDlRKnsxa-n\"\n  },\n  \"next_action\": null,\n  \"on_behalf_of\": null,\n  \"payment_method\": \"pm_1KHrnWAWOtgoysogqXkTXrCb\",\n  \"payment_method_options\": {\n    \"card\": {\n      \"installments\": null,\n      \"mandate_options\": null,\n      \"network\": null,\n      \"request_three_d_secure\": \"automatic\"\n    }\n  },\n  \"payment_method_types\": [\n    \"card\"\n  ],\n  \"processing\": null,\n  \"receipt_email\": null,\n  \"review\": null,\n  \"setup_future_usage\": null,\n  \"shipping\": null,\n  \"source\": null,\n  \"statement_descriptor\": null,\n  \"statement_descriptor_suffix\": null,\n  \"status\": \"succeeded\",\n  \"transfer_data\": null,\n  \"transfer_group\": null\n}\n"
      read 5204 bytes
      Conn close
    SCRUBBED
  end

  def successful_purchase_avs_pass
    <<-RESPONSE
      {
        "id": "pi_3OAbBTAWOtgoysog36MuKzzw",
        "object": "payment_intent",
        "amount": 2000,
        "amount_capturable": 0,
        "amount_received": 2000,
        "capture_method": "automatic",
        "charges": {
          "object": "list",
          "data": [
            {
              "id": "ch_3OAbBTAWOtgoysog3eoQxrT9",
              "object": "charge",
              "amount": 2000,
              "amount_captured": 2000,
              "outcome": {
                "network_status": "approved_by_network",
                "reason": null,
                "risk_level": "normal",
                "risk_score": 37,
                "seller_message": "Payment complete.",
                "type": "authorized"
              },
              "paid": true,
              "payment_intent": "pi_3OAbBTAWOtgoysog36MuKzzw",
              "payment_method": "pm_1OAbBTAWOtgoysogVf7KTk4H",
              "payment_method_details": {
                "card": {
                  "amount_authorized": 2000,
                  "brand": "visa",
                  "checks": {
                    "address_line1_check": "pass",
                    "address_postal_code_check": "pass",
                    "cvc_check": "pass"
                  },
                  "country": "US",
                  "ds_transaction_id": null,
                  "exp_month": 10,
                  "exp_year": 2028,
                  "extended_authorization": {
                    "status": "disabled"
                  },
                  "fingerprint": "hfaVNMiXc0dYSiC5",
                  "funding": "credit",
                  "incremental_authorization": {
                    "status": "unavailable"
                  },
                  "installments": null,
                  "last4": "4242",
                  "mandate": null,
                  "moto": null,
                  "multicapture": {
                    "status": "unavailable"
                  },
                  "network": "visa",
                  "network_token": {
                    "used": false
                  },
                  "network_transaction_id": "104102978678771",
                  "overcapture": {
                    "maximum_amount_capturable": 2000,
                    "status": "unavailable"
                  },
                  "three_d_secure": null,
                  "wallet": null
                },
                "type": "card"
              },
              "receipt_url": "https://pay.stripe.com/receipts/payment/CAcaFwoVYWNjdF8xNjBEWDZBV090Z295c29nKJCUtKoGMgYHwo4IbXs6LBbLMStawAC9eTsIUAmLDXw4dZNPmxzC6ds3zZxb-WVIVBJi_F4M59cPA3fR",
              "refunded": false,
              "refunds": {
                "object": "list",
                "data": [],
                "has_more": false,
                "total_count": 0,
                "url": "/v1/charges/ch_3OAbBTAWOtgoysog3eoQxrT9/refunds"
              }
            }
          ],
          "has_more": false,
          "total_count": 1,
          "url": "/v1/charges?payment_intent=pi_3OAbBTAWOtgoysog36MuKzzw"
        },
        "client_secret": "pi_3OAbBTAWOtgoysog36MuKzzw_secret_YjUUEVStFrCFJK0imrUjspILY",
        "confirmation_method": "automatic",
        "created": 1699547663,
        "currency": "usd",
        "latest_charge": "ch_3OAbBTAWOtgoysog3eoQxrT9",
        "payment_method": "pm_1OAbBTAWOtgoysogVf7KTk4H",
        "payment_method_types": [
          "card"
        ],
        "status": "succeeded"
      }
    RESPONSE
  end
end
