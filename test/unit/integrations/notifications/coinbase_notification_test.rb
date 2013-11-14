require 'test_helper'

class CoinbaseNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @coinbase = Coinbase::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @coinbase.complete?
    assert_equal "", @coinbase.status
    assert_equal "", @coinbase.transaction_id
    assert_equal "", @coinbase.item_id
    assert_equal "", @coinbase.gross
    assert_equal "", @coinbase.currency
    assert_equal "", @coinbase.received_at
    assert @coinbase.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @coinbase.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @coinbase.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
