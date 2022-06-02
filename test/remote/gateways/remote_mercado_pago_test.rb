require 'test_helper'

class RemoteMercadoPagoTest < Test::Unit::TestCase
  def setup
    @gateway = MercadoPagoGateway.new(fixtures(:mercado_pago))
    @argentina_gateway = MercadoPagoGateway.new(fixtures(:mercado_pago_argentina))

    @amount = 500
    @credit_card = credit_card('4509953566233704')
    @elo_credit_card = credit_card('5067268650517446',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737'
    )
    @cabal_credit_card = credit_card('6035227716427021',
      :month => 10,
      :year => 2020,
      :first_name => 'John',
      :last_name => 'Smith',
      :verification_value => '737'
    )
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      shipping_address: address,
      email: 'user+br@example.com',
      description: 'Store Purchase'
    }
    @processing_options = {
      binary_mode: false,
      processing_mode: 'gateway',
      merchant_account_id: fixtures(:mercado_pago)[:merchant_account_id],
      fraud_scoring: true,
      fraud_manual_review: true
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'accredited', response.message
  end

  def test_successful_purchase_with_elo
    response = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success response
    assert_equal 'accredited', response.message
  end

  def test_successful_purchase_with_cabal
    response = @argentina_gateway.purchase(@amount, @cabal_credit_card, @options)
    assert_success response
    assert_equal 'accredited', response.message
  end

  def test_successful_purchase_with_binary_false
    @options.update(binary_mode: false)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'pending_capture', response.message
  end

  # Requires setup on merchant account
  def test_successful_purchase_with_processing_mode_gateway
    response = @gateway.purchase(@amount, @credit_card, @options.merge(@processing_options))
    assert_success response
    assert_equal 'accredited', response.message
  end

  def test_successful_purchase_with_american_express
    amex_card = credit_card('375365153556885', brand: 'american_express', verification_value: '1234')

    response = @gateway.purchase(@amount, amex_card, @options)
    assert_success response
    assert_equal 'accredited', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'rejected', response.error_code
    assert_equal 'cc_rejected_other_reason', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'pending_capture', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'accredited', capture.message
  end

  def test_successful_authorize_and_capture_with_elo
    auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_success auth
    assert_equal 'pending_capture', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'accredited', capture.message
  end

  def test_successful_authorize_and_capture_with_cabal
    auth = @argentina_gateway.authorize(@amount, @cabal_credit_card, @options)
    assert_success auth
    assert_equal 'pending_capture', auth.message

    assert capture = @argentina_gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'accredited', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'cc_rejected_other_reason', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount+1, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'accredited', capture.message
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'json_parse_error', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal nil, refund.message
  end

  def test_successful_refund_with_elo
    purchase = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal nil, refund.message
  end

  def test_successful_refund_with_cabal
    purchase = @argentina_gateway.purchase(@amount, @cabal_credit_card, @options)
    assert_success purchase

    assert refund = @argentina_gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal nil, refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'Not Found', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'by_collector', void.message
  end

  def test_successful_void_with_elo
    auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'by_collector', void.message
  end

  def test_successful_void_with_cabal
    auth = @argentina_gateway.authorize(@amount, @cabal_credit_card, @options)
    assert_success auth

    assert void = @argentina_gateway.void(auth.authorization)
    assert_success void
    assert_equal 'by_collector', void.message
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'json_parse_error', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{pending_capture}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{cc_rejected_other_reason}, response.message
  end

  def test_invalid_login
    gateway = MercadoPagoGateway.new(access_token: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid access parameters}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:access_token], transcript)
  end

end
