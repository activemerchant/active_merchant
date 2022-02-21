require 'test_helper'

class RemoteAdyenCheckoutTest < Test::Unit::TestCase
  def setup
    @gateway = AdyenCheckoutGateway.new(fixtures(:adyen_checkout))

    @amount = 100

    @credit_card = credit_card('4111111111111111',
        :month => 03,
        :year => 2030,
        :first_name => 'John',
        :last_name => 'Smith',
        :verification_value => '737',
        :brand => 'visa'
    )

    @declined_card = credit_card('4000300011112220')

    @options = {
        reference: '345123',
        shopper_email: 'john.smith@test.com',
        shopper_ip: '77.110.174.153',
        shopper_reference: 'John Smith',
        billing_address: address(),
        order_id: '123',
        stored_credential: {reason_type: 'unscheduled'},
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_purchase_no_cvv
    credit_card = @credit_card
    credit_card.verification_value = nil
    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge!(
        fraudOffset: '1',
        installments: 2,
        shopper_statement: 'statement note',
        device_fingerprint: 'm7Cmrf++0cW4P6XfF7m/rA',
        capture_delay_hours: 4)
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Authorised', response.message
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
    assert_equal 'Authorised', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Refused | Refused', response.message
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
    assert_equal '[refund-received]', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Original pspReference required for this operation', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message
  end

  def test_successful_update_card_details_store
    assert response = @gateway.store(
      credit_card('4111111111111111',
        :month => 03,
        :year => 2030,
        :first_name => 'John',
        :last_name => 'Smith',
        :brand => 'visa',
        :verification_value => nil
      ),
      @options.merge(
        shopper_reference: 'chargify_js_1587733806270148',
        update_card_details: true,
        stored_payment_method_id: "8415877340540131",
        recurring_processing_model: "Subscription",
        shopperReference: "chargify_js_1587733806270148",
        stored_credential: {reason_type: 'unscheduled'}
      )
    )

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message
  end

  def test_failed_store
    assert response = @gateway.store(@declined_card, @options)

    assert_failure response
    assert_equal 'Refused | Refused', response.message
  end

  def test_successful_purchase_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(@amount, store_response.params['additionalData']['recurring.recurringDetailReference'], @options)
    assert_success response
    assert_equal 'Authorised', response.message
  end

  def test_invalid_login
    gateway = AdyenCheckoutGateway.new(username: '', password: '', merchant_account: '', url_prefix: '')

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
    assert_equal 'The provided Expiry Date is not valid.: Expiry month should be between 1 and 12 inclusive', response.message
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

  def test_successful_unstore
    assert response = @gateway.store(@credit_card, @options)

    assert_success response
    assert !response.authorization.split('#')[2].nil?
    assert_equal 'Authorised', response.message

    unstore_token = {
      customer_profile_token: response.params["additionalData"]["recurring.shopperReference"],
      payment_profile_token: response.params["additionalData"]["recurring.recurringDetailReference"],
    }

    assert response = @gateway.unstore(unstore_token, {})
    assert_success response
  end
end
