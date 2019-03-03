require 'test_helper'

class RemoteDLocalTest < Test::Unit::TestCase
  def setup
    @gateway = DLocalGateway.new(fixtures(:d_local))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    # No test card numbers, all txns are approved by default,
    # but errors can be invoked directly with the `description` field
    @options = {
      billing_address: address(country: 'Brazil'),
      document: '42243309114',
      currency: 'BRL'
    }
    @options_colombia = {
      billing_address: address(country: 'Colombia'),
      document: '11186456',
      currency: 'COP'
    }
    @options_argentina = {
      billing_address: address(country: 'Argentina'),
      document: '10563145',
      currency: 'ARS'
    }
    @options_mexico = {
      billing_address: address(country: 'Mexico'),
      document: '128475869794933',
      currency: 'MXN'
    }
    @options_peru = {
      billing_address: address(country: 'Peru'),
      document: '184853849',
      currency: 'PEN'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge(
      order_id: '1',
      ip: '127.0.0.1',
      email: 'joe@example.com',
      birth_date: '03-01-1970',
      document2: '87648987569',
      idempotency_key: generate_unique_id,
      user_reference: generate_unique_id
    )

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  # You may need dLocal to enable your test account to support individual countries
  def test_successful_purchase_colombia
    response = @gateway.purchase(100000, @credit_card, @options_colombia)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_argentina
    response = @gateway.purchase(@amount, @credit_card, @options_argentina)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_mexico
    response = @gateway.purchase(@amount, @credit_card, @options_mexico)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_peru
    response = @gateway.purchase(@amount, @credit_card, @options_peru)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, @options.merge(description: '300'))
    assert_failure response
    assert_match 'The payment was rejected', response.message
  end

  def test_failed_document_format
    response = @gateway.purchase(@amount, @credit_card, @options.merge(document: 'bad_document'))
    assert_failure response
    assert_match 'Invalid parameter: payer.document', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_match 'The payment was authorized', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_match 'The payment was paid', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @credit_card, @options.merge(description: '309'))
    assert_failure response
    assert_equal '309', response.error_code
    assert_match 'Card expired', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization, @options)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 'bad_id')
    assert_failure response

    assert_equal '4000', response.error_code
    assert_match 'Payment not found', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options.merge(notification_url: 'http://example.com'))
    assert_success refund
    assert_match 'The refund was paid', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options.merge(notification_url: 'http://example.com'))
    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.refund(@amount+1, purchase.authorization, @options.merge(notification_url: 'http://example.com'))
    assert_failure response
    assert_match 'Amount exceeded', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_match 'The payment was cancelled', void.message
  end

  def test_failed_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture

    response = @gateway.void(auth.authorization)
    assert_failure response
    assert_match 'Invalid transaction status', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{The payment was authorized}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@credit_card, @options.merge(description: '315'))
    assert_failure response
    assert_equal '315', response.error_code
    assert_match %r{Invalid security code}, response.message
  end

  def test_invalid_login
    gateway = DLocalGateway.new(login: '', trans_key: '', secret_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid parameter}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:trans_key], transcript)
  end

end
