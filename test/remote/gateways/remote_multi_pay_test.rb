require 'test_helper'

class RemoteMultiPayTest < Test::Unit::TestCase
  def setup
    @gateway = MultiPayGateway.new(fixtures(:multi_pay))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000000000000002')
    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      email: 'customer@example.com'
    }
  end

  def test_successful_authorization
    response = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @credit_card, @options)
    end

    transcript = @gateway.scrub(response)
    puts transcript
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_match %r{declined}i, response.message
  end

  def test_successful_purchase_with_more_options
    extra_options = @options.merge({
      customer: 'Test Customer',
      ip: '127.0.0.1',
      currency: 'USD'
    })

    response = @gateway.purchase(@amount, @credit_card, extra_options)
    assert_success response
    assert_equal 'Transaction approved', response.message
  end

  def test_invalid_login
    gateway = MultiPayGateway.new(
      api_key: 'invalid',
      merchant_id: 'invalid'
    )

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{authentication failed}i, response.message
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

  private

  def generate_unique_id
    SecureRandom.hex(16)
  end
end
