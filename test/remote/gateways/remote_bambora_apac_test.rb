require 'test_helper'

class RemoteBamboraApacTest < Test::Unit::TestCase
  def setup
    @gateway = BamboraApacGateway.new(fixtures(:bambora_apac))

    @credit_card = credit_card('4005550000000001')

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(200, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(200, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(105, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(200, @credit_card, @options)
    assert_success response
    response = @gateway.capture(200, response.authorization)
    assert_success response
  end

  def test_failed_authorize
    response = @gateway.authorize(105, @credit_card, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(200, '')
    assert_failure response
  end

  def test_successful_refund
    response = @gateway.purchase(200, @credit_card, @options)
    response = @gateway.refund(200, response.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_refund
    response = @gateway.purchase(200, @credit_card, @options)
    response = @gateway.refund(105, response.authorization, @options)
    assert_failure response
    assert_equal 'Do Not Honour', response.message
  end

  def test_successful_void
    response = @gateway.purchase(200, @credit_card, @options)
    assert_success response
    response = @gateway.void(200, response.authorization)
    assert_success response
  end

  def test_failed_void
    response = @gateway.purchase(200, @credit_card, @options)
    assert_success response
    response = @gateway.void(200, 123)
    assert_failure response
    assert_equal 'Cannot find matching transaction to VOID', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_failed_store
    bad_credit_card = credit_card(nil)

    response = @gateway.store(bad_credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(500, store_response.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.authorize(500, store_response.authorization, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_invalid_login
    gateway = BamboraApacGateway.new(
      username: '',
      password: ''
    )
    response = gateway.purchase(200, @credit_card, @options)
    assert_failure response
  end
end
