require 'test_helper'

class RemoteSeerbitTest < Test::Unit::TestCase
  def setup
    @gateway = SeerbitGateway.new(fixtures(:seerbit))

    @amount = 100
    @credit_card = credit_card('5123450000000008', {
      month: '05',
      year: '21',
      verification_value: 100,
      brand: 'master'
    })
    @declined_card = credit_card('4242424242424242')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      reference: SecureRandom.uuid,
      currency: 'GHS',
      address: address({ country: 'GH' }),
      customer: {
        email: "john.smith@test.com",
        full_name: 'John smith',
        mob_phone: '08032000001'
      }
    }

    @declined_options = {
      billing_address: address,
      description: 'Store Purchase',
      reference: SecureRandom.uuid,
      currency: 'GHS',
      address: address({ country: 'US' })
    }

    @recurring_options = {
      start_date: 1.month.from_now,
      billing_cycle: 'MONTHLY',
      billing_period: 12,
      callback_url: 'http://127.0.0.1'
    }
  end

  def test_successful_3ds_initiation
    response = @gateway.initiate_3ds(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction is pending', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_successful_recurring
    response = @gateway.recurring(
      @amount, @credit_card, @options.merge(@recurring_options))
    assert_success response
    assert_equal 'Transaction is pending', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @declined_options)
    assert_failure response
    assert_equal 'Invalid country/currency combination', response.message
  end

  def test_failed_recurring
    response = @gateway.recurring(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Billing Cycle cannot be null', response.message
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
