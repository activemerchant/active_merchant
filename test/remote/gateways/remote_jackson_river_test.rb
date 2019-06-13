require 'test_helper'

class RemoteJacksonRiverTest < Test::Unit::TestCase
  def setup
    @gateway = JacksonRiverGateway.new(fixtures(:jackson_river))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @options = {
      first_name: 'Longbob',
      last_name: 'Longsen',
      billing_address: address,
      description: 'Store Purchase',
      form_id: 34467,
      market_source: 'FooBar_MarketSource',
      canvasser_name: 'John Doe Canvasser'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Submission successful', response.message
    assert_match %r(\d+), response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card, @options.except(:first_name))
    assert_failure response
    assert_equal 'first_name::First Name field is required.', response.message
  end

  def test_invalid_login
    gateway = JacksonRiverGateway.new(fixtures(:jackson_river).merge!(api_key: ''))

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Access denied.}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

end
