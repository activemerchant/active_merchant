require 'test_helper'

class RemotePaymentwallTest < Test::Unit::TestCase
  def setup
    @gateway = PaymentwallGateway.new(fixtures(:paymentwall))

    @amount = 100
    @credit_card = credit_card('4242 4242 4242 4242')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      ip: '172.217.3.78',
      browser_domain: 'example.com',
      email: 'you@gmail.com',
      plan: 'Example'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'CHARGED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'CHARGED', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REQUEST IS EMPTY', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'REFUNDED', refund.message
  end

  # TEST API DOES NOT SUPPORT PARTIAL REFUNDS
  # TEST API DOES NOT FAIL INCORRECT REFUNDS

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    # SHOULD WORK BUT TEST API DOES NOT RETURN AS EXPECTED
    # assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    # SHOULD WORK BUT TEST API DOES NOT RETURN AS EXPECTED
    # assert_match %r{AUTHORIZED}, response.message 
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
  end

  def test_invalid_login
    gateway = PaymentwallGateway.new(public_key: '', secret_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{API KEY IS INVALID}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:secret_key], transcript)
  end

end
