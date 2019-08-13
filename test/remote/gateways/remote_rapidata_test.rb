require 'test_helper'

class RemoteRapidataTest < Test::Unit::TestCase
  def setup
    @gateway = RapidataGateway.new(fixtures(:rapidata))

    @amount = 100
    @checking_account = check(routing_number: 123456)
    @options = {
      billing_address: address.merge(county: 'Greater Manchester'),
      description: 'Store Purchase',
      database_id: 20040,
      frequency_id: 1,
      first_name: 'Bob',
      last_name: 'Longsen',
      first_collection_date: (Date.current + 1.month).change(day: 1),
      source: 'Evergiving'
    }
    @more_options = @options.merge(
      is_fulfilment: false,
      gift_aid: true,
      other1: 'Something',
      other2: 'To',
      other3: 'Send',
      other4: 'As a test',
      email: 'longbob@example.com'
    )
  end

  def test_successful_direct_debit_plan
    response = @gateway.create_direct_debit_plan(@amount, @checking_account, @options)
    assert_success response
    assert_equal 'OK', response.message
    assert_match /[a-z0-9]+/i, response.authorization
  end

  def test_successful_direct_debit_plan_with_more_options
    response = @gateway.create_direct_debit_plan(@amount, @checking_account, @more_options)
    assert_success response
    assert_equal 'OK', response.message
    assert_match /[a-z0-9]+/i, response.authorization
  end


  def test_failed_direct_debit_plan
    response = @gateway.create_direct_debit_plan(@amount, @checking_account, @options.merge(first_collection_date: Date.current))
    assert_failure response
    assert_equal 'The request is invalid.', response.message
  end

  def test_invalid_login
    gateway = RapidataGateway.new(username: '', password: '', client_id: '')

    response = gateway.create_direct_debit_plan(@amount, @checking_account, @options)
    assert_failure response
    assert_match %r{ClientId should be sent.}, response.message['error_description']
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.create_direct_debit_plan(@amount, @checking_account, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@checking_account.account_number, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

end
