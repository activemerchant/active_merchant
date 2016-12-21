require "test_helper"

class RemoteCulqiTest < Test::Unit::TestCase
  def setup
    CulqiGateway.ssl_strict = false # Sandbox has an improperly installed cert
    @gateway = CulqiGateway.new(fixtures(:culqi))

    @amount = 1000
    @credit_card = credit_card("4111111111111111")
    @declined_card = credit_card("4000300011112220", month: 06, year: 2016)

    @options = {
      order_id: generate_unique_id,
      billing_address: address
    }
  end

  def teardown
    CulqiGateway.ssl_strict = true
  end

  def test_invalid_login
    gateway = CulqiGateway.new(merchant_id: "", terminal_id: "", secret_key: "")
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_match %r{Approved}, purchase.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{Failed}, response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_match %r{Approved}, response.message
    assert_match %r(^\d+$), response.authorization

    capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_match %r{Transaction has been successfully captured}, capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{Failed}, response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
    assert_match %r{Transaction has been successfully captured}, capture.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "0")
    assert_failure response
    assert_match %r{Transaction not found}, response.message
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void = @gateway.void(response.authorization, @options)
    assert_success void
    assert_match %r{cancelled}, void.message
  end

  def test_failed_void
    response = @gateway.void("0", @options)
    assert_failure response
    assert_match %r{Transaction not found}, response.message
  end

  def test_successful_refund
    auth = @gateway.authorize(@amount, @credit_card, @options)
    capture = @gateway.capture(@amount, auth.authorization)

    refund = @gateway.refund(@amount, capture.authorization)
    assert_success refund
    assert_match %r{reversed}, refund.message
  end

  def test_partial_refund
    auth = @gateway.authorize(@amount, @credit_card, @options)
    capture = @gateway.capture(@amount, auth.authorization)

    refund = @gateway.refund(@amount-1, capture.authorization)
    assert_success refund
    assert_match %r{reversed}, refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, "0")
    assert_failure response
    assert_match %r{Transaction not found}, response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Approved}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Failed}, response.message
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = CulqiGateway.new(merchant_id: 'unknown', terminal_id: 'unknown', secret_key: 'unknown')
    assert !gateway.verify_credentials
    gateway = CulqiGateway.new(merchant_id: fixtures(:culqi)[:merchant_id], terminal_id: fixtures(:culqi)[:terminal_id], secret_key: 'unknown')
    assert !gateway.verify_credentials
  end

  def test_successful_store_and_purchase
    credit_card = credit_card("4929927409600297")

    response = @gateway.store(credit_card, @options.merge(partner_id: fixtures(:culqi)[:partner_id]))
    assert_success response
    assert_match %r{Card tokenized successfully}, response.message

    purchase = @gateway.purchase(@amount, response.authorization, @options.merge(cvv: credit_card.verification_value))
    assert_success purchase
    assert_match %r{Successful}, purchase.message

    response = @gateway.invalidate(response.authorization, @options.merge(partner_id: fixtures(:culqi)[:partner_id]))
    assert_success response
    assert_match %r{Token invalidated successfully}, response.message
  end

  def test_failed_store
    credit_card = credit_card("4929927409600297")

    store = @gateway.store(credit_card, @options.merge(partner_id: fixtures(:culqi)[:partner_id]))
    assert_success store
    assert_match %r{Card tokenized successfully}, store.message

    response = @gateway.store(credit_card, @options.merge(partner_id: fixtures(:culqi)[:partner_id]))
    assert_failure response
    assert_match %r{Card already tokenized for same merchant}, response.message

    response = @gateway.invalidate(store.authorization, @options.merge(partner_id: fixtures(:culqi)[:partner_id]))
    assert_success response
    assert_match %r{Token invalidated successfully}, response.message
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?

    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    clean_transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, clean_transcript)
    assert_scrubbed(@credit_card.verification_value.to_s, clean_transcript)
    assert_scrubbed(@gateway.options[:secret_key], clean_transcript)
  end
end
