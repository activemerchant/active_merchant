require 'test_helper'

class RemoteEzidebitTest < Test::Unit::TestCase
  def setup
    @gateway = EzidebitGateway.new(fixtures(:ezidebit))

    @amount = 100
    @credit_card = credit_card('4987654321098769', month: 5, year: 2021, verification_value: 454)
    @declined_amount = 105
    @options = {
      order_id: SecureRandom.uuid,
      description: 'Store Purchase',
      customer_name: 'Longsen Longbob'
    }
    @address = {
        address1: '456 My Street',
        address2: 'Apt 1',
        company:  'Widgets Inc',
        city:     'Bondi Beach',
        state:    'NSW',
        zip:      '2026',
        country:  'AU'
    }
    @store_options = @options.merge(
      billing_address: @address,
      start_date: '2018-01-19',
      last_name: 'Longsen',
      first_name: 'Longbob'
    )
    @recurring_options = @store_options.merge(
      scheduler_period_type: 'M',
      day_of_month: 15
    )
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'APPROVED', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @store_options)
    assert_success response
    assert_match /\d+/, response.authorization
  end

  def test_successful_recurring
    response = @gateway.recurring(@amount, @credit_card, @recurring_options)
    assert_success response
    assert_match /\d+/, response.authorization
  end

  def test_invalid_login
    gateway = EzidebitGateway.new(digital_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{You must provide a value for the \'DigitalKey\' parameter \(WSvc\)}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:digital_key], transcript)
  end

end
