require 'test_helper'

class RemoteVacaypayTest < Test::Unit::TestCase
  def setup
    @gateway = VacaypayGateway.new(fixtures(:vacaypay))

    @credit_card = credit_card('4242424242424242')
    @declined_card = credit_card('4000000000000002')
    @store_declined_card = credit_card('4000000000000002', {
      :verification_value => nil
    })
    @amount = 10000

    @options = {
      :currency => "USD",
      :description => 'ActiveMerchant Test Purchase',
      :email => 'wow@example.com',
      :ip => '127.0.0.1',
      :first_name => 'Longbob',
      :last_name => 'Longsen'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_successful_purchase_with_more_options

    options = @options.merge({
      :externalPaymentReference => 'payment-test-1234',
      :externalBookingReference => 'booking-test-1234'
    })

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Succeeded', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Your card was declined.', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    refute auth.params["data"]["captured"]
    assert_equal "ActiveMerchant Test Purchase", auth.params["data"]["description"]
    assert_equal "wow@example.com", auth.params["data"]["email"]

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Succeeded', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'card_declined', response.error_code
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 100, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '0')
    assert_failure response
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 100, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    response = @gateway.refund(@amount + 100, purchase.authorization)
    assert_failure response
    assert_equal 'Cannot refund a value less than 0, or higher than the amount refundable (100).', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Succeeded', void.message
  end

  def test_failed_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Succeeded', refund.message

    response = @gateway.void(purchase.authorization)
    assert_failure response
    assert_equal 'Cannot refund a value less than 0, or higher than the amount refundable (0).', response.message
  end

  def test_successful_store
    response = @gateway.store(@credit_card, @options)
    assert_success response
  end

  def test_failed_store
    response = @gateway.store(@store_declined_card, @options)
    assert_failure response
  end

  def test_invalid_login
    gateway = VacaypayGateway.new(api_key: '0', account_uuid: '0')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:api_key], transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end
end
