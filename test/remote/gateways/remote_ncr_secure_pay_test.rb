require 'test_helper'

class RemoteMonetraTest < Test::Unit::TestCase
  def setup
    @gateway = NcrSecurePayGateway.new(fixtures(:ncr_secure_pay))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @bad_credit_card = credit_card('1234567890123456')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(601, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'SUCCESS', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(601, @credit_card, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'invalid')
    assert_failure response
    assert_equal 'This transaction requires an apprcode ttid or unique ptrannum', response.message
  end

  # Unable to test this case since have to wait for original tx to settle
  # for refund
  def test_successful_refund
  end

  # Unable to test this case since have to wait for original tx to settle
  # for refund
  def test_partial_refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_failure refund
    assert_equal 'USE VOID OR REVERSAL TO REFUND UNSETTLED TRANSACTIONS', refund.message
  end

  def test_successful_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'SUCCESS', void.message
  end

  def test_failed_void
    response = @gateway.void('invalid')
    assert_failure response
    assert_equal 'Must specify ttid or ptrannum', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'APPROVED', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@bad_credit_card, @options)
    assert_failure response
    assert_match 'UNSUPPORTED CARD TYPE', response.message
  end

  def test_invalid_login
    gateway = NcrSecurePayGateway.new(username: '', password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'AUTHENTICATION FAILED', response.message
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

end
