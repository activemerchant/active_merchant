require 'test_helper'

class RemoteSumUpTest < Test::Unit::TestCase
  def setup
    @gateway = SumUpGateway.new(fixtures(:sum_up))

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

  def test_handle_credentials_error
    gateway = SumUpGateway.new({ access_token: 'sup_sk_xx', pay_to_email: 'example@example.com' })
    response = gateway.purchase(@amount, @visa_card, @options)

    assert_equal('invalid access token', response.message)
  end

  def test_handle_pay_to_email_credential_error
    gateway = SumUpGateway.new(fixtures(:sum_up).merge(pay_to_email: 'example@example.com'))
    response = gateway.purchase(@amount, @visa_card, @options)

    assert_equal('Validation error', response.message)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'PENDING', response.message
    assert_equal @options[:order_id], response.params['checkout_reference']
    refute_empty response.params['id']
    refute_empty response.params['transactions']
    refute_empty response.params['transactions'].first['id']
    assert_equal 'PENDING', response.params['transactions'].first['status']
  end

  def test_successful_purchase_with_existing_checkout
    existing_checkout = @gateway.purchase(@amount, @credit_card, @options)
    assert_success existing_checkout
    refute_empty existing_checkout.params['id']
    @options[:checkout_id] = existing_checkout.params['id']

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'PENDING', response.message
    assert_equal @options[:order_id], response.params['checkout_reference']
    refute_empty response.params['id']
    assert_equal existing_checkout.params['id'], response.params['id']
    refute_empty response.params['transactions']
    assert_equal response.params['transactions'].count, 2
    refute_empty response.params['transactions'].last['id']
    assert_equal 'PENDING', response.params['transactions'].last['status']
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
    assert_equal 'PENDING', response.message
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
