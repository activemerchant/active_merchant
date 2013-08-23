require 'test_helper'

class PayboxSystemNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paybox_system = PayboxSystem::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @paybox_system.complete?
    assert_equal "00000", @paybox_system.status
    assert_equal "ABCDEFGH123456", @paybox_system.transaction_id
    assert_equal "order-500", @paybox_system.item_id
    assert_equal "500", @paybox_system.gross
    assert_equal "EUR", @paybox_system.currency
    assert @paybox_system.test?
  end

  def test_compositions
    assert_equal Money.new(@paybox_system.gross.to_i, 'EUR'), @paybox_system.amount
  end

  def test_respond_to_acknowledge
    assert @paybox_system.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "amount=500&error=00000&reference=order-500&sign=ABCDEFGH123456"
  end
end
