require "test_helper"

class RemoteQvalentTest < Test::Unit::TestCase
  def setup
    @gateway = QvalentGateway.new(fixtures(:qvalent))

    @amount = 100
    @credit_card = credit_card("4000100011112224")
    @declined_card = credit_card("4000000000000000")
    @expired_card = credit_card("4111111113444494")

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: "Store Purchase"
    }
  end

  def test_invalid_login
    gateway = QvalentGateway.new(
      username: "bad",
      password: "bad",
      merchant: "101",
      pem: "bad",
      pem_password: "bad"
    )

    assert_raise ActiveMerchant::ClientCertificateError do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_soft_descriptors
    options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: "Store Purchase",
      customer_merchant_name: "Some Merchant",
      customer_merchant_street_address: "42 Wallaby Way",
      customer_merchant_location: "Sydney",
      customer_merchant_country: "AU",
      customer_merchant_post_code: "2060",
      customer_merchant_state: "NSW"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_3d_secure
    options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: "Store Purchase",
      xid: "123",
      cavv: "456",
      eci: "5"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
  end

  def test_successful_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "Succeeded", auth.message
    assert_not_nil auth.authorization

    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge({ order_id: generate_unique_id }))
    assert_success capture
  end

  def test_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "Succeeded", auth.message
    assert_not_nil auth.authorization

    assert capture = @gateway.capture(@amount, '', @options.merge({ order_id: generate_unique_id }))
    assert_failure capture
  end

  def test_successful_partial_capture
    assert auth = @gateway.authorize(200, @credit_card, @options)
    assert_success auth
    assert_equal "Succeeded", auth.message
    assert_not_nil auth.authorization

    assert capture = @gateway.capture(100, auth.authorization, @options.merge({ order_id: generate_unique_id }))
    assert_success capture
  end

  def test_successful_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "Succeeded", auth.message
    assert_not_nil auth.authorization

    assert void = @gateway.void(auth.authorization, @options.merge({ order_id: generate_unique_id }))
    assert_success void
  end

  def test_failed_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "Succeeded", auth.message
    assert_not_nil auth.authorization

    assert void = @gateway.void('', @options.merge({ order_id: generate_unique_id }))
    assert_failure void
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
  end

  def test_failed_refund
    response = @gateway.refund(nil, "")
    assert_failure response
    assert_match %r{Invalid card number}, response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_credit
    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_credit
    response = @gateway.credit(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value, clean_transcript)
    assert_scrubbed(@gateway.options[:password], clean_transcript)
  end
end
