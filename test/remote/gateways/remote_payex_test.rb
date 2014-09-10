require 'test_helper'

class RemotePayexTest < Test::Unit::TestCase

  def setup
    @gateway = PayexGateway.new(fixtures(:payex))

    @amount = 1000
    @credit_card = credit_card('4581090329655682')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '1234',
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    # we can't test for a message since the messages vary so much
    assert_not_equal 'OK', response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert response = @gateway.authorize(amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message

    assert response.authorization
    assert response = @gateway.capture(amount, response.authorization)
    assert_success response
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '1')
    assert_failure response
    assert_not_equal 'OK', response.message
    assert_not_equal 'RecordNotFound', response.params[:status_errorcode]
  end

  def test_authorization_and_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert response = @gateway.void(response.authorization)
    assert_success response
  end

  def test_unsuccessful_void
    assert response = @gateway.void("1")
    assert_failure response
    assert_not_equal 'OK', response.message
    assert_match %r{1}, response.message
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.authorization
    assert response = @gateway.refund(@amount - 200, response.authorization, order_id: '123')
    assert_success response
  end

  def test_unsuccessful_refund
    assert response = @gateway.refund(@amount, "1", order_id: '123')
    assert_failure response
    assert_not_equal 'OK', response.message
    assert_match %r{1}, response.message
  end

  def test_successful_store_and_purchase
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message

    assert response = @gateway.purchase(@amount, response.authorization, @options.merge({order_id: '5678'}))
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_store_and_authorize_and_capture
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message

    assert response = @gateway.authorize(@amount, response.authorization, @options.merge({order_id: '5678'}))
    assert_success response
    assert_equal 'OK', response.message
    assert response.authorization

    assert response = @gateway.capture(@amount, response.authorization)
    assert_success response
  end

  def test_successful_unstore
    assert response = @gateway.store(@credit_card, @options)
    assert_equal 'OK', response.message
    assert response = @gateway.unstore(response.authorization)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_invalid_login
    gateway = PayexGateway.new(
                :account => '1',
                :encryption_key => '1'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_not_equal 'OK', response.message
  end
end
