require 'test_helper'

class RemoteReachTest < Test::Unit::TestCase
  def setup
    @gateway = ReachGateway.new(fixtures(:reach))
    @amount = 100
    @credit_card = credit_card('4444333322221111', {
      month: 3,
      year: 2030,
      verification_value: 737
    })
    @declined_card = credit_card('4000300011112220')
    @options = {
      email: 'johndoe@reach.com',
      order_id: '123',
      description: 'Store Purchase',
      currency: 'USD',
      billing_address: {
        address1: '1670',
        address2: '1670 NW 82ND AVE',
        city: 'Miami',
        state: 'FL',
        zip: '32191',
        country: 'US'
      }
    }
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert response.params['response'][:Authorized]
    assert response.params['response'][:OrderId]
  end

  def test_failed_authorize
    @options[:currency] = 'PPP'
    @options.delete(:email)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_equal 'Invalid ConsumerCurrency', response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert response.params['response'][:Authorized]
    assert response.params['response'][:OrderId]
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'NotATestCard', response.message
  end

  # The Complete flag in the response returns false when capture is
  # in progress
  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    response = @gateway.capture(@amount, response.authorization)
    assert_success response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, "#{@gateway.options[:merchant_id]}#123")

    assert_failure response
    assert_equal 'Not Found', response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end

    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:merchant_id], transcript)
    assert_scrubbed(@gateway.options[:secret], transcript)
  end
end
