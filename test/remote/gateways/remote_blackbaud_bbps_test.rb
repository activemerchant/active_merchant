require 'test_helper'

class RemoteBlackbaudBbpsTest < Test::Unit::TestCase
  def setup
    @gateway = BlackbaudBbpsGateway.new(fixtures(:blackbaud_bbps))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('1111111111111111')
    @options = {
      client_app: 'Evergiving Test'
    }
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match %r{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}, response.authorization
  end

  def test_success_store_without_options
    response = @gateway.store(@credit_card)
    assert_success response
    assert_match %r{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}, response.authorization
  end

  def test_failed_store
    response = @gateway.store(@declined_card, @options)
    assert_failure response
    assert_match 'Credit card number is not valid.', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.store(@credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    basic_auth = Base64.strict_encode64("#{@options[:username]}:#{@options[:password]}")
    assert_scrubbed(basic_auth, transcript)
  end

end
