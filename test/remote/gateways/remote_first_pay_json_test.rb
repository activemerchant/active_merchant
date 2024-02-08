require 'test_helper'

class RemoteFirstPayJsonTest < Test::Unit::TestCase
  def setup
    @gateway = FirstPayGateway.new(fixtures(:first_pay_rest_json))

    @amount = 100
    @credit_card = credit_card('4111111111111111')

    @options = {
      order_id: SecureRandom.hex(24),
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(200, @credit_card, @options)
    assert_failure response
    assert_equal 'isError', response.error_code
    assert_match 'Declined', response.message
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
    response = @gateway.authorize(200, @credit_card, @options)
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
    @credit_card.verification_value = 789
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:processor_id], transcript)
    assert_scrubbed(@gateway.options[:merchant_key], transcript)
  end
end
