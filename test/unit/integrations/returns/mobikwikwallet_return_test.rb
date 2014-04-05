require 'test_helper'

class MobikwikwalletReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @mobikwikwallet = Mobikwikwallet::Return.new(http_raw_data_success, :credential3 => 'ju6tygh7u7tdg554k098ujd5468o')
  end

  def setup_failed_return
    @mobikwikwallet = Mobikwikwallet::Return.new(http_raw_data_canceled, :credential3 => 'ju6tygh7u7tdg554k098ujd5468o')
  end

  def setup_tampered_return
    @mobikwikwallet = Mobikwikwallet::Return.new(http_raw_data_tampered, :credential3 => 'ju6tygh7u7tdg554k098ujd5468o')
  end

  def test_success
    assert @mobikwikwallet.success?
    assert_equal 'Completed', @mobikwikwallet.status('ordertest98','200.00')
  end

  def test_failure_is_successful
    setup_failed_return
    assert_equal 'Failed', @mobikwikwallet.status('ordertest100', '200.00')
  end

  def test_tampered_is_successful
    setup_tampered_return
    assert_equal 'Tampered', @mobikwikwallet.status('ordertest98', '100.00')
  end

  def test_treat_initial_failures_as_pending
    setup_failed_return
    assert_equal 'Failed', @mobikwikwallet.notification.status
  end

  def test_return_has_notification
    notification = @mobikwikwallet.notification

    assert notification.complete?

    assert_equal "Completed", notification.status
    assert_equal "ordertest98", notification.transaction_id
    assert_equal "The payment has been successfully collected", notification.statusmessage
    assert_equal "200.00", notification.amount
    assert_equal "MBK9002", notification.merchantid
    assert_equal "0", notification.statuscode
    assert_equal true, notification.invoice_ok?('ordertest98')
    assert_equal true, notification.amount_ok?(BigDecimal.new('200.00'))
    assert_equal "ordertest98", notification.invoice
    assert_equal "00c4ffa4d6d5aa432e85ca8e389e441fa2354548c86ace496681bb52edbe629f", notification.checksum
    assert_equal "The payment has been successfully collected", notification.message
    assert_equal true, notification.checksum_ok?
  end

  private

  def http_raw_data_success
	  "statuscode=0&orderid=ordertest98&mid=MBK9002&amount=200.00&statusmessage=The payment has been successfully collected&checksum=00c4ffa4d6d5aa432e85ca8e389e441fa2354548c86ace496681bb52edbe629f"
  end

  def http_raw_data_canceled
  "statuscode=40&orderid=ordertest100&mid=MBK9002&amount=200.00&statusmessage=User cancelled Transaction&checksum=376e62537a6096898b4b8f36219f8a7bb6428f6f1759636a4a1920fb54b93289"
  end

  def http_raw_data_tampered
   "statuscode=0&orderid=ordertest98&mid=MBK9002&amount=200.00&statusmessage=The payment has been successfully collected&checksum=00c4ffa4d6d5aa432e85ca8e389e441fa2354548c86ace496681bb52edbe629f"
  end

end
