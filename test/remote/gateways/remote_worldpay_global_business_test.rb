require 'test_helper'

class RemoteWorldpayGlobalBusinessTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayGlobalBusinessGateway.new(fixtures(:worldpay_global_business))

    @amount = 100
    @credit_card = credit_card('4444333322221111')
    @declined_card = credit_card('4444333322221111',
     first_name: '',
     last_name: 'REFUSED')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      order_id: generate_unique_id,
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(310, @declined_card, @options)
    assert_failure response
    assert_equal 'REFUSED', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
    assert_scrubbed(@gateway.options[:username], transcript)
  end
end
