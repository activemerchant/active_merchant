require 'test_helper'

class RemoteAdyenTest < Test::Unit::TestCase
  def setup
    @gateway = AdyenGateway.new(fixtures(:adyen))

    @amount = 100

    @bank_account = check(account_number: '123456789', routing_number: '121000358')

    @declined_bank_account = check(account_number: '123456789', routing_number: '121000348')

    @general_bank_account = check(name: 'A. Klaassen', account_number: '123456789', routing_number: 'NL13TEST0123456789')

    @credit_card = credit_card(
      '4111111111111111',
      month: 3,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'visa'
    )

    @avs_credit_card = credit_card(
      '4400000000000008',
      month: 3,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'visa'
    )

    @elo_credit_card = credit_card(
      '5066 9911 1111 1118',
      month: 3,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'elo'
    )

    @three_ds_enrolled_card = credit_card(
      '4917610000000000',
      month: 3,
      year: 2030,
      verification_value: '737',
      brand: :visa
    )

    @cabal_credit_card = credit_card(
      '6035 2277 1642 7021',
      month: 3,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'cabal'
    )

    @invalid_cabal_credit_card = credit_card(
      '6035 2200 0000 0006',
      month: 3,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'cabal'
    )

    @unionpay_credit_card = credit_card(
      '8171 9999 0000 0000 021',
      month: 10,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'unionpay'
    )

    @invalid_unionpay_credit_card = credit_card(
      '8171 9999 1234 0000 921',
      month: 10,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'unionpay'
    )

    @declined_card = credit_card('4000300011112220')

    @improperly_branded_maestro = credit_card(
      '5500000000000004',
      month: 8,
      year: 2018,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'mastercard'
    )

    @apple_pay_card = network_tokenization_credit_card(
      '4761209980011439',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: '2022',
      source: :apple_pay,
      verification_value: 569
    )

    @google_pay_card = network_tokenization_credit_card(
      '4761209980011439',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: '2022',
      source: :google_pay,
      verification_value: nil
    )

    @nt_credit_card = network_tokenization_credit_card(
      '4895370015293175',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      eci: '07',
      source: :network_token,
      verification_value: '737',
      brand: 'visa'
    )
    @us_address = {
      address1: 'Brannan Street',
      address2: '121',
      country: 'US',
      city: 'Beverly Hills',
      state: 'CA',
      zip: '90210'
    }

    @payout_options = {
      reference: 'P9999999999999999',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: @us_address,
      nationality: 'NL',
      order_id: 'P9999999999999999',
      date_of_birth: '1990-01-01',
      payout: true
    }

    @options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: @us_address,
      order_id: '123',
      stored_credential: { reason_type: 'unscheduled' }
    }

    @normalized_3ds_2_options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: { reason_type: 'unscheduled' },
      three_ds_2: {
        channel: 'browser',
        notification_url: 'https://example.com/notification',
        browser_info: {
          accept_header: 'unknown',
          depth: 48,
          java: false,
          language: 'US',
          height: 1000,
          width: 500,
          timezone: '-120',
          user_agent: 'unknown'
        }
      }
    }

    @long_order_id = 'asdfjkl;asdfjkl;asdfj;aiwyutinvpoaieryutnmv;203987528752098375j3q-p489756ijmfpvbijpq348nmdf;vbjp3845'
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_authorize_with_bank_account
    response = @gateway.authorize(@amount, @bank_account, @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_authorize_avs
    # Account configuration may need to be done: https://docs.adyen.com/developers/api-reference/payments-api#paymentresultadditionaldata
    options = @options.update({
      billing_address: {
        address1: 'Infinite Loop',
        address2: 1,
        country: 'US',
        city: 'Cupertino',
        state: 'CA',
        zip: '95014'
      }
    })
    response = @gateway.authorize(@amount, @avs_credit_card, options)
    assert_success response
    assert_equal 'Authorised', response.message
    assert_equal 'D', response.avs_result['code']
  end

  def test_successful_authorize_with_idempotency_key
    options = @options.merge(idempotency_key: SecureRandom.hex)
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Authorised', response.message
    first_auth = response.authorization

    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal response.authorization, first_auth
  end

  def test_successful_authorize_with_3ds
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(execute_threed: true))
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'RedirectShopper'
    refute response.params['issuerUrl'].blank?
    refute response.params['md'].blank?
    refute response.params['paRequest'].blank?
  end

  def test_successful_authorize_with_execute_threed_false
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(execute_threed: false, sca_exemption: 'lowValue'))
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'Authorised'
  end

  def test_successful_authorize_with_3ds_with_idempotency_key
    options = @options.merge(idempotency_key: SecureRandom.hex, execute_threed: true)
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, options)
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'RedirectShopper'
    refute response.params['issuerUrl'].blank?
    refute response.params['md'].blank?
    refute response.params['paRequest'].blank?

    assert response2 = @gateway.authorize(@amount, @three_ds_enrolled_card, options)
    assert_success response2
    refute response2.authorization.blank?
    assert_equal response2.params['resultCode'], 'RedirectShopper'
    refute response2.params['issuerUrl'].blank?
    refute response2.params['md'].blank?
    refute response2.params['paRequest'].blank?
    assert_equal response.authorization, response2.authorization
  end

  def test_successful_authorize_with_3ds_dynamic
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(threed_dynamic: true))
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'RedirectShopper'
    refute response.params['issuerUrl'].blank?
    refute response.params['md'].blank?
    refute response.params['paRequest'].blank?
  end

  def test_successful_authorize_with_3ds2_browser_client_data
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @normalized_3ds_2_options)
    assert response.test?
    refute response.authorization.blank?

    assert_equal response.params['resultCode'], 'IdentifyShopper'
    refute response.params['additionalData']['threeds2.threeDS2Token'].blank?
    refute response.params['additionalData']['threeds2.threeDSServerTransID'].blank?
    refute response.params['additionalData']['threeds2.threeDSMethodURL'].blank?
  end

  def test_successful_authorize_with_network_token
    response = @gateway.authorize(@amount, @nt_credit_card, @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_purchase_with_3ds2_exemption_requested_and_execute_threed_false
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @normalized_3ds_2_options.merge(execute_threed: false, sca_exemption: 'lowValue'))
    assert response.test?
    refute response.authorization.blank?

    assert_equal response.params['resultCode'], 'Authorised'
  end

  # According to Adyen documentation, if execute_threed is set to true and an exemption provided
  # the gateway will apply and request for the specified exemption in the authentication request,
  # after the device fingerprint is submitted to the issuer.
  def test_successful_purchase_with_3ds2_exemption_requested_and_execute_threed_true
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @normalized_3ds_2_options.merge(execute_threed: true, sca_exemption: 'lowValue'))
    assert response.test?
    refute response.authorization.blank?

    assert_equal response.params['resultCode'], 'IdentifyShopper'
    refute response.params['additionalData']['threeds2.threeDS2Token'].blank?
    refute response.params['additionalData']['threeds2.threeDSServerTransID'].blank?
    refute response.params['additionalData']['threeds2.threeDSMethodURL'].blank?
  end

  def test_successful_authorize_with_3ds2_app_based_request
    three_ds_app_based_options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: { reason_type: 'unscheduled' },
      three_ds_2: {
        channel: 'app'
      }
    }

    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, three_ds_app_based_options)
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'IdentifyShopper'
    refute response.params['additionalData']['threeds2.threeDS2Token'].blank?
    refute response.params['additionalData']['threeds2.threeDSServerTransID'].blank?
    refute response.params['additionalData']['threeds2.threeDS2DirectoryServerInformation.algorithm'].blank?
    refute response.params['additionalData']['threeds2.threeDS2DirectoryServerInformation.directoryServerId'].blank?
    refute response.params['additionalData']['threeds2.threeDS2DirectoryServerInformation.publicKey'].blank?
  end

  # with rule set in merchant account to skip 3DS for cards of this brand
  def test_successful_authorize_with_3ds_dynamic_rule_broken
    mastercard_threed = credit_card(
      '5212345678901234',
      month: 3,
      year: 2030,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737',
      brand: 'mastercard'
    )
    assert response = @gateway.authorize(@amount, mastercard_threed, @options.merge(threed_dynamic: true))
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'Authorised'
  end

  # Fail in situations where neither execute_threed nor dynamic_threed is
  # present, but the account is set to dynamic 3ds and it is triggered. This
  # test assumes a Dynamic 3DS rule set for the Adyen test account to always
  # perform 3ds auth for an amount of 8484
  def test_purchase_fails_on_unexpected_3ds_initiation
    response = @gateway.purchase(8484, @three_ds_enrolled_card, @options)
    assert_failure response
    assert_match 'Received unexpected 3DS authentication response, but a 3DS initiation flag was not included in the request.', response.message
  end

  def test_successful_purchase_with_auth_data_via_threeds1_standalone
    eci = '05'
    cavv = '3q2+78r+ur7erb7vyv66vv\/\/\/\/8='
    cavv_algorithm = '1'
    xid = 'ODUzNTYzOTcwODU5NzY3Qw=='
    enrolled = 'Y'
    authentication_response_status = 'Y'
    options = @options.merge(
      three_d_secure: {
        eci: eci,
        cavv: cavv,
        cavv_algorithm: cavv_algorithm,
        xid: xid,
        enrolled: enrolled,
        authentication_response_status: authentication_response_status
      }
    )

    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth
    assert_equal 'Authorised', auth.message
    # The assertion below requires the "3D Secure Result" data activated for the test account
    assert_equal 'true', auth.params['additionalData']['liabilityShift']

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_auth_data_via_threeds2_standalone
    version = '2.1.0'
    eci = '02'
    cavv = 'jJ81HADVRtXfCBATEp01CJUAAAA='
    ds_transaction_id = '97267598-FAE6-48F2-8083-C23433990FBC'
    directory_response_status = 'C'
    authentication_response_status = 'Y'

    options = @options.merge(
      three_d_secure: {
        version: version,
        eci: eci,
        cavv: cavv,
        ds_transaction_id: ds_transaction_id,
        directory_response_status: directory_response_status,
        authentication_response_status: authentication_response_status
      }
    )

    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth
    assert_equal 'Authorised', auth.message
    # The assertion below requires the "3D Secure Result" data activated for the test account
    assert_equal 'true', auth.params['additionalData']['liabilityShift']

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_authorize_with_no_address
    options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      order_id: '123',
      recurring_processing_model: 'CardOnFile'
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_authorize_with_credit_card_no_name
    credit_card_no_name = ActiveMerchant::Billing::CreditCard.new({
      number: '4111111111111111',
      month: 3,
      year: 2030,
      verification_value: '737',
      brand: 'visa'
    })

    response = @gateway.authorize(@amount, credit_card_no_name, @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
    assert_equal 'Refused', response.error_code
  end

  def test_failed_authorize_with_bank_account
    response = @gateway.authorize(@amount, @declined_bank_account, @options)
    assert_failure response
    assert_equal 'Bank Account or Bank Location Id not valid or missing', response.message
  end

  def test_failed_authorize_with_bank_account_missing_country_code
    response = @gateway.authorize(@amount, @bank_account, @options.except(:billing_address))
    assert_failure response
    assert_equal 'BankDetails missing', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_bank_account
    response = @gateway.purchase(@amount, @bank_account, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_no_cvv
    credit_card = @credit_card
    credit_card.verification_value = nil
    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge!(
      fraudOffset: '1',
      installments: 2,
      shopper_statement: 'statement note',
      device_fingerprint: 'm7Cmrf++0cW4P6XfF7m/rA',
      capture_delay_hours: 4
    )
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_risk_data
    options = @options.merge(
      risk_data:
      {
        'operatingSystem' => 'HAL9000',
        'destinationLatitude' => '77.641423',
        'destinationLongitude' => '12.9503376'
      }
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_idempotency_key
    options = @options.merge(idempotency_key: SecureRandom.hex)
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal '[capture-received]', response.message
    first_auth = response.authorization

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal response.authorization, first_auth
  end

  def test_successful_purchase_with_billing_default_country_code
    options = @options.dup.update({
      billing_address: {
        address1: 'Infinite Loop',
        address2: 1,
        country: '',
        city: 'Cupertino',
        state: 'CA',
        zip: '95014'
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_shipping_default_country_code
    options = @options.dup.update({
      shipping_address: {
        address1: 'Infinite Loop',
        address2: 1,
        country: '',
        city: 'Cupertino',
        state: 'CA',
        zip: '95014'
      }
    })
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_apple_pay
    response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_succesful_purchase_with_brand_override
    response = @gateway.purchase(@amount, @improperly_branded_maestro, @options.merge({ overwrite_brand: true, selected_brand: 'maestro' }))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_succesful_purchase_with_brand_override_with_execute_threed_false
    response = @gateway.purchase(@amount, @improperly_branded_maestro, @options.merge({ execute_threed: false, overwrite_brand: true, selected_brand: 'maestro' }))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_google_pay
    response = @gateway.purchase(@amount, @google_pay_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_google_pay_without_billing_address_and_address_override
    options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: {
        address1: '',
        address2: '',
        country: 'US',
        city: 'Beverly Hills',
        state: 'CA',
        zip: '90210'
      },
      order_id: '123',
      stored_credential: { reason_type: 'unscheduled' },
      address_override: true
    }

    response = @gateway.purchase(@amount, @google_pay_card, options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_google_pay_and_truncate_order_id
    response = @gateway.purchase(@amount, @google_pay_card, @options.merge(order_id: @long_order_id))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_elo_card
    response = @gateway.purchase(@amount, @elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_cabal_card
    response = @gateway.purchase(@amount, @cabal_credit_card, @options.merge(currency: 'ARS'))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_unionpay_card
    response = @gateway.purchase(@amount, @unionpay_credit_card, @options.merge(currency: 'CNY'))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_network_token
    response = @gateway.purchase(@amount, @nt_credit_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_failed_purchase_with_bank_account
    response = @gateway.purchase(@amount, @declined_bank_account, @options)
    assert_failure response
    assert_equal 'Bank Account or Bank Location Id not valid or missing', response.message
  end

  def test_failed_purchase_with_invalid_cabal_card
    response = @gateway.purchase(@amount, @invalid_cabal_credit_card, @options)
    assert_failure response
    assert_equal 'Invalid card number', response.message
  end

  def test_failed_purchase_with_invalid_unionpay_card
    response = @gateway.purchase(@amount, @invalid_unionpay_credit_card, @options)
    assert_failure response
    assert_equal 'Invalid card number', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message
  end

  def test_successful_authorize_and_capture_with_elo_card
    auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message
  end

  def test_successful_authorize_and_capture_with_cabal_card
    auth = @gateway.authorize(@amount, @cabal_credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message
  end

  def test_successful_authorize_and_capture_with_unionpay_card
    auth = @gateway.authorize(@amount, @unionpay_credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message
  end

  def test_error_code_render_from_response
    options = {
      order_id: '123',
      email: 'shopper@sky.uk',
      billing_address: {
        address2: 'address2',
        zip: '31331',
        city: 'Wanaque',
        state: 'NJ',
        country: 'IE'
      },
      delivery_date: 'invalid'
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_failure response
    assert_equal '702', response.error_code
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Original pspReference required for this operation', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal '[refund-received]', refund.message
  end

  def test_successful_refund_with_bank_account
    purchase = @gateway.purchase(@amount, @bank_account, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal '[refund-received]', refund.message
  end

  def test_successful_refund_with_auth_original_reference
    auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response
    assert_equal 'Authorised', auth_response.message

    refund_resp = @gateway.refund(@amount, auth_response.authorization)
    assert_success refund_resp
    assert_equal '[refund-received]', refund_resp.message
  end

  def test_successful_refund_with_elo_card
    purchase = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal '[refund-received]', refund.message
  end

  def test_successful_refund_with_cabal_card
    purchase = @gateway.purchase(@amount, @cabal_credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal '[refund-received]', refund.message
  end

  def test_successful_refund_with_unionpay_card
    purchase = @gateway.purchase(@amount, @unionpay_credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal '[refund-received]', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund_with_bank_account
    purchase = @gateway.purchase(@amount, @bank_account, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Original pspReference required for this operation', response.message
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Received', response.message
  end

  def test_successful_credit_with_bank_account
    @options[:currency] = 'EUR'
    @options[:billing_address][:country] = 'NL'
    response = @gateway.credit(1500, @general_bank_account, @options)

    assert_success response
    assert_equal 'Received', response.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, '')
    assert_failure response
    assert_equal "Required field 'reference' is not provided.", response.message
  end

  def test_successful_payout_with_credit_card
    response = @gateway.credit(2500, @credit_card, @payout_options)

    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_payout_with_fund_source
    fund_source = {
      fund_source: {
        additional_data: { fundingSource: 'Debit' },
        first_name: 'Payer',
        last_name: 'Name',
        billing_address: @us_address
      }
    }

    response = @gateway.credit(2500, @credit_card, @payout_options.merge!(fund_source))

    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_failed_payout_with_credit_card
    response = @gateway.credit(2500, @credit_card, @payout_options.except(:date_of_birth))

    assert_failure response
    assert_equal 'Payout has been refused due to regulatory reasons', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal '[cancel-received]', void.message
  end

  def test_successful_void_with_bank_account
    auth = @gateway.authorize(@amount, @bank_account, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal '[cancel-received]', void.message
  end

  def test_successful_void_with_elo_card
    auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal '[cancel-received]', void.message
  end

  def test_successful_void_with_cabal_card
    auth = @gateway.authorize(@amount, @cabal_credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal '[cancel-received]', void.message
  end

  def test_successful_void_with_unionpay_card
    auth = @gateway.authorize(@amount, @unionpay_credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal '[cancel-received]', void.message
  end

  def test_successul_void_of_pending_3ds_authorization
    assert auth = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(execute_threed: true))
    assert auth.test?
    refute auth.authorization.blank?
    assert_equal auth.params['resultCode'], 'RedirectShopper'
    refute auth.params['issuerUrl'].blank?
    refute auth.params['md'].blank?
    refute auth.params['paRequest'].blank?

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal '[cancel-received]', void.message
  end

  def test_successful_void_requires_unique_idempotency_key
    idempotency_key = SecureRandom.hex
    options = @options.merge(idempotency_key: idempotency_key)
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, idempotency_key: idempotency_key)
    assert_failure void

    assert void = @gateway.void(auth.authorization, idempotency_key: "#{idempotency_key}-auto-void")
    assert_success void
    assert_equal '[cancel-received]', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Original pspReference required for this operation', response.message
  end

  def test_successful_asynchronous_adjust
    authorize = @gateway.authorize(@amount, @credit_card, @options.merge(authorisation_type: 'PreAuth'))
    assert_success authorize

    assert adjust = @gateway.adjust(200, authorize.authorization, @options)
    assert_success adjust
    assert_equal '[adjustAuthorisation-received]', adjust.message
  end

  def test_successful_asynchronous_adjust_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options.merge(authorisation_type: 'PreAuth'))
    assert_success authorize

    assert adjust = @gateway.adjust(200, authorize.authorization, @options)
    assert_success adjust
    assert_equal '[adjustAuthorisation-received]', adjust.message

    assert capture = @gateway.capture(200, authorize.authorization)
    assert_success capture
  end

  def test_failed_asynchronous_adjust
    authorize = @gateway.authorize(@amount, @credit_card, @options.merge(authorisation_type: 'PreAuth'))
    assert_success authorize

    assert response = @gateway.adjust(200, '', @options)
    assert_failure response
    assert_equal 'Original pspReference required for this operation', response.message
  end

  # Requires Adyen to set your test account to Synchronous Adjust mode.
  def test_successful_synchronous_adjust_using_adjust_data
    authorize = @gateway.authorize(@amount, @credit_card, @options.merge(authorisation_type: 'PreAuth', shopper_statement: 'statement note'))
    assert_success authorize

    options = @options.merge(adjust_authorisation_data: authorize.params['additionalData']['adjustAuthorisationData'], update_shopper_statement: 'new statement note', industry_usage: 'DelayedCharge')
    assert adjust = @gateway.adjust(200, authorize.authorization, options)
    assert_success adjust
    assert_equal 'Authorised', adjust.message
  end

  # Requires Adyen to set your test account to Synchronous Adjust mode.
  def test_successful_synchronous_adjust_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options.merge(authorisation_type: 'PreAuth'))
    assert_success authorize

    options = @options.merge(adjust_authorisation_data: authorize.params['additionalData']['adjustAuthorisationData'])
    assert adjust = @gateway.adjust(200, authorize.authorization, options)
    assert_success adjust
    assert_equal 'Authorised', adjust.message

    assert capture = @gateway.capture(200, authorize.authorization)
    assert_success capture
  end

  # Requires Adyen to set your test account to Synchronous Adjust mode.
  def test_failed_synchronous_adjust_using_adjust_data
    authorize = @gateway.authorize(@amount, @credit_card, @options.merge(authorisation_type: 'PreAuth'))
    assert_success authorize

    options = @options.merge(adjust_authorisation_data: authorize.params['additionalData']['adjustAuthorisationData'],
                             requested_test_acquirer_response_code: '2')
    assert adjust = @gateway.adjust(200, authorize.authorization, options)
    assert_failure adjust
    assert_equal 'Refused', adjust.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message
  end

  def test_successful_store_with_bank_account
    assert response = @gateway.store(@bank_account, @options)

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message
  end

  def test_successful_unstore
    assert response = @gateway.store(@credit_card, @options)

    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message

    shopper_reference = response.params['additionalData']['recurring.shopperReference']
    recurring_detail_reference = response.params['additionalData']['recurring.recurringDetailReference']

    assert response = @gateway.unstore(shopper_reference: shopper_reference,
                                       recurring_detail_reference: recurring_detail_reference)

    assert_success response
    assert_equal '[detail-successfully-disabled]', response.message
  end

  def test_successful_unstore_with_bank_account
    assert response = @gateway.store(@bank_account, @options)

    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message

    shopper_reference = response.params['additionalData']['recurring.shopperReference']
    recurring_detail_reference = response.params['additionalData']['recurring.recurringDetailReference']

    assert response = @gateway.unstore(shopper_reference: shopper_reference,
                                       recurring_detail_reference: recurring_detail_reference)

    assert_success response
    assert_equal '[detail-successfully-disabled]', response.message
  end

  def test_failed_unstore
    assert response = @gateway.store(@credit_card, @options)

    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message

    shopper_reference = response.params['additionalData']['recurring.shopperReference']
    recurring_detail_reference = response.params['additionalData']['recurring.recurringDetailReference']

    assert response = @gateway.unstore(shopper_reference: 'random_reference',
                                       recurring_detail_reference: recurring_detail_reference)

    assert_failure response
    assert_equal 'Contract not found', response.message

    assert response = @gateway.unstore(shopper_reference: shopper_reference,
                                       recurring_detail_reference: 'random_reference')

    assert_failure response
    assert_equal 'PaymentDetail not found', response.message
  end

  def test_successful_tokenize_only_store
    assert response = @gateway.store(@credit_card, @options.merge({ tokenize_only: true }))

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Success', response.message
  end

  def test_successful_tokenize_only_store_with_ntid
    assert response = @gateway.store(@credit_card, @options.merge({ tokenize_only: true, network_transaction_id: '858435661128555' }))

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Success', response.message
  end

  def test_successful_store_with_elo_card
    assert response = @gateway.store(@elo_credit_card, @options)

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message
  end

  def test_successful_store_with_cabal_card
    assert response = @gateway.store(@cabal_credit_card, @options)
    assert_success response
  end

  def test_successful_store_with_unionpay_card
    assert response = @gateway.store(@unionpay_credit_card, @options)

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message
  end

  def test_failed_store
    assert response = @gateway.store(@declined_card, @options)

    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_successful_purchase_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_using_stored_elo_card
    assert store_response = @gateway.store(@elo_credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_authorize_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.authorize(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'Authorised', response.message
  end

  def test_successful_verify_with_custom_amount
    response = @gateway.verify(@credit_card, @options.merge({ verify_amount: '500' }))
    assert_success response
    assert_match 'Authorised', response.message
  end

  def test_successful_verify_with_bank_account
    response = @gateway.verify(@bank_account, @options)
    assert_success response
    assert_match 'Authorised', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match 'Refused', response.message
  end

  def test_verify_with_idempotency_key
    options = @options.merge(idempotency_key: SecureRandom.hex)
    response = @gateway.authorize(0, @credit_card, options)
    assert_success response
    assert_equal 'Authorised', response.message
    first_auth = response.authorization

    response = @gateway.verify(@credit_card, options)
    assert_success response
    assert_equal response.authorization, first_auth

    response = @gateway.void(first_auth, @options)
    assert_success response
  end

  def test_invalid_login
    gateway = AdyenGateway.new(username: '', password: '', merchant_account: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_transcript_scrubbing_with_bank_account
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @bank_account, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@bank_account.account_number, transcript)
    assert_scrubbed(@bank_account.routing_number, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_transcript_scrubbing_network_tokenization_card
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @apple_pay_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@apple_pay_card.number, transcript)
    assert_scrubbed(@apple_pay_card.payment_cryptogram, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_incorrect_number_for_purchase
    card = credit_card('4242424242424241')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_invalid_number_for_purchase
    card = credit_card('-1')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_number], response.error_code
  end

  def test_invalid_expiry_month_for_purchase
    card = credit_card('4242424242424242', month: 16)
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_equal 'The provided Expiry Date is not valid.: Expiry month should be between 1 and 12 inclusive: 16', response.message
  end

  def test_invalid_expiry_year_for_purchase
    card = credit_card('4242424242424242', year: 'xx')
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert response.message.include?('Expiry year should be a 4 digit number greater than')
  end

  def test_invalid_cvc_for_purchase
    card = credit_card('4242424242424242', verification_value: -1)
    assert response = @gateway.purchase(@amount, card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_cvc], response.error_code
  end

  def test_missing_address_for_purchase
    @options[:billing_address].delete(:address1)
    @options[:billing_address].delete(:address2)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_missing_city_for_purchase
    @options[:billing_address].delete(:city)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_missing_house_number_or_name_for_purchase
    @options[:billing_address].delete(:address2)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_missing_state_for_purchase
    @options[:billing_address].delete(:state)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_blank_country_for_purchase
    @options[:billing_address][:country] = ''
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_nil_state_for_purchase
    @options[:billing_address][:state] = nil
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_nil_country_for_purchase
    @options[:billing_address][:country] = nil
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_blank_state_for_purchase
    @options[:billing_address][:state] = ''
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_missing_phone_for_purchase
    @options[:billing_address].delete(:phone)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_auth_application_info
    options = @options.merge!(
      externalPlatform: {
        name: 'Acme',
        version: '1',
        integrator: 'abc'
      },
      merchantApplication: {
        name: 'Acme Inc.',
        version: '2'
      }
    )
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_authorize_phone
    @options[:billing_address][:phone] = '1234567890'
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_authorize_phone_number
    @options[:billing_address].delete(:phone)
    @options[:billing_address][:phone_number] = '0987654321'
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_purchase_using_stored_credential_recurring_cit
    initial_options = stored_credential_options(:cardholder, :recurring, :initial)
    assert auth = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success auth
    assert_equal 'Subscription', auth.params['additionalData']['recurringProcessingModel']
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message

    used_options = stored_credential_options(:recurring, :cardholder, ntid: auth.network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_recurring_mit
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert auth = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success auth
    assert_equal 'Subscription', auth.params['additionalData']['recurringProcessingModel']
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message

    used_options = stored_credential_options(:recurring, :cardholder, ntid: auth.network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_unscheduled_cit
    initial_options = stored_credential_options(:cardholder, :unscheduled, :initial)
    assert auth = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success auth
    assert_equal 'CardOnFile', auth.params['additionalData']['recurringProcessingModel']
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message

    used_options = stored_credential_options(:unscheduled, :cardholder, ntid: auth.network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_purchase_using_stored_credential_unscheduled_mit
    initial_options = stored_credential_options(:merchant, :unscheduled, :initial)
    assert auth = @gateway.authorize(@amount, @credit_card, initial_options)
    assert_success auth
    assert_equal 'UnscheduledCardOnFile', auth.params['additionalData']['recurringProcessingModel']
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message

    used_options = stored_credential_options(:unscheduled, :cardholder, ntid: auth.network_transaction_id)
    assert purchase = @gateway.purchase(@amount, @credit_card, used_options)
    assert_success purchase
  end

  def test_auth_and_capture_with_network_txn_id
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert auth = @gateway.authorize(@amount, @credit_card, initial_options)
    assert auth.network_transaction_id

    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(network_transaction_id: auth.network_transaction_id))
    assert_success capture
  end

  def test_auth_and_capture_with_network_txn_id_from_stored_cred_hash
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert auth = @gateway.authorize(@amount, @credit_card, initial_options)
    assert auth.network_transaction_id

    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(stored_credential: { network_transaction_id: auth.network_transaction_id }))
    assert_success capture
  end

  def test_auth_capture_refund_with_network_txn_id
    initial_options = stored_credential_options(:merchant, :recurring, :initial)
    assert auth = @gateway.authorize(@amount, @credit_card, initial_options)
    assert auth.network_transaction_id

    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(network_transaction_id: auth.network_transaction_id))
    assert_success capture

    assert refund = @gateway.refund(@amount, auth.authorization, @options.merge(network_transaction_id: auth.network_transaction_id))
    assert_success refund
  end

  def test_successful_capture_with_shopper_statement
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(shopper_statement: 'test1234'))
    assert_success capture
  end

  def test_purchase_with_skip_mpi_data
    options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'shopper 123',
      billing_address: address(country: 'US', state: 'CA')
    }
    first_options = options.merge(
      order_id: generate_unique_id,
      shopper_interaction: 'Ecommerce',
      recurring_processing_model: 'Subscription'
    )
    assert auth = @gateway.authorize(@amount, @apple_pay_card, first_options)
    assert_success auth

    assert_equal 'Subscription', auth.params['additionalData']['recurringProcessingModel']
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal '[capture-received]', capture.message

    used_options = options.merge(
      order_id: generate_unique_id,
      skip_mpi_data: 'Y',
      shopper_interaction: 'ContAuth',
      recurring_processing_model: 'Subscription',
      network_transaction_id: auth.network_transaction_id
    )

    assert purchase = @gateway.purchase(@amount, @apple_pay_card, used_options)
    assert_success purchase
  end

  def test_successful_authorize_with_sub_merchant_data
    sub_merchant_data = {
      sub_merchant_id: '123451234512345',
      sub_merchant_name: 'Wildsea',
      sub_merchant_street: '1234 Street St',
      sub_merchant_city: 'Night City',
      sub_merchant_state: 'East Block',
      sub_merchant_postal_code: '112233',
      sub_merchant_country: 'EUR',
      sub_merchant_tax_id: '12345abcde67',
      sub_merchant_mcc: '1234'
    }
    options = @options.update({
      installments: 2,
      billing_address: {
        address1: 'Infinite Loop',
        address2: 1,
        country: 'US',
        city: 'Cupertino',
        state: 'CA',
        zip: '95014'
      }
    })
    assert response = @gateway.authorize(@amount, @avs_credit_card, options.merge(sub_merchant_data))
    assert response.test?
    refute response.authorization.blank?
    assert_success response
  end

  def test_successful_authorize_with_sub_merchant_sub_seller_data
    @sub_seller_options = {
      "subMerchant.numberOfSubSellers": '2',
      "subMerchant.subSeller1.id": '111111111',
      "subMerchant.subSeller1.name": 'testSub1',
      "subMerchant.subSeller1.street": 'Street1',
      "subMerchant.subSeller1.postalCode": '12242840',
      "subMerchant.subSeller1.city": 'Sao jose dos campos',
      "subMerchant.subSeller1.state": 'SP',
      "subMerchant.subSeller1.country": 'BRA',
      "subMerchant.subSeller1.taxId": '12312312340',
      "subMerchant.subSeller1.mcc": '5691',
      "subMerchant.subSeller1.debitSettlementBank": '1',
      "subMerchant.subSeller1.debitSettlementAgency": '1',
      "subMerchant.subSeller1.debitSettlementAccountType": '1',
      "subMerchant.subSeller1.debitSettlementAccount": '1',
      "subMerchant.subSeller1.creditSettlementBank": '1',
      "subMerchant.subSeller1.creditSettlementAgency": '1',
      "subMerchant.subSeller1.creditSettlementAccountType": '1',
      "subMerchant.subSeller1.creditSettlementAccount": '1',
      "subMerchant.subSeller2.id": '22222222',
      "subMerchant.subSeller2.name": 'testSub2',
      "subMerchant.subSeller2.street": 'Street2',
      "subMerchant.subSeller2.postalCode": '12300000',
      "subMerchant.subSeller2.city": 'Jacarei',
      "subMerchant.subSeller2.state": 'SP',
      "subMerchant.subSeller2.country": 'BRA',
      "subMerchant.subSeller2.taxId": '12312312340',
      "subMerchant.subSeller2.mcc": '5691',
      "subMerchant.subSeller2.debitSettlementBank": '1',
      "subMerchant.subSeller2.debitSettlementAgency": '1',
      "subMerchant.subSeller2.debitSettlementAccountType": '1',
      "subMerchant.subSeller2.debitSettlementAccount": '1',
      "subMerchant.subSeller2.creditSettlementBank": '1',
      "subMerchant.subSeller2.creditSettlementAgency": '1',
      "subMerchant.subSeller2.creditSettlementAccountType": '1',
      "subMerchant.subSeller2.creditSettlementAccount": '1'
    }
    assert response = @gateway.authorize(@amount, @avs_credit_card, @options.merge(sub_merchant_data: @sub_seller_options))
    assert response.test?
    refute response.authorization.blank?
    assert_success response
  end

  def test_sending_mcc_on_authorize
    options = {
      reference: '345123',
      email: 'john.smith@test.com',
      ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      order_id: '123',
      mcc: '5411'
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'Could not find an acquirer account for the provided currency (USD).', response.message
  end

  def test_successful_authorize_with_level_2_data
    level_2_data = {
      total_tax_amount: '160',
      customer_reference: '101'
    }
    assert response = @gateway.authorize(@amount, @avs_credit_card, @options.merge(level_2_data: level_2_data))
    assert response.test?
    refute response.authorization.blank?
    assert_success response
  end

  def test_successful_purchase_with_level_2_data
    level_2_data = {
      total_tax_amount: '160',
      customer_reference: '101'
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge(level_2_data: level_2_data))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_authorize_with_level_3_data
    level_3_data = {
      total_tax_amount: '12800',
      customer_reference: '101',
      freight_amount: '300',
      destination_state_province_code: 'NYC',
      ship_from_postal_code: '1082GM',
      order_date: '101216',
      destination_postal_code: '1082GM',
      destination_country_code: 'NLD',
      duty_amount: '500',
      items: [
        {
          description: 'T16 Test products 1',
          product_code: 'TEST120',
          commodity_code: 'COMMCODE1',
          quantity: '5',
          unit_of_measure: 'm',
          unit_price: '1000',
          discount_amount: '60',
          total_amount: '4940'
        }
      ]
    }
    assert response = @gateway.authorize(@amount, @avs_credit_card, @options.merge(level_3_data: level_3_data))
    assert response.test?
    assert_success response
  end

  def test_successful_purchase_with_level_3_data
    level_3_data = {
      total_tax_amount: '12800',
      customer_reference: '101',
      freight_amount: '300',
      destination_state_province_code: 'NYC',
      ship_from_postal_code: '1082GM',
      order_date: '101216',
      destination_postal_code: '1082GM',
      destination_country_code: 'NLD',
      duty_amount: '500',
      items: [
        {
          description: 'T16 Test products 1',
          product_code: 'TEST120',
          commodity_code: 'COMMCODE1',
          quantity: '5',
          unit_of_measure: 'm',
          unit_price: '1000',
          discount_amount: '60',
          total_amount: '4940'
        }
      ]
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge(level_3_data: level_3_data))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_succesful_purchase_with_airline_data
    airline_data = {
      agency_invoice_number: 'BAC123',
      agency_plan_name: 'plan name',
      airline_code: '434234',
      airline_designator_code: '1234',
      boarding_fee: '100',
      computerized_reservation_system: 'abcd',
      customer_reference_number: 'asdf1234',
      document_type: 'cc',
      flight_date: '2023-09-08',
      ticket_issue_address: 'abcqwer',
      ticket_number: 'ABCASDF',
      travel_agency_code: 'ASDF',
      travel_agency_name: 'hopper',
      passenger_name: 'Joe Doe',
      leg: {
        carrier_code: 'KL',
        class_of_travel: 'F'
      },
      passenger: {
        first_name: 'Joe',
        last_name: 'Doe',
        telephone_number: '432211111'
      }
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(additional_data_airline: airline_data))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_succesful_purchase_with_lodging_data
    lodging_data = {
      check_in_date: '20230822',
      check_out_date: '20230830',
      customer_service_toll_free_number: '234234',
      fire_safety_act_indicator: 'abc123',
      folio_cash_advances: '1234667',
      folio_number: '32343',
      food_beverage_charges: '1234',
      no_show_indicator: 'Y',
      prepaid_expenses: '100',
      property_phone_number: '54545454',
      number_of_nights: '5',
      rate: '100',
      total_room_tax: '1000',
      total_tax: '100',
      duration: '2',
      market: 'H'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(additional_data_lodging: lodging_data))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_cancel_or_refund
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert cancel = @gateway.void(auth.authorization)
    assert_success cancel
    assert_equal '[cancel-received]', cancel.message

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    @options[:cancel_or_refund] = true
    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal '[cancelOrRefund-received]', void.message
    assert_void_references_original_authorization(void, auth)
  end

  def test_successful_cancel_or_refund_passing_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @options[:cancel_or_refund] = true
    assert void = @gateway.void(purchase.authorization, @options)
    assert_success void
    assert_equal '[cancelOrRefund-received]', void.message
    assert_void_references_original_authorization(void, purchase.responses.first)
  end

  def test_successful_cancel_or_refund_passing_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    @options[:cancel_or_refund] = true
    assert void = @gateway.void(capture.authorization, @options)
    assert_success void
    assert_equal '[cancelOrRefund-received]', void.message
    assert_void_references_original_authorization(void, auth)
  end

  def test_successful_authorize_with_alternate_kosovo_code
    @options[:billing_address][:country] = 'XK'
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Billing address problem (Country XK invalid)', response.message

    @options[:billing_address][:country] = 'QZ'
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_authorize_with_address_override
    address = {
      address1: 'Bag End',
      address2: '123 Hobbiton Way',
      city: 'Hobbiton',
      state: 'Derbyshire',
      country: 'GB',
      zip: 'DE45 1PP'
    }
    response = @gateway.purchase(@amount, @credit_card, @options.merge(billing_address: address, address_override: true))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_metadata
    metadata = {
      field_one: 'A',
      field_two: 'B',
      field_three: 'C',
      field_four: 'EASY AS ONE TWO THREE'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(metadata: metadata))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  private

  def stored_credential_options(*args, ntid: nil)
    @options.merge(order_id: generate_unique_id,
                   stored_credential: stored_credential(*args, network_transaction_id: ntid))
  end

  def assert_void_references_original_authorization(void, auth)
    assert_equal void.authorization.split('#').first, auth.params['pspReference']
  end
end
