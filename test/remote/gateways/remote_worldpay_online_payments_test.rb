require 'test_helper'

class RemoteWorldpayOnlinePaymentsTest < Test::Unit::TestCase
  def setup
    @gateway = WorldpayOnlinePaymentsGateway.new(fixtures(:worldpay_online_payments))

    @amount = 1000
    @credit_card = credit_card('4444333322221111')
    @declined_card = credit_card('2424242424242424')

    @options = {
      order_id: '1',
      currency: 'GBP',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS', response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_not_equal 'SUCCESS', response.message
  end

  def test_failed_card_purchase
    @options[:billing_address][:name] = 'FAILED'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_not_equal 'SUCCESS', response.message
  end

  def test_error_card_purchase
    @options[:billing_address][:name] = 'ERROR'
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_not_equal 'SUCCESS', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
  end

  def test_failed_authorize_and_capture
    auth = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_not_equal 'SUCCESS', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
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

  def test_failed_refund
    response = @gateway.refund(nil, '')
    assert_failure response
  end

  def test_failed_double_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund

    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_failure refund
  end

  def test_failed_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    refund = @gateway.refund(@amount+1, purchase.authorization)
    assert_failure refund
  end

  def test_successful_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void
  end

  def test_successful_order_void
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_failed_void
    void = @gateway.void('InvalidOrderCode')
    assert_failure void
  end

  def test_failed_double_void
    authorize = @gateway.authorize(@amount, @credit_card, @options)
    assert_success authorize

    void = @gateway.void(authorize.authorization)
    assert_success void

    void = @gateway.void(authorize.authorization)
    assert_failure void
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{SUCCESS}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_not_match %r{SUCCESS}, response.message
  end

  def test_invalid_login
    badgateway = WorldpayOnlinePaymentsGateway.new(
      client_key: "T_C_NOT_VALID",
      service_key: "T_S_NOT_VALID"
    )
    response = badgateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
end
