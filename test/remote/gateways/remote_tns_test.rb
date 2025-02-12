require 'test_helper'

class RemoteTnsTest < Test::Unit::TestCase
  def setup
    TnsGateway.ssl_strict = false # Sandbox has an improperly installed cert
    @gateway = TnsGateway.new(fixtures(:tns))

    @amount = 100
    @credit_card = credit_card('4111111111111111', month: 05, year: 2025)
    @ap_credit_card = credit_card('5424180279791732', month: 05, year: 2024)
    @declined_card = credit_card('5123456789012346', month: 01, year: 2028)
    @three_ds_card = credit_card('4440000009900010', month: 01, year: 2039)

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase'
    }
    @nt_credit_card = network_tokenization_credit_card('4111111111111111',
                                                       brand: 'visa',
                                                       eci: '05',
                                                       month: 06,
                                                       year: 2029,
                                                       source: :network_token,
                                                       payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')
  end

  def teardown
    TnsGateway.ssl_strict = true
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_authorize_with_3ds
    @options[:authentication] = { redirectResponseUrl: 'https://example.com/redirect', channel: 'PAYMENT_TRANSACTION' }

    assert response = @gateway.authorize(@amount, @three_ds_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_network_token
    assert response = @gateway.purchase(@amount, @nt_credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_sans_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_more_options
    more_options = @options.merge({
      ip: '127.0.0.1',
      email: 'joe@example.com'
    })

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(more_options))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  # This requires a test account flagged for pay/purchase mode.
  # The primary test account (TESTSPREEDLY01) is not flagged for this mode.
  # This was initially tested with a private account.
  def test_successful_purchase_in_pay_mode
    gateway = TnsGateway.new(fixtures(:tns_pay_mode).merge(region: 'europe'))

    assert response = gateway.purchase(@amount, @credit_card, @options.merge(currency: 'GBP', pay_mode: true))
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_equal 'CAPTURED', response.params['order']['status']
  end

  def test_successful_purchase_with_region
    @gateway = TnsGateway.new(fixtures(:tns_ap).merge(region: 'asia_pacific'))

    assert response = @gateway.purchase(@amount, @ap_credit_card, @options.merge(currency: 'AUD'))
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'FAILURE - UNSPECIFIED_FAILURE', response.message
  end

  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
    assert_match %r(^.+\|\d+$), response.authorization

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'FAILURE - UNSPECIFIED_FAILURE', response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_successful_verify
    assert response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message

    assert_success response.responses.last, 'The void should succeed'
    assert_equal 'SUCCESS', response.responses.last.params['result']
  end

  def test_invalid_login
    gateway = TnsGateway.new(
      userid: 'nosuch',
      password: 'thing'
    )
    response = gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'ERROR - INVALID_REQUEST - Invalid credentials.', response.message
  end

  def test_transcript_scrubbing
    card = credit_card('5123456789012346', verification_value: '834')
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
