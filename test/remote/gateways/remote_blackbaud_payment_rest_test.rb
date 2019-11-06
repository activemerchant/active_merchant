require 'test_helper'

class RemoteBlackbaudPaymentRestTest < Test::Unit::TestCase
  def setup
    @gateway = BlackbaudPaymentRestGateway.new(fixtures(:blackbaud_payment_rest))
    @amount = 1000
    @credit_card = credit_card('4242424242424242')
    @expired_card = credit_card('4000000000000069')

    @options = {
        first_name: 'Longbob',
        last_name: 'Longsen',
        address: address
    }
  end

  def test_successful_card_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match %r{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}, response.authorization
  end

  def test_successful_debit_store
    response = @gateway.store(check, @options)
    
    assert_success response
    assert_match %r{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}, response.authorization
  end

  def test_successful_purchase_with_credit_card
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_purchase_with_credit_card
    response = @gateway.purchase(@amount, @expired_card, @options)
    assert_failure response
    assert_match 'Expired card', response.message
  end

  def test_successful_purchase_with_credit_card_token
    credit_card_stored = @gateway.store(@credit_card, @options)
    @options[:card_token] = credit_card_stored.authorization
    response = @gateway.purchase(@amount, nil, @options)
    assert_success response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:merchant_id], transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

  # Validation error code: <InvalidUserAgent> Validation error message <Invalid User-Agent string.>
  #   def test_successful_purchase_with_debit_card_token
  #     debit_stored = @gateway.store(check, @options)
  #     @options[:direct_debit_account_token] = debit_stored.authorization
  #     response = response = @gateway.purchase(@amount, nil, @options)
  #     assert_success response
  #   end
end
