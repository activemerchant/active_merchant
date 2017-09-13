require 'test_helper'

class RemoteEbanxTest < Test::Unit::TestCase
  def setup
    @gateway = EbanxGateway.new(fixtures(:ebanx))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4716909774636285')
    @token = network_tokenization_credit_card('4111111111111111',
      source: :ebanx,
      payment_cryptogram: "70d4561db7ef543509d41b5f98f8418c8cd97b718962afd91bc12bebe7f0fd37cb7058a826c3c3840bee8f9333cf7194e8ce351c6607aed650afaad4503c1332"
    )
    @options = {
      billing_address: address({
        address1: '1040 Rua E',
        city: 'Maracanaú',
        state: 'CE',
        zip: '61919-230',
        country: 'BR',
        phone_number: '8522847035'
      }),
      order_id: generate_unique_id,
      document: "853.513.468-93"
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Sandbox - Test credit card, transaction captured', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge({
      order_id: generate_unique_id,
      ip: "127.0.0.1",
      email: "joe@example.com",
      birth_date: "10/11/1980"
    })

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Sandbox - Test credit card, transaction captured', response.message
  end

  def test_successful_purchase_by_token
    response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert_equal 'Sandbox - Test credit card, transaction captured', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Sandbox - Test credit card, transaction declined reason insufficientFunds', response.message
    assert_equal 'NOK', response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Sandbox - Test credit card, transaction will be approved', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Sandbox - Test credit card, transaction captured', capture.message
  end

  def test_successful_authorize_by_token_and_capture
    auth = @gateway.authorize(@amount, @token, @options)
    assert_success auth
    assert_equal 'Sandbox - Test credit card, transaction will be approved', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Sandbox - Test credit card, transaction captured', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Sandbox - Test credit card, transaction declined reason insufficientFunds', response.message
    assert_equal 'NOK', response.error_code
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Parameters hash or merchant_payment_code not informed', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund_options = @options.merge({description: "full refund"})
    assert refund = @gateway.refund(@amount, purchase.authorization, refund_options)
    assert_success refund
    assert_equal 'Sandbox - Test credit card, transaction captured', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund_options = @options.merge(description: "refund due to returned item")
    assert refund = @gateway.refund(@amount-1, purchase.authorization, refund_options)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_match('Parameter hash not informed', response.message)
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Sandbox - Test credit card, transaction cancelled', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'Parameter hash not informed', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Sandbox - Test credit card, transaction will be approved}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Sandbox - Test credit card, transaction declined reason insufficientFunds}, response.message
  end

  def test_invalid_login
    gateway = EbanxGateway.new(integration_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Field integration_key is required}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:integration_key], transcript)
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_failed_store
    response = @gateway.store(credit_card('1111111111111111'), @options)
    assert_failure response
    assert_equal 'Card number is invalid', response.message
    assert_equal 'BP-DR-75', response.error_code
  end

end
