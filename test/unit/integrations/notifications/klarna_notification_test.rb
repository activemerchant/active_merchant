require 'test_helper'

class KlarnaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @klarna = Klarna::Notification.new(http_raw_data)
  end

  def test_accessors
    skip "Implement once we have a remote test harness for Klarna"
    assert @klarna.complete?
    assert_equal "", @klarna.status
    assert_equal "", @klarna.transaction_id
    assert_equal "", @klarna.item_id
    assert_equal "", @klarna.gross
    assert_equal "", @klarna.currency
    assert_equal "", @klarna.received_at
    assert @klarna.test?
  end

  def test_compositions
    skip "Implement once we have a remote test harness for Klarna"
    assert_equal Money.new(3166, 'USD'), @klarna.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    skip "Implement once we have a remote test harness for Klarna"
    assert @klarna.respond_to?(:acknowledge)
  end

  private
  
  def http_raw_data
    ""
  end
end
