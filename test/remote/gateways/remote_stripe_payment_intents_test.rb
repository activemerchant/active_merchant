require 'test_helper'

class RemoteStripeIntentsTest < Test::Unit::TestCase
  def setup
    @gateway = StripePaymentIntentsGateway.new(fixtures(:stripe))
    @customer = @gateway.create_test_customer
    @amount = 2000
    @three_ds_payment_method = 'pm_card_threeDSecure2Required'
    @visa_payment_method = 'pm_card_visa'
    @declined_payment_method = 'pm_card_chargeDeclined'
    @three_ds_moto_enabled = 'pm_card_authenticationRequiredOnSetup'
    @three_ds_authentication_required = 'pm_card_authenticationRequired'
    @cvc_check_fails_credit_card = 'pm_card_cvcCheckFail'
    @avs_fail_card = 'pm_card_avsFail'
    @three_ds_authentication_required_setup_for_off_session = 'pm_card_authenticationRequiredSetupForOffSession'
    @three_ds_off_session_credit_card = credit_card(
      '4000002500003155',
      verification_value: '737',
      month: 10,
      year: 2028
    )

    @three_ds_1_credit_card = credit_card(
      '4000000000003063',
      verification_value: '737',
      month: 10,
      year: 2028
    )

    @three_ds_credit_card = credit_card(
      '4000000000003220',
      verification_value: '737',
      month: 10,
      year: 2028
    )

    @three_ds_not_required_card = credit_card(
      '4000000000003055',
      verification_value: '737',
      month: 10,
      year: 2028
    )

    @three_ds_external_data_card = credit_card(
      '4000002760003184',
      verification_value: '737',
      month: 10,
      year: 2031
    )

    @visa_card = credit_card(
      '4242424242424242',
      verification_value: '737',
      month: 10,
      year: 2028
    )

    @google_pay = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: 'dGVzdGNyeXB0b2dyYW1YWFhYWFhYWFhYWFg9PQ==',
      source: :google_pay,
      brand: 'visa',
      eci: '05',
      month: '09',
      year: '2030',
      first_name: 'Longbob',
      last_name: 'Longsen'
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
      payment_cryptogram: 'AAEBAwQjSQAAXXXXXXXJYe0BbQA=',
      source: :network_token,
      brand: 'visa',
      month: '09',
      year: '2030',
      first_name: 'Longbob',
      last_name: 'Longsen'
    )

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
    assert purchase.params.dig('charges', 'data')[0]['balance_transaction']
  end

  def test_successful_purchase_with_shipping_address
    options = {
      currency: 'GBP',
      customer: @customer,
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

    assert response = @gateway.purchase(@amount, @visa_payment_method, options)
    assert_success response
    assert_equal 'succeeded', response.params['status']
    assert_nil response.params['shipping']['email']
  end

  def test_successful_purchase_with_level3_data
    options = {
      currency: 'USD',
      customer: @customer,
      merchant_reference: 123,
      customer_reference: 456,
      shipping_address_zip: 71601,
      shipping_from_zip: 71601,
      shipping_amount: 10,
      line_items: [
        {
          'product_code' => 1234,
          'product_description' => 'An item',
          'unit_cost' => 15,
          'quantity' => 2,
          'tax_amount' => 0
        },
        {
          'product_code' => 999,
          'product_description' => 'A totes different item',
          'tax_amount' => 10,
          'unit_cost' => 50,
          'quantity' => 1
        }
      ]
    }

    assert response = @gateway.purchase(100, @visa_card, options)
    assert_success response
    assert_equal 'succeeded', response.params['status']
    assert response.params.dig('charges', 'data')[0]['captured']
  end

  def test_unsuccessful_purchase_google_pay_with_invalid_card_number
    options = {
      currency: 'GBP'
    }

    @google_pay.number = '378282246310000'
    purchase = @gateway.purchase(@amount, @google_pay, options)
    assert_equal 'The tokenization process fails. Your card number is incorrect.', purchase.message
    assert_false purchase.success?
  end

  def test_unsuccessful_purchase_google_pay_without_cryptogram
    options = {
      currency: 'GBP'
    }
    @google_pay.payment_cryptogram = ''
    purchase = @gateway.purchase(@amount, @google_pay, options)
    assert_equal "The tokenization process fails. Cards using 'tokenization_method=android_pay' require the 'cryptogram' field to be set.", purchase.message
    assert_false purchase.success?
  end

  def test_unsuccessful_purchase_google_pay_without_month
    options = {
      currency: 'GBP'
    }
    @google_pay.month = ''
    purchase = @gateway.purchase(@amount, @google_pay, options)
    assert_equal 'The tokenization process fails. Missing required param: card[exp_month].', purchase.message
    assert_false purchase.success?
  end

  def test_successful_authorize_with_google_pay
    options = {
      currency: 'GBP'
    }

    auth = @gateway.authorize(@amount, @google_pay, options)

    assert_match('android_pay', auth.responses.first.params.dig('token', 'card', 'tokenization_method'))
    assert auth.success?
    assert_match('google_pay', auth.params.dig('charges', 'data')[0]['payment_method_details']['card']['wallet']['type'])
  end

  def test_successful_purchase_with_google_pay
    options = {
      currency: 'GBP'
    }

    purchase = @gateway.purchase(@amount, @google_pay, options)

    assert_match('android_pay', purchase.responses.first.params.dig('token', 'card', 'tokenization_method'))
    assert purchase.success?
    assert_match('google_pay', purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['wallet']['type'])
  end

  def test_successful_purchase_with_tokenized_visa
    options = {
      currency: 'USD',
      last_4: '4242'
    }

    purchase = @gateway.purchase(@amount, @network_token_credit_card, options)
    assert_equal(nil, purchase.responses.first.params.dig('token', 'card', 'tokenization_method'))
    assert purchase.success?
    assert_not_nil(purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['network_token'])
  end

  def test_successful_purchase_with_google_pay_when_sending_the_billing_address
    options = {
      currency: 'GBP',
      billing_address: address
    }

    purchase = @gateway.purchase(@amount, @google_pay, options)

    assert_match('android_pay', purchase.responses.first.params.dig('token', 'card', 'tokenization_method'))
    billing_address_line1 = purchase.responses.first.params.dig('token', 'card', 'address_line1')
    assert_equal '456 My Street', billing_address_line1
    assert purchase.success?
    assert_match('google_pay', purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['wallet']['type'])
  end

  def test_successful_purchase_with_apple_pay
    options = {
      currency: 'GBP'
    }

    purchase = @gateway.purchase(@amount, @apple_pay, options)
    assert_match('apple_pay', purchase.responses.first.params.dig('token', 'card', 'tokenization_method'))
    assert purchase.success?
    assert_match('apple_pay', purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['wallet']['type'])
  end

  def test_successful_purchase_with_apple_pay_when_sending_the_billing_address
    options = {
      currency: 'GBP',
      billing_address: address
    }

    purchase = @gateway.purchase(@amount, @apple_pay, options)
    assert_match('apple_pay', purchase.responses.first.params.dig('token', 'card', 'tokenization_method'))
    billing_address_line1 = purchase.responses.first.params.dig('token', 'card', 'address_line1')
    assert_equal '456 My Street', billing_address_line1
    assert purchase.success?
    assert_match('apple_pay', purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['wallet']['type'])
  end

  def test_succesful_purchase_with_connect_for_apple_pay
    options = {
      stripe_account: @destination_account
    }
    assert response = @gateway.purchase(@amount, @apple_pay, options)
    assert_success response
  end

  def test_succesful_application_with_connect_for_google_pay
    options = {
      stripe_account: @destination_account
    }
    assert response = @gateway.purchase(@amount, @google_pay, options)
    assert_success response
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

  def test_successful_purchase_with_radar_session
    options = {
      radar_session_id: 'rse_1JXSfZAWOtgoysogUpPJa4sm'
    }
    assert purchase = @gateway.purchase(@amount, @visa_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
  end

  def test_successful_purchase_with_skip_radar_rules
    options = { skip_radar_rules: true }
    assert purchase = @gateway.purchase(@amount, @visa_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert_equal ['all'], purchase.params['charges']['data'][0]['radar_options']['skip_rules']
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

  def test_successful_authorization_with_radar_session
    options = {
      radar_session_id: 'rse_1JXSfZAWOtgoysogUpPJa4sm'
    }
    assert authorization = @gateway.authorize(@amount, @visa_card, options)

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
      metadata: { key_1: 'value_1', key_2: 'value_2' },
      event_type: 'concert'
    }

    assert response = @gateway.create_intent(@amount, nil, options)

    assert_success response
    assert_equal 'value_1', response.params['metadata']['key_1']
    assert_equal 'concert', response.params['metadata']['event_type']
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

  def test_create_setup_intent_with_setup_future_usage
    [@three_ds_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert authorize_response = @gateway.create_setup_intent(card_to_use, {
        address: {
          email: 'test@example.com',
          name: 'John Doe',
          line1: '1 Test Ln',
          city: 'Durham',
          tracking_number: '123456789'
        },
        currency: 'USD',
        confirm: true,
        execute_threed: true,
        return_url: 'https://example.com'
      })

      assert_equal 'requires_action', authorize_response.params['status']
      assert_match 'https://hooks.stripe.com', authorize_response.params.dig('next_action', 'redirect_to_url', 'url')

      # since we cannot "click" the stripe hooks URL to confirm the authorization
      # we will at least confirm we can retrieve the created setup_intent and it contains the structure we expect
      setup_intent_id = authorize_response.params['id']

      assert si_reponse = @gateway.retrieve_setup_intent(setup_intent_id)
      assert_equal 'requires_action', si_reponse.params['status']

      assert_not_empty si_reponse.params.dig('latest_attempt', 'payment_method_details', 'card')
      assert_nil si_reponse.params.dig('latest_attempt', 'payment_method_details', 'card', 'network_transaction_id')
    end
  end

  def test_create_setup_intent_with_connected_account
    [@three_ds_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert authorize_response = @gateway.create_setup_intent(card_to_use, {
        address: {
          email: 'test@example.com',
          name: 'John Doe',
          line1: '1 Test Ln',
          city: 'Durham',
          tracking_number: '123456789'
        },
        currency: 'USD',
        confirm: true,
        execute_threed: true,
        return_url: 'https://example.com',
        stripe_account: @destination_account
      })

      assert_equal 'requires_action', authorize_response.params['status']
      assert_match 'https://hooks.stripe.com', authorize_response.params.dig('next_action', 'redirect_to_url', 'url')

      # since we cannot "click" the stripe hooks URL to confirm the authorization
      # we will at least confirm we can retrieve the created setup_intent and it contains the structure we expect
      setup_intent_id = authorize_response.params['id']

      # If we did not pass the stripe_account header it would return an error
      assert si_response = @gateway.retrieve_setup_intent(setup_intent_id, {
        stripe_account: @destination_account
      })
      assert_equal 'requires_action', si_response.params['status']

      assert_not_empty si_response.params.dig('latest_attempt', 'payment_method_details', 'card')
      assert_nil si_response.params.dig('latest_attempt', 'payment_method_details', 'card', 'network_transaction_id')
    end
  end

  def test_create_setup_intent_with_request_three_d_secure
    [@three_ds_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert authorize_response = @gateway.create_setup_intent(card_to_use, {
        address: {
          email: 'test@example.com',
          name: 'John Doe',
          line1: '1 Test Ln',
          city: 'Durham',
          tracking_number: '123456789'
        },
        currency: 'USD',
        confirm: true,
        execute_threed: true,
        return_url: 'https://example.com',
        request_three_d_secure: 'any'

      })

      assert_equal 'requires_action', authorize_response.params['status']
      assert_match 'https://hooks.stripe.com', authorize_response.params.dig('next_action', 'redirect_to_url', 'url')

      assert_equal 'any', authorize_response.params.dig('payment_method_options', 'card', 'request_three_d_secure')

      # since we cannot "click" the stripe hooks URL to confirm the authorization
      # we will at least confirm we can retrieve the created setup_intent and it contains the structure we expect
      setup_intent_id = authorize_response.params['id']

      assert si_reponse = @gateway.retrieve_setup_intent(setup_intent_id)
      assert_equal 'requires_action', si_reponse.params['status']

      assert_not_empty si_reponse.params.dig('latest_attempt', 'payment_method_details', 'card')
      assert_nil si_reponse.params.dig('latest_attempt', 'payment_method_details', 'card', 'network_transaction_id')
    end
  end

  def test_retrieving_error_for_non_existant_setup_intent
    assert si_reponse = @gateway.retrieve_setup_intent('seti_does_not_exist')
    assert_nil si_reponse.params['status']
    assert_nil si_reponse.params.dig('latest_attempt', 'payment_method_details', 'card', 'network_transaction_id')

    assert_match 'resource_missing', si_reponse.params.dig('error', 'code')
    assert_match "No such setupintent: 'seti_does_not_exist'", si_reponse.params.dig('error', 'message')
  end

  def test_3ds_unauthenticated_authorize_with_off_session_requires_capture
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert authorize_response = @gateway.authorize(@amount, card_to_use, {
        address: {
          email: 'test@example.com',
          name: 'John Doe',
          line1: '1 Test Ln',
          city: 'Durham',
          tracking_number: '123456789'
        },
        currency: 'USD',
        confirm: true,
        setup_future_usage: 'off_session',
        execute_threed: true,
        three_d_secure: {
          version: '2.2.0',
          eci: '02',
          cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
          ds_transaction_id: 'f879ea1c-aa2c-4441-806d-e30406466d79'
        }
      })

      assert_success authorize_response
      assert_equal 'requires_capture', authorize_response.params['status']
      assert_not_empty authorize_response.params.dig('charges', 'data')[0]['payment_method_details']['card']['network_transaction_id']
    end
  end

  def test_purchase_sends_network_transaction_id_separate_from_stored_creds
    [@visa_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert purchase = @gateway.purchase(@amount, card_to_use, {
        currency: 'USD',
        execute_threed: true,
        confirm: true,
        off_session: true,
        network_transaction_id: '1234567891011'
      })
      assert_success purchase
      assert_equal 'succeeded', purchase.params['status']
      assert purchase.params.dig('charges', 'data')[0]['captured']
      assert purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['network_transaction_id']
    end
  end

  def test_purchase_works_with_stored_credentials
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert purchase = @gateway.purchase(@amount, card_to_use, {
        currency: 'USD',
        execute_threed: true,
        confirm: true,
        off_session: true,
        setup_future_usage: true,
        stored_credential: {
          network_transaction_id: '1098510912210968', # TEST env seems happy with any value :/
          ds_transaction_id: 'null' # this is not req
        }
      })

      assert_success purchase
      assert_equal 'succeeded', purchase.params['status']
      assert purchase.params.dig('charges', 'data')[0]['captured']
    end
  end

  def test_purchase_works_with_stored_credentials_without_optional_ds_transaction_id
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert purchase = @gateway.purchase(@amount, card_to_use, {
        currency: 'USD',
        execute_threed: true,
        confirm: true,
        off_session: true,
        stored_credential: {
          network_transaction_id: '1098510912210968' # TEST env seems happy with any value :/
        }
      })

      assert_success purchase
      assert_equal 'succeeded', purchase.params['status']
      assert purchase.params.dig('charges', 'data')[0]['captured']
    end
  end

  def test_succeeds_with_ntid_in_stored_credentials_and_separately
    [@visa_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert purchase = @gateway.purchase(@amount, card_to_use, {
        currency: 'USD',
        execute_threed: true,
        confirm: true,
        off_session: true,
        network_transaction_id: '1078784111114777',
        stored_credential: {
          network_transaction_id: '1098510912210968',
          ds_transaction_id: 'null'
        }
      })
      assert_success purchase
      assert_equal 'succeeded', purchase.params['status']
      assert purchase.params.dig('charges', 'data')[0]['captured']
      assert purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['network_transaction_id']
    end
  end

  def test_succeeds_with_initial_cit
    assert purchase = @gateway.purchase(@amount, @visa_card, {
      currency: 'USD',
      execute_threed: true,
      confirm: true,
      stored_credential_transaction_type: true,
      stored_credential: {
        initiator: 'cardholder',
        reason_type: 'unscheduled',
        initial_transaction: true
      }
    })
    assert_success purchase
    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
    assert purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['network_transaction_id']
  end

  def test_succeeds_with_initial_cit_3ds_required
    assert purchase = @gateway.purchase(@amount, @three_ds_authentication_required_setup_for_off_session, {
      currency: 'USD',
      execute_threed: true,
      confirm: true,
      stored_credential_transaction_type: true,
      stored_credential: {
        initiator: 'cardholder',
        reason_type: 'unscheduled',
        initial_transaction: true
      }
    })
    assert_success purchase
    assert_equal 'requires_action', purchase.params['status']
  end

  def test_succeeds_with_mit
    assert purchase = @gateway.purchase(@amount, @visa_card, {
      currency: 'USD',
      execute_threed: true,
      confirm: true,
      stored_credential_transaction_type: true,
      stored_credential: {
        initiator: 'merchant',
        reason_type: 'recurring',
        initial_transaction: false,
        network_transaction_id: '1098510912210968'
      }
    })
    assert_success purchase
    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
    assert purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['network_transaction_id']
  end

  def test_succeeds_with_mit_3ds_required
    assert purchase = @gateway.purchase(@amount, @three_ds_authentication_required_setup_for_off_session, {
      currency: 'USD',
      confirm: true,
      stored_credential_transaction_type: true,
      stored_credential: {
        initiator: 'merchant',
        reason_type: 'unscheduled',
        initial_transaction: false,
        network_transaction_id: '1098510912210968'
      }
    })
    assert_success purchase
    assert_equal 'succeeded', purchase.params['status']
    assert purchase.params.dig('charges', 'data')[0]['captured']
    assert purchase.params.dig('charges', 'data')[0]['payment_method_details']['card']['network_transaction_id']
  end

  def test_successful_off_session_purchase_when_claim_without_transaction_id_present
    [@three_ds_off_session_credit_card, @three_ds_authentication_required_setup_for_off_session].each do |card_to_use|
      assert response = @gateway.purchase(@amount, card_to_use, {
        currency: 'USD',
        execute_thread: true,
        confirm: true,
        off_session: true,
        claim_without_transaction_id: true
      })
      assert_success response
      assert_equal 'succeeded', response.params['status']
      assert response.params.dig('charges', 'data')[0]['captured']
    end
  end

  def test_successful_off_session_purchase_with_authentication_when_claim_without_transaction_id_is_false
    assert response = @gateway.purchase(@amount, @three_ds_authentication_required_setup_for_off_session, {
      currency: 'USD',
      execute_thread: true,
      confirm: true,
      off_session: true,
      claim_without_transaction_id: false
    })
    # Purchase should succeed since other credentials are passed
    assert_success response
    assert_equal 'succeeded', response.params['status']
    assert response.params.dig('charges', 'data')[0]['captured']
  end

  def test_failed_off_session_purchase_with_card_when_claim_without_transaction_id_is_false
    assert response = @gateway.purchase(@amount, @three_ds_off_session_credit_card, {
      currency: 'USD',
      execute_thread: true,
      confirm: true,
      off_session: true,
      claim_without_transaction_id: false
    })
    # Purchase should fail since no other credentials are passed,
    # and Stripe will not manage the transaction without a transaction id
    assert_failure response
    assert_equal 'failed', response.params.dig('error', 'payment_intent', 'charges', 'data')[0]['status']
    assert !response.params.dig('error', 'payment_intent', 'charges', 'data')[0]['captured']
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
    assert_match 'Received unexpected 3DS authentication response, but a 3DS initiation flag was not included in the request.', response.message
  end

  def test_create_payment_intent_with_shipping_address
    options = {
      currency: 'USD',
      customer: @customer,
      shipping_address: {
        address1: '1 Test Ln',
        city: 'Durham',
        name: 'John Doe'
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
      email: 'jim@widgets.inc',
      confirm: true
    }
    assert response = @gateway.create_intent(@amount, @visa_card, options)
    assert_success response
    assert billing_details = response.params.dig('charges', 'data')[0].dig('billing_details')
    assert_equal 'Ottawa', billing_details['address']['city']
    assert_equal 'jim@widgets.inc', billing_details['email']
  end

  def test_create_payment_intent_with_name_if_billing_address_absent
    options = {
      currency: 'USD',
      customer: @customer,
      confirm: true
    }
    name_on_card = [@visa_card.first_name, @visa_card.last_name].join(' ')

    assert response = @gateway.create_intent(@amount, @visa_card, options)
    assert_success response
    assert_equal name_on_card, response.params.dig('charges', 'data')[0].dig('billing_details', 'name')
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

  def test_create_payment_intent_with_fulfillment_date
    options = {
      currency: 'USD',
      customer: @customer,
      fulfillment_date: 1636756194
    }
    assert response = @gateway.authorize(@amount, @visa_payment_method, options)
    assert_success response
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

  def test_create_a_payment_intent_and_manually_capture_with_network_token
    options = {
      currency: 'GBP',
      customer: @customer,
      confirmation_method: 'manual',
      capture_method: 'manual',
      confirm: true,
      last_4: '4242'
    }
    assert create_response = @gateway.create_intent(@amount, @network_token_credit_card, options)
    intent_id = create_response.params['id']
    assert_equal 'requires_capture', create_response.params['status']

    assert capture_response = @gateway.capture(@amount, intent_id, options)
    assert_equal 'succeeded', capture_response.params['status']
    assert_equal 'Payment complete.', capture_response.params.dig('charges', 'data')[0].dig('outcome', 'seller_message')
  end

  def test_failed_create_a_payment_intent_with_set_error_on_requires_action
    options = {
      currency: 'GBP',
      customer: @customer,
      confirm: true,
      error_on_requires_action: true
    }
    assert create_response = @gateway.create_intent(@amount, @three_ds_credit_card, options)
    assert create_response.message.include?('This payment required an authentication action to complete, but `error_on_requires_action` was set.')
  end

  def test_successful_create_a_payment_intent_with_set_error_on_requires_action
    options = {
      currency: 'GBP',
      customer: @customer,
      confirm: true,
      error_on_requires_action: true
    }
    assert create_response = @gateway.create_intent(@amount, @visa_payment_method, options)
    assert_equal 'succeeded', create_response.params['status']
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

  def test_create_a_payment_intent_and_confirm_with_different_payment_method
    options = {
      currency: 'USD',
      payment_method_types: %w[afterpay_clearpay],
      metadata: { key_1: 'value_1', key_2: 'value_2' }
    }
    assert create_response = @gateway.setup_purchase(@amount, options)
    assert_equal 'requires_payment_method', create_response.params['status']
    intent_id = create_response.params['id']
    assert_equal 2000, create_response.params['amount']
    assert_equal 'afterpay_clearpay', create_response.params['payment_method_types'][0]

    assert confirm_response = @gateway.confirm_intent(intent_id, @visa_payment_method, payment_method_types: 'card')
    assert_equal 'card', confirm_response.params['payment_method_types'][0]
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
      'requires_payment_method, requires_capture, requires_confirmation, requires_action, processing.', cancel_response.message
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

  def test_successful_customer_creating
    options = {
      currency: 'GBP',
      billing_address: address,
      shipping_address: address.merge!(email: 'test@email.com')
    }
    assert customer = @gateway.customer({}, @visa_card, options)

    assert_equal customer.params['name'], 'Jim Smith'
    assert_equal customer.params['phone'], '(555)555-5555'
    assert_nil customer.params['shipping']['email']
    assert_not_empty customer.params['shipping']
    assert_not_empty customer.params['address']
  end

  def test_successful_store_with_false_validate_option
    options = {
      currency: 'GBP',
      validate: false
    }
    assert store = @gateway.store(@visa_card, options)
    assert store.params['customer'].start_with?('cus_')
    assert_equal 'unchecked', store.params['card']['checks']['cvc_check']
  end

  def test_successful_store_with_true_validate_option
    options = {
      currency: 'GBP',
      validate: true
    }
    assert store = @gateway.store(@visa_card, options)
    assert store.params['customer'].start_with?('cus_')
    assert_equal 'pass', store.params['card']['checks']['cvc_check']
  end

  def test_successful_verify
    options = {
      customer: @customer
    }
    assert verify = @gateway.verify(@visa_card, options)
    assert_equal 'US', verify.responses[0].params.dig('card', 'country')
    assert_equal 'succeeded', verify.params['status']
  end

  def test_failed_verify
    options = {
      customer: @customer
    }
    assert verify = @gateway.verify(@declined_payment_method, options)

    assert_equal 'Your card was declined.', verify.message
  end

  def test_verify_stores_response_for_payment_method_creation
    assert verify = @gateway.verify(@visa_card)

    assert_equal 2, verify.responses.count
    assert_match 'pm_', verify.responses.first.params['id']
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

  def test_setup_purchase
    options = {
      currency: 'USD',
      payment_method_types: %w[afterpay_clearpay card],
      metadata: { key_1: 'value_1', key_2: 'value_2' }
    }

    assert response = @gateway.setup_purchase(@amount, options)
    assert_equal 'requires_payment_method', response.params['status']
    assert_equal 'value_1', response.params['metadata']['key_1']
    assert_equal 'value_2', response.params['metadata']['key_2']
    assert response.params['client_secret'].start_with?('pi')
  end

  def test_failed_setup_purchase
    options = {
      currency: 'GBP',
      payment_method_types: %w[afterpay_clearpay card]
    }

    assert response = @gateway.setup_purchase(@amount, options)
    assert_failure response
    assert_match 'The currency provided (gbp) is invalid for one or more payment method types on this PaymentIntent.', response.message
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

  def test_succeeded_cvc_check
    options = {}
    assert purchase = @gateway.purchase(@amount, @visa_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert_equal 'M', purchase.cvv_result.dig('code')
    assert_equal 'CVV matches', purchase.cvv_result.dig('message')
  end

  def test_failed_cvc_check
    options = {}
    assert purchase = @gateway.purchase(@amount, @cvc_check_fails_credit_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert_equal 'N', purchase.cvv_result.dig('code')
    assert_equal 'CVV does not match', purchase.cvv_result.dig('message')
  end

  def test_failed_avs_check
    options = {}
    assert purchase = @gateway.purchase(@amount, @avs_fail_card, options)

    assert_equal 'succeeded', purchase.params['status']
    assert_equal 'N', purchase.avs_result['code']
    assert_equal 'N', purchase.avs_result['postal_match']
    assert_equal 'N', purchase.avs_result['street_match']
  end
end
