require 'test_helper'

class RemoteWorldpayTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayGateway.new(fixtures(:world_pay_gateway))
    @cftgateway = WorldpayGateway.new(fixtures(:world_pay_gateway_cft))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @elo_credit_card = credit_card('4514 1600 0000 0008',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737',
      :brand => 'elo'
    )
    @cabal_card = credit_card('6035220000000006')
    @naranja_card = credit_card('5895620000000002')
    @sodexo_voucher = credit_card('6060704495764400', brand: 'sodexo')
    @declined_card = credit_card('4111111111111111', :first_name => nil, :last_name => 'REFUSED')
    @threeDS_card = credit_card('4111111111111111', :first_name => nil, :last_name => '3D')
    @threeDS2_card = credit_card('4111111111111111', :first_name => nil, :last_name => '3DS_V2_FRICTIONLESS_IDENTIFIED')
    @threeDS_card_external_MPI = credit_card('4444333322221111', :first_name => 'AA', :last_name => 'BD')

    @options = {
      order_id: generate_unique_id,
      email: 'wow@example.com'
    }
    @store_options = {
      customer: generate_unique_id,
      email: 'wow@example.com'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_elo
    assert response = @gateway.purchase(@amount, @elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_cabal
    response = @gateway.purchase(@amount, @cabal_card, @options.merge(currency: 'ARS'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_naranja
    response = @gateway.purchase(@amount, @naranja_card, @options.merge(currency: 'ARS'))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_avs_and_cvv
    card = credit_card('4111111111111111', :verification_value => 555)
    assert response = @gateway.authorize(@amount, card, @options.merge(billing_address: address.update(zip: 'CCCC')))
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_match %r{Street address does not match, but 5-digit postal code matches}, response.avs_result['message']
    assert_match %r{CVV matches}, response.cvv_result['message']
  end

  def test_successful_3ds2_authorize
    options = @options.merge({execute_threed: true, three_ds_version: '2.0'})
    assert response = @gateway.authorize(@amount, @threeDS2_card, options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_with_hcg_additional_data
    @options[:hcg_additional_data] = {
      key1: 'value1',
      key2: 'value2',
      key3: 'value3'
    }

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_equal 'REFUSED', response.message
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_authorize_and_capture_by_reference
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
    assert reference = auth.authorization
    @options[:order_id] = generate_unique_id

    assert auth = @gateway.authorize(@amount, reference, @options)
    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_authorize_and_purchase_by_reference
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'SUCCESS', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
    assert reference = auth.authorization

    @options[:order_id] = generate_unique_id
    assert auth = @gateway.authorize(@amount, reference, @options)

    @options[:order_id] = generate_unique_id
    assert capture = @gateway.purchase(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_authorize_and_purchase_with_instalments
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(instalment: 3))
    assert_success auth
    assert_equal 'SUCCESS', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_authorize_with_3ds
    session_id = generate_unique_id
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        user_agent: 'Mozilla/5.0',
        session_id: session_id,
        ip: '127.0.0.1',
        cookie: 'machine=32423423'
      })
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert_equal "A transaction status of 'AUTHORISED' is required.", first_message.message
    assert first_message.test?
    refute first_message.authorization.blank?
    refute first_message.params['issuer_url'].blank?
    refute first_message.params['pa_request'].blank?
    refute first_message.params['cookie'].blank?
    refute first_message.params['session_id'].blank?
  end

  # Ensure the account is configured to use this feature to proceed successfully
  def test_marking_3ds_purchase_as_moto
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(metadata: { manual_entry: true }))
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_auth_and_capture_with_normalized_stored_credential
    stored_credential_params = {
      initial_transaction: true,
      reason_type: 'unscheduled',
      initiator: 'merchant',
      network_transaction_id: nil
    }

    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge({stored_credential: stored_credential_params}))
    assert_success auth
    assert auth.authorization
    assert auth.params['scheme_response']
    assert auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    @options[:order_id] = generate_unique_id
    @options[:stored_credential] = {
      initial_transaction: false,
      reason_type: 'installment',
      initiator: 'merchant',
      network_transaction_id: auth.params['transaction_identifier']
    }

    assert next_auth = @gateway.authorize(@amount, @credit_card, @options)
    assert next_auth.authorization
    assert next_auth.params['scheme_response']
    assert next_auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_auth_and_capture_with_gateway_specific_stored_credentials
    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(stored_credential_usage: 'FIRST'))
    assert_success auth
    assert auth.authorization
    assert auth.params['scheme_response']
    assert auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
    assert_success capture

    options = @options.merge(
      order_id: generate_unique_id,
      stored_credential_usage: 'USED',
      stored_credential_initiated_reason: 'UNSCHEDULED',
      stored_credential_transaction_id: auth.params['transaction_identifier']
    )
    assert next_auth = @gateway.authorize(@amount, @credit_card, options)
    assert next_auth.authorization
    assert next_auth.params['scheme_response']
    assert next_auth.params['transaction_identifier']

    assert capture = @gateway.capture(@amount, next_auth.authorization, authorization_validated: true)
    assert_success capture
  end

  def test_successful_authorize_with_3ds_with_normalized_stored_credentials
    session_id = generate_unique_id
    stored_credential_params = {
      initial_transaction: true,
      reason_type: 'unscheduled',
      initiator: 'merchant',
      network_transaction_id: nil
    }
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        user_agent: 'Mozilla/5.0',
        session_id: session_id,
        ip: '127.0.0.1',
        cookie: 'machine=32423423',
        stored_credential: stored_credential_params
      })
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert_equal "A transaction status of 'AUTHORISED' is required.", first_message.message
    assert first_message.test?
    refute first_message.authorization.blank?
    refute first_message.params['issuer_url'].blank?
    refute first_message.params['pa_request'].blank?
    refute first_message.params['cookie'].blank?
    refute first_message.params['session_id'].blank?
  end

  def test_successful_authorize_with_3ds_with_gateway_specific_stored_credentials
    session_id = generate_unique_id
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        user_agent: 'Mozilla/5.0',
        session_id: session_id,
        ip: '127.0.0.1',
        cookie: 'machine=32423423',
        stored_credential_usage: 'FIRST'
      })
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert_equal "A transaction status of 'AUTHORISED' is required.", first_message.message
    assert first_message.test?
    refute first_message.authorization.blank?
    refute first_message.params['issuer_url'].blank?
    refute first_message.params['pa_request'].blank?
    refute first_message.params['cookie'].blank?
    refute first_message.params['session_id'].blank?
  end

  # Fails currently because the sandbox doesn't actually validate the stored_credential options
  # def test_failed_authorize_with_bad_stored_cred_options
  #   assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(stored_credential_usage: 'FIRST'))
  #   assert_success auth
  #   assert auth.authorization
  #   assert auth.params['scheme_response']
  #   assert auth.params['transaction_identifier']
  #
  #   assert capture = @gateway.capture(@amount, auth.authorization, authorization_validated: true)
  #   assert_success capture
  #
  #   options = @options.merge(
  #     order_id: generate_unique_id,
  #     stored_credential_usage: 'MEH',
  #     stored_credential_initiated_reason: 'BLAH',
  #     stored_credential_transaction_id: 'nah'
  #   )
  #   assert next_auth = @gateway.authorize(@amount, @credit_card, options)
  #   assert_failure next_auth
  # end

  def test_failed_authorize_with_3ds
    session_id = generate_unique_id
    options = @options.merge(
      {
        execute_threed: true,
        accept_header: 'text/html',
        session_id: session_id,
        ip: '127.0.0.1',
        cookie: 'machine=32423423'
      })
    assert first_message = @gateway.authorize(@amount, @threeDS_card, options)
    assert_match %r{missing info for 3D-secure transaction}i, first_message.message
    assert first_message.test?
    assert first_message.params['issuer_url'].blank?
    assert first_message.params['pa_request'].blank?
  end

  def test_3ds_version_1_parameters_pass_thru
    options = @options.merge(
      {
        three_d_secure: {
          version: '1.0.2',
          xid: '',
          cavv: 'MAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          eci: '05'
        }
      }
    )

    assert response = @gateway.authorize(@amount, @threeDS_card_external_MPI, @options.merge(options))
    assert response.test?
    assert response.success?
    assert response.params['last_event'] || response.params['ok']
  end

  def test_3ds_version_2_parameters_pass_thru
    options = @options.merge(
      {
        three_d_secure: {
          version: '2.1.0',
          xid: 'A' * 40,
          cavv: 'MAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          eci: '05'
        }
      }
    )

    assert response = @gateway.authorize(@amount, @threeDS_card_external_MPI, @options.merge(options))
    assert response.test?
    assert response.success?
    assert response.params['last_event'] || response.params['ok']
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 'bogus')
    assert_failure response
    assert_equal 'Could not find payment for order', response.message
  end

  def test_billing_address
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(:billing_address => address))
  end

  def test_partial_address
    billing_address = address
    billing_address.delete(:address1)
    billing_address.delete(:zip)
    billing_address.delete(:country)
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(:billing_address => billing_address))
  end

  def test_ip_address
    assert_success @gateway.authorize(@amount, @credit_card, @options.merge(ip: '192.18.123.12'))
  end

  def test_void
    assert_success response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success void = @gateway.void(response.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', void.message
    assert void.params['cancel_received_order_code']
  end

  def test_void_with_elo
    assert_success response = @gateway.authorize(@amount, @elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success void = @gateway.void(response.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', void.message
    assert void.params['cancel_received_order_code']
  end

  def test_void_nonexistent_transaction
    assert_failure response = @gateway.void('non_existent_authorization')
    assert_equal 'Could not find payment for order', response.message
  end

  def test_authorize_fractional_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(:currency => 'USD')))
    assert_equal 'USD', result.params['amount_currency_code']
    assert_equal '1234', result.params['amount_value']
    assert_equal '2', result.params['amount_exponent']
  end

  def test_authorize_nonfractional_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(:currency => 'IDR')))
    assert_equal 'IDR', result.params['amount_currency_code']
    assert_equal '12', result.params['amount_value']
    assert_equal '0', result.params['amount_exponent']
  end

  def test_authorize_three_decimal_currency
    assert_success(result = @gateway.authorize(1234, @credit_card, @options.merge(:currency => 'OMR')))
    assert_equal 'OMR', result.params['amount_currency_code']
    assert_equal '1234', result.params['amount_value']
    assert_equal '3', result.params['amount_exponent']
  end

  def test_reference_transaction
    assert_success(original = @gateway.authorize(100, @credit_card, @options))
    assert_success(@gateway.authorize(200, original.authorization, :order_id => generate_unique_id))
  end

  def test_invalid_login
    gateway = WorldpayGateway.new(:login => '', :password => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid credentials', response.message
  end

  def test_refund_fails_unless_status_is_captured
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success(response)

    assert refund = @gateway.refund(30, response.authorization)
    assert_failure refund
    assert_equal 'Order not ready', refund.message
  end

  def test_refund_nonexistent_transaction
    assert_failure response = @gateway.refund(@amount, 'non_existent_authorization')
    assert_equal 'Could not find payment for order', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_successful_verify_with_elo
    response = @gateway.verify(@elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{REFUSED}, response.message
  end

  def test_successful_visa_credit_on_cft_gateway
    credit = @cftgateway.credit(@amount, @credit_card, @options)
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_successful_mastercard_credit_on_cft_gateway
    cc = credit_card('5555555555554444')
    credit = @cftgateway.credit(@amount, cc, @options)
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_failed_authorize_with_unknown_card
    assert auth = @gateway.authorize(@amount, @sodexo_voucher, @options)
    assert_failure auth
    assert_equal '5', auth.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, auth.message
  end

  def test_failed_purchase_with_unknown_card
    assert response = @gateway.purchase(@amount, @sodexo_voucher, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, response.message
  end

  def test_failed_verify_with_unknown_card
    response = @gateway.verify(@sodexo_voucher, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{XML failed validation: Invalid payment details : Card number not recognised:}, response.message
  end

  # Worldpay has a delay between asking for a transaction to be captured and actually marking it as captured
  # These 2 tests work if you get authorizations from a purchase, wait some time and then perform the refund/void operation.
  #
  # def test_get_authorization
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert response.authorization
  #   puts 'auth: ' + response.authorization
  # end
  #
  def test_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert response.authorization

    refund = @gateway.refund(@amount, response.authorization, authorization_validated: true)
    assert_success refund
    assert_equal 'SUCCESS', refund.message
  end

  def test_multiple_refunds
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'SUCCESS', purchase.message

    partial_amount = @amount - 1
    assert_success refund1 = @gateway.refund(partial_amount, purchase.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', refund1.message

    assert_success refund2 = @gateway.refund(@amount - partial_amount, purchase.authorization, authorization_validated: true)
    assert_equal 'SUCCESS', refund2.message
  end

  # def test_void_fails_unless_status_is_authorised
  #   response = @gateway.void('replace_with_authorization') # existing transaction in CAPTURED state
  #   assert_failure response
  #   assert_equal 'A transaction status of 'AUTHORISED' is required.', response.message
  # end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @store_options)
    assert_success response
    assert_equal 'SUCCESS', response.message
    assert_match response.params['payment_token_id'], response.authorization
    assert_match 'shopper', response.authorization
    assert_match @store_options[:customer], response.authorization
  end

  def test_successful_authorize_using_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_using_token_and_minimum_options
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, order_id: generate_unique_id)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_purchase_using_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_successful_verify_using_token
    assert store = @gateway.store(@credit_card, @store_options)
    assert_success store

    response = @gateway.verify(store.authorization, @options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_successful_credit_using_token
    assert store = @cftgateway.store(@credit_card, @store_options)
    assert_success store

    credit = @cftgateway.credit(@amount, store.authorization, @options)
    assert_success credit
    assert_equal 'SUCCESS', credit.message
  end

  def test_failed_store
    assert response = @gateway.store(@credit_card, @store_options.merge(customer: '_invalidId'))
    assert_failure response
    assert_equal '2', response.error_code
    assert_equal 'authenticatedShopperID cannot start with an underscore', response.message
  end

  def test_failed_authorize_using_token
    assert store = @gateway.store(@declined_card, @store_options)
    assert_success store

    assert response = @gateway.authorize(@amount, store.authorization, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_equal 'REFUSED', response.message
  end

  def test_failed_authorize_using_bogus_token
    assert response = @gateway.authorize(@amount, '|this|is|bogus', @options)
    assert_failure response
    assert_equal '2', response.error_code
    assert_match 'tokenScope', response.message
  end

  def test_failed_verify_using_token
    assert store = @gateway.store(@declined_card, @store_options)
    assert_success store

    response = @gateway.verify(store.authorization, @options)
    assert_failure response
    assert_equal '5', response.error_code
    assert_match %r{REFUSED}, response.message
  end
end
