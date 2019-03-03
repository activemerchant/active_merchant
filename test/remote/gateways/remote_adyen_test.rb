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

    @three_ds_enrolled_card = credit_card('4212345678901237', brand: :visa)

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
      recurring_processing_model: 'CardOnFile'
    }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Authorised', response.message
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

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
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
    options = @options.merge!(fraudOffset: '1', installments: 2)
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

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
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

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Original pspReference required for this operation', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)

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
    assert_match 'Refused', response.message
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

  def test_invalid_country_for_purchase
    @options[:billing_address][:country] = ''
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_address], response.error_code
  end

  def test_invalid_state_for_purchase
    @options[:billing_address][:state] = ''
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_match Gateway::STANDARD_ERROR_CODE[:incorrect_address], response.error_code
  end
end
