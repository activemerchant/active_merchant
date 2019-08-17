require 'test_helper'

class RemoteAdyenTest < Test::Unit::TestCase
  def setup
    @gateway = AdyenGateway.new(fixtures(:adyen))

    @amount = 100

    @credit_card = credit_card('4111111111111111',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737',
      :brand => 'visa'
    )

    @avs_credit_card = credit_card('4400000000000008',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737',
      :brand => 'visa'
    )

    @elo_credit_card = credit_card('5066 9911 1111 1118',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737',
      :brand => 'elo'
    )

    @three_ds_enrolled_card = credit_card('4917610000000000', brand: :visa)

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

    @apple_pay_card = network_tokenization_credit_card('4111111111111111',
      :payment_cryptogram => 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      :month              => '08',
      :year               => '2018',
      :source             => :apple_pay,
      :verification_value => nil
    )

    @google_pay_card = network_tokenization_credit_card('4111111111111111',
      :payment_cryptogram => 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      :month              => '08',
      :year               => '2018',
      :source             => :google_pay,
      :verification_value => nil
    )

    @options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: {reason_type: 'unscheduled'},
    }

    @normalized_3ds_2_options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: {reason_type: 'unscheduled'},
      three_ds_2: {
        channel: 'browser',
        notification_url: 'https://example.com/notification',
        browser_info: {
          accept_header: 'unknown',
          depth: 100,
          java: false,
          language: 'US',
          height: 1000,
          width: 500,
          timezone: '-120',
          user_agent: 'unknown'
        }
      }
    }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
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

  def test_successful_authorize_with_3ds2_app_based_request
    three_ds_app_based_options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: {reason_type: 'unscheduled'},
      three_ds_2: {
        channel: 'app',
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
    mastercard_threed = credit_card('5212345678901234',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737',
      :brand => 'mastercard'
    )
    assert response = @gateway.authorize(@amount, mastercard_threed, @options.merge(threed_dynamic: true))
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'Authorised'
  end

  def test_successful_authorize_with_no_address
    options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      order_id: '123',
      recurring_processing_model: 'CardOnFile'
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'CVC Declined', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
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
    options = @options.merge!(fraudOffset: '1', installments: 2, shopper_statement: 'statement note', device_fingerprint: 'm7Cmrf++0cW4P6XfF7m/rA')
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

  def test_successful_purchase_with_apple_pay
    response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_succesful_purchase_with_brand_override
    response = @gateway.purchase(@amount, @improperly_branded_maestro, @options.merge({overwrite_brand: true, selected_brand: 'maestro'}))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_google_pay
    response = @gateway.purchase(@amount, @google_pay_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_elo_card
    response = @gateway.purchase(@amount, @elo_credit_card, @options.merge(currency: 'BRL'))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'CVC Declined', response.message
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

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
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

  def test_successful_refund_with_elo_card
    purchase = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal '[refund-received]', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Original pspReference required for this operation', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
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

  def test_successful_store_with_elo_card
    assert response = @gateway.store(@elo_credit_card, @options)

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message
  end

  def test_failed_store
    assert response = @gateway.store(@declined_card, @options)

    assert_failure response
    assert_equal 'CVC Declined', response.message
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

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match 'CVC Declined', response.message
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
    assert_equal 'Expiry Date Invalid: Expiry month should be between 1 and 12 inclusive', response.message
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
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_address], response.error_code
  end

  def test_nil_state_for_purchase
    @options[:billing_address][:state] = nil
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
end
