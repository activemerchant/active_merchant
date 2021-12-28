require 'test_helper'

class RemoteTest < Test::Unit::TestCase
  def setup
    @gateway = QuickbooksGateway.new(fixtures(:quickbooks))
    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000000000000001')

    @partial_amount = @amount - 1

    @options = {
      order_id: '1',
      billing_address: address({ zip: 90210,
                                 country: 'US',
                                 state: 'CA' }),
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'CAPTURED', response.message
    assert_equal @gateway.options[:access_token], response.params['access_token']
    assert_equal @gateway.options[:refresh_token], response.params['refresh_token']
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'card.number is invalid.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(nil, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@partial_amount, auth.authorization)
    assert_equal capture.params['captureDetail']['amount'], sprintf('%.2f', @partial_amount.to_f / 100)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(nil, '')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@partial_amount, purchase.authorization)
    assert_equal refund.params['amount'], sprintf('%.2f', @partial_amount.to_f / 100)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{AUTHORIZED}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{card.number is invalid.}, response.message
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_invalid_login
    gateway = QuickbooksGateway.new(
      consumer_key: '',
      consumer_secret: '',
      access_token: '',
      token_secret: '',
      realm: ''
    )
    assert_raises ActiveMerchant::ResponseError do
      gateway.purchase(@amount, @credit_card, @options)
    end
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'ISSUED', void.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:access_token], transcript)
    assert_scrubbed(@gateway.options[:refresh_token], transcript)
  end

  def test_failed_purchase_with_expired_token
    @gateway.options[:access_token] = 'not_a_valid_token'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'AuthenticationFailed', response.params['code']
  end

  def test_successful_purchase_with_expired_token
    @gateway.options[:access_token] = 'not_a_valid_token'
    response = @gateway.purchase(@amount, @credit_card, @options.merge(allow_refresh: true))
    assert_success response
  end

  def test_successful_purchase_without_state_in_address
    options = {
      order_id: '1',
      billing_address:
        {
          zip: 90210,
          # Submitting a value of an empty string for the `state` field
          # results in a `region is invalid` error message from Quickbooks.
          # This test ensures that an empty string is not sent from AM.
          state: '',
          country: ''
        }
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'CAPTURED', response.message
  end

  def test_refresh
    response = @gateway.refresh
    assert_success response
    assert response.params['access_token']
  end
end
