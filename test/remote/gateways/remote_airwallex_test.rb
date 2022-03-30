require 'test_helper'

class RemoteAirwallexTest < Test::Unit::TestCase
  def setup
    @gateway = AirwallexGateway.new(fixtures(:airwallex))

    # https://www.airwallex.com/docs/online-payments__test-card-numbers
    @amount = 100
    @declined_amount = 8014
    @credit_card = credit_card('4111 1111 1111 1111')
    @declined_card = credit_card('2223 0000 1018 1375')
    @options = { return_url: 'https://example.com' }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_purchase_with_more_options
    response = @gateway.purchase(@amount, @credit_card, @options.merge(address))
    assert_success response
    assert_equal 'AUTHORIZED', response.message
  end

  def test_successful_purchase_with_specified_ids
    request_id = "request_#{(Time.now.to_f.round(2) * 100).to_i}"
    merchant_order_id = "order_#{(Time.now.to_f.round(2) * 100).to_i}"
    response = @gateway.purchase(@amount, @credit_card, @options.merge(request_id: request_id, merchant_order_id: merchant_order_id))
    assert_success response
    assert_match(/request_/, response.params.dig('request_id'))
    assert_match(/order_/, response.params.dig('merchant_order_id'))
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The card issuer declined this transaction. Please refer to the original response code.', response.message
    assert_equal '14', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal 'CAPTURE_REQUESTED', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @declined_card, @options)
    assert_failure response
    assert_equal 'The card issuer declined this transaction. Please refer to the original response code.', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@declined_amount, '12345', @options)
    assert_failure response
    assert_match(/The requested endpoint does not exist/, response.message)
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options.merge(generated_ids))
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options.merge(generated_ids))
    assert_success refund
    assert_equal 'RECEIVED', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@declined_amount, '12345', @options)
    assert_failure response
    assert_match(/The PaymentIntent with ID 12345 cannot be found./, response.message)
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(generated_ids))
    assert_success auth

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal 'CANCELLED', void.message
  end

  def test_failed_void
    response = @gateway.void('12345', @options)
    assert_failure response
    assert_match(/The requested endpoint does not exist/, response.message)
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{AUTHORIZED}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(credit_card('1111111111111111'), @options)
    assert_failure response
    assert_match %r{Invalid card number}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:client_api_key], transcript)
  end

  private

  def generated_ids
    timestamp = (Time.now.to_f.round(2) * 100).to_i.to_s
    { request_id: timestamp.to_s, merchant_order_id: "mid_#{timestamp}" }
  end
end
