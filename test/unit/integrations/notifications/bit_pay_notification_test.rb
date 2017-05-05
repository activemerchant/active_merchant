require 'test_helper'

class BitPayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @bit_pay = BitPay::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @bit_pay.complete?
    assert_equal "Completed", @bit_pay.status
    assert_equal "98kui1gJ7FocK41gUaBZxG", @bit_pay.transaction_id
    assert_equal 10.00, @bit_pay.gross
    assert_equal "USD", @bit_pay.currency
    assert_equal 1370539476654, @bit_pay.received_at
    assert_equal 123, @bit_pay.item_id
  end

  def test_invalid_data
    hash = JSON.parse(http_raw_data)
    @bit_pay = BitPay::Notification.new('{"invalid":json}')

    assert @bit_pay.params.empty?
  end

  def test_item_id_invalid_json
    hash = JSON.parse(http_raw_data)
    @bit_pay = BitPay::Notification.new(hash.merge('posData' => 'Invalid JSON').to_json)

    assert_nil @bit_pay.item_id
  end

  def test_compositions
    assert_equal Money.new(1000, 'USD'), @bit_pay.amount
  end

  def test_successful_acknowledgement
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => http_raw_data))
    assert @bit_pay.acknowledge
  end

  def test_acknowledgement_error
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{"error":"Doesnt match"}'))
    assert !@bit_pay.acknowledge
  end

  def test_acknowledgement_invalid_json
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{invalid json'))
    assert !@bit_pay.acknowledge
  end

  private
  def http_raw_data
    {
      "id"=>"98kui1gJ7FocK41gUaBZxG",
      "orderID"=>"123",
      "url"=>"https://bitpay.com/invoice/98kui1gJ7FocK41gUaBZxG",
      "status"=>"complete",
      "btcPrice"=>"0.0295",
      "price"=>"10.00",
      "currency"=>"USD",
      "invoiceTime"=>"1370539476654",
      "expirationTime"=>"1370540376654",
      "currentTime"=>"1370539573956",
      "posData" => '{"orderId":123}'
    }.to_json
  end
end
