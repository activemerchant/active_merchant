# encoding: utf-8
require 'test_helper'

class RemoteFinansbankTest < Test::Unit::TestCase
  def setup
    if RUBY_VERSION < '1.9' && $KCODE == "NONE"
      @original_kcode = $KCODE
      $KCODE = 'u'
    end

    @gateway = FinansbankGateway.new(fixtures(:finansbank))

    @amount = 100

    @credit_card = credit_card('4022774022774026', month: 12, year: 14, verification_value: '000')
    @declined_card = credit_card('4000300011112220')

    @options = {
      :order_id => '#' + generate_unique_id,
      :billing_address => address,
      :description => 'Store Purchase',
      :email => 'xyz@gmail.com'
    }
  end

  def teardown
    $KCODE = @original_kcode if @original_kcode
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_not_nil response.params['order_id']
    assert_not_nil response.params['response']
    assert_not_nil response.params['auth_code']
    assert_not_nil response.params['trxdate']
    assert_not_nil response.params['numcode']
    assert_not_nil response.params['trans_id']
    assert_nil response.params['errorcode']
    assert_equal response.params['order_id'], response.authorization
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
  end

  def test_credit
    assert response = @gateway.credit(@amount, @credit_card)
    assert_success response
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert void = @gateway.refund(@amount, response.authorization)
    assert_success void
    assert_equal response.params['order_id'], void.params['order_id']
  end

  def test_unsuccessful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert void = @gateway.refund(@amount + 100, response.authorization)
    assert_failure void
    assert_nil void.params['order_id']
    assert_equal 'Declined (Reason: 99 - Net miktardan fazlasi iade edilemez.)', void.message
    assert_equal "CORE-2503", void.params['errorcode']
  end

  def test_void
    assert response = @gateway.authorize(@amount, @credit_card, @options)

    assert void = @gateway.void(response.authorization)
    assert_success void
    assert_equal response.params['order_id'], void.params['order_id']
  end

  def test_invalid_login
    gateway = FinansbankGateway.new(
      :login => '',
      :password => '',
      :client_id => ''
    )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined (Reason: 99 - System based initialization problem. Please try again later.)', response.message
    assert_equal "2100", response.params['errorcode']
  end
end
