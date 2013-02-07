require 'test_helper'

class EasyPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @easypay = EasyPay::Notification.new(http_raw_data, :credential2 => 'dh48djklhgl5893j')
  end

  def test_accessors
    assert @easypay.complete?
    assert_equal "100.00", @easypay.gross
    assert_equal "1000", @easypay.item_id
  end

  def test_compositions
    assert_equal BigDecimal.new("100"), @easypay.amount
  end

  def test_credential2_required
    assert_raises ArgumentError do
      EasyPay::Notification.new(http_raw_data, {})
    end

    assert_nothing_raised do
      EasyPay::Notification.new(http_raw_data, :credential2 => 'secret')
    end
  end

  def test_respond_to_acknowledge
    assert @easypay.respond_to?(:acknowledge)
  end

  def test_acknowledgement
    assert @easypay.acknowledge
  end

  def test_wrong_signature
    @easypay = EasyPay::Notification.new(http_raw_data_with_wrong_signature, :credential2 => 'dh48djklhgl5893j')
    assert !@easypay.acknowledge
  end

  private
  def http_raw_data
    "order_mer_code=1000&sum=100.00&mer_no=ok6666&card=00539900&purch_date=2006-09-11 22:45:21&notify_signature=633f711926e02eeb22fb0025c2308e75"
  end

  def http_raw_data_with_wrong_signature
    "order_mer_code=1000&sum=100.00&mer_no=ok6666&card=00539900&purch_date=2006-09-11 22:45:21&notify_signature=wrong"
  end
end
