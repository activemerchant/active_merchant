require 'test_helper'

class WebPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @web_pay = WebPay::Notification.new(http_raw_data, :secret => 'secret')
  end

  def test_accessors
    assert @web_pay.complete?
    assert_equal "500", @web_pay.gross
    assert_equal "123", @web_pay.item_id
  end

  def test_compositions
    assert_equal BigDecimal.new("500"), @web_pay.amount
  end

  def test_respond_to_acknowledge
    assert @web_pay.respond_to?(:acknowledge)
  end

  def test_acknowledgement
    assert @web_pay.acknowledge
  end

  def test_wrong_signature
    @web_pay = WebPay::Notification.new(http_raw_data_with_wrong_signature, :secret => 'secret')
    assert !@web_pay.acknowledge
  end

  private

  def http_raw_data
    "batch_timestamp=123&currency_id=BYR&amount=500&payment_method=test&order_id=666&site_order_id=123&transaction_id=666&payment_type=type&rrn=123&wsb_signature=9b1d56e24e5cd0a0a443276073248510"
  end

  def http_raw_data_with_wrong_signature
    "batch_timestamp=123&currency_id=BYR&amount=500&payment_method=test&order_id=666&site_order_id=123&transaction_id=666&payment_type=type&rrn=123&wsb_signature=wrong"
  end
end
