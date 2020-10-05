require 'test_helper'

class RemoteSeerbitTest < Test::Unit::TestCase
  def setup
    @gateway = SeerbitGateway.new(fixtures(:seerbit))

    @amount = 100
    @credit_card = credit_card('5123450000000008')
    @declined_card = credit_card('2223000000000007')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      reference: SecureRandom.uuid,
      currency: 'GHS',
      address: address({ country: 'GH' })
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Successful', response.message
  end

  # def test_failed_purchase
  #   response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'Transaction Failed', response.message
  # end

  def test_dump_transcript
    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic.  You can delete
    # this helper after completing your scrub implementation.
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:token], transcript)
  end

end
