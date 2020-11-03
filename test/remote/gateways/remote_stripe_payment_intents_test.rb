require 'test_helper'

class RemoteStripeIntentsTest < Test::Unit::TestCase
  def setup
    @gateway = StripePaymentIntentsGateway.new(fixtures(:stripe))
    @customer = fixtures(:stripe)[:customer_id]
    @amount = 2000
    @three_ds_payment_method = 'pm_card_threeDSecure2Required'
    @visa_payment_method = 'pm_card_visa'
    @declined_payment_method = 'pm_card_chargeDeclined'
    @three_ds_moto_enabled = 'pm_card_authenticationRequiredOnSetup'
    @three_ds_authentication_required = 'pm_card_authenticationRequired'
    @three_ds_credit_card = credit_card('4000000000003220',
      verification_value: '737',
      month: 10,
      year: 2021)
    @three_ds_not_required_card = credit_card('4000000000003055',
      verification_value: '737',
      month: 10,
      year: 2021)
    @three_ds_external_data_card = credit_card('4000002760003184',
      verification_value: '737',
      month: 10,
      year: 2021)
    @visa_card = credit_card('4242424242424242',
      verification_value: '737',
      month: 10,
      year: 2021)
    @destination_account = fixtures(:stripe_destination)[:stripe_user_id]
  end

  def test_authorization_and_void
    options = {
      currency: 'GBP',
      customer: @customer
    }
    assert authorization = @gateway.authorize(@amount, @visa_payment_method, options)

    assert_equal 'requires_capture', authorization.params['status']
    refute authorization.params.dig('charges', 'data')[0]['captured']

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_successful_purchase
    options = {
      currency: 'GBP',
      customer: @customer
    }
    assert purchase = @gateway.purchase(@amount, @visa_payment_method, options)

    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
  end

  def test_purchases_with_same_idempotency_key
    options = {
      currency: 'GBP',
      customer: @customer,
      idempotency_key: SecureRandom.hex
    }
    assert purchase1 = @gateway.purchase(@amount, @visa_payment_method, options)
    assert_equal 'succeeded', purchase1.params['status']
    assert purchase1.params.dig('charges', 'data')[0]['captured']

    assert purchase2 = @gateway.purchase(@amount, @visa_payment_method, options)
    assert purchase2.success?
    assert_equal purchase1.authorization, purchase2.authorization
    assert_equal purchase1.params['charges']['data'][0]['id'], purchase2.params['charges']['data'][0]['id']
  end

  def test_credit_card_purchases_with_same_idempotency_key
    options = {
      currency: 'GBP',
      customer: @customer,
      idempotency_key: SecureRandom.hex
    }
    assert purchase1 = @gateway.purchase(@amount, @visa_card, options)
    assert_equal 'succeeded', purchase1.params['status']
    assert purchase1.params.dig('charges', 'data')[0]['captured']

    assert purchase2 = @gateway.purchase(@amount, @visa_card, options)
    assert purchase2.success?
    assert_equal purchase1.authorization, purchase2.authorization
    assert_equal purchase1.params['charges']['data'][0]['id'], purchase2.params['charges']['data'][0]['id']
  end

  def test_purchases_with_same_idempotency_key_different_options
    options = {
      currency: 'GBP',
      customer: @customer,
      idempotency_key: SecureRandom.hex
    }
    assert purchase = @gateway.purchase(@amount, @visa_payment_method, options)
    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']

    options[:currency] = 'USD'
    assert purchase = @gateway.purchase(@amount, @visa_payment_method, options)
    refute purchase.success?
    assert_match(/^Keys for idempotent requests can only be used with the same parameters they were first used with/, purchase.message)
  end

  def test_credit_card_purchases_with_same_idempotency_key_different_options
    options = {
      currency: 'GBP',
      customer: @customer,
      idempotency_key: SecureRandom.hex
    }
    assert purchase = @gateway.purchase(@amount, @visa_card, options)
    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']

    options[:currency] = 'USD'
    assert purchase = @gateway.purchase(@amount, @visa_card, options)
    refute purchase.success?
    assert_match(/^Keys for idempotent requests can only be used with the same parameters they were first used with/, purchase.message)
  end

  def test_unsuccessful_purchase
    options = {
      currency: 'GBP',
      customer: @customer
    }
    assert purchase = @gateway.purchase(@amount, @declined_payment_method, options)

    assert_equal 'Your card was declined.', purchase.message
    refute purchase.params.dig('error', 'payment_intent', 'charges', 'data')[0]['captured']
  end

  def test_successful_purchase_with_external_auth_data_3ds_1
    options = {
      currency: 'GBP',
      three_d_secure: {
        eci: '05',
        cavv: '4BQwsg4yuKt0S1LI1nDZTcO9vUM=',
        xid: 'd+NEBKSpEMauwleRhdrDY06qj4A='
      }
    }

    assert purchase = @gateway.purchase(@amount, @three_ds_external_data_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
  end

  def test_successful_purchase_with_external_auth_data_3ds_2
    options = {
      currency: 'GBP',
      three_d_secure: {
        version: '2.1.0',
        eci: '02',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        ds_transaction_id: 'f879ea1c-aa2c-4441-806d-e30406466d79'
      }
    }

    assert purchase = @gateway.purchase(@amount, @three_ds_external_data_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
  end

  def test_successful_purchase_with_customer_token_and_external_auth_data_3ds_2
    options = {
      currency: 'GBP',
      customer: @customer,
      three_d_secure: {
        version: '2.1.0',
        eci: '02',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        ds_transaction_id: 'f879ea1c-aa2c-4441-806d-e30406466d79'
      }
    }

    assert purchase = @gateway.purchase(@amount, @three_ds_authentication_required, options)

    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
  end

  def test_successful_authorization_with_external_auth_data_3ds_2
    options = {
      currency: 'GBP',
      three_d_secure: {
        version: '2.1.0',
        eci: '02',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        ds_transaction_id: 'f879ea1c-aa2c-4441-806d-e30406466d79'
      }
    }

    assert authorization = @gateway.authorize(@amount, @three_ds_external_data_card, options)

    assert_equal 'requires_capture', authorization.params['status']
    refute authorization.params.dig('charges', 'data')[0]['captured']
  end

  def test_create_payment_intent_manual_capture_method
    options = {
      currency: 'USD',
      capture_method: 'manual'
    }

    assert response = @gateway.create_intent(@amount, nil, options)

    assert_success response
    assert_equal 'payment_intent', response.params['object']
    assert_equal 'manual', response.params['capture_method']
  end

  def test_create_payment_intent_manual_confimation_method
    options = {
      currency: 'USD',
      description: 'ActiveMerchant Test Purchase',
      confirmation_method: 'manual'
    }

    assert response = @gateway.create_intent(@amount, nil, options)

    assert_success response
    assert_equal 'payment_intent', response.params['object']
    assert_equal 'manual', response.params['confirmation_method']
  end

  def test_create_payment_intent_with_customer
    options = {
      currency: 'USD',
      customer: @customer || 'set customer in fixtures'
    }

    assert response = @gateway.create_intent(@amount, nil, options)

    assert_success response
    assert_equal 'payment_intent', response.params['object']
    assert_equal @customer, response.params['customer']
  end

  def test_create_payment_intent_with_credit_card
    options = {
      currency: 'USD',
      customer: @customer
    }

    assert response = @gateway.create_intent(@amount, @three_ds_credit_card, options)

    assert_success response
    assert_equal 'payment_intent', response.params['object']
  end

  def test_create_payment_intent_with_return_url
    options = {
      currency: 'USD',
      customer: @customer,
      confirm: true,
      return_url: 'https://www.example.com',
      execute_threed: true
    }

    assert response = @gateway.create_intent(@amount, @three_ds_credit_card, options)

    assert_success response
    assert_equal 'https://www.example.com', response.params['next_action']['redirect_to_url']['return_url']
  end

  def test_create_payment_intent_with_metadata
    suffix = 'SUFFIX'

    options = {
      currency: 'USD',
      customer: @customer,
      description: 'ActiveMerchant Test Purchase',
      receipt_email: 'test@example.com',
      statement_descriptor: 'Statement Descriptor',
      statement_descriptor_suffix: suffix,
      metadata: { key_1: 'value_1', key_2: 'value_2' }
    }

    assert response = @gateway.create_intent(@amount, nil, options)

    assert_success response
    assert_equal 'value_1', response.params['metadata']['key_1']
    assert_equal 'ActiveMerchant Test Purchase', response.params['description']
    assert_equal 'test@example.com', response.params['receipt_email']
    assert_equal 'Statement Descriptor', response.params['statement_descriptor']
    assert_equal suffix, response.params['statement_descriptor_suffix']
  end

  def test_create_payment_intent_that_saves_payment_method
    options = {
      currency: 'USD',
      customer: @customer,
      save_payment_method: true
    }

    assert response = @gateway.create_intent(@amount, @three_ds_credit_card, options)
    assert_success response

    assert response = @gateway.create_intent(@amount, nil, options)
    assert_failure response
    assert_equal 'A payment method must be provided or already '\
                 'attached to the PaymentIntent when `save_payment_method=true`.', response.message

    options.delete(:customer)
    assert response = @gateway.create_intent(@amount, @three_ds_credit_card, options)
    assert_failure response
    assert_equal 'A valid `customer` must be provided when `save_payment_method=true`.', response.message
  end

  def test_create_payment_intent_with_setup_future_usage
    options = {
      currency: 'USD',
      customer: @customer,
      setup_future_usage: 'on_session'
    }

    assert response = @gateway.create_intent(@amount, @three_ds_credit_card, options)
    assert_success response
    assert_equal 'on_session', response.params['setup_future_usage']
  end

  def test_3ds_unauthenticated_authorize_with_off_session
    options = {
      currency: 'USD',
      customer: @customer,
      off_session: true
    }

    assert response = @gateway.authorize(@amount, @three_ds_credit_card, options)
    assert_failure response
  end

  def test_purchase_fails_on_unexpected_3ds_initiation
    options = {
      currency: 'USD',
      customer: @customer,
      confirm: true,
      return_url: 'https://www.example.com'
    }

    assert response = @gateway.purchase(100, @three_ds_credit_card, options)
    assert_failure response
    assert_match 'Received unexpected 3DS authentication response', response.message
  end

  def test_create_payment_intent_with_shipping_address
    options = {
      currency: 'USD',
      customer: @customer,
      shipping: {
        address: {
          line1: '1 Test Ln',
          city: 'Durham'
        },
        name: 'John Doe',
        tracking_number: '123456789'
      }
    }

    assert response = @gateway.create_intent(@amount, nil, options)
    assert_success response
    assert response.params['shipping']['address']
    assert_equal 'John Doe', response.params['shipping']['name']
  end

  def test_create_payment_intent_with_billing_address
    options = {
      currency: 'USD',
      customer: @customer,
      billing_address: address,
      confirm: true
    }

    assert response = @gateway.create_intent(@amount, @visa_card, options)
    assert_success response
    assert billing = response.params.dig('charges', 'data')[0].dig('billing_details', 'address')
    assert_equal 'Ottawa', billing['city']
  end

  def test_create_payment_intent_with_connected_account
    transfer_group = 'XFERGROUP'
    application_fee = 100

    # You may not provide the application_fee_amount parameter and the transfer_data[amount] parameter
    # simultaneously. They are mutually exclusive.
    options = {
      currency: 'USD',
      customer: @customer,
      application_fee: application_fee,
      transfer_destination: @destination_account,
      on_behalf_of: @destination_account,
      transfer_group: transfer_group
    }

    assert response = @gateway.create_intent(@amount, nil, options)

    assert_success response
    assert_equal application_fee, response.params['application_fee_amount']
    assert_equal transfer_group, response.params['transfer_group']
    assert_equal @destination_account, response.params['on_behalf_of']
    assert_equal @destination_account, response.params.dig('transfer_data', 'destination')
  end

  def test_create_a_payment_intent_and_confirm
    options = {
      currency: 'GBP',
      customer: @customer,
      return_url: 'https://www.example.com',
      confirmation_method: 'manual',
      capture_method: 'manual'
    }
    assert create_response = @gateway.create_intent(@amount, @three_ds_payment_method, options)
    assert_equal 'requires_confirmation', create_response.params['status']
    intent_id = create_response.params['id']

    assert get_response = @gateway.show_intent(intent_id, options)
    assert_equal 'requires_confirmation', get_response.params['status']

    assert confirm_response = @gateway.confirm_intent(intent_id, nil, return_url: 'https://example.com/return-to-me')
    assert_equal 'redirect_to_url', confirm_response.params.dig('next_action', 'type')
  end

  def test_create_a_payment_intent_and_manually_capture
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    intent_id = create_response.params['id']
    assert_equal 'requires_capture', create_response.params['status']

    assert capture_response = @gateway.capture(@amount, intent_id, options)
    assert_equal 'succeeded', capture_response.params['status']
    assert_equal 'Payment complete.', capture_response.params.dig('charges', 'data')[0].dig('outcome', 'seller_message')
  end

  def test_amount_localization
    amount = 200000
    options = {
      currency: 'XPF',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(amount, @visa_payment_method, options)
    intent_id = create_response.params['id']
    assert_equal 'requires_capture', create_response.params['status']

    assert capture_response = @gateway.capture(amount, intent_id, options)
    assert_equal 'succeeded', capture_response.params['status']
    assert_equal 2000, capture_response.params['amount']
  end

  def test_auth_and_capture_with_destination_account_and_fee
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      transfer_destination: @destination_account,
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    intent_id = create_response.params['id']
    assert_equal 'requires_capture', create_response.params['status']
    assert_equal @destination_account, create_response.params['transfer_data']['destination']
    assert_nil create_response.params['application_fee_amount']

    assert capture_response = @gateway.capture(@amount, intent_id, { application_fee: 100 })
    assert_equal 'succeeded', capture_response.params['status']
    assert_equal @destination_account, capture_response.params['transfer_data']['destination']
    assert_equal 100, capture_response.params['application_fee_amount']
    assert_equal 'Payment complete.', capture_response.params.dig('charges', 'data')[0].dig('outcome', 'seller_message')
  end

  def test_create_a_payment_intent_and_automatically_capture
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    assert_nil create_response.params['next_action']
    assert_equal 'succeeded', create_response.params['status']
    assert_equal 'Payment complete.', create_response.params.dig('charges', 'data')[0].dig('outcome', 'seller_message')
  end

  def test_failed_capture_after_creation
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, 'pm_card_chargeDeclined', options)
    assert_equal 'requires_payment_method', create_response.params.dig('error', 'payment_intent', 'status')
    assert_equal false, create_response.params.dig('error', 'payment_intent', 'charges', 'data')[0].dig('captured')
  end

  def test_create_a_payment_intent_and_update
    amount = 200000
    update_amount = 250000
    options = {
      currency: 'XPF',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual'
    }
    assert create_response = @gateway.create_intent(amount, @visa_payment_method, options)
    intent_id = create_response.params['id']
    assert_equal 2000, create_response.params['amount']

    assert update_response = @gateway.update_intent(update_amount, intent_id, nil, options.merge(payment_method_types: 'card'))
    assert_equal 2500, update_response.params['amount']
    assert_equal 'requires_confirmation', update_response.params['status']
  end

  def test_create_a_payment_intent_and_void
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    intent_id = create_response.params['id']

    assert cancel_response = @gateway.void(intent_id, cancellation_reason: 'requested_by_customer')
    assert_equal @amount, cancel_response.params.dig('charges', 'data')[0].dig('amount_refunded')
    assert_equal 'canceled', cancel_response.params['status']
    assert_equal 'requested_by_customer', cancel_response.params['cancellation_reason']
  end

  def test_create_a_payment_intent_and_void_requires_unique_idempotency_key
    idempotency_key = SecureRandom.hex
    options = {
      currency: 'GBP',
      customer: @customer,
      return_url: 'https://www.example.com',
      confirmation_method: 'manual',
      capture_method: 'manual',
      idempotency_key: idempotency_key
    }
    assert create_response = @gateway.create_intent(@amount, @three_ds_payment_method, options)
    assert_equal 'requires_confirmation', create_response.params['status']
    intent_id = create_response.params['id']

    assert get_response = @gateway.show_intent(intent_id, options)
    assert_equal 'requires_confirmation', get_response.params['status']

    assert_failure cancel_response = @gateway.void(intent_id, cancellation_reason: 'requested_by_customer', idempotency_key: idempotency_key)
    assert_match(/^Keys for idempotent requests can only be used for the same endpoint they were first used for/, cancel_response.message)

    assert cancel_response = @gateway.void(intent_id, cancellation_reason: 'requested_by_customer', idempotency_key: "#{idempotency_key}-auto-void")
    assert_equal 'canceled', cancel_response.params['status']
    assert_equal 'requested_by_customer', cancel_response.params['cancellation_reason']
  end

  def test_failed_void_after_capture
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    assert_equal 'succeeded', create_response.params['status']
    intent_id = create_response.params['id']

    assert cancel_response = @gateway.void(intent_id, cancellation_reason: 'requested_by_customer')
    assert_equal 'You cannot cancel this PaymentIntent because ' \
      'it has a status of succeeded. Only a PaymentIntent with ' \
      'one of the following statuses may be canceled: ' \
      'requires_payment_method, requires_capture, requires_confirmation, requires_action.', cancel_response.message
  end

  def test_refund_a_payment_intent
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    intent_id = create_response.params['id']

    assert @gateway.capture(@amount, intent_id, options)

    assert refund = @gateway.refund(@amount - 20, intent_id)
    assert_equal @amount - 20, refund.params['charge']['amount_refunded']
    assert_equal true, refund.params['charge']['captured']
    refund_id = refund.params['id']
    assert_equal refund.authorization, refund_id
  end

  def test_refund_when_payment_intent_not_captured
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    intent_id = create_response.params['id']

    refund = @gateway.refund(@amount - 20, intent_id)
    assert_failure refund
    assert refund.params['error']
  end

  def test_refund_when_payment_intent_requires_action
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      confirm: true
    }
    assert create_response = @gateway.create_intent(@amount, @three_ds_authentication_required, options)
    assert_equal 'requires_action', create_response.params['status']
    intent_id = create_response.params['id']

    refund = @gateway.refund(@amount - 20, intent_id)
    assert_failure refund
    assert_match(/has a status of requires_action/, refund.message)
  end

  def test_successful_store_purchase_and_unstore
    options = {
      currency: 'GBP'
    }
    assert store = @gateway.store(@visa_card, options)
    assert store.params['customer'].start_with?('cus_')

    assert purchase = @gateway.purchase(@amount, store.authorization, options)
    assert 'succeeded', purchase.params['status']

    assert unstore = @gateway.unstore(store.authorization)
    assert_nil unstore.params['customer']
  end

  def test_successful_store_with_idempotency_key
    idempotency_key = SecureRandom.hex

    options = {
      currency: 'GBP',
      idempotency_key: idempotency_key
    }

    assert store1 = @gateway.store(@visa_card, options)
    assert store1.success?
    assert store1.params['customer'].start_with?('cus_')

    assert store2 = @gateway.store(@visa_card, options)
    assert store2.success?
    assert_equal store1.authorization, store2.authorization
    assert_equal store1.params['id'], store2.params['id']
  end

  def test_successful_verify
    options = {
      customer: @customer
    }
    assert verify = @gateway.verify(@visa_payment_method, options)

    assert_equal 'succeeded', verify.params['status']
  end

  def test_failed_verify
    options = {
      customer: @customer
    }
    assert verify = @gateway.verify(@declined_payment_method, options)

    assert_equal 'Your card was declined.', verify.message
  end

  def test_moto_enabled_card_requires_action_when_not_marked
    options = {
      currency: 'GBP',
      confirm: true
    }
    assert purchase = @gateway.purchase(@amount, @three_ds_moto_enabled, options)

    assert_equal 'requires_action', purchase.params['status']
  end

  def test_moto_enabled_card_succeeds_when_marked
    options = {
      currency: 'GBP',
      confirm: true,
      moto: true
    }
    assert purchase = @gateway.purchase(@amount, @three_ds_moto_enabled, options)

    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
  end

  def test_certain_cards_require_action_even_when_marked_as_moto
    options = {
      currency: 'GBP',
      confirm: true,
      moto: true
    }
    assert purchase = @gateway.purchase(@amount, @three_ds_authentication_required, options)

    assert_failure purchase
    assert_equal 'Your card was declined. This transaction requires authentication.', purchase.message
  end

  def test_request_three_d_secure
    options = {
      currency: 'GBP',
      request_three_d_secure: 'any'
    }
    assert purchase = @gateway.purchase(@amount, @three_ds_not_required_card, options)
    assert_equal 'requires_action', purchase.params['status']

    options = {
      currency: 'GBP'
    }
    assert purchase = @gateway.purchase(@amount, @three_ds_not_required_card, options)
    assert_equal 'succeeded', purchase.params['status']
  end

  def test_transcript_scrubbing
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      return_url: 'https://www.example.com/return',
      confirm: true
    }
    transcript = capture_transcript(@gateway) do
      @gateway.create_intent(@amount, @three_ds_credit_card, options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@three_ds_credit_card.number, transcript)
    assert_scrubbed(@three_ds_credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:login], transcript)
  end
end
