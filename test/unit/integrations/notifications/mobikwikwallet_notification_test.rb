require 'test_helper'

class MobikwikwalletNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @mobikwikwallet = Mobikwikwallet::Notification.new(http_raw_data, :credential3 => 'ju6tygh7u7tdg554k098ujd5468o')
  end

  def test_accessors
    assert @mobikwikwallet.complete?
    assert_equal "Completed", @mobikwikwallet.status
    assert_equal "0", @mobikwikwallet.statuscode
    assert_equal "ordertest98", @mobikwikwallet.transaction_id
    assert_equal "The payment has been successfully collected", @mobikwikwallet.statusmessage
    assert_equal "200.00", @mobikwikwallet.amount
    assert_equal true, @mobikwikwallet.invoice_ok?('ordertest98')
    assert_equal true, @mobikwikwallet.amount_ok?(BigDecimal.new('200.00'))
    assert_equal "ordertest98", @mobikwikwallet.invoice
    assert_equal "00c4ffa4d6d5aa432e85ca8e389e441fa2354548c86ace496681bb52edbe629f", @mobikwikwallet.checksum
    assert_equal "The payment has been successfully collected", @mobikwikwallet.message
    assert_equal "MBK9002", @mobikwikwallet.merchantid
    assert_equal true, @mobikwikwallet.checksum_ok?
  end

  def test_compositions
    assert_equal '200.00', @mobikwikwallet.gross
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    assert @mobikwikwallet.acknowledge
  end

  def test_respond_to_acknowledge
   assert @mobikwikwallet.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "statuscode=0&orderid=ordertest98&mid=MBK9002&amount=200.00&statusmessage=The payment has been successfully collected&checksum=00c4ffa4d6d5aa432e85ca8e389e441fa2354548c86ace496681bb52edbe629f"
  end
end
