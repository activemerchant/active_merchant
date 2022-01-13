require 'test_helper'

class RemoteDLocalTest < Test::Unit::TestCase
  def setup
    @gateway = DLocalGateway.new(fixtures(:d_local))

    @amount = 200
    @credit_card = credit_card('4111111111111111')
    @credit_card_naranja = credit_card('5895627823453005')
    @cabal_credit_card = credit_card('5896 5700 0000 0004')
    @wallet_token = wallet_token()
    # No test card numbers, all txns are approved by default,
    # but errors can be invoked directly with the `description` field
    @options = {
      billing_address: address(country: 'Brazil'),
      document: '71575743221',
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
    @options_argentina_installments = {
      billing_address: address(country: 'Argentina'),
      document: '10563145',
      currency: 'ARS',
      installments: '3',
      installments_id: 'INS54434'
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
    @card_save_options = {
      billing_address: address(country: 'Brazil'),
      document: '71575743221',
      currency: 'BRL',
      save_card: true
    }
    @offsite_payment_options = {
      billing_address: address(country: 'Indonesia'),
      document: '1234567890123456',
      currency: 'IDR',
      label: 'Test payment',
      payment_method_id: 'XW',
      payment_method_flow: 'REDIRECT',
      callback_url: 'https://example.com/callback',
      notification_url: 'https://example.com/notify'
    }
    @offsite_payment_options_india = {
      billing_address: address(country: 'India'),
      document: 'ABCDE1111N',
      currency: 'INR',
      label: 'Test payment',
      payment_method_id: 'PW',
      payment_method_flow: 'REDIRECT',
      callback_url: 'https://example.com/callback',
      notification_url: 'https://example.com/notify'
    }
    @offsite_payment_options_mexico = {
      billing_address: address(country: 'Mexico'),
      document: '42243309114',
      currency: 'MXN',
      label: 'Test payment',
      payment_method_id: 'SE',
      payment_method_flow: 'REDIRECT',
      callback_url: 'https://example.com/callback',
      notification_url: 'https://example.com/notify'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_device_id_and_ip
    options = @options.merge({customer_ip: "127.0.0.1", device_id: "test_device"})
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_card_save
    response = @gateway.verify(@credit_card, @card_save_options)
    assert_success response.primary_response
    assert_match 'The payment was authorized', response.message
    assert response.primary_response.params["card"].key?("card_id")
  end

  def test_successful_offsite_payment_initiation
    order_id = SecureRandom.hex(16)
    @offsite_payment_options.update(
      :order_id => order_id
    )
    response = @gateway.initiate(@amount, @wallet_token, @offsite_payment_options)
    assert_success response
    assert_match 'The payment is pending', response.message
    assert_match order_id, response.params["order_id"]
    assert response.params["redirect_url"] != nil
  end

  def test_successful_offsite_payment_initiation_paytm_india
    order_id = SecureRandom.hex(16)
    @offsite_payment_options_india.update(
      :order_id => order_id
    )
    response = @gateway.initiate(@amount, @wallet_token, @offsite_payment_options_india)
    assert_success response
    assert_match 'The payment is pending', response.message
    assert_match order_id, response.params["order_id"]
    assert response.params["redirect_url"] != nil
  end

  def test_successful_token_payment
    response = @gateway.verify(@credit_card, @card_save_options)
    assert_success response.primary_response
    assert_match 'The payment was authorized', response.message

    token = response.primary_response.params['card']['card_id']
    token_payment = psp_tokenized_card(token)
    response = @gateway.purchase(@amount, token_payment, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_installments
    response = @gateway.purchase(@amount, @credit_card, @options_argentina_installments)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_naranja
    response = @gateway.purchase(@amount, @credit_card_naranja, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_cabal
    response = @gateway.purchase(@amount, @cabal_credit_card, @options)
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

  def test_successful_purchase_partial_address
    response = @gateway.purchase(@amount, @credit_card, @options.merge(billing_address: address(address1: 'My Street', country: 'Brazil')))
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, @options.merge(description: '300'))
    assert_failure response
    assert_match 'The payment was rejected', response.message
  end

  def test_failed_card_save
    response = @gateway.verify(@credit_card, @card_save_options.merge(description: '300'))
    assert_failure response.primary_response
    assert_match 'The payment was rejected', response.message
  end

  def test_failed_token_payment
    response = @gateway.verify(@credit_card, @card_save_options)
    assert_success response.primary_response
    assert_match 'The payment was authorized', response.message

    token = response.primary_response.params['card']['card_id']
    token_payment = psp_tokenized_card(token)
    response = @gateway.purchase(@amount, token_payment, @options.merge(description: '300'))
    assert_failure response
    assert_match 'The payment was rejected', response.message
  end

  def test_failed_document_format
    response = @gateway.purchase(@amount, @credit_card, @options.merge(document: 'bad_document'))
    assert_failure response
    assert_match 'Invalid parameter: payer.document', response.message
  end

  def test_failed_offsite_invalid_document
    response = @gateway.initiate(@amount, @wallet_token, @offsite_payment_options.merge(document: 'bad_document'))
    assert_failure response
    assert_match 'Invalid parameter: payer.document', response.message
  end

  def test_failed_offsite_verify_with_nonzero_amount
    response = @gateway.initiate(@amount, @wallet_token, @offsite_payment_options.merge(verify: true))
    assert_failure response
    assert_match 'Invalid parameter: wallet.verify', response.message
  end

  def test_offsite_payment_when_address_empty_and_country_india_then_failed
    response = @gateway.initiate(@amount, @wallet_token, @offsite_payment_options_india.update(billing_address: {'country': 'IN'}))
    assert_failure response
    assert_match 'Missing parameter: payer.address', response.message
  end

  def test_failed_offsite_save_with_0_payment
    response = @gateway.initiate(0, @wallet_token, @offsite_payment_options.merge(save: true))
    assert_failure response
    assert_match 'Amount too low', response.message
  end

  def test_offsite_payment_mexico_SE_REDIRECT
    response = @gateway.initiate(100, nil, @offsite_payment_options_mexico)
    assert_success response
    assert_match 'The payment is pending.', response.message
    assert_equal '100', response.params["status_code"]
    assert response.params["redirect_url"].present?
    assert response.authorization.present?
  end

  def test_offsite_payment_mexico_OX_REDIRECT
    response = @gateway.initiate(100, nil, @offsite_payment_options_mexico.update({payment_method_id: 'OX'}))
    assert_success response
    assert_match 'The payment is pending.', response.message
    assert_equal '100', response.params["status_code"]
    assert response.params["redirect_url"].present?
    assert response.authorization.present?
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_match 'The payment was authorized', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_match 'The payment was paid', capture.message
  end

  def test_successful_authorize_and_capture_with_cabal
    auth = @gateway.authorize(@amount, @cabal_credit_card, @options)
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

    assert capture = @gateway.capture(@amount - 1, auth.authorization, @options)
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

    assert refund = @gateway.refund(@amount - 1, purchase.authorization, @options.merge(notification_url: 'http://example.com'))
    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.refund(@amount + 100, purchase.authorization, @options.merge(notification_url: 'http://example.com'))
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
    response = @gateway.void('')
    assert_failure response
    assert_match 'Invalid request', response.message
  end

  def test_successful_verify_credentials
    response = @gateway.verify_credentials()
    assert_success response
    assert_match "OK", response.message
  end

  def test_failed_verify_credentials
    gateway = DLocalGateway.new(login: 'dssdfsdf', trans_key: 'sdfsdf', secret_key: 'sdfsdf')
    response = gateway.verify_credentials()
    assert_match '3001', response.error_code
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{The payment was authorized}, response.message
  end

  def test_successful_verify_with_cabal
    response = @gateway.verify(@cabal_credit_card, @options)
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
