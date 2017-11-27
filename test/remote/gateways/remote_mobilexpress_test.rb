require 'test_helper'

class RemoteMobilexpressTest < Test::Unit::TestCase
  def setup
    @gateway = MobilexpressGateway.new(fixtures(:mobilexpress))

    @amount = 100
    @credit_card = credit_card('4603454603454606', month: 12, year: 2018, verification_value: '000')
    @credit_card_store = credit_card('4603454603454606', month: 12, year: 2018, verification_value: nil)
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com"
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Success', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'CardRefused', response.message
  end

  def test_invalid_login
    gateway = MobilexpressGateway.new(merchant_key: '', api_password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{AuthenticationError}, response.message
  end

  def test_successful_store
    @options.merge!(
      customer_id: SecureRandom.uuid,
      customer_name: 'Bob Longson',
      ip: '127.0.0.1'
    )
    response = @gateway.store(@credit_card_store, @options)
    assert_success response
    assert_match %r{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}, response.authorization
  end

  def test_failed_store
    options = { customer_name: 'Bob Longson' }
    # store will fail because :ip is mandator
    response = @gateway.store(@credit_card_store, options)
    assert_failure response
  end

  def test_successful_store_and_unstore
    customer_id = SecureRandom.uuid
    options = {
      customer_id: customer_id,
      customer_name: 'Bob Longson',
      ip: '127.0.0.1'
    }
    response = @gateway.store(@credit_card_store, options)
    assert_success response
    assert_match %r{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}, response.authorization

    options = { customer_id: customer_id }
    unstore = @gateway.unstore(response.authorization, options)
    assert_success unstore
  end

  def test_failed_unstore
    options = { customer_id: 'foo-bar' }
    unstore = @gateway.unstore('123', options)
    assert_failure unstore
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_password], transcript)
  end

end
