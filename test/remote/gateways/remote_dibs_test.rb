require 'test_helper'

class RemoteDibsTest < Test::Unit::TestCase
  def setup
    @gateway = DibsGateway.new(fixtures(:dibs))

    cc_options = {
        :month => 6,
        :year => 24,
        :verification_value => '684',
        :brand => 'visa'
      }

    @amount = 100
    @credit_card = credit_card("4711100000000000", cc_options)
    @declined_card_auth = credit_card("4711000000000000", cc_options)
    @declined_card_capture = credit_card("4711100000000001", cc_options)

    @options = {
      order_id: generate_unique_id
    }
  end

  def test_invalid_login
    gateway = DibsGateway.new(
      merchant_id: "123456789",
      secret_key: "987654321"
    )
    response = gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card_capture, @options)
    assert_failure response
    assert_match %r(DECLINE.+), response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card_auth, @options)
    assert_failure response
    assert_match %r(DECLINE.+), response.message
  end

  def test_successful_authorize_and_failed_capture
    response = @gateway.authorize(@amount, @declined_card_capture, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_failure capture
    assert_match %r(DECLINE.+), capture.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "")
    assert_failure response
    assert_match %r(ERROR.+), response.message
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message

    capture = @gateway.capture(@amount, response.authorization)
    assert_failure capture
    assert_match %r(DECLINE.+), capture.message
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
    assert_match %r(ERROR.+), response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, "")
    assert_failure response
    assert_match %r(ERROR.+), response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card_auth, @options)
    assert_failure response
    assert_match %r(DECLINE.+), response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_not_nil response.params['ticketId']
    assert_not_nil response.authorization
    assert_equal response.params['ticketId'], response.authorization
  end

  def test_failed_store
    response = @gateway.store(@declined_card_auth, @options)
    assert_failure response
    assert_match %r(DECLINE.+), response.message
  end

  def test_successful_authorize_with_stored_card
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_not_nil response.authorization
    response = @gateway.authorize(@amount, response.authorization, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_authorize_and_capture_with_stored_card
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_not_nil response.authorization
    response = @gateway.authorize(@amount, response.authorization, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end
end
