require 'test_helper'

class RemoteRazorpayTest < Test::Unit::TestCase
  def setup
    @gateway = RazorpayGateway.new(fixtures(:razorpay))

    @amount = 10000
    @order_id = 'order_12345trewq6543'
    @invalid_order_id = 'order_HziMBC148n2VXu'
    @payment_id = 'pay_HziML4B8Uybcvr'
    @unauthorized_payment_id = 'pay_HyQdXlAAwUuNxt'
    @invalid_payment_id = 'pay_HnTllcQFCxVGNU'
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      currency: 'INR',
      phone: '917912341123',
      email: 'user@example.com'
    }
    @order_options = {
      currency: 'INR',
      order_id: 'order-id'
    }
    @partial_refund_options = {
      amount: @amount - 100
    }
  end

  def test_A_successful_capture
    response = @gateway.capture(@amount, @payment_id, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_order
    response = @gateway.create_order(@amount, @order_options)
    assert_success response
    assert_equal 'OK', response.message
    assert_match 'created', response.params['status']
    assert response.params['id'] != nil
    assert_equal @order_options[:order_id], response.params['receipt'] 
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Payment ID is mandatory', response.message
  end

  def test_B_successful_partial_refund
    refund = @gateway.refund(@payment_id, @partial_refund_options)
    assert_success refund
    assert_equal 'OK', refund.message
  end

  def test_C_failed_refund_amount_lower_than_100
    refund = @gateway.refund(@payment_id, {"amount": 50})
    assert_failure refund
    assert_equal 'The amount must be atleast INR 1.00', refund.message
  end

  def test_D_successful_full_refund
    refund = @gateway.refund(@payment_id)
    assert_success refund
    assert_equal 'OK', refund.message
  end

  def test_E_failed_refund_aleady_refunded_payment
    refund = @gateway.refund(@payment_id)
    assert_failure refund
    assert_equal 'The payment has been fully refunded already', refund.message
  end

  def test_successful_void
    assert void = @gateway.void(@payment_id, @options)
    assert_success void
    assert_equal 'Razorpay does not support void api', void.message
  end

  def test_invalid_login
    gateway = RazorpayGateway.new(key_id: '', key_secret: '')
    response = gateway.capture(@amount, @payment_id, @options)
    assert_failure response
    assert_match "The api key provided is invalid", response.message
  end

  def test_successful_order_fetch
    response = @gateway.get_payments_by_order_id(@order_id)
    assert_success response
    assert_equal "collection", response.params["entity"]
    assert_equal 1, response.params["items"].length()
    assert_equal @order_id, response.params["items"][0]["order_id"]
    assert response.params["items"][0]["id"] != nil
  end

  def test_order_fetch_when_order_id_not_provided_then_400
    response = @gateway.get_payments_by_order_id('')
    assert_failure response
    assert_match 'Order ID is mandatory', response.message
  end

  def test_order_fetch_when_invalid_order_id_provided_then_400
    response = @gateway.get_payments_by_order_id(@invalid_order_id)
    assert_success response
    assert_equal "collection", response.params["entity"]
    assert_equal 0, response.params["count"]
  end

  def test_successful_payment_fetch
    response = @gateway.get_payment(@payment_id)
    assert_success response
    assert_equal "payment", response.params["entity"]
    assert_equal @payment_id, response.authorization
  end

  def test_successful_payment_fetch_with_failed_payment_id
    response = @gateway.get_payment(@unauthorized_payment_id)
    assert_failure response
    assert_equal "payment", response.params["entity"]
    assert_equal @unauthorized_payment_id, response.authorization
    assert_equal "failed", response.params["status"]
    assert response.params["error_code"] != nil
    assert response.params["error_description"] != nil
    assert response.params["error_source"] != nil
    assert response.params["error_step"] != nil
    assert response.params["error_reason"] != nil
  end

end
