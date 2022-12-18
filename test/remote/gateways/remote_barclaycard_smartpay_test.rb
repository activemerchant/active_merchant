require 'test_helper'

class RemoteBarclaycardSmartpayTest < Test::Unit::TestCase
  def setup
    @gateway = BarclaycardSmartpayGateway.new(fixtures(:barclaycard_smartpay))

    @amount = 100
    @credit_card = credit_card('4111111111111111', :month => 8, :year => 2018, :verification_value => 737)
    @declined_card = credit_card('4000300011112220', :month => 8, :year => 2018, :verification_value => 737)

    @options = {
      order_id: '1',
      billing_address:       {
              name:     'Jim Smith',
              address1: '100 Street',
              company:  'Widgets Inc',
              city:     'Ottawa',
              state:    'ON',
              zip:      'K1C2N6',
              country:  'CA',
              phone:    '(555)555-5555',
              fax:      '(555)555-6666'},
      email: 'long@bob.com',
      customer: 'Longbob Longsen',
      description: 'Store Purchase'
    }

    @avs_credit_card = credit_card('4400000000000008',
                                    :month => 8,
                                    :year => 2018,
                                    :verification_value => 737)

    @avs_address = @options
    @avs_address.update(billing_address: {
      name:     'Jim Smith',
      street:   'Test AVS result',
      houseNumberOrName: '2',
      city:     'Cupertino',
      state:    'CA',
      zip:      '95014',
      country:  'US'
    })

    @normalized_3ds_2_options = {
      reference: '345123',
      shopper_email: 'john.smith@test.com',
      shopper_ip: '77.110.174.153',
      shopper_reference: 'John Smith',
      billing_address: address(),
      order_id: '123',
      stored_credential: { reason_type: 'unscheduled' },
      three_ds_2: {
        channel: 'browser',
        browser_info: {
          accept_header: 'unknown',
          depth: 100,
          java: false,
          language: 'US',
          height: 1000,
          width: 500,
          timezone: '-120',
          user_agent: 'unknown'
        },
        notification_url: 'https://example.com/notification'
      }
    }
  end

  def teardown
    BarclaycardSmartpayGateway.ssl_strict = true
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_successful_purchase_with_unusual_address
    response = @gateway.purchase(@amount,
      @credit_card,
      @options_with_alternate_address)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_house_number_and_street
    response = @gateway.purchase(@amount,
      @credit_card,
      @options.merge(street: 'Top Level Drive', house_number: '100'))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_no_address
    response = @gateway.purchase(@amount,
      @credit_card,
      @options_with_no_address)
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_shopper_interaction
    response = @gateway.purchase(@amount, @credit_card, @options.merge(shopper_interaction: 'ContAuth'))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_device_fingerprint
    response = @gateway.purchase(@amount, @credit_card, @options.merge(device_fingerprint: 'abcde1123'))
    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_purchase_with_shopper_statement
    response = @gateway.purchase(
      @amount,
      @credit_card,
      @options.merge(shopper_statement: 'One-year premium subscription')
    )

    assert_success response
    assert_equal '[capture-received]', response.message
  end

  def test_successful_authorize_with_3ds
    assert response = @gateway.authorize(@amount, @three_ds_enrolled_card, @options.merge(execute_threed: true))
    assert_equal 'RedirectShopper', response.message
    assert response.test?
    refute response.authorization.blank?
    refute response.params['issuerUrl'].blank?
    refute response.params['md'].blank?
    refute response.params['paRequest'].blank?
  end

  def test_successful_authorize_with_3ds2_browser_client_data
    assert response = @gateway.authorize(@amount, @three_ds_2_enrolled_card, @normalized_3ds_2_options)
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'IdentifyShopper'
    refute response.params['additionalData']['threeds2.threeDS2Token'].blank?
    refute response.params['additionalData']['threeds2.threeDSServerTransID'].blank?
    refute response.params['additionalData']['threeds2.threeDSMethodURL'].blank?
  end

  def test_successful_purchase_with_3ds2_exemption_requested_and_execute_threed_false
    assert response = @gateway.authorize(@amount, @three_ds_2_enrolled_card, @normalized_3ds_2_options.merge(execute_threed: false, sca_exemption: 'lowValue'))
    assert response.test?
    refute response.authorization.blank?

    assert_equal response.params['resultCode'], 'Authorised'
  end

  # According to Adyen documentation, if execute_threed is set to true and an exemption provided
  # the gateway will apply and request for the specified exemption in the authentication request,
  # after the device fingerprint is submitted to the issuer.
  def test_successful_purchase_with_3ds2_exemption_requested_and_execute_threed_true
    assert response = @gateway.authorize(@amount, @three_ds_2_enrolled_card, @normalized_3ds_2_options.merge(execute_threed: true, sca_exemption: 'lowValue'))
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
      stored_credential: { reason_type: 'unscheduled' },
      three_ds_2: {
        channel: 'app'
      }
    }

    assert response = @gateway.authorize(@amount, @three_ds_2_enrolled_card, three_ds_app_based_options)
    assert response.test?
    refute response.authorization.blank?
    assert_equal response.params['resultCode'], 'IdentifyShopper'
    refute response.params['additionalData']['threeds2.threeDS2Token'].blank?
    refute response.params['additionalData']['threeds2.threeDSServerTransID'].blank?
    refute response.params['additionalData']['threeds2.threeDS2DirectoryServerInformation.algorithm'].blank?
    refute response.params['additionalData']['threeds2.threeDS2DirectoryServerInformation.directoryServerId'].blank?
    refute response.params['additionalData']['threeds2.threeDS2DirectoryServerInformation.publicKey'].blank?
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '', @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization, @options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, nil, @options)
    assert_failure response
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_credit
    response = @gateway.credit(nil, @declined_card, @options)
    assert_failure response
  end

  def test_failed_credit_insufficient_validation
    # This test will fail currently (the credit will succeed), but it should succeed after October 29th
    # response = @gateway.credit(@amount, @credit_card, @options)
    # assert_failure response
  end

  def test_successful_third_party_payout
    response = @gateway.credit(@amount, @credit_card, @options_with_credit_fields.merge({ third_party_payout: true }))
    assert_success response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void(nil, @options)
    assert_failure response
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal "Authorised", response.message
    assert response.authorization
  end

  def test_unsuccessful_verify
    assert response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "Refused", response.message
  end

  def test_invalid_login
    gateway = BarclaycardSmartpayGateway.new(
    company: '',
    merchant: '',
    password: ''
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Success", response.message
  end

  def test_failed_store
    response = @gateway.store(credit_card('', :month => '', :year => '', :verification_value => ''), @options)
    assert_failure response
    assert_equal "Unprocessable Entity", response.message
  end

  # AVS must be enabled on the gateway's end for the test account used
  def test_avs_result
    response = @gateway.authorize(@amount, @avs_credit_card, @avs_address)
    assert_equal 'N', response.avs_result['code']
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:password], clean_transcript)
  end
end
