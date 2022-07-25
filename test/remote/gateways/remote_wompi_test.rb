require 'test_helper'

class RemoteWompiTest < Test::Unit::TestCase
  def setup
    @gateway = WompiGateway.new(fixtures(:wompi))

    @amount = 150000
    @credit_card = credit_card('4242424242424242')
    @credit_card_without_cvv = credit_card('4242424242424242', verification_value: nil)
    @declined_card = credit_card('4111111111111111')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      currency: 'COP'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_more_options
    reference = SecureRandom.alphanumeric(12)
    response = @gateway.purchase(@amount, @credit_card, @options.merge(reference: reference, installments: 3))
    assert_success response
    response_data = response.params['data']
    assert_equal response_data.dig('reference'), reference
    assert_equal response_data.dig('payment_method', 'installments'), 3
  end

  def test_successful_purchase_without_cvv
    response = @gateway.purchase(@amount, @credit_card_without_cvv, @options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'La transacción fue rechazada (Sandbox)', response.message
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
  end

  def test_successful_auth_capture_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert void = @gateway.void(capture.authorization)
    assert_success void
  end

  def test_failed_capture
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_success response

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_failure capture
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  # def test_partial_refund
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase

  #   assert refund = @gateway.refund(@amount - 1, purchase.authorization)
  #   assert_success refund
  # end

  # def test_failed_refund
  #   response = @gateway.refund(@amount, '')
  #   assert_failure response
  #   message = JSON.parse(response.message)
  #   assert_equal 'transaction_id Debe ser completado', message['transaction_id'].first
  # end

  def test_successful_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('bad_auth')
    assert_failure response
    assert_equal 'La entidad solicitada no existe', response.message
  end

  def test_invalid_login
    gateway = WompiGateway.new(test_public_key: 'weet', test_private_key: 'woo')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{La llave proporcionada no corresponde a este ambiente}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:test_private_key], transcript)
  end
end
