require 'test_helper'

class RemoteAlliedWalletTest < Test::Unit::TestCase
  def setup
    @gateway = AlliedWalletGateway.new(fixtures(:allied_wallet))

    @amount = 100
    @credit_card = credit_card
    @declined_card = credit_card('4242424242424242', verification_value: "555")

    @options = {
      billing_address: address,
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "The test operation was declined.", response.message
  end

  def test_failed_purchase_no_address
    response = @gateway.purchase(@amount, @declined_card)
    assert_failure response
    assert_match(/Address.* should not be empty/, response.message)
  end

  def test_successful_purchase_with_more_options
    response = @gateway.purchase(@amount, @credit_card, @options.merge(
      order_id: generate_unique_id,
      ip: "127.0.0.1",
      email: "jim_smith@example.com"
    ))
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "The test operation was declined.", response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "")
    assert_failure response
    assert_equal "'Authorize Transaction Id' should not be empty.", response.message
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization)
    assert_success void
    assert_equal "Succeeded", void.message
  end

  def test_failed_void
    response = @gateway.void("")
    assert_failure response
    assert_equal "'Authorize Transaction Id' should not be empty.", response.message
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, "UnknownAuthorization")
    assert_failure response
    assert_match(/An internal exception has occurred/, response.message)
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "The test operation was declined.", response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:token], clean_transcript)
    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
  end

  def test_nil_cvv_transcript_scrubbing
    @credit_card.verification_value = nil
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_equal transcript.include?('\"cVVCode\":[BLANK]'), true
  end

  def test_empty_string_cvv_transcript_scrubbing
    @credit_card.verification_value = ""
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_equal transcript.include?('\"cVVCode\":\"[BLANK]'), true
  end

  def test_whitespace_string_cvv_transcript_scrubbing
    @credit_card.verification_value = "    "
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_equal transcript.include?('\"cVVCode\":\"[BLANK]'), true
  end
end
