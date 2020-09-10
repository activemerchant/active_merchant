require 'test_helper'

class RemoteKushkiTest < Test::Unit::TestCase
  def setup
    @gateway = KushkiGateway.new(fixtures(:kushki))
    @amount = 100
    @credit_card = credit_card('4000100011112224', verification_value: '777')
    @declined_card = credit_card('4000300011112220')
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_successful_purchase_with_options
    options = {
      currency: 'USD',
      amount: {
        subtotal_iva_0: '4.95',
        subtotal_iva: '10',
        iva: '1.54',
        ice: '3.50'
      }
    }

    amount = 100 * (
      options[:amount][:subtotal_iva_0].to_f +
      options[:amount][:subtotal_iva].to_f +
      options[:amount][:iva].to_f +
      options[:amount][:ice].to_f
    )

    response = @gateway.purchase(amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_failed_purchase
    options = {
      amount: {
        subtotal_iva: '200'
      }
    }

    response = @gateway.purchase(@amount, @declined_card, options)
    assert_failure response
    assert_equal 'Monto de la transacción es diferente al monto de la venta inicial', response.message
  end

  def test_successful_authorize
    # Kushki only allows preauthorization for PEN, CLP, and UF.
    response = @gateway.authorize(@amount, @credit_card, {currency: 'PEN'})
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^\d+$), response.authorization
  end

  def test_failed_authorize
    options = {
      amount: {
        subtotal_iva: '200'
      }
    }
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_failure response
    assert_equal '220', response.responses.last.error_code
    assert_equal 'Monto de la transacción es diferente al monto de la venta inicial', response.message
  end

  def test_successful_capture
    auth = @gateway.authorize(@amount, @credit_card)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_capture
    options = {
      amount: {
        subtotal_iva: '200'
      }
    }
    auth = @gateway.authorize(@amount, @credit_card)
    assert_success auth

    capture = @gateway.capture(@amount, auth.authorization, options)
    assert_failure capture
    assert_equal 'K012', capture.error_code
    assert_equal 'Monto de captura inválido.', capture.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    assert refund = @gateway.refund(@amount, nil)
    assert_failure refund
    assert_equal 'Missing Authentication Token', refund.message
  end

  def test_successful_void
    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    response = @gateway.void('000')
    assert_failure response
    assert_equal 'Cuerpo de la petición inválido.', response.message
  end

  def test_invalid_login
    gateway = KushkiGateway.new(public_merchant_id: '', private_merchant_id: '')

    response = gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_match %r{Unauthorized}, response.message
  end

  def test_transcript_scrubbing
    assert @gateway.supports_scrubbing?

    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:private_merchant_id], transcript)
  end
end
