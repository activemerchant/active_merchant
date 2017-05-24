require 'test_helper'

class RemoteWepayTest < Test::Unit::TestCase
  def setup
    @gateway = WepayGateway.new(fixtures(:wepay))

    @amount = 2000
    @credit_card = credit_card('5496198584584769')
    @declined_card = credit_card('')

    @options = {
      billing_address: address,
      email: "test@example.com"
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_successful_purchase_with_token
    store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
  end

  def test_successful_purchase_sans_cvv
    @options[:recurring] = true
    store = @gateway.store(@credit_card, @options)
    assert_success store

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
  end

  def test_successful_purchase_with_few_options
    options = { address: { zip: "27701" }, email: "test@example.com" }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase_sans_ccv
    @credit_card.verification_value = nil
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_failed_purchase_with_token
    response = @gateway.purchase(@amount, "12345", @options)
    assert_failure response
  end

  def test_successful_purchase_with_fee
    response = @gateway.purchase(@amount, @credit_card, @options.merge(application_fee: 3, fee_payer: "payee"))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_unique_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(unique_id: generate_unique_id))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_ip_and_risk_token
    response = @gateway.purchase(@amount, @credit_card, @options.merge(ip: "100.166.99.123", risk_token: "123e4567-e89b-12d3-a456-426655440000"))
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end
  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    sleep 30 # Wait for purchase to clear. Doesn't always work.
    response = @gateway.refund(@amount - 100, purchase.authorization)
    assert_success response
  end

  def test_successful_full_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    sleep 30 # Wait for purchase to clear. Doesn't always work.
    response = @gateway.refund(@amount, purchase.authorization)
    assert_success response
  end

  def test_failed_capture
    response = @gateway.capture(nil, '123')
    assert_failure response
  end

  def test_failed_void
    response = @gateway.void('123')
    assert_failure response
  end

  def test_authorize_and_capture
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    sleep 30  # Wait for authorization to clear. Doesn't always work.
    assert capture = @gateway.capture(nil, authorize.authorization)
    assert_success capture
  end

  def test_authorize_and_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization, cancel_reason: "Cancel")
    assert_success void
  end

  def test_invalid_login
    gateway = WepayGateway.new(
      client_id: 12515,
      account_id: 'abc',
      access_token: 'def'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:access_token], transcript)
  end
end
