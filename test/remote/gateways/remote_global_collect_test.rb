require 'test_helper'

class RemoteGlobalCollectTest < Test::Unit::TestCase


  def setup
    @gateway = GlobalCollectGateway.new(fixtures(:global_collect))

    @amount = 100
    @credit_card = credit_card('4000100011112224')

    @order_id = rand(9999999999)

    @options = {
      :order_id => @order_id,
      :billing_address => address,
      :description => 'Store Purchase',
      :currency => 'CAD'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Success', response.message

    order_status = fetch_status
    assert_equal '800', order_status['STATUSID']
    assert_equal '100', order_status['AMOUNT']
    assert_equal 'CAD', order_status['CURRENCYCODE']
    assert_equal '1',   order_status['EFFORTID']
  end

  def test_unsuccessful_purchase
    @credit_card.year = 2010
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/REQUEST \d+ EXPIRY DATE \(0910\) IS IN THE PAST OR NOT IN CORRECT MMYY FORMAT/, response.message)
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization

    order_status = fetch_status
    assert_equal '600', order_status['STATUSID']
    assert_equal '100', order_status['AMOUNT']
    assert_equal 'CAD', order_status['CURRENCYCODE']
    assert_equal '1',   order_status['EFFORTID']

    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture

    order_status = fetch_status
    assert_equal '800', order_status['STATUSID']
    assert_equal '100', order_status['AMOUNT']
    assert_equal 'CAD', order_status['CURRENCYCODE']
    assert_equal '1',   order_status['EFFORTID']
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'PARAMETER ORDERID NOT FOUND IN REQUEST; PARAMETER PAYMENTPRODUCTID NOT FOUND IN REQUEST', response.message
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message
    assert auth.authorization
    assert_equal '600', fetch_status['STATUSID']

    assert void = @gateway.void(auth.authorization)
    assert_equal 'Success', void.message
    assert_success void

    assert_equal '99999', fetch_status['STATUSID']
  end

  def test_purchase_and_refund
    assert auth = @gateway.purchase(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Success', auth.message

    assert refund = @gateway.refund(@amount - 20, auth.authorization)
    # Refunds can't be issued until the transaction is settled, so this doesn't work against the test server
    assert_failure refund
    assert_equal 'ORDER WITHOUT REFUNDABLE PAYMENTS', refund.message
  end

  def test_unsuccessful_status
    assert response = @gateway.status(@order_id)
    assert_failure response
    assert_match(/GET_ORDERSTATUS ORDER NOT FOUND$/, response.message)
  end

  def test_invalid_merchant_id
    gateway = GlobalCollectGateway.new(:merchant_id => '')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'NO MERCHANTID ACTION INSERT_ORDERWITHPAYMENT (130) IS NOT ALLOWED', response.message
  end

  def test_multiple_variable_recurring_payments
    assert first = @gateway.multiple_initial_purchase(@amount, @credit_card, @options)
    assert_success first

    order_status = fetch_status
    assert_equal '1', order_status['EFFORTID']
    assert_equal '800', order_status['STATUSID']

    @options[:effort_id] = 2
    assert second = @gateway.multiple_append_purchase(@amount, @options)
    assert_success second

    order_status = fetch_status
    assert_equal '2', order_status['EFFORTID']
    assert_equal '800', order_status['STATUSID']
  end

  private
  def fetch_status
    @gateway.status(@order_id).params['STATUS']
  end
end
