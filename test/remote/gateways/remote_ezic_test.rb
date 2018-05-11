require 'test_helper'

class RemoteEzicTest < Test::Unit::TestCase
  def setup
    @gateway = EzicGateway.new(fixtures(:ezic))

    @amount = 100
    @failed_amount = 19088
    @credit_card = credit_card('4000100011112224')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "TEST APPROVED", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@failed_amount, @credit_card, @options)
    assert_failure response
    assert_equal "TEST DECLINED", response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal "TEST CAPTURED", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@failed_amount, @credit_card, @options)
    assert_failure response
    assert_equal "TEST DECLINED", response.message
  end

  def test_failed_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount+30, auth.authorization)
    assert_failure capture
    assert_match /Settlement amount cannot exceed authorized amount/, capture.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal "TEST RETURNED", refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
    assert_equal "TEST RETURNED", refund.message
    assert_equal "-0.99", refund.params["settle_amount"]
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount + 49, purchase.authorization)
    assert_failure refund
    assert_match /Amount of refunds exceed original sale/, refund.message
  end

  def test_failed_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    assert void = @gateway.void(authorize.authorization)
    assert_failure void
    assert_equal "Processor/Network Error", void.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal "TEST APPROVED", response.message
  end

  def test_failed_verify
    response = @gateway.verify(credit_card(""), @options)
    assert_failure response
    assert_match %r{Missing card or check number}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

  def test_invalid_login
    gateway = EzicGateway.new(account_id: '11231')
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match /Invalid account number/, response.message
  end
end
