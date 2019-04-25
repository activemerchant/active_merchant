require 'test_helper'

class RemoteMundipaggTest < Test::Unit::TestCase
  def setup
    @gateway = MundipaggGateway.new(fixtures(:mundipagg))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @sodexo_voucher = credit_card('6060704495764400', brand: 'sodexo')
    # Mundipagg only allows certain card numbers for success and failure scenarios.
    # As such, we cannot use a card number with a BIN belonging to VR.
    # See https://docs.mundipagg.com/docs/simulador-de-voucher.
    @vr_voucher = credit_card('4000000000000010', brand: 'vr')
    @options = {
      billing_address: address({neighborhood: 'Sesame Street'}),
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', response.message
  end

  def test_successful_purchase_no_address
    @options.delete(:billing_address)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.update({
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      shipping_address: address
    })

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_successful_purchase_with_sodexo_voucher
    @options.update(holder_document: '93095135270')
    response = @gateway.purchase(@amount, @sodexo_voucher, @options)
    assert_success response
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', response.message
  end

  def test_successful_purchase_with_vr_voucher
    @options.update(holder_document: '93095135270')
    response = @gateway.purchase(@amount, @vr_voucher, @options)
    assert_success response
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(105200, @declined_card, @options)
    assert_failure response
    assert_equal 'Simulator|Transação de simulada negada por falta de crédito, utilizado para realizar simulação de autorização parcial.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Simulator|Transação de simulação capturada com sucesso', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(105200, @declined_card, @options)
    assert_failure response
    assert_equal 'Simulator|Transação de simulada negada por falta de crédito, utilizado para realizar simulação de autorização parcial.', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'abc')
    assert_failure response
    assert_equal 'The requested resource does not exist; Charge not found.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'abc')
    assert_failure response
    assert_equal 'The requested resource does not exist; Charge not found.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_void_with_sodexo_voucher
    @options.update(holder_document: '93095135270')
    auth = @gateway.purchase(@amount, @sodexo_voucher, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_void_with_vr_voucher
    @options.update(holder_document: '93095135270')
    auth = @gateway.purchase(@amount, @vr_voucher, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_refund_with_sodexo_voucher
    @options.update(holder_document: '93095135270')
    auth = @gateway.purchase(@amount, @sodexo_voucher, @options)
    assert_success auth

    assert void = @gateway.refund(1, auth.authorization)
    assert_success void
  end

  def test_successful_refund_with_vr_voucher
    @options.update(holder_document: '93095135270')
    auth = @gateway.purchase(@amount, @vr_voucher, @options)
    assert_success auth

    assert void = @gateway.refund(1, auth.authorization)
    assert_success void
  end

  def test_failed_void
    response = @gateway.void('abc')
    assert_failure response
    assert_equal 'The requested resource does not exist; Charge not found.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Simulator|Transação de simulação autorizada com sucesso}, response.message
  end

  def test_successful_store_and_purchase
    store = @gateway.store(@credit_card, @options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', purchase.message
  end

  def test_invalid_login
    gateway = MundipaggGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid API key; Authorization has been denied for this request.}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end
end
