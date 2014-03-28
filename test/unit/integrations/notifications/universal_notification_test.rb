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
    'x_account_id=zork&x_reference=order-500&x_currency=USD&x_test=true&x_amount=123.45&x_gateway_reference=blorb123&x_timestamp=2014-03-24T12:15:41Z&x_result=success&x_signature=4365fef32f5309845052b728c8cbe962e583ecaf62bf1cdec91f248162b7f65e'
  end

  def http_raw_data_uppercase_signature
    'x_account_id=zork&x_reference=order-500&x_currency=USD&x_test=true&x_amount=123.45&x_gateway_reference=blorb123&x_timestamp=2014-03-24T12:15:41Z&x_result=success&x_signature=4365FEF32F5309845052B728C8CBE962E583ECAF62BF1CDEC91F248162B7F65E'
  end

  def http_raw_data_invalid_signature
    'x_account_id=zork&x_reference=order-500&x_currency=USD&x_test=true&x_amount=123.45&x_gateway_reference=blorb123&x_timestamp=2014-03-24T12:15:41Z&x_result=success&x_signature=4365fef32f5309845052b728c8cbe962e583ecaf62bf1cdec91f248162b7f65f'
  end

end
