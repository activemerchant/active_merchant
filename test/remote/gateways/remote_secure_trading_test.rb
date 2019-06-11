require 'test_helper'

class RemoteSecureTradingTest < Test::Unit::TestCase
  def setup
    @gateway = SecureTradingGateway.new(fixtures(:secure_trading))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000000000000002')
    @options = {
      address: address,
      description: 'Store Purchase',
      unique_identifier: '8be9c12d-8dd5-4539-b6ae-6d8b3212de65',
      first_name: 'Robo',
      currency: 'GBP'
    }
  end

  def test_successful_authorize
    auth = @gateway.authorize(0, @credit_card, @options)
    assert_success auth
    assert_equal 'ACCOUNTCHECK', auth.message
  end

  def test_failed_authorize
    auth = @gateway.authorize(0, @declined_card, @options)
    assert_failure auth
  end

  def test_successful_purchase
    auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'AUTH', auth.message
  end

  def test_failed_purchase
    auth = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure auth
    assert_equal 'AUTH', auth.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript) # pan
    assert_scrubbed(@gateway.options[:user_id], transcript) # alias  
    assert_scrubbed(@credit_card.verification_value, transcript) # securitycode
  end
end
