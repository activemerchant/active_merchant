require 'test_helper'

class RobokassaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @robokassa = Robokassa::Notification.new(http_raw_data, :secret => 'secret')
  end

  def test_accessors
    assert @robokassa.complete?
    assert_equal "500", @robokassa.gross
    assert_equal "123", @robokassa.item_id
  end

  def test_compositions
    assert_equal Money.new(50000, 'USD'), @robokassa.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    assert @robokassa.acknowledge
  end

  def test_respond_to_acknowledge
    assert @robokassa.respond_to?(:acknowledge)
  end

  def test_wrong_signature
    @robokassa = Robokassa::Notification.new(http_raw_data_with_wrong_signature, :secret => 'secret')
    assert !@robokassa.acknowledge
  end

  private
  def http_raw_data
    "InvId=123&OutSum=500&SignatureValue=4a827a06c6e54595c2bd8f67fb7a0091&shpMySuperParam=456&shpa=123"
  end

  def http_raw_data_with_wrong_signature
    "InvId=123&OutSum=500&SignatureValue=wrong&shpMySuperParam=456&shpa=123"
  end
end
