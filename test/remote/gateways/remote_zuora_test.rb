require 'test_helper'

class RemoteZuoraTest < Test::Unit::TestCase
  def setup
    @gateway = ZuoraGateway.new(fixtures(:zuora))

    @credit_card = credit_card('4000100011112224', verification_value: nil)
    @options = {
      billing_address: address,
      first_name: 'Bob',
      last_name: 'Longsen',
      currency: 'AUD',
      description: 'Store Purchase'
    }
    @failed_options = {
      first_name: 'Bob',
      last_name: 'Longsen',
    }
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)

    assert_success response
  end

  def test_failed_store
    response = @gateway.store(@credit_card, @failed_options)
    
    assert_failure response
    assert_match /'billToContact' may not be null/, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_invalid_login
    gateway = ZuoraGateway.new(username: 'active_merchant_test', password: 'sekrit')
    assert response = gateway.store(@credit_card, @options)
    assert_failure response
    assert_match 'this resource is protected, please sign in first', response.message
  end
end
