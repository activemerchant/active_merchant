require 'test_helper'

class CoinbaseNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @coinbase = Coinbase::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @coinbase.complete?
    assert_equal "completed", @coinbase.status
    assert_equal "ABC123", @coinbase.transaction_id
    assert_equal "test123", @coinbase.item_id
    assert_equal 1.00, @coinbase.gross
    assert_equal "USD", @coinbase.currency
    assert_equal 0, @coinbase.received_at
  end

  def test_acknowledgement
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => http_raw_data))
    assert @coinbase.acknowledge
  end

  def test_respond_to_acknowledge
    assert @coinbase.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    '{"order":{"id":"ABC123","custom":"test123","created_at":"1970-01-01T00:00:00Z","total_native":{"cents":100,"currency":"USD"},"status":"completed"}}'
  end
end
