require 'test_helper'

class RemoteEpayTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = EpayGateway.new(fixtures(:epay))

    @credit_card = credit_card('3333333333333000')
    @credit_card_declined = credit_card('3333333333333102')

    @amount = 100
    @options = {order_id: '1'}
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert !response.authorization.blank?
    assert response.test?
  end

  def test_successful_authorize_and_capture
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert !response.authorization.blank?

    capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response
  end

  def test_failed_authorization
    response = @gateway.authorize(@amount, @credit_card_declined, @options)
    assert_failure response
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @credit_card_declined, @options)
    assert_failure response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 0)
    assert_failure response
  end

  def test_successful_refund
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    refund_response = @gateway.refund(@amount, response.authorization)
    assert_success refund_response
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 0)
    assert_failure response
  end

  def test_successful_void
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    void_response = @gateway.void(response.authorization)
    assert_success void_response
  end

  def test_failed_void
    response = @gateway.void(0)
    assert_failure response
  end
end
