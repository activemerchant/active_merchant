require 'test_helper'

class RemoteSeerbitTest < Test::Unit::TestCase
  def setup
    @gateway = SeerbitGateway.new(fixtures(:seerbit))

    @amount = 100
    @credit_card = credit_card('5123450000000008', {
      month: '05',
      year: '21',
      verification_value: 100
    })
    @declined_card = credit_card('4242424242424242')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      reference: SecureRandom.uuid,
      currency: 'GHS',
      address: address({ country: 'GH' })
    }

    @declined_options = {
      billing_address: address,
      description: 'Store Purchase',
      reference: SecureRandom.uuid,
      currency: 'GHS',
      address: address({ country: 'US' })
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase
    puts
    puts " # ========== test_failed_purchase ============== "
    puts " # @amount = #{@amount}"
    puts " # @declined_card.inspect = #{@declined_card.inspect}"
    puts " # ===================== "
    puts
    response = @gateway.purchase(@amount, @declined_card, @declined_options)
    assert_failure response
    assert_equal 'Transaction Failed', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(/(\\?\\?\\?"cvv\\?\\?\\?":\\?\\?\\?"?)#{@credit_card.verification_value}+/, transcript)
    assert_scrubbed(@gateway.options[:private_key], transcript)
  end
end
