require 'test_helper'

class RemoteMercadoPagoTest < Test::Unit::TestCase
  def setup
    exp_year = Time.now.year + 1
    @gateway = MercadoPagoGateway.new(fixtures(:mercado_pago))
    @argentina_gateway = MercadoPagoGateway.new(fixtures(:mercado_pago_argentina))
    @colombian_gateway = MercadoPagoGateway.new(fixtures(:mercado_pago_colombia))

    @amount = 500
    @credit_card = credit_card('5031433215406351')
    @colombian_card = credit_card('4013540682746260')
    @elo_credit_card = credit_card('5067268650517446',
      month: 10,
      year: exp_year,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737')
    @cabal_credit_card = credit_card('6035227716427021',
      month: 10,
      year: exp_year,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '737')
    @naranja_credit_card = credit_card('5895627823453005',
      month: 10,
      year: exp_year,
      first_name: 'John',
      last_name: 'Smith',
      verification_value: '123')
    @declined_card = credit_card('5031433215406351',
      first_name: 'OTHE')
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
      fraud_manual_review: true,
      payment_method_option_id: '123abc'
    }
    @payer = {
      entity_type: 'individual',
      type: 'customer',
      identification: {},
      first_name: 'Longbob',
      last_name: 'Longsen'
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

  def test_successful_purchase_with_naranja
    response = @argentina_gateway.purchase(@amount, @naranja_credit_card, @options)
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

  def test_successful_purchase_with_taxes_and_net_amount
    # Minimum transaction amount is 0.30 EUR or ~1112 $COL on 1/27/20.
    # This value must exceed that
    amount = 10000_00

    # These values need to be represented as dollars, so divide them by 100
    tax_amount = amount * 0.19
    @options[:net_amount] = (amount - tax_amount) / 100
    @options[:taxes] = [{ value: tax_amount / 100, type: 'IVA' }]

    response = @colombian_gateway.purchase(amount, @colombian_card, @options)
    assert_success response
    assert_equal 'accredited', response.message
  end

  def test_successful_purchase_with_notification_url
    response = @gateway.purchase(@amount, @credit_card, @options.merge(notification_url: 'https://www.spreedly.com/'))
    assert_success response
    assert_equal 'https://www.spreedly.com/', response.params['notification_url']
  end

  def test_successful_purchase_with_payer
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ payer: @payer }))
    assert_success response
    assert_equal 'accredited', response.message
  end

  def test_successful_purchase_with_metadata_passthrough
    metadata = { 'key_1' => 'value_1',
      'key_2' => 'value_2',
      'key_3' => { 'nested_key_1' => 'value_3' } }
    response = @gateway.purchase(@amount, @credit_card, @options.merge({ metadata: metadata }))
    assert_success response
    assert_equal metadata, response.params['metadata']
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

  def test_successful_authorize_and_capture_with_naranja
    auth = @argentina_gateway.authorize(@amount, @naranja_credit_card, @options)
    assert_success auth
    assert_equal 'pending_capture', auth.message

    assert capture = @argentina_gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'accredited', capture.message
  end

  def test_successful_authorize_with_capture_option
    auth = @gateway.authorize(@amount, @credit_card, @options.merge(capture: true))
    assert_success auth
    assert_equal 'accredited', auth.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'cc_rejected_other_reason', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount + 1, @credit_card, @options)
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

  def test_successful_refund_with_naranja
    purchase = @argentina_gateway.purchase(@amount, @naranja_credit_card, @options)
    assert_success purchase

    assert refund = @argentina_gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal nil, refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
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

  def test_successful_void_with_naranja
    auth = @argentina_gateway.authorize(@amount, @naranja_credit_card, @options)
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

  def test_successful_verify_with_amount
    @options[:amount] = 200
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
