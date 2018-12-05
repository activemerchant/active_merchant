require 'test_helper'

class RemoteFirstPayTest < Test::Unit::TestCase
  def setup
    @gateway = FirstPayGateway.new(fixtures(:first_pay))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: SecureRandom.hex(24),
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_failed_purchase_with_no_address
    @options.delete(:billing_address)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'Address is invalid (street, city, zip, state and or country fields)', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '1234')
    assert_failure response
  end

  def test_successful_refund
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    # Not sure why purchase tx is not refundable??
    # purchase = @gateway.purchase(@amount, @credit_card, @options)
    # assert_success purchase

    assert refund = @gateway.refund(@amount, capture.authorization)
    assert_success refund
  end

  def test_partial_refund
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture

    # Not sure why purchase tx is not refundable??
    # purchase = @gateway.purchase(@amount, @credit_card, @options)
    # assert_success purchase

    assert refund = @gateway.refund(@amount / 2, capture.authorization)
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
      transaction_center_id: '1234',
      gateway_id: 'abcd'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/Merchant: 1234 has encountered error #DTO-200-TC./, response.error_code)
  end

  def test_recurring_payment
    @options.merge!({recurring: 1, recurring_start_date: DateTime.now.strftime('%m/%d/%Y'), recurring_end_date: DateTime.now.strftime('%m/%d/%Y'), recurring_type: 'monthly'})
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = 789
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:gateway_id], transcript)
  end
end
