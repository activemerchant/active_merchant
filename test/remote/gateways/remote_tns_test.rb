require 'test_helper'

class RemoteTnsTest < Test::Unit::TestCase

  def setup
    TnsGateway.ssl_strict = false # Sandbox has an improperly installed cert
    @gateway = TnsGateway.new(fixtures(:tns))

    @amount = 100
    @credit_card = credit_card('5123456789012346')
    @ap_credit_card = credit_card('5424180279791732', month: 05, year: 2017, verification_value: 222)
    @declined_card = credit_card('4000300011112220')

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def teardown
    TnsGateway.ssl_strict = true
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_sans_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_more_options
    more_options = @options.merge({
      ip: "127.0.0.1",
      email: "joe@example.com",
    })

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(more_options))
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_successful_purchase_with_region
    @gateway = TnsGateway.new(fixtures(:tns_ap).merge(region: 'asia_pacific'))

    assert response = @gateway.purchase(@amount, @ap_credit_card, @options.merge(currency: "AUD"))
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "FAILURE - DECLINED", response.message
  end

  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^.+\|\d+$), response.authorization

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "FAILURE - DECLINED", response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", refund.message
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
    assert_equal "Succeeded", response.message

    assert_success response.responses.last, "The void should succeed"
    assert_equal "SUCCESS", response.responses.last.params["result"]
  end

  def test_invalid_login
    gateway = TnsGateway.new(
                :userid => 'nosuch',
                :password => 'thing'
              )
    response = gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "ERROR - INVALID_REQUEST - Invalid credentials.", response.message
  end

  def test_transcript_scrubbing
    card = credit_card("5123456789012346", verification_value: "834")
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = TnsGateway.new(userid: 'unknown', password: 'unknown')
    assert !gateway.verify_credentials
  end
end
