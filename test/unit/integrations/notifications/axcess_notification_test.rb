require 'test_helper'

class AxcessNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @axcess = Axcess::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @axcess.complete?
    assert_equal "", @axcess.status
    assert_equal "", @axcess.transaction_id
    assert_equal "", @axcess.item_id
    assert_equal "", @axcess.gross
    assert_equal "", @axcess.currency
    assert_equal "", @axcess.received_at
    assert @axcess.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @axcess.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @axcess.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
