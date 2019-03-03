require 'test_helper'

class PsigateRemoteTest < Test::Unit::TestCase

  def setup
    Base.mode = :test
    @gateway = PsigateGateway.new(fixtures(:psigate))
    PsigateGateway.ssl_strict = false

    @amount = 2400
    @creditcard = credit_card('4111111111111111')
    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :email => 'jack@example.com'
    }
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @creditcard, @options)
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['transrefnumber']}", response.authorization
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @creditcard, @options)
    assert_success response
    assert_equal "#{@options[:order_id]};#{response.params['transrefnumber']}", response.authorization
  end

  def test_successful_authorization_and_capture
    assert authorization = @gateway.authorize(@amount, @creditcard, @options)
    assert_success authorization

    assert capture = @gateway.capture(@amount, authorization.authorization)
    assert_success capture
  end

  def test_successful_purchase_and_refund
    assert purchase = @gateway.purchase(@amount, @creditcard, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @creditcard, @options.update(:test_result => 'D'))
    assert_failure response
  end

  def test_successful_void
    assert authorization = @gateway.authorize(@amount, @creditcard, @options)
    assert_success authorization

    assert void = @gateway.void(authorization.authorization)
    assert_success void
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @creditcard, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@creditcard.number, transcript)
    assert_scrubbed(@creditcard.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end
end
