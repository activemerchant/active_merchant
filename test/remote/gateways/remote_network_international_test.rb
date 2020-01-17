require 'test_helper'

class RemoteNetworkInternationalTest < Test::Unit::TestCase
  def setup
    @gateway = NetworkInternationalGateway.new(fixtures(:network_international))

    @amount = 1000
    @credit_card = credit_card('4093191766216474')
    @declined_card = credit_card('4396294095051580')
    @options = {
      billing_address: address,
      currency: 'AED'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'AUTHORISED', response.message
  end

  def test_successful_purchase_capture
    options = @options.merge(action: 'SALE')
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'CAPTURED', response.message
  end

  def test_successful_purchase_capture_moto
    options = @options.merge(action: 'SALE', channel: 'MoTo')
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'CAPTURED', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  # ToDo: Fix
  # Not sure why it's not failing. Per their documentation it should fail, but
  # instead it's approved :(
  #  https://docs.ngenius-payments.com/reference#sandbox-test-environment
  #
  # def test_failed_purchase
  #   response = @gateway.purchase(@amount, @declined_card, @options)
  #   assert_failure response
  #   assert_equal 'FAILED', response.message
  # end

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
