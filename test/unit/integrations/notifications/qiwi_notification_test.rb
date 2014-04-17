require 'test_helper'

class QiwiNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @qiwi = Qiwi::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @qiwi.complete?
    assert_equal "pay", @qiwi.status
    assert_equal "1234567", @qiwi.transaction_id
    assert_equal "4957835959", @qiwi.item_id
    assert_equal "10.45", @qiwi.gross
    assert_equal "RUR", @qiwi.currency
    assert_equal "20090815120133", @qiwi.received_at
  end

  def test_compositions
    assert_equal 10.45, @qiwi.amount
  end

  def test_acknowledgement
    assert @qiwi.acknowledge
  end

  def test_respond_to_acknowledge
    assert @qiwi.respond_to?(:acknowledge)
  end

  private

  def http_raw_data
    "command=pay&txn_id=1234567&txn_date=20090815120133&account=4957835959&sum=10.45"
  end
end
