require 'test_helper'

class RemoteStoneTest < Test::Unit::TestCase
  def setup
    @gateway = StoneGateway.new(fixtures(:stone))

    @credit_card = credit_card('4000100011112224')

    @amount = 10000
    @declined_amount = 150100
    @timeout_amount = 105050

    @options = {
      order_id: '123123'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transação de simulação autorizada com sucesso', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Transação de simulação não autorizada', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.params)
    assert_success capture
    assert_equal 'Transação de simulação capturada com sucesso', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Transação de simulação não autorizada', response.message
  end

  def test_failed_capture
    captured = @gateway.purchase(@amount, @credit_card, @options)

    response = @gateway.capture(@amount, captured.params)
    assert_failure response
    assert_equal 'Erro no processamento.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.params)
    assert_success refund
    assert_equal 'Transação de simulação cancelada com sucesso', refund.message
  end

  def test_failed_refund
    auth = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure auth

    response = @gateway.refund(@declined_amount, auth.params)
    assert_failure response
    assert_equal 'Erro no processamento.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(@amount, auth.params)
    assert_success void
    assert_equal 'Transação de simulação cancelada com sucesso', void.message
  end

  def test_failed_void
    auth = @gateway.authorize(@declined_amount, @credit_card, @options)
    assert_failure auth

    response = @gateway.void(@declined_amount, auth.params)
    assert_failure response
    assert_equal 'Erro no processamento.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'Transação de simulação autorizada com sucesso', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@credit_card, @options.merge({money: @declined_amount}))
    assert_failure response
    assert_match 'Transação de simulação não autorizada', response.message
  end

  def test_invalid_login
    gateway = StoneGateway.new(merchant_key: 'Fake Key')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Failed with 401 Unauthorized', response.message
  end

  def test_transcript_scrubbing
    @credit_card.verification_value = '9999'
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:merchant_key], transcript)
  end

end