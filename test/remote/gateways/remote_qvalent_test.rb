require "test_helper"

class RemoteQvalentTest < Test::Unit::TestCase
  def setup
    @gateway = QvalentGateway.new(fixtures(:qvalent))

    @amount = 100
    @credit_card = credit_card("4000100011112224")
    @declined_card = credit_card("4000000000000000")

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase',
      customer_reference_number: generate_unique_id
    }
  end

  def test_invalid_login
    gateway = QvalentGateway.new(
      username: "bad",
      password: "bad",
      merchant: "101"
    )

    authentication_exception = assert_raise ActiveMerchant::ResponseError do
      gateway.purchase(@amount, @credit_card, @options)
    end
    response = authentication_exception.response
    assert_match(%r{Error 403: Missing authentication}, response.body)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_soft_descriptors
    options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase',
      customer_merchant_name: 'Some Merchant',
      customer_merchant_street_address: '42 Wallaby Way',
      customer_merchant_location: 'Sydney',
      customer_merchant_country: 'AU',
      customer_merchant_post_code: '2060',
      customer_merchant_state: 'NSW'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_3d_secure
    options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase',
      xid: 'sgf7h125tr8gh24abmah',
      cavv: 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=',
      eci: 'INS'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid card number (no such number)", response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
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
