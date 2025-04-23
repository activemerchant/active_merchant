require 'test_helper'

class RemoteCredoraxTest < Test::Unit::TestCase
  def setup
    @gateway = CredoraxGateway.new(fixtures(:credorax))

    @amount = 100
    @adviser_amount = 1000001
    @credit_card = credit_card('4012001038443335', verification_value: '512', month: '12')
    @fully_auth_card = credit_card('5223450000000007', brand: 'mastercard', verification_value: '090', month: '12')
    @declined_card = credit_card('4176661000001111', verification_value: '681', month: '12')
    @three_ds_card = credit_card('5455330200000016', verification_value: '737', month: '10', year: Time.now.year + 2)
    @inquiry_match_card = credit_card('4123560000000072')
    @inquiry_no_match_card = credit_card('4123560000000429')
    @inquiry_unverified_card = credit_card('4176660000000266')
    @address = {
      name:     'Jon Smith',
      address1: '123 Your Street',
      address2: 'Apt 2',
      city:     'Toronto',
      state:    'ON',
      zip:      'K2C3N7',
      country:  'CA',
      phone_number: '(123)456-7890'
    }
    @options = {
      order_id: '1',
      currency: 'EUR',
      billing_address: @address,
      description: 'Store Purchase'
    }
    @normalized_3ds_2_options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: @address,
      shipping_address: @address,
      order_id: '123',
      execute_threed: true,
      three_ds_version: '2',
      three_ds_challenge_window_size: '01',
      three_ds_reqchallengeind: '04',
      stored_credential: { reason_type: 'unscheduled' },
      three_ds_2: {
        channel: 'browser',
        notification_url: 'www.example.com',
        browser_info: {
          accept_header: 'unknown',
          depth: 24,
          java: false,
          language: 'US',
          height: 1000,
          width: 500,
          timezone: '-120',
          user_agent: 'unknown'
        }
      }
    }

    @apple_pay_card = network_tokenization_credit_card(
      '4012001038443335',
      month: '12',
      year: Time.new.year + 2,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '512',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      eci: '07',
      transaction_id: 'abc123',
      source: :apple_pay
    )

    @google_pay_card = network_tokenization_credit_card(
      '4012001038443335',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '12',
      year: Time.new.year + 2,
      source: :google_pay,
      transaction_id: '123456789',
      eci: '07',
      verification_value: 512
    )

    @nt_credit_card = network_tokenization_credit_card(
      '4012001038443335',
      brand: 'visa',
      month: '12',
      source: :network_token,
      payment_cryptogram: 'AgAAAAAAosVKVV7FplLgQRYAAAA=',
      verification_value: 512
    )
  end

  def test_successful_purchase_with_apple_pay
    response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_google_pay
    response = @gateway.purchase(@amount, @google_pay_card, @options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_network_token
    response = @gateway.purchase(@amount, @nt_credit_card, @options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_transcript_scrubbing_network_tokenization_card
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @apple_pay_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@apple_pay_card.number, transcript)
    assert_scrubbed(@apple_pay_card.payment_cryptogram, transcript)
  end

  def test_invalid_login
    gateway = CredoraxGateway.new(merchant_id: '', cipher_key: '')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_and_amount_for_non_decimal_currency
    response = @gateway.purchase(14200, @credit_card, @options.merge(currency: 'JPY'))
    assert_success response
    assert_equal '142', response.params['A4']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_and_amount_for_isk
    response = @gateway.purchase(14200, @credit_card, @options.merge(currency: 'ISK'))
    assert_success response
    assert_equal '142', response.params['A4']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_extra_options
    response = @gateway.purchase(@amount, @credit_card, @options.merge(transaction_type: '10'))
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_aft_fields
    aft_options = @options.merge(
      aft: true,
      sender_ref_number: 'test',
      sender_fund_source: '01',
      sender_country_code: 'USA',
      sender_street_address: 'sender street',
      sender_city: 'city',
      sender_state: 'NY',
      sender_first_name: 'george',
      sender_last_name: 'smith',
      recipient_street_address: 'street',
      recipient_postal_code: '12345',
      recipient_city: 'chicago',
      recipient_province_code: '312',
      recipient_country_code: 'USA',
      recipient_first_name: 'logan',
      recipient_last_name: 'bill'
    )

    response = @gateway.purchase(@amount, @credit_card, aft_options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_auth_data_via_3ds1_fields
    options = @options.merge(
      eci: '02',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: '00000000000000000501',
      # Having processor-specification enabled in Credorax test account causes 3DS tests to fail without a r1 (processor) parameter.
      processor: 'CREDORAX'
    )

    response = @gateway.purchase(@amount, @fully_auth_card, options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_auth_data_via_3ds1_fields_passing_3ds_version
    options = @options.merge(
      eci: '02',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: '00000000000000000501',
      # Having processor-specification enabled in Credorax test account causes 3DS tests to fail without a r1 (processor) parameter.
      processor: 'CREDORAX',
      three_ds_version: '1.0.2'
    )

    response = @gateway.purchase(@amount, @fully_auth_card, options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_auth_data_via_normalized_3ds1_options
    version = '1.0.2'
    eci = '02'
    cavv = 'jJ81HADVRtXfCBATEp01CJUAAAA='
    xid = '00000000000000000501'

    options = @options.merge(
      three_d_secure: {
        version:,
        eci:,
        cavv:,
        xid:
      },
      # Having processor-specification enabled in Credorax test account causes 3DS tests to fail without a r1 (processor) parameter.
      processor: 'CREDORAX'
    )

    response = @gateway.purchase(@amount, @fully_auth_card, options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_3ds2_fields
    options = @options.merge(@normalized_3ds_2_options)
    response = @gateway.purchase(@amount, @three_ds_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_3ds_adviser
    threeds_options = @options.merge(@normalized_3ds_2_options)
    options = threeds_options.merge(three_ds_initiate: '03', f23: '1')
    response = @gateway.purchase(@adviser_amount, @three_ds_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal '01', response.params['SMART_3DS_RESULT']
  end

  def test_successful_moto_purchase
    response = @gateway.purchase(@amount, @three_ds_card, @options.merge(metadata: { manual_entry: true }))
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal '3', response.params['A2']
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_auth_data_via_normalized_3ds2_options
    version = '2.2.0'
    eci = '02'
    cavv = 'jJ81HADVRtXfCBATEp01CJUAAAA='
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    options = @options.merge(
      three_d_secure: {
        version:,
        eci:,
        cavv:,
        ds_transaction_id:
      },
      # Having processor-specification enabled in Credorax test account causes 3DS tests to fail without a r1 (processor) parameter.
      processor: 'CREDORAX'
    )

    response = @gateway.purchase(@amount, @fully_auth_card, options)
    assert_success response
    assert_equal '1', response.params['H9']
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
  end

  def test_failed_purchase_invalid_auth_data_via_3ds1_fields
    options = @options.merge(
      eci: '02',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: 'this is not a valid xid, it will be rejected'
    )

    response = @gateway.purchase(@amount, @fully_auth_card, options)
    assert_failure response
    assert_equal '-9', response.params['Z2']
    assert_match 'Parameter i8 is invalid', response.message
  end

  def test_failed_purchase_invalid_auth_data_via_normalized_3ds2_options
    version = '2.0'
    eci = '02'
    cavv = 'BOGUS;:'
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    options = @options.merge(
      three_d_secure: {
        version:,
        eci:,
        cavv:,
        ds_transaction_id:
      }
    )

    response = @gateway.purchase(@amount, @fully_auth_card, options)
    assert_failure response
    assert_equal '-9', response.params['Z2']
    assert_match 'malformed', response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_successful_authorize_with_transaction_type
    response = @gateway.authorize(@amount, @credit_card, @options.merge(transaction_type: '10'))
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal '1', response.params['H9']
    assert_equal '10', response.params['A9']
  end

  def test_successful_authorize_with_authorization_details
    options_with_auth_details = @options.merge({ authorization_type: '2', multiple_capture_count: '5' })
    response = @gateway.authorize(@amount, @credit_card, options_with_auth_details)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_successful_zero_authorize_with_name_inquiry_match
    extra_options = @options.merge({ account_name_inquiry: true, first_name: 'Art', last_name: 'Vandelay' })
    response = @gateway.authorize(0, @inquiry_match_card, extra_options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal '2', response.params['O']
    assert_equal 'A', response.params['Z26']
    assert_equal 'A', response.params['Z27']
    assert_equal 'A', response.params['Z28']
    assert response.authorization
  end

  def test_successful_zero_authorize_with_name_inquiry_no_match
    extra_options = @options.merge({ account_name_inquiry: true, first_name: 'Art', last_name: 'Vandelay' })
    response = @gateway.authorize(0, @inquiry_no_match_card, extra_options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal '2', response.params['O']
    assert_equal 'C', response.params['Z26']
    assert_equal 'C', response.params['Z27']
    assert_equal 'C', response.params['Z28']
    assert response.authorization
  end

  def test_successful_zero_authorize_with_name_inquiry_unverified
    extra_options = @options.merge({ account_name_inquiry: true, first_name: 'Art', last_name: 'Vandelay' })
    response = @gateway.authorize(0, @inquiry_unverified_card, extra_options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal '2', response.params['O']
    assert_equal 'U', response.params['Z26']
    assert response.authorization
  end

  def test_successful_authorize_with_auth_data_via_3ds1_fields
    options = @options.merge(
      eci: '02',
      cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
      xid: '00000000000000000501',
      # Having processor-specification enabled in Credorax test account causes 3DS tests to fail without a r1 (processor) parameter.
      processor: 'CREDORAX'
    )

    response = @gateway.authorize(@amount, @fully_auth_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_successful_authorize_with_auth_data_via_normalized_3ds2_options
    version = '2.0'
    eci = '02'
    cavv = 'jJ81HADVRtXfCBATEp01CJUAAAA='
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    options = @options.merge(
      three_d_secure: {
        version:,
        eci:,
        cavv:,
        ds_transaction_id:
      },
      # Having processor-specification enabled in Credorax test account causes 3DS tests to fail without a r1 (processor) parameter.
      processor: 'CREDORAX'
    )

    response = @gateway.authorize(@amount, @fully_auth_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
  end

  def test_failed_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(0, auth.authorization)
    assert_failure capture
    assert_equal 'System malfunction', capture.message
  end

  def test_successful_purchase_and_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_successful_authorize_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_successful_capture_and_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message

    void = @gateway.void(capture.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Referred to transaction has not been found.', response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_successful_refund_with_recipient_fields
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund_options = {
      recipient_street_address: 'street',
      recipient_city: 'chicago',
      recipient_province_code: '312',
      recipient_country_code: 'USA'
    }

    refund = @gateway.refund(@amount, response.authorization, refund_options)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_successful_refund_and_void
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message

    void = @gateway.void(refund.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, '123;123;123')
    assert_failure response
    assert_equal 'Referred to transaction has not been found.', response.message
  end

  def test_successful_referral_cft
    options = @options.merge(@normalized_3ds_2_options)
    response = @gateway.purchase(@amount, @three_ds_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message

    cft_options = { referral_cft: true, email: 'john.smith@test.com' }
    referral_cft = @gateway.refund(@amount, response.authorization, cft_options)
    assert_success referral_cft
    assert_equal 'Succeeded', referral_cft.message
    # Confirm that the operation code was `referral_cft`
    assert_equal '34', referral_cft.params['O']
  end

  def test_successful_referral_cft_with_first_and_last_name
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message

    cft_options = { referral_cft: true, email: 'john.smith@test.com', first_name: 'John', last_name: 'Smith' }
    referral_cft = @gateway.refund(@amount, response.authorization, cft_options)
    assert_success referral_cft
    assert_equal 'Succeeded', referral_cft.message
    # Confirm that the operation code was `referral_cft`
    assert_equal '34', referral_cft.params['O']
  end

  def test_failed_referral_cft
    options = @options.merge(@normalized_3ds_2_options)
    response = @gateway.purchase(@amount, @three_ds_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message

    cft_options = { referral_cft: true, email: 'john.smith@test.com' }
    referral_cft = @gateway.refund(@amount, '123;123;123', cft_options)
    assert_failure referral_cft
    assert_equal 'Referred to transaction has not been found.', referral_cft.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options.merge(first_name: 'Test', last_name: 'McTest'))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_credit_with_zero_amount
    response = @gateway.credit(0, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_verify_with_0_auth
    response = @gateway.verify(@credit_card, @options.merge(zero_dollar_auth: true))
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal '0', response.params['A4']
    assert_equal '5', response.params['A9']
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Transaction not allowed for cardholder', response.message
  end

  def test_purchase_using_stored_credential_recurring_cit
    initial_options = stored_credential_options(:cardholder, :recurring, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal '9', purchase.params['A9']
    assert network_transaction_id = purchase.params['Z13']

    used_options = stored_credential_options(:recurring, :cardholder, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_failed_purchase_using_stored_credential_recurring_mit
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal '1', purchase.params['A9']
    assert network_transaction_id = purchase.params['Z13']

    used_options = stored_credential_options(:merchant, :recurring, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_failure purchase
    assert_match 'Parameter g6 is invalid', purchase.message
  end

  def test_successful_purchase_using_stored_credential_recurring_mit
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal '1', purchase.params['A9']
    assert initial_network_transaction_id = purchase.params['Z50']

    used_options = stored_credential_options(:merchant, :recurring, id: initial_network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_installment_cit
    initial_options = stored_credential_options(:cardholder, :installment, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal '9', purchase.params['A9']
    assert network_transaction_id = purchase.params['Z13']

    used_options = stored_credential_options(:cardholder, :installment, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_installment_mit
    initial_options = stored_credential_options(:merchant, :installment, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal '8', purchase.params['A9']
    assert network_transaction_id = purchase.params['Z50']

    used_options = stored_credential_options(:merchant, :installment, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_unscheduled_cit
    initial_options = stored_credential_options(:cardholder, :unscheduled, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal '9', purchase.params['A9']
    assert network_transaction_id = purchase.params['Z13']

    used_options = stored_credential_options(:cardholder, :unscheduled, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_unscheduled_mit
    initial_options = stored_credential_options(:merchant, :unscheduled, :initial)
    assert purchase = @gateway.purchase(@amount, @credit_card, initial_options)
    assert_success purchase
    assert_equal '8', purchase.params['A9']
    assert network_transaction_id = purchase.params['Z50']

    used_options = stored_credential_options(:merchant, :unscheduled, id: network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_authorize_and_capture_with_stored_credential
    initial_options = stored_credential_options(:cardholder, :recurring, :initial)
    assert authorization = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success authorization
    assert_equal '9', authorization.params['A9']
    assert network_transaction_id = authorization.params['Z13']

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture

    used_options = stored_credential_options(:cardholder, :recurring, id: network_transaction_id)
    assert authorization = @gateway.authorize(@amount, @credit_card, used_options)
    assert_success authorization
    assert @gateway.capture(@amount, authorization.authorization)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_cvv_scrubbed(clean_transcript)
  end

  def test_purchase_passes_processor
    # returns a successful response when a valid processor parameter is sent
    assert good_response = @gateway.purchase(@amount, @credit_card, @options.merge(processor: 'CREDORAX'))
    assert_success good_response
    assert_equal 'Succeeded', good_response.message
    assert_equal 'CREDORAX', good_response.params['Z33']

    # returns a failed response when an invalid processor parameter is sent
    assert bad_response = @gateway.purchase(@amount, @credit_card, @options.merge(processor: 'invalid'))
    assert_failure bad_response
  end

  def test_purchase_passes_d2_field
    response = @gateway.purchase(@amount, @credit_card, @options.merge(echo: 'Echo Parameter'))
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'Echo Parameter', response.params['D2']
  end

  # #########################################################################
  # # CERTIFICATION SPECIFIC REMOTE TESTS
  # #########################################################################
  #
  # # Send [a5] currency code parameter as "AFN"
  # def test_certification_error_unregistered_currency
  #   @options[:echo] = "33BE888"
  #   @options[:currency] = "AFN"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # Send [b2] parameter as "6"
  # def test_certification_error_unregistered_card
  #   @options[:echo] = "33BE889"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # In the future, merchant expected to investigate each such case offline.
  # def test_certification_error_no_response_from_the_gate
  #   @options[:echo] = "33BE88A"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # Merchant is expected to verify if the code is "0" - in this case the
  # # transaction should be considered approved. In all other cases the
  # # offline investigation should take place.
  # def test_certification_error_unknown_result_code
  #   @options[:echo] = "33BE88B"
  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
  #
  # # Merchant is expected to verify if the code is "00" - in this case the
  # # transaction should be considered approved. In all other cases the
  # # transaction is declined. The exact reason should be investigated offline.
  # def test_certification_error_unknown_response_reason_code
  #   @options[:echo] = "33BE88C"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   response = @gateway.purchase(@amount, credit_card, @options)
  #   assert_failure response
  # end
  #
  # # All fields marked as mandatory are expected to be populated with the
  # # above default values. Mandatory fields with no values on the
  # # certification template should be populated with your own meaningful
  # # values and comply with our API specifications. The d2 parameter is
  # # mandatory during certification only to allow for tracking of tests.
  # # Expected result of this test: Time out
  # def test_certification_time_out
  #   @options[:echo] = "33BE88D"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('5473470000000010',
  #                              brand: "master",
  #                              verification_value: "939",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   response = @gateway.purchase(@amount, credit_card, @options)
  #   assert_failure response
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # def test_certification_za_zb_zc
  #   @options[:echo] = "33BE88E"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('5473470000000010',
  #                              verification_value: "939",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   purchase = @gateway.purchase(@amount, credit_card, @options)
  #   assert_success purchase
  #   assert_equal "Succeeded", purchase.message
  #
  #   refund_options = {echo: "33BE892"}
  #   refund = @gateway.refund(@amount, purchase.authorization, refund_options)
  #   assert_success refund
  #   assert_equal "Succeeded", refund.message
  #
  #   void_options = {echo: "33BE895"}
  #   void = @gateway.void(refund.authorization, void_options)
  #   assert_success void
  #   assert_equal "Succeeded", refund.message
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # def test_certification_zg_zh
  #   @options[:echo] = "33BE88F"
  #   @options[:email] = "clark.kent@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "2020 Krypton Drive",
  #     city: "Toronto",
  #     zip: "S2M 1YR",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800) 78737626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Clark",
  #                              last_name: "Kent")
  #
  #   response = @gateway.authorize(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  #
  #   capture_options = {echo: "33BE890"}
  #   capture = @gateway.capture(@amount, response.authorization, capture_options)
  #   assert_success capture
  #   assert_equal "Succeeded", capture.message
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # def test_certification_zg_zj
  #   @options[:echo] = "33BE88F"
  #   @options[:email] = "clark.kent@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "2020 Krypton Drive",
  #     city: "Toronto",
  #     zip: "S2M 1YR",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800) 78737626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Clark",
  #                              last_name: "Kent")
  #
  #   response = @gateway.authorize(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  #
  #   auth_void_options = {echo: "33BE891"}
  #   auth_void = @gateway.void(response.authorization, auth_void_options)
  #   assert_success auth_void
  #   assert_equal "Succeeded", auth_void.message
  # end
  #
  # # All fields marked as mandatory are expected to be populated
  # # with the above default values. Mandatory fields with no values
  # # on the certification template should be populated with your
  # # own meaningful values and comply with our API specifications.
  # # The d2 parameter is mandatory during certification only to
  # # allow for tracking of tests.
  # #
  # # Certification for independent credit (credit)
  # def test_certification_zd
  #   @options[:echo] = "33BE893"
  #   @options[:email] = "wadewilson@marvel.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Deadpool Drive",
  #     city: "Toronto",
  #     zip: "D2P 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "+1(555)123-4567"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Wade",
  #                              last_name: "Wilson")
  #
  #   response = @gateway.credit(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  # end
  #
  # # Use the above values to fill the mandatory parameters in your
  # # certification test transactions. Note:The d2 parameter is only
  # # mandatory during certification to allow for tracking of tests.
  # #
  # # Certification for purchase void
  # def test_certification_zf
  #   @options[:echo] = "33BE88E"
  #   @options[:email] = "brucewayne@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "5050 Gotham Drive",
  #     city: "Toronto",
  #     zip: "B2M 1Y9",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800)228626"
  #   }
  #
  #   credit_card = credit_card('5473470000000010',
  #                              verification_value: "939",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Bruce",
  #                              last_name: "Wayne")
  #
  #   response = @gateway.purchase(@amount, credit_card, @options)
  #   assert_success response
  #   assert_equal "Succeeded", response.message
  #
  #   void_options = {echo: "33BE894"}
  #   void = @gateway.void(response.authorization, void_options)
  #   assert_success void
  #   assert_equal "Succeeded", void.message
  # end
  #
  # # Use the above values to fill the mandatory parameters in your
  # # certification test transactions. Note:The d2 parameter is only
  # # mandatory during certification to allow for tracking of tests.
  # #
  # # Certification for capture void
  # def test_certification_zi
  #   @options[:echo] = "33BE88F"
  #   @options[:email] = "clark.kent@dccomics.com"
  #   @options[:billing_address] = {
  #     address1: "2020 Krypton Drive",
  #     city: "Toronto",
  #     zip: "S2M 1YR",
  #     state: "ON",
  #     country: "CA",
  #     phone: "(0800) 78737626"
  #   }
  #
  #   credit_card = credit_card('4176661000001015',
  #                              brand: "visa",
  #                              verification_value: "281",
  #                              month: "12",
  #                              year: "17",
  #                              first_name: "Clark",
  #                              last_name: "Kent")
  #
  #   authorize = @gateway.authorize(@amount, credit_card, @options)
  #   assert_success authorize
  #   assert_equal "Succeeded", authorize.message
  #
  #   capture_options = {echo: "33BE890"}
  #   capture = @gateway.capture(@amount, authorize.authorization, capture_options)
  #   assert_success capture
  #   assert_equal "Succeeded", capture.message
  #
  #   void_options = {echo: "33BE896"}
  #   void = @gateway.void(capture.authorization, void_options)
  #   assert_success void
  #   assert_equal "Succeeded", void.message
  # end

  private

  def assert_cvv_scrubbed(transcript)
    assert_match(/b5=\[FILTERED\]/, transcript)
  end

  def stored_credential_options(*args, id: nil)
    @options.merge(order_id: generate_unique_id,
                   stored_credential: stored_credential(*args, id:))
  end
end
