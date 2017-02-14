require 'test_helper'

class RemoteKushkiTest < Test::Unit::TestCase
  def setup
    @gateway = KushkiGateway.new(fixtures(:kushki))
    @amount = 100
    @credit_card = credit_card('4000100011112224', verification_value: "777")
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
      currency: "USD",
      amount: {
        subtotal_iva_0: "4.95",
        subtotal_iva: "10",
        iva: "1.54",
        ice: "3.50"
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
        subtotal_iva: "200"
      }
    }

    response = @gateway.purchase(@amount, @declined_card, options)
    assert_failure response
    assert_equal 'Monto de la transacción es diferente al monto de la venta inicial', response.message
  end

  def test_successful_void
    options = {
      amount: {
        subtotal_iva_0: "4.95",
        subtotal_iva: "10",
        iva: "1.54",
        ice: "3.50"
      }
    }
    amount = 100 * (
      options[:amount][:subtotal_iva_0].to_f +
      options[:amount][:subtotal_iva].to_f +
      options[:amount][:iva].to_f +
      options[:amount][:ice].to_f
    )

    purchase = @gateway.purchase(amount, @credit_card, options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization, options)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    purchase = @gateway.purchase(@amount, @credit_card)
    assert_success purchase

    response = @gateway.void(purchase.authorization)
    assert_failure response
    assert_equal 'El monto es zero', response.message
  end

  def test_invalid_login
    gateway = KushkiGateway.new(public_merchant_id: '', private_merchant_id: '')

    response = gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_match %r{ID de comercio no válido}, response.message
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
