require 'test_helper'

class RemoteBamboraNaTest < Test::Unit::TestCase
  def setup
    @gateway = BamboraNaGateway.new(fixtures(:bambora_na))

    @amount = 100
    @credit_card = credit_card('4030000010001234')
    @credit_card_store = credit_card('4030000010001234', verification_value: nil)
    @declined_card = credit_card('4003050500040005')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      order_id: SecureRandom.hex(10)
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Approved', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'DECLINE', response.message
  end

  def test_invalid_login
    gateway = BamboraNaGateway.new(merchant_id: '', api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{authentication failed}i, response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card_store, @options)
    assert_success response
    assert_match /[-a-f0-9]+/, response.authorization
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(Base64.strict_encode64("#{@options[:merchant_id]}:#{@options[:api_key]}"), transcript)
  end

end
