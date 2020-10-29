require 'test_helper'

class RemoteEpayTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = EpayGateway.new(fixtures(:epay))
    @credit_card = credit_card('3333333333333000')
    @credit_card_declined = credit_card('3333333333333102')
    @amount = 100
    @options_xid = { order_id: generate_unique_id, three_d_secure: { eci: '7', xid: '123', cavv: '456', version: '2', ds_transaction_id: nil } }
    @options_ds_transaction_id = { order_id: generate_unique_id, three_d_secure: { eci: '7', xid: nil, cavv: '456', version: '2', ds_transaction_id: '798' } }
  end

  def test_successful_purchase_xid
    response = @gateway.purchase(@amount, @credit_card, @options_xid)
    assert_success response
    assert !response.authorization.blank?
    assert response.test?
  end

  def test_successful_authorize_and_capture_xid
    response = @gateway.authorize(@amount, @credit_card, @options_xid)
    assert_success response
    assert !response.authorization.blank?

    capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response
  end

  def test_failed_authorization_xid
    response = @gateway.authorize(@amount, @credit_card_declined, @options_xid)
    assert_failure response
  end

  def test_failed_purchase_xid
    response = @gateway.purchase(@amount, @credit_card_declined, @options_xid)
    assert_failure response
  end

  def test_successful_refund_xid
    response = @gateway.purchase(@amount, @credit_card, @options_xid)
    assert_success response

    refund_response = @gateway.refund(@amount, response.authorization)
    assert_success refund_response
  end

  def test_successful_void_xid
    response = @gateway.authorize(@amount, @credit_card, @options_xid)
    assert_success response

    void_response = @gateway.void(response.authorization)
    assert_success void_response
  end

  def test_successful_purchase_ds_transaction_id
    response = @gateway.purchase(@amount, @credit_card, @options_ds_transaction_id)
    assert_success response
    assert !response.authorization.blank?
    assert response.test?
  end

  def test_successful_authorize_and_capture_ds_transaction_id
    response = @gateway.authorize(@amount, @credit_card, @options_ds_transaction_id)
    assert_success response
    assert !response.authorization.blank?

    capture_response = @gateway.capture(@amount, response.authorization)
    assert_success capture_response
  end

  def test_failed_authorization_ds_transaction_id
    response = @gateway.authorize(@amount, @credit_card_declined, @options_ds_transaction_id)
    assert_failure response
  end

  def test_failed_purchase_ds_transaction_id
    response = @gateway.purchase(@amount, @credit_card_declined, @options_ds_transaction_id)
    assert_failure response
  end

  def test_successful_refund_ds_transaction_id
    response = @gateway.purchase(@amount, @credit_card, @options_ds_transaction_id)
    assert_success response

    refund_response = @gateway.refund(@amount, response.authorization)
    assert_success refund_response
  end

  def test_successful_void_ds_transaction_id
    response = @gateway.authorize(@amount, @credit_card, @options_ds_transaction_id)
    assert_success response

    void_response = @gateway.void(response.authorization)
    assert_success void_response
  end

  def test_failed_capture
    response = @gateway.capture(@amount, 0)
    assert_failure response
  end

  def test_failed_refund
    response = @gateway.refund(@amount, 0)
    assert_failure response
  end

  def test_failed_void
    response = @gateway.void(0)
    assert_failure response
  end
end
