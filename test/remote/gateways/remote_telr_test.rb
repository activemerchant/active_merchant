require "test_helper"

class RemoteTelrTest < Test::Unit::TestCase
  def setup
    @gateway = TelrGateway.new(fixtures(:telr))

    @amount = 100
    @credit_card = credit_card("5105105105105100")
    @declined_card = credit_card("5105105105105100", verification_value: "031")

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: "Test transaction",
      email: "email@address.com"
    }
  end

  def test_invalid_login
    gateway = TelrGateway.new(merchant_id: "", api_key: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid request", response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_sans_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Not authorised", response.message
    assert_equal "31", response.error_code
  end

  def test_successful_reference_purchase
    assert ref_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success ref_response

    response = @gateway.purchase(@amount, ref_response.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Not authorised", response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "")
    assert_failure response
    assert_equal "Invalid transaction reference", response.message
    assert_equal "22", response.error_code
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
    assert_equal "Transaction cost or currency not valid", response.message
    assert_equal "05", response.error_code
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
  end

  def test_partial_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(50, response.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, "0")
    assert_failure response
    assert_equal "Invalid transaction reference", response.message
    assert_equal "22", response.error_code
  end

  def test_excess_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund = @gateway.refund(200, response.authorization)
    assert_failure refund
    assert_equal "Amount greater than available balance", refund.message
    assert_equal "29", refund.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Succeeded}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal "Not authorised", response.message
    assert_equal "31", response.error_code
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = TelrGateway.new(merchant_id: 'unknown', api_key: 'unknown')
    assert !gateway.verify_credentials
    gateway = TelrGateway.new(merchant_id: fixtures(:telr)[:merchant_id], api_key: 'unknown')
    assert !gateway.verify_credentials
  end

  def test_cvv_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "M", response.cvv_result["code"]
  end

  def test_avs_result
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "I", response.avs_result["code"]
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:api_key], clean_transcript)
  end
end
