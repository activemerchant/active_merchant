require 'test_helper'

class UniversalNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @secret = 'TO78ghHCfBQ6ZBw2Q2fJ3wRwGkWkUHVs'
    @notification = Universal::Notification.new(http_raw_data, :credential2 => @secret)
  end

  def test_accessors
    assert_equal 'order-500', @notification.item_id
    assert_equal 'USD', @notification.currency
    assert_equal '123.45', @notification.gross
    assert_equal 'blorb123', @notification.transaction_id
    assert_equal 'Completed', @notification.status
    assert @notification.test?
  end

  def test_compositions
    assert_equal Money.new(12345, 'USD'), @notification.amount
  end

  def test_acknowledge
    assert @notification.acknowledge
  end

  def test_acknowledge_invalid_signature
    @notification = Universal::Notification.new(http_raw_data_invalid_signature, :credential2 => @secret)
    assert !@notification.acknowledge
  end

  private

  def http_raw_data
    'x-account-id=zork&x-reference=order-500&x-currency=USD&x-test=true&x-amount=123.45&x-gateway-reference=blorb123&x-timestamp=2014-03-24T12:15:41Z&x-result=success&x-signature=2859972ffaf1276bad5b7c2009fa55fff111c87946fcd0a32eb5c51601b4e68d'
  end

  def http_raw_data_invalid_signature
    'x-account-id=zork&x-reference=order-500&x-currency=USD&x-test=true&x-amount=123.45&x-gateway-reference=blorb123&x-timestamp=2014-03-24T12:15:41Z&x-result=success&x-signature=2859972ffaf1276bad5b7c2009fa55fff111c87946fcd0a32eb5c51601b4e68e'
  end

end
