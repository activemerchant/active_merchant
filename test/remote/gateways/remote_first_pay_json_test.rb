require 'test_helper'

class RemoteFirstPayJsonTest < Test::Unit::TestCase
  def setup
    @gateway = FirstPayGateway.new(fixtures(:first_pay_rest_json))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('5130405452262903')

    @google_pay = network_tokenization_credit_card(
      '4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :google_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )
    @apple_pay = network_tokenization_credit_card(
      '4005550000000019',
      brand: 'visa',
      eci: '05',
      month: '02',
      year: '2035',
      source: :apple_pay,
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk='
    )

    @options = {
      order_id: SecureRandom.hex(24),
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'APPROVED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(99999999999, @credit_card, @options)
    assert_failure response
    assert_equal 'validationHasFailed', response.error_code
    assert_match 'Amount exceed numeric limit of 9999999.99', response.message
  end

  def test_successful_purchase_with_google_pay
    response = @gateway.purchase(@amount, @google_pay, @options)
    assert_success response
    assert_match 'APPROVED', response.message
    assert_equal 'Visa-GooglePay', response.params['data']['cardType']
  end

  def test_successful_purchase_with_apple_pay
    response = @gateway.purchase(@amount, @apple_pay, @options)
    assert_success response
    assert_match 'APPROVED', response.message
    assert_equal 'Visa-ApplePay', response.params['data']['cardType']
  end

  def test_failed_purchase_with_no_address
    @options.delete(:billing_address)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'validationHasFailed', response.error_code
    assert_equal 'Name on credit card is required; Street is required.; City is required.; State is required.; Postal Code is required.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(99999999999, @credit_card, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '1234')
    assert_failure response
  end

  def test_successful_refund_for_authorize_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    assert refund = @gateway.refund(@amount, capture.authorization)
    assert_success refund
  end

  def test_successful_refund_for_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '1234')
    assert_failure response
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('1')
    assert_failure response
  end

  def test_recurring_payment
    @options.merge!({
      recurring: 'monthly',
      recurring_start_date: (DateTime.now + 1.day).strftime('%m/%d/%Y'),
      recurring_end_date: (DateTime.now + 1.month).strftime('%m/%d/%Y')
    })
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'APPROVED', response.message
  end

  def test_invalid_login
    gateway = FirstPayGateway.new(
      processor_id: '1234',
      merchant_key: 'abcd'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal('isError', response.error_code)
  end

  def test_transcript_scrubbing
    @google_pay.verification_value = 789
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @google_pay, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@google_pay.number, transcript)
    assert_scrubbed(@google_pay.verification_value, transcript)
    assert_scrubbed(@google_pay.payment_cryptogram, transcript)
    assert_scrubbed(@gateway.options[:processor_id], transcript)
    assert_scrubbed(@gateway.options[:merchant_key], transcript)
  end
end
