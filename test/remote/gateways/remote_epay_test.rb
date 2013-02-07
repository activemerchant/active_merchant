require 'test_helper'

class RemoteEpayTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test

    @gateway = EpayGateway.new(fixtures(:epay))

    @credit_card = credit_card('3333333333333000')
    @credit_card_declined = credit_card('3333333333333102')

    @amount = 100
    @options = { :order_id => '1' }
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_equal "1", response.params['accept']
    assert_not_nil response.params['tid']
    assert_not_nil response.params['cur']
    assert_not_nil response.params['amount']
    assert_not_nil response.params['orderid']
    assert !response.authorization.blank?
    assert_success response
    assert response.test?
  end

  def test_failed_authorization
    assert response = @gateway.authorize(@amount, @credit_card_declined, @options)
    assert_equal '1', response.params['decline']
    assert_not_nil response.params['error']
    assert_not_nil response.params['errortext']
    assert_failure response
    assert response.test?
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal '1', response.params['accept']
    assert_not_nil response.params['tid']
    assert_not_nil response.params['cur']
    assert_not_nil response.params['amount']
    assert_not_nil response.params['orderid']
    assert !response.authorization.blank?
    assert_success response
    assert response.test?
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @credit_card_declined, @options)
    assert_equal '1', response.params['decline']
    assert_not_nil response.params['error']
    assert_not_nil response.params['errortext']
    assert_failure response
    assert response.test?
  end

  def test_successful_capture
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)

    assert response = @gateway.capture(@amount, authorize_response.authorization)
    assert_equal 'true', response.params['result']
    assert_success response
    assert response.test?
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, 0)
    assert_equal 'false', response.params['result']
    assert_failure response
    assert response.test?
  end

  def test_successful_refund
    authorize_response = @gateway.purchase(@amount, @credit_card, @options)

    assert response = @gateway.refund(@amount, authorize_response.authorization)
    assert_equal 'true', response.params['result']
    assert_success response
    assert response.test?
  end

  def test_failed_refund
    assert response_refund = @gateway.refund(@amount, 0)
    assert_equal 'false', response_refund.params['result']
    assert_failure response_refund
    assert response_refund.test?
  end

  def test_successful_void
    authorize_response = @gateway.authorize(@amount, @credit_card, @options)

    assert response = @gateway.void(authorize_response.authorization)
    assert_equal 'true', response.params['result']
    assert_success response
    assert response.test?
  end

  def test_failed_void
    assert response_void = @gateway.void(0)
    assert_equal 'false', response_void.params['result']
    assert_failure response_void
    assert response_void.test?
  end
end
