require 'test_helper'

class UniversalNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @universal = Universal::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @universal.complete?
    assert_equal "", @universal.status
    assert_equal "", @universal.transaction_id
    assert_equal "", @universal.item_id
    assert_equal "", @universal.gross
    assert_equal "", @universal.currency
    assert_equal "", @universal.received_at
    assert @universal.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @universal.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @universal.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
