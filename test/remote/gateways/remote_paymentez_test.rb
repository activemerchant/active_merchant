require 'test_helper'

class RemotePaymentezTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentezGateway.new(fixtures(:paymentez))

    @amount = 100
    @credit_card = credit_card('4111111111111111', verification_value: '555')
    @declined_card = credit_card('4242424242424242', verification_value: '555')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      user_id: '998',
      email: 'joe@example.com',
      vat: 0,
      dev_reference: 'Testing'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      tax_percentage: 0.07
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
  end

  def test_successful_purchase_with_token
    store_response = @gateway.store(@credit_card, @options)
    assert_success store_response
    token = store_response.authorization
    purchase_response = @gateway.purchase(@amount, token, @options)
    assert_success purchase_response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_refund
    auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth

    assert refund = @gateway.refund(@amount, @credit_card, @options)
    assert_success refund
  end

  def test_successful_void
    auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Carrier not supported', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:config_error], response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_successful_authorize_and_capture_with_token
    store_response = @gateway.store(@credit_card, @options)
    assert_success store_response
    token = store_response.authorization
    auth = @gateway.authorize(@amount, token, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_successful_authorize_and_capture_with_different_amount
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount + 100, auth.authorization)
    assert_success capture
    assert_equal 'Response by mock', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Response by mock', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_failure capture # Paymentez explicitly does not support partial capture; only GREATER than auth capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'The modification of the amount is not supported by carrier', response.message
  end

  def test_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_unstore
    response = @gateway.store(@credit_card, @options)
    assert_success response
    auth = response.authorization
    response = @gateway.unstore(auth, @options)
    assert_success response
  end

  def test_invalid_login
    gateway = PaymentezGateway.new(application_code: '9z8y7w6x', app_key: '1a2b3c4d')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'BackendResponseException', response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:config_error], response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:app_key], transcript)
  end
end
