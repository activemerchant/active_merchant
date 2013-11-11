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
  end

  def test_compositions
    assert_equal Money.new(1000, 'USD'), @bit_pay.amount
  end

  def test_successful_acknowledgement
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => http_raw_data))
    assert @bit_pay.acknowledge
  end

  def test_failed_acknowledgement
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{"error":"Doesnt match"}'))
    exception = assert_raise StandardError do
      @bit_pay.acknowledge
    end
    assert_equal 'Faulty BitPay result: {"error":"Doesnt match"}', exception.message
  end

  private
  def http_raw_data
    {
      "id"=>"98kui1gJ7FocK41gUaBZxG",
      "orderID"=>"123",
      "url"=>"https://bitpay.com/invoice/98kui1gJ7FocK41gUaBZxG",
      "status"=>"confirmed",
      "btcPrice"=>"0.0295",
      "price"=>"10.00",
      "currency"=>"USD",
      "invoiceTime"=>"1370539476654",
      "expirationTime"=>"1370540376654",
      "currentTime"=>"1370539573956",
      "posData" => "custom"
    }.to_json
  end
end
