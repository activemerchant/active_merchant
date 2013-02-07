require 'test_helper'

class RemoteRedsysTest < Test::Unit::TestCase
  def setup
    @gateway = RedsysGateway.new(fixtures(:redsys))
    @credit_card = credit_card('4548812049400004')
    @declined_card = credit_card
  end

  def test_successful_purchase
    order_id = generate_order_id
    result = @gateway.purchase(100, @credit_card, :order_id => order_id)
    assert_success result
    assert_equal "#{order_id}|100|978", result.authorization
  end

  def test_failed_purchase
    order_id = generate_order_id
    result = @gateway.purchase(100, @declined_card, :order_id => order_id)
    assert_failure result
    assert_nil result.authorization
  end

  def test_purchase_and_refund
    order_id = generate_order_id
    result = @gateway.purchase(100, @credit_card, :order_id => order_id)
    assert_success result
    result = @gateway.refund(100, order_id)
    assert_success result
  end

  # Multiple currencies are not supported in test, but should at least fail.
  def test_purchase_and_refund_with_currency
    order_id = generate_order_id
    result = @gateway.purchase(600, @credit_card, :order_id => order_id, :currency => 'PEN')
    assert_failure result
    assert_equal "SIS0027 ERROR", result.message
  end

  def test_authorise_and_capture
    order_id = generate_order_id
    result = @gateway.authorize(100, @credit_card, :order_id => order_id)
    assert_success result
    assert_equal "#{order_id}|100|978", result.authorization
    result = @gateway.capture(100, order_id)
    assert_success result
  end

  def test_authorise_and_void
    order_id = generate_order_id
    result = @gateway.authorize(100, @credit_card, :order_id => order_id)
    assert_success result
    result = @gateway.void(result.authorization)
    assert_success result
    assert_equal "100", result.params["ds_amount"]
  end

  private

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
