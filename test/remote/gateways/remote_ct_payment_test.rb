require 'test_helper'

class RemoteCtPaymentTest < Test::Unit::TestCase
  def setup
    @gateway = CtPaymentGateway.new(fixtures(:ct_payment))

    @amount = 100
    @credit_card = credit_card('4501161107217214', month: '07', year: 2020)
    @declined_card = credit_card('4502244713161718')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      order_id: generate_unique_id[0, 11],
      email: 'bigbird@sesamestreet.com'

    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction declined', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge(order_id: generate_unique_id[0, 11]))
    assert_success capture
    assert_equal 'APPROVED', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Transaction declined', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization, @options.merge(order_id: generate_unique_id[0, 11]))
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '0123456789asd;0123456789asdf;12345678', @options)
    assert_failure response
    assert_equal 'The original transaction number does not match any actual transaction', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, @options.merge(order_id: generate_unique_id[0, 11]))
    assert_success refund
    assert_equal 'APPROVED', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, @options.merge(order_id: generate_unique_id[0, 11]))
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '0123456789asd;0123456789asdf;12345678', @options.merge(order_id: generate_unique_id[0, 11]))
    assert_failure response
    assert_equal 'The original transaction number does not match any actual transaction', response.message
  end

  def test_successful_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
    assert_equal 'APPROVED', void.message
  end

  def test_failed_void
    response = @gateway.void('0123456789asd;0123456789asdf;12345678')
    assert_failure response
    assert_equal 'The original transaction number does not match any actual transaction', response.message
  end

  def test_successful_credit
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_successful_store
    assert response = @gateway.store(@credit_card, @options)

    assert_success response
    assert !response.authorization.split(';')[3].nil?
  end

  def test_successful_purchase_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.purchase(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_successful_authorize_using_stored_card
    assert store_response = @gateway.store(@credit_card, @options)
    assert_success store_response

    response = @gateway.authorize(@amount, store_response.authorization, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{APPROVED}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Transaction declined}, response.message
  end

  def test_invalid_login
    gateway = CtPaymentGateway.new(api_key: '', company_number: '12345', merchant_number: '12345')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid API KEY}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(Base64.strict_encode64(@credit_card.number), transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

  def test_transcript_scrubbing_store
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(Base64.strict_encode64(@credit_card.number), transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

end
