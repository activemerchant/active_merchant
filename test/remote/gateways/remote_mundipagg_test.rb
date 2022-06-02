require 'test_helper'

class RemoteMundipaggTest < Test::Unit::TestCase
  def setup
    @gateway = MundipaggGateway.new(fixtures(:mundipagg))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @sodexo_voucher = credit_card('6060704495764400', brand: 'sodexo')

    # Mundipagg only allows certain card numbers for success and failure scenarios.
    # As such, we cannot use card numbers with BINs belonging to VR or Alelo.
    # See https://docs.mundipagg.com/docs/simulador-de-voucher.
    @vr_voucher = credit_card('4000000000000010', brand: 'vr')
    @alelo_voucher = credit_card('4000000000000010', brand: 'alelo')
    @declined_alelo_voucher = credit_card('4000000000000028', brand: 'alelo')

    @options = {
      gateway_affiliation_id: fixtures(:mundipagg)[:gateway_affiliation_id],
      billing_address: address({neighborhood: 'Sesame Street'}),
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    test_successful_purchase_with(@credit_card)
  end

  def test_successful_purchase_with_alelo_card
    test_successful_purchase_with(@alelo_voucher)
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
    test_failed_purchase_with(@declined_card)
  end

  def test_failed_purchase_with_alelo_card
    test_failed_purchase_with(@declined_alelo_voucher)
  end

  def test_successful_authorize_and_capture
    test_successful_authorize_and_capture_with(@credit_card)
  end

  def test_successful_authorize_and_capture_with_alelo_card
    test_successful_authorize_and_capture_with(@alelo_voucher)
  end

  def test_failed_authorize
    test_failed_authorize_with(@declined_card)
  end

  def test_failed_authorize_with_alelo_card
    test_failed_authorize_with(@declined_alelo_voucher)
  end

  def test_partial_capture
    test_partial_capture_with(@credit_card)
  end

  def test_partial_capture_with_alelo_card
    test_partial_capture_with(@alelo_voucher)
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'abc')
    assert_failure response
    assert_equal 'The requested resource does not exist; Charge not found.', response.message
  end

  def test_successful_refund
    test_successful_refund_with(@credit_card)
  end

  def test_successful_refund_with_alelo_card
    test_successful_refund_with(@alelo_voucher)
  end

  def test_partial_refund
    test_partial_refund_with(@credit_card)
  end

  def test_partial_refund_with_alelo_card
    test_partial_refund_with(@alelo_voucher)
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 'abc')
    assert_failure response
    assert_equal 'The requested resource does not exist; Charge not found.', response.message
  end

  def test_successful_void
    test_successful_void_with(@credit_card)
  end

  def test_successful_void_with_alelo_card
    test_successful_void_with(@alelo_voucher)
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
    test_successful_verify_with(@credit_card)
  end

  def test_successful_verify_with_alelo_card
    test_successful_verify_with(@alelo_voucher)
  end

  def test_successful_store_and_purchase
    test_successful_store_and_purchase_with(@credit_card)
  end

  def test_successful_store_and_purchase_with_alelo_card
    test_successful_store_and_purchase_with(@alelo_voucher)
  end

  def test_invalid_login
    gateway = MundipaggGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid API key; Authorization has been denied for this request.}, response.message
  end

  def test_gateway_id_fallback
    gateway = MundipaggGateway.new(api_key: fixtures(:mundipagg)[:api_key], gateway_id: fixtures(:mundipagg)[:gateway_id])
    options = {
      billing_address: address({neighborhood: 'Sesame Street'}),
      description: 'Store Purchase'
    }
    response = gateway.purchase(@amount, @credit_card, options)
    assert_success response
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

  private

  def test_successful_purchase_with(card)
    response = @gateway.purchase(@amount, card, @options)
    assert_success response
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', response.message
  end

  def test_failed_purchase_with(card)
    response = @gateway.purchase(105200, card, @options)
    assert_failure response
    assert_equal 'Simulator|Transação de simulada negada por falta de crédito, utilizado para realizar simulação de autorização parcial.', response.message
  end

  def test_successful_authorize_and_capture_with(card)
    auth = @gateway.authorize(@amount, card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Simulator|Transação de simulação capturada com sucesso', capture.message
  end

  def test_failed_authorize_with(card)
    response = @gateway.authorize(105200, card, @options)
    assert_failure response
    assert_equal 'Simulator|Transação de simulada negada por falta de crédito, utilizado para realizar simulação de autorização parcial.', response.message
  end

  def test_partial_capture_with(card)
    auth = @gateway.authorize(@amount, card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_successful_refund_with(card)
    purchase = @gateway.purchase(@amount, card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund_with(card)
    purchase = @gateway.purchase(@amount, card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_successful_void_with(card)
    auth = @gateway.authorize(@amount, card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_verify_with(card)
    response = @gateway.verify(card, @options)
    assert_success response
    assert_match %r{Simulator|Transação de simulação autorizada com sucesso}, response.message
  end

  def test_successful_store_and_purchase_with(card)
    store = @gateway.store(card, @options)
    assert_success store

    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', purchase.message
  end
end
