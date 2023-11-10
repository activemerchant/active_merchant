require 'test_helper'

class RemotePayeezyTest < Test::Unit::TestCase
  def setup
    @gateway = PayeezyGateway.new(fixtures(:payeezy))
    @credit_card = credit_card
    @bad_credit_card = credit_card('4111111111111113')
    @check = check
    @amount = 100
    @reversal_id = "REV-#{SecureRandom.random_number(1000000)}"
    @options = {
      billing_address: address,
      merchant_ref: 'Store Purchase',
      ta_token: 'NOIW'
    }
    @options_mdd = {
      soft_descriptors: {
        dba_name: 'Caddyshack',
        street: '1234 Any Street',
        city: 'Durham',
        region: 'North Carolina',
        mid: 'mid_1234',
        mcc: 'mcc_5678',
        postal_code: '27701',
        country_code: 'US',
        merchant_contact_info: '8885551212'
      }
    }
    @options_stored_credentials = {
      cardbrand_original_transaction_id: 'abc123',
      sequence: 'FIRST',
      is_scheduled: true,
      initiator: 'MERCHANT',
      auth_type_override: 'A'
    }
    @options_standardized_stored_credentials = {
      stored_credential: {
        network_transaction_id: 'abc123', # Not checked if initial_transaction == true; not valid if initial_transaction == false.
        initial_transaction: true,
        reason_type: 'recurring',
        initiator: 'cardholder'
      }
    }
    @apple_pay_card = network_tokenization_credit_card(
      '4761209980011439',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: Time.now.year + 1,
      eci: 5,
      source: :apple_pay,
      verification_value: 569
    )
    @apple_pay_card_amex = network_tokenization_credit_card(
      '373953192351004',
      brand: 'american_express',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: Time.now.year + 1,
      eci: 5,
      source: :apple_pay,
      verification_value: 569
    )
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'Token successfully created.', response.message
    assert response.authorization
  end

  def test_successful_store_and_purchase
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert !response.authorization.blank?
    assert purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_success purchase
  end

  def test_unsuccessful_store
    assert response = @gateway.store(@bad_credit_card, @options)
    assert_failure response
    assert_equal 'The credit card number check failed', response.message
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_equal '100', response.params['bank_resp_code']
    assert_equal nil, response.error_code
    assert_success response
  end

  def test_successful_purchase_with_apple_pay
    assert response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_apple_pay_amex
    assert response = @gateway.purchase(@amount, @apple_pay_card_amex, @options)
    assert_success response
  end

  def test_successful_authorize_and_capture_with_apple_pay
    assert auth = @gateway.authorize(@amount, @apple_pay_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_purchase_with_echeck
    options = @options.merge({ customer_id_type: '1', customer_id_number: '1', client_email: 'test@example.com' })
    assert response = @gateway.purchase(@amount, @check, options)
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_soft_descriptors
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@options_mdd))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_and_authorize_with_reference_3
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(reference_3: '123345'))
    assert_match(/Transaction Normal/, response.message)
    assert_success response

    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(reference_3: '123345'))
    assert_match(/Transaction Normal/, auth.message)
    assert_success auth
  end

  def test_successful_purchase_and_authorize_with_customer_ref_top_level
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(customer_ref: 'abcde'))
    assert_match(/Transaction Normal/, response.message)
    assert_success response

    assert auth = @gateway.authorize(@amount, @credit_card, @options.merge(customer_ref: 'abcde'))
    assert_match(/Transaction Normal/, auth.message)
    assert_success auth
  end

  def test_successful_purchase_with_customer_ref
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(level2: { customer_ref: 'An important customer' }))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_stored_credentials
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@options_stored_credentials))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_standardized_stored_credentials
    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(@options_standardized_stored_credentials))
    assert_match(/Transaction Normal/, response.message)
    assert_success response
  end

  def test_successful_purchase_with_apple_pay_name_from_billing_address
    @apple_pay_card.first_name = nil
    @apple_pay_card.last_name = nil
    assert response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
    assert_equal 'Jim Smith', response.params['card']['cardholder_name']
  end

  def test_failed_purchase_with_apple_pay_no_name
    @options[:billing_address] = nil
    @apple_pay_card.first_name = nil
    @apple_pay_card.last_name = nil
    assert response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_failure response
    assert_equal 'Bad Request (27) - Invalid Card Holder', response.message
  end

  def test_failed_purchase
    @amount = 501300
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction not approved/, response.message)
    assert_failure response
  end

  def test_failed_purchase_with_insufficient_funds
    assert response = @gateway.purchase(530200, @credit_card, @options)
    assert_failure response
    assert_equal '302', response.error_code
    assert_match(/Insufficient Funds/, response.message)
  end

  def test_successful_purchase_with_three_ds_data
    @options[:three_d_secure] = {
      version: '1',
      eci: '05',
      cavv: '3q2+78r+ur7erb7vyv66vv////8=',
      acs_transaction_id: '6546464645623455665165+qe-jmhabcdefg'
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_equal '100', response.params['bank_resp_code']
    assert_equal nil, response.error_code
    assert_success response
  end

  def test_authorize_and_capture_three_ds_data
    @options[:three_d_secure] = {
      version: '1',
      eci: '05',
      cavv: '3q2+78r+ur7erb7vyv66vv////8=',
      acs_transaction_id: '6546464645623455665165+qe-jmhabcdefg'
    }
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_purchase_with_three_ds_version_data
    @options[:three_d_secure] = {
      version: '1.0.2',
      eci: '05',
      cavv: '3q2+78r+ur7erb7vyv66vv////8=',
      acs_transaction_id: '6546464645623455665165+qe-jmhabcdefg'
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, response.message)
    assert_equal '100', response.params['bank_resp_code']
    assert_equal nil, response.error_code
    assert_success response
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert auth.authorization
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_successful_store_and_auth_and_capture
    assert response = @gateway.store(@credit_card, @options)
    assert_success response

    assert auth = @gateway.authorize(@amount, response.authorization, @options)
    assert_success auth
    assert auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    @amount = 501300
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure auth
    assert auth.authorization
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '1|1')
    assert_failure response
  end

  def test_successful_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_successful_refund_with_soft_descriptors
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization, @options.merge(@options_mdd))
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_successful_refund_with_order_id
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization, @options.merge(order_id: '1234'))
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_successful_refund_with_echeck
    assert purchase = @gateway.purchase(@amount, @check, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_successful_refund_with_stored_card
    response = @gateway.store(@credit_card, @options)
    assert_success response

    assert purchase = @gateway.purchase(@amount, response.authorization, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, purchase.authorization)
    assert_success response
    assert_match(/Transaction Normal/, response.message)
    assert response.authorization
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Transaction Normal/, purchase.message)
    assert_success purchase

    assert response = @gateway.refund(50, 'bad-authorization')
    assert_failure response
    assert_match(/The transaction tag is not provided/, response.message)
    assert response.authorization
  end

  def test_successful_general_credit
    assert response = @gateway.credit(@amount, @credit_card, @options.merge(@options_mdd))
    assert_match(/Transaction Normal/, response.message)
    assert_equal '100', response.params['bank_resp_code']
    assert_equal nil, response.error_code
    assert_success response
  end

  def test_successful_general_credit_with_order_id
    assert response = @gateway.credit(@amount, @credit_card, @options.merge(order_id: '1234'))
    assert_match(/Transaction Normal/, response.message)
    assert_equal '100', response.params['bank_resp_code']
    assert_equal nil, response.error_code
    assert_success response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction Normal - Approved', void.message
  end

  def test_successful_auth_void_with_reversal_id
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(reversal_id: @reversal_id))
    assert_success auth

    assert void = @gateway.void(auth.authorization, reversal_id: @reversal_id)
    assert_success void
    assert_equal 'Transaction Normal - Approved', void.message
  end

  def test_successful_void_purchase_with_reversal_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(reversal_id: @reversal_id))
    assert_success response

    assert void = @gateway.void(response.authorization, reversal_id: @reversal_id)
    assert_success void
    assert_equal 'Transaction Normal - Approved', void.message
  end

  def test_successful_void_with_stored_card_and_reversal_id
    response = @gateway.store(@credit_card, @options)
    assert_success response

    auth = @gateway.authorize(@amount, response.authorization, @options.merge(reversal_id: @reversal_id))
    assert_success auth

    assert void = @gateway.void(auth.authorization, reversal_id: @reversal_id)
    assert_success void
    assert_equal 'Transaction Normal - Approved', void.message
  end

  def test_successful_void_with_stored_card
    response = @gateway.store(@credit_card, @options)
    assert_success response

    auth = @gateway.authorize(@amount, response.authorization, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transaction Normal - Approved', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'The transaction id is not provided', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Transaction Normal - Approved}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match %r{The credit card number check failed}, response.message
  end

  def test_bad_creditcard_number
    assert response = @gateway.purchase(@amount, @bad_credit_card, @options)
    assert_failure response
    assert_equal response.error_code, 'invalid_card_number'
  end

  def test_invalid_login
    gateway = PayeezyGateway.new(apikey: 'NotARealUser', apisecret: 'NotARealPassword', token: 'token')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_match %r{Invalid Api Key}, response.message
    assert_failure response
  end

  def test_response_contains_cvv_and_avs_results
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'M', response.cvv_result['code']
    assert_equal '4', response.avs_result['code']
  end

  def test_trans_error
    # ask for error 42 (unable to send trans) as the cents bit...
    @amount = 500042
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_match(/Server Error/, response.message) # 42 is 'unable to send trans'
    assert_failure response
    assert_equal '500 INTERNAL_SERVER_ERROR', response.error_code
  end

  def test_transcript_scrubbing_store
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:token], transcript)
    assert_scrubbed(@gateway.options[:apikey], transcript)
  end

  def test_transcript_scrubbing_store_with_missing_ta_token
    transcript = capture_transcript(@gateway) do
      @options.delete(:ta_token)
      @gateway.store(@credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:token], transcript)
    assert_scrubbed(@gateway.options[:apikey], transcript)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:token], transcript)
  end

  def test_transcript_scrubbing_echeck
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @check, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@check.account_number, transcript)
    assert_scrubbed(@check.routing_number, transcript)
    assert_scrubbed(@gateway.options[:token], transcript)
  end

  def test_transcript_scrubbing_network_token
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @apple_pay_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@apple_pay_card.payment_cryptogram, transcript)
    assert_scrubbed(@apple_pay_card.verification_value, transcript)
  end
end
