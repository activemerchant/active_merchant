require 'test_helper'

class RemotePagarmeTest < Test::Unit::TestCase
  def setup
    @gateway = PagarmeGateway.new(fixtures(:pagarme))

    @amount = 1000

    @credit_card = credit_card('4242424242424242', {
      first_name: 'Richard',
      last_name: 'Deschamps'
    })

    @declined_card = credit_card('4242424242424242', {
      first_name: 'Richard',
      last_name: 'Deschamps',
      :verification_value => '688'
    })

    @options = {
      billing_address: address(),
      description: 'ActiveMerchant Teste de Compra'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transação aprovada', response.message

    # Assert metadata
    assert_equal response.params["metadata"]["description"], @options[:description]
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      customer: 'Richard Deschamps',
      invoice: '1',
      merchant: 'Richard\'s',
      description: 'ActiveMerchant Teste de Compra',
      email: 'suporte@pagar.me',
      billing_address: address()
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Transação aprovada', response.message

    # Assert metadata
    assert_equal response.params["metadata"]["order_id"], options[:order_id]
    assert_equal response.params["metadata"]["ip"], options[:ip]
    assert_equal response.params["metadata"]["customer"], options[:customer]
    assert_equal response.params["metadata"]["invoice"], options[:invoice]
    assert_equal response.params["metadata"]["merchant"], options[:merchant]
    assert_equal response.params["metadata"]["description"], options[:description]
    assert_equal response.params["metadata"]["email"], options[:email]
  end

  def test_successful_purchase_without_options
    response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Transação aprovada', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transação recusada', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert_equal 'Transação autorizada', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Transação aprovada', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transação recusada', response.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, nil)
    assert_failure response
    assert_equal 'Não é possível capturar uma transação sem uma prévia autorização.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Transação estornada', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, nil)
    assert_failure response
    assert_equal 'Não é possível estornar uma transação sem uma prévia captura.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Transação estornada', void.message
  end

  def test_failed_void
    response = @gateway.void(nil)
    assert_failure response
    assert_equal 'Não é possível estornar uma transação autorizada sem uma prévia autorização.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Transação autorizada', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal 'Transação recusada', response.message
  end

  def test_invalid_login
    gateway = PagarmeGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{401 Authorization Required}, response.message
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
