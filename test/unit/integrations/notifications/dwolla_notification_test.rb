require 'test_helper'

class DwollaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @error_dwolla = Dwolla::Notification.new(http_raw_error_data, {:credential3 => 'mysecret'})
    @dwolla = Dwolla::Notification.new(http_raw_success_data, {:credential3 => 'mysecret'})
  end

  def test_success_accessors
    assert @dwolla.complete?
    assert_equal "1234asdfasd567", @dwolla.item_id
    assert_equal "Completed", @dwolla.status
    assert_equal 0.01, @dwolla.gross
    assert_equal "USD", @dwolla.currency
    assert @dwolla.test?
  end

  def test_error_accessors
    assert_false @error_dwolla.complete?
    assert_equal "order-1", @error_dwolla.item_id
    assert_equal "Failed", @error_dwolla.status
    assert_equal 0.01, @error_dwolla.gross
    assert_equal "USD", @error_dwolla.currency
    assert_equal "Invalid Credentials", @error_dwolla.error
    assert @error_dwolla.test?
  end

  def test_compositions
    assert_equal Money.new(1, 'USD'), @dwolla.amount
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
    %*{"Amount": 0.01, "CheckoutId": "f32b1e55-9612-4b6d-90f9-1c1519e588da", "ClearingDate": "8/28/2012 3:17:18 PM", "Error": "Invalid Credentials", "OrderId": "order-1", "Signature": "098d3f32654bd8eebc9db323228879fa2ea12459", "Status": "Failed", "TestMode": "false", "TransactionId": 1312616}*
  end

  def http_raw_success_data
    %*{"Amount": 0.01, "CheckoutId": "f32b1e55-9612-4b6d-90f9-1c1519e588da", "ClearingDate": "8/28/2012 3:17:18 PM", "Error": null, "OrderId": "1234asdfasd567", "Signature": "098d3f32654bd8eebc9db323228879fa2ea12459", "Status": "Completed", "TestMode": "false", "TransactionId": 1312616}*
  end
end
