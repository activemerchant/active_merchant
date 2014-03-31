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

  def test_acknowledge_valid_signature
    assert @notification.acknowledge
  end

  def test_acknowledge_valid_uppercase_signature
    @notification = Universal::Notification.new(http_raw_data_uppercase_signature, :credential2 => @secret)

    assert @notification.acknowledge
  end

  def test_acknowledge_invalid_signature
    @notification = Universal::Notification.new(http_raw_data_invalid_signature, :credential2 => @secret)

    assert !@notification.acknowledge
  end

  private

  def http_raw_data
    'x_account_id=zork&x_reference=order-500&x_currency=USD&x_test=true&x_amount=123.45&x_gateway_reference=blorb123&x_timestamp=2014-03-24T12:15:41Z&x_result=completed&x_signature=d8797220f2f0ccef90c1ee80e82494cd709fb10ab1f50a016578208c3fb5a0c1'
  end

  def http_raw_data_uppercase_signature
    'x_account_id=zork&x_reference=order-500&x_currency=USD&x_test=true&x_amount=123.45&x_gateway_reference=blorb123&x_timestamp=2014-03-24T12:15:41Z&x_result=completed&x_signature=D8797220F2F0CCEF90C1EE80E82494CD709FB10AB1F50A016578208C3FB5A0C1'
  end

  def http_raw_data_invalid_signature
    'x_account_id=zork&x_reference=order-500&x_currency=USD&x_test=true&x_amount=123.45&x_gateway_reference=blorb123&x_timestamp=2014-03-24T12:15:41Z&x_result=completed&x_signature=d8797220f2f0ccef90c1ee80e82494cd709fb10ab1f50a016578208c3fb5a0c2'
  end
end
