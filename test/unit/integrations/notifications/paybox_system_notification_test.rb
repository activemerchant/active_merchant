require 'test_helper'

class PayboxSystemNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paybox_system = PayboxSystem::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @paybox_system.complete?
    assert_equal "", @paybox_system.status
    assert_equal "", @paybox_system.transaction_id
    assert_equal "", @paybox_system.item_id
    assert_equal "", @paybox_system.gross
    assert_equal "", @paybox_system.currency
    assert_equal "", @paybox_system.received_at
    assert @paybox_system.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @paybox_system.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @paybox_system.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
