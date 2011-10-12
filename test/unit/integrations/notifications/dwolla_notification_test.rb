require 'test_helper'

class DwollaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @error_dwolla = Dwolla::Notification.new(http_raw_error_data)
    @dwolla = Dwolla::Notification.new(http_raw_success_data)
  end

  def test_success_accessors
    assert @dwolla.complete?
    assert_equal "1234asdfasd567", @dwolla.item_id
    assert_equal "Completed", @dwolla.status
    assert_equal 1.00, @dwolla.gross
    assert_equal "USD", @dwolla.currency
    assert @dwolla.test?
  end

  def test_error_accessors
    assert_false @error_dwolla.complete?
    assert_equal "order-1", @error_dwolla.item_id
    assert_equal nil, @error_dwolla.status
    assert_equal nil, @error_dwolla.gross
    assert_equal "USD", @error_dwolla.currency
    assert_equal "Invalid Credentials", @error_dwolla.error
    assert @error_dwolla.test?
  end

  def test_compositions
    assert_equal Money.new(100, 'USD'), @dwolla.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement    
    assert_equal true, @dwolla.acknowledge
  end

  def test_respond_to_acknowledge
    assert @dwolla.respond_to?(:acknowledge)
  end

  def test_raw_should_be_set
    assert @dwolla.raw.present?
  end

  private
  def http_raw_error_data
    %*{"OrderId":"order-1", "Result": "Error", "Message": "Invalid Credentials", "TestMode":true}*
  end

  def http_raw_success_data
    %*{"Amount":1.0, "OrderId":"1234asdfasd567", "Status":"Completed", "TransactionId":null, "TestMode":true}*
  end
end
