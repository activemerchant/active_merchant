require 'test_helper'

class RemoteSumUpTest < Test::Unit::TestCase
  def setup
    @gateway = SumUpGateway.new(fixtures(:sum_up_successful_purchase))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('55555555555555555')
    @options = {
      payment_type: 'card',
      billing_address: address,
      description: 'Store Purchase',
      order_id: SecureRandom.uuid
    }
  end

  def test_handle_pay_to_email_credential_error
    gateway = SumUpGateway.new(fixtures(:sum_up).merge(pay_to_email: 'example@example.com'))
    response = gateway.purchase(@amount, @credit_card, @options)

    assert_equal('Validation error', response.message)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'PAID', response.message
    assert_equal @options[:order_id], response.params['checkout_reference']
    refute_empty response.params['id']
    refute_empty response.params['transactions']
    refute_empty response.params['transactions'].first['id']
    assert_equal 'SUCCESSFUL', response.params['transactions'].first['status']
  end

  def test_successful_purchase_with_more_options
    options = {
      email: 'joe@example.com',
      tax_id: '12345',
      redirect_url: 'https://checkout.example.com',
      return_url: 'https://checkout.example.com',
      billing_address: address,
      order_id: SecureRandom.uuid,
      currency: 'USD',
      description: 'Sample description',
      payment_type: 'card'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'PAID', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Validation error', response.message
    assert_equal 'The value located under the \'$.card.number\' path is not a valid card number', response.params['detail']
  end

  def test_failed_purchase_invalid_customer_id
    options = @options.merge!(customer_id: 'customer@example.com', payment_type: 'card')
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'Validation error', response.message
    assert_equal 'customer_id', response.params['param']
  end

  def test_failed_purchase_invalid_currency
    options = @options.merge!(currency: 'EUR')
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_failure response
    assert_equal 'Given currency differs from merchant\'s country currency', response.message
  end

  # In Sum Up the account can only return checkout/purchase in pending or success status,
  # to obtain a successful refund we will need an account that returns the checkout/purchase in successful status
  #
  # For the following refund tests configure in the fixtures => :sum_up_successful_purchase
  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    transaction_id = purchase.params['transaction_id']
    assert_not_nil transaction_id

    response = @gateway.refund(@amount, transaction_id, {})
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_partial_refund
    purchase = @gateway.purchase(@amount * 10, @credit_card, @options)
    transaction_id = purchase.params['transaction_id']
    assert_not_nil transaction_id

    response = @gateway.refund(@amount, transaction_id, {})
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  # In Sum Up to trigger the 3DS flow (next_step object) you need to an European account
  #
  # For this example configure in the fixtures => :sum_up_3ds
  def test_trigger_3ds_flow
    gateway = SumUpGateway.new(fixtures(:sum_up_3ds))
    options = @options.merge(
      currency: 'EUR',
      redirect_url: 'https://mysite.com/completed_purchase'
    )
    purchase = gateway.purchase(@amount, @credit_card, options)
    assert_success purchase
    assert_equal 'Succeeded', purchase.message
    assert_not_nil purchase.params['next_step']
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:pay_to_email], transcript)
  end
end
