require 'test_helper'

class RemoteCharityEngineTest < Test::Unit::TestCase
  def setup
    @gateway = CharityEngineGateway.new(fixtures(:charity_engine))

    @amount = 100
    @declined_amount = 1201
    @credit_card = credit_card('370000000000002')
    @declined_card = credit_card('4111111111111111', year: 2010)
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: '127.0.0.1',
      customer: {
        email: 'joe@example.com',
        dob: '1981-01-01',
        first_name: 'Longbob',
        last_name: 'Longsen',
        gender: 'Male',
        phone_number: address[:phone],
      },
      attribution: {
        response_channel_id: '123',
        initiative_id: '456',
        initiative_segment_id: '789',
        tracking_codes: {
          code4: SecureRandom.uuid,
          code6: 'Foo Bar'
        }
      }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Expired Card', response.message
  end

  def test_declined_purchase
    response = @gateway.purchase(@declined_amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined', response.message
  end

  def test_invalid_login
    gateway = CharityEngineGateway.new(username: '', password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match '100 - authentication failed', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:username], transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

end
