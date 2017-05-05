require 'test_helper'

class DwollaNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @error_dwolla = Dwolla::Notification.new(http_raw_error_data, {:credential3 => '62hdv0jBjsBlD+0AmhVn9pQuULSC661AGo2SsksQTpqNUrff7Z'})
    @success = Dwolla::Notification.new(http_raw_success_data, {:credential3 => '62hdv0jBjsBlD+0AmhVn9pQuULSC661AGo2SsksQTpqNUrff7Z'})
  end

  def test_success_accessors
    assert @success.complete?
    assert_equal "abc123", @success.item_id
    assert_equal "Completed", @success.status
    assert_equal 0.01, @success.gross
    assert_equal "USD", @success.currency
    assert_false @success.test?
  end

  def test_error_accessors
    assert_false @error_dwolla.complete?
    assert_equal "abc123", @error_dwolla.item_id
    assert_equal "Failed", @error_dwolla.status
    assert_equal 300.00, @error_dwolla.gross
    assert_equal "USD", @error_dwolla.currency
    assert_equal "Insufficient funds exist to complete the transaction.", @error_dwolla.error
    assert_false @error_dwolla.test?
  end

  def test_compositions
    assert_equal Money.new(1, 'USD'), @success.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement    
    assert_equal true, @success.acknowledge
  end

  def test_respond_to_acknowledge
    assert @success.respond_to?(:acknowledge)
  end

  def test_raw_should_be_set
    assert @success.raw.present?
  end

  private

  def http_raw_error_data
    %*{"Amount":300.00,"OrderId":"abc123","Status":"Failed","Error":"Insufficient funds exist to complete the transaction.","TransactionId":null,"CheckoutId":"a6129f18-2932-4c4f-ac36-4363aa2bd19b","Signature":"641ac3fb80566eb33c5f6bf3db282a8c9f912a71","TestMode":"false","ClearingDate":""}*
  end

  def http_raw_success_data
    %*{"Amount":0.01,"OrderId":"abc123","Status":"Completed","Error":null,"TransactionId":3165397,"CheckoutId":"ac5b910a-7ec1-4b65-9f68-90449ed030f6","Signature":"7d4c5deaf9178faae7c437fd8693fc0b97b1b22b","TestMode":"false","ClearingDate":"6/8/2013 8:07:41 PM"}*
  end
end
