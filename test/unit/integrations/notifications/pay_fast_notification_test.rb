require 'test_helper'

class PayFastNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @pay_fast = PayFast::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @pay_fast.complete?
    assert_equal "46591", @pay_fast.transaction_id
    assert_equal "COMPLETE", @pay_fast.status
    assert_equal "Name", @pay_fast.item_name
    assert_equal "123.00", @pay_fast.gross
    assert_equal "-2.80", @pay_fast.fee
    assert_equal "120.20", @pay_fast.amount
    assert_equal "10000100", @pay_fast.merchant_id
  end

  def test_acknowledgement
    PayFast::Notification.any_instance.stubs(:ssl_post).returns('VALID')
    assert @pay_fast.acknowledge

    PayFast::Notification.any_instance.stubs(:ssl_post).returns('INVALID')
    assert !@pay_fast.acknowledge
  end

  def test_send_acknowledgement
    PayFast::Notification.any_instance.expects(:ssl_post).with(
      PayFast.validate_service_url,
      @pay_fast.notify_signature_string,
      { 'Content-Type' => 'application/x-www-form-urlencoded',
        'Content-Length' => "#{@pay_fast.notify_signature_string.size}" }
    ).returns('VALID')

    assert @pay_fast.acknowledge
  end

  def test_payment_successful_status
    notification = PayFast::Notification.new('payment_status=COMPLETED')
    assert_equal 'COMPLETED', notification.status
  end

  def test_payment_pending_status
    notification = PayFast::Notification.new('payment_status=PENDING')
    assert_equal 'PENDING', notification.status
  end

  def test_payment_failure_status
    notification = PayFast::Notification.new('payment_status=FAILED')
    assert_equal 'FAILED', notification.status
  end

  def test_respond_to_acknowledge
    assert @pay_fast.respond_to?(:acknowledge)
  end

  private

  def http_raw_data
    "m_payment_id=&pf_payment_id=46591&payment_status=COMPLETE&item_name=Name&item_description=&amount_gross=123.00&amount_fee=-2.80&amount_net=120.20&custom_str1=&custom_str2=&custom_str3=&custom_str4=&custom_str5=&custom_int1=&custom_int2=&custom_int3=&custom_int4=&custom_int5=&name_first=Test&name_last=User+01&email_address=sbtu01%40payfast.co.za&merchant_id=10000100&signature=bae21e96d4dc7bf36bd1a6bb1a103f5f"
  end
end
