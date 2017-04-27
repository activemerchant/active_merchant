require 'test_helper'

class RemoteMicropaymentTest < Test::Unit::TestCase
  def setup
    @gateway = MicropaymentGateway.new(fixtures(:micropayment))

    @amount = 250
    @credit_card = credit_card("4111111111111111", verification_value: "666")
    @declined_card = credit_card("4111111111111111")

    @options = {
      order_id: generate_unique_id,
      description: "Eggcellent",
      billing_address: address
    }
  end

  def test_invalid_login
    gateway = MicropaymentGateway.new(access_key: "invalid", api_key:"invalid")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Authorization failed - Reason: api accesskey wrong", response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "AS stellt falsches Routing fest", response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\w+\|.+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_successful_authorize_and_capture_with_recurring
    @credit_card.verification_value = ""
    response = @gateway.authorize(@amount, @credit_card, @options.merge(recurring: true))
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\w+\|.+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_partial_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    capture = @gateway.capture(100, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "AS stellt falsches Routing fest", response.message
    assert_equal "ipg92", response.params["transactionResultCode"]
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "1|2")
    assert_failure response
    assert_equal "\"sessionId\" with the value \"1\" does not exist", response.message
    assert_equal "3110", response.params["error"]
  end

  def test_successful_void_for_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_successful_authorize_and_capture_and_refund
    response = @gateway.authorize(@amount, @credit_card,  @options.merge(recurring: false))
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\w+\|.+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message

    refund = @gateway.refund(@amount, capture.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
    assert_equal "\"transactionId\" is empty", response.message
    assert_equal "3101", response.params["error"]
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
    assert_equal "\"transactionId\" is empty", response.message
    assert_equal "3101", response.params["error"]
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match "Succeeded", response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "AS stellt falsches Routing fest", response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:access_key], clean_transcript)
  end
end
