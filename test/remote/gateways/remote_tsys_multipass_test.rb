require 'test_helper'

class RemoteTsysMultipassTest < Test::Unit::TestCase
  def setup
    @fixtures = fixtures(:tsys_multipass)
    @card_token = @fixtures[:card][:token]
    @expiration_date = @fixtures[:card][:expiration_date]

    @gateway = TsysMultipassGateway.new(
      device_id: @fixtures[:device_id],
      transaction_key: @fixtures[:transaction_key]
    )
  end

  def test_successful_purchase
    purchase_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '100',
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    response = @gateway.purchase('100', @card_token, purchase_options)

    assert_equal true, response.success?
    assert_equal '100', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_purchase
    purchase_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '101',
      cardNumber: @card_token,
      expirationDate: 'INVALID VALUE'
    }

    response = @gateway.purchase('102', @card_token, purchase_options)

    assert_equal false, response.success?
    assert_equal nil, response.authorization
    assert_equal nil, response.amount
    assert_equal 'F9901', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_authorize
    auth_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '103',
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    response = @gateway.authorize('103', @card_token, auth_options)

    assert_equal true, response.success?
    assert_equal '103', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_authorize
    auth_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '104',
      cardNumber: @card_token,
      expirationDate: 'INVALID VALUE'
    }

    response = @gateway.authorize('104', @card_token, auth_options)

    assert_equal false, response.success?
    assert_equal nil, response.amount
    assert_equal 'F9901', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_capture
    # Authorize first
    auth_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '105',
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    auth_id = @gateway.authorize('105', @card_token, auth_options).authorization

    capture_options = {
      transactionAmount: '105',
      transactionID: auth_id
    }

    response = @gateway.capture('105', @card_token, capture_options)

    assert_equal true, response.success?
    assert_equal '105', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_capture
    capture_options = {
      transactionAmount: '106',
      transactionID: 'invalidtransactionid'
    }

    response = @gateway.capture('106', @card_token, capture_options)

    assert_equal false, response.success?
    assert_equal nil, response.amount
    assert_equal 'F9901', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_void
    # Authorize first
    auth_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '107',
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    auth_id = @gateway.authorize('107', @card_token, auth_options).authorization

    void_options = {
      transactionAmount: '107',
      transactionID: auth_id
    }

    response = @gateway.void(@card_token, void_options)

    assert_equal true, response.success?
    assert_equal '107', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_void
    void_options = {
      transactionAmount: '108',
      transactionID: 'invalid auth id'
    }

    response = @gateway.void(@card_token, void_options)

    assert_equal false, response.success?
    assert_equal nil, response.amount
    assert_equal 'F9901', response.error_code
    assert_instance_of Response, response
  end

  def test_successful_refund
    # Authorize first
    auth_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '109',
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    auth_id = @gateway.authorize('109', @card_token, auth_options).authorization

    refund_options = {
      transactionAmount: '109',
      transactionID: auth_id
    }

    response = @gateway.refund('109', @card_token, refund_options)

    assert_equal true, response.success?
    assert_equal '109', response.amount
    assert_equal '', response.error_code
    assert_instance_of Response, response
  end

  def test_failed_refund
    # Authorize first
    purchase_options = {
      cardDataSource: 'INTERNET',
      transactionAmount: '110',
      cardNumber: @card_token,
      expirationDate: @expiration_date
    }

    auth_id = @gateway.purchase('110', @card_token, purchase_options).authorization

    refund_options = {
      transactionAmount: '10000', # More amount than purchased
      transactionID: auth_id
    }

    response = @gateway.refund('10000', @card_token, refund_options)

    assert_equal false, response.success?
    assert_equal nil, response.amount
    assert_equal 'D0005', response.error_code
    assert_instance_of Response, response
  end

  def test_supports_scrubbing
    is_scrubbing_supported = @gateway.supports_scrubbing?

    assert_equal true, is_scrubbing_supported
  end
end
