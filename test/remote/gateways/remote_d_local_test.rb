require 'test_helper'

class RemoteDLocalTest < Test::Unit::TestCase
  def setup
    @gateway = DLocalGateway.new(fixtures(:d_local))

    @amount = 1000
    @credit_card = credit_card('4111111111111111')
    @credit_card_naranja = credit_card('5895627823453005')
    @cabal_credit_card = credit_card('5896 5700 0000 0004')
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
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_ip_and_phone
    response = @gateway.purchase(@amount, @credit_card, @options.merge(ip: '127.0.0.1'))
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_save_option
    response = @gateway.purchase(@amount, @credit_card, @options.merge(save: true))
    assert_success response
    assert_equal true, response.params['card']['save']
    assert_equal 'CREDIT', response.params['card']['type']
    assert_not_empty response.params['card']['card_id']
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_network_tokens
    credit_card = network_tokenization_credit_card('4242424242424242', payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    response = @gateway.purchase(@amount, credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_network_tokens_and_store_credential_type
    options = @options.merge!(stored_credential: stored_credential(:merchant, :recurring, id: 'abc123'))
    credit_card = network_tokenization_credit_card('4242424242424242', payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    response = @gateway.purchase(@amount, credit_card, options)
    assert_success response
    assert_match 'SUBSCRIPTION', response.params['card']['stored_credential_type']
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_network_tokens_and_store_credential_usage
    options = @options.merge!(stored_credential: stored_credential(:merchant, :recurring, id: 'abc123'))
    credit_card = network_tokenization_credit_card('4242424242424242', payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA=')
    response = @gateway.purchase(@amount, credit_card, options)
    assert_success response
    assert_match 'USED', response.params['card']['stored_credential_usage']
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_installments
    response = @gateway.purchase(@amount * 50, @credit_card, @options_argentina_installments)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_naranja
    response = @gateway.purchase(@amount * 50, @credit_card_naranja, @options_argentina)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_cabal
    response = @gateway.purchase(@amount, @cabal_credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_inquire_with_payment_id
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message

    authorization = response.params['id']
    response = @gateway.inquire(authorization, @options)
    assert_success response
    assert_match 'PAID', response.params['status']
    assert_match 'The payment was paid.', response.params['status_detail']
  end

  def test_successful_inquire_with_order_id
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_match 'The payment was paid', response.message

    purchase_payment_id = response.params['id']
    order_id = response.params['order_id']

    response = @gateway.inquire(nil, { order_id: order_id })
    check_payment_id = response.params['payment_id']
    assert_success response
    assert_match purchase_payment_id, check_payment_id
  end

  def test_successful_purchase_with_original_order_id
    response = @gateway.purchase(@amount, @credit_card, @options.merge(original_order_id: '123ABC'))
    assert_success response
    assert_match 'The payment was paid', response.message
    assert_match '123ABC', response.params['original_order_id']
  end

  def test_successful_purchase_with_more_options
    options = @options.merge(
      order_id: '1',
      ip: '127.0.0.1',
      device_id: '123',
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

  def test_successful_purchase_with_additional_data
    options = @options.merge(
      additional_data: { submerchant: { name: 'socks' } }
    )
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_with_force_type_debit
    options = @options_argentina.merge(force_type: 'DEBIT')

    response = @gateway.purchase(@amount * 50, @credit_card, options)
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
    response = @gateway.purchase(@amount * 50, @credit_card, @options_argentina)
    assert_success response
    assert_match 'The payment was paid', response.message
  end

  def test_successful_purchase_mexico
    response = @gateway.purchase(@amount, @cabal_credit_card, @options_mexico)
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

  def test_failed_purchase_with_network_tokens
    credit_card = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: 'BwABB4JRdgAAAAAAiFF2AAAAAAA='
    )
    response = @gateway.purchase(@amount, credit_card, @options.merge(description: '300'))
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

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 0, response.params['amount']
    assert_match %r{The payment was verified}, response.message
  end

  def test_successful_verify_with_cabal
    response = @gateway.verify(@cabal_credit_card, @options)
    assert_success response
    assert_equal 0, response.params['amount']
    assert_match %r{The payment was verified}, response.message
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

  def test_successful_authorize_with_3ds_v1_options
    @options[:three_d_secure] = {
      version: '1.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      xid: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y'
    }
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_match 'The payment was authorized', auth.message
  end

  def test_successful_authorize_with_3ds_v2_options
    @options[:three_d_secure] = {
      version: '2.2.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      ds_transaction_id: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'Y',
      authentication_response_status: 'Y'
    }
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_match 'The payment was authorized', auth.message
  end
end
