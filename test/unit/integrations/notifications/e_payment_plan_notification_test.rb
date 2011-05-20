require 'test_helper'

class EPaymentPlanNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @e_payment_plan = EPaymentPlan::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @e_payment_plan.complete?
    assert_equal "completed", @e_payment_plan.status
    assert_equal "12345", @e_payment_plan.order_id
    assert_equal "2011-05-24 23:55:52 UTC", @e_payment_plan.received_at
    assert_equal "789123456", @e_payment_plan.transaction_id
    assert_equal "xxxxxxxxxx", @e_payment_plan.security_key
    assert @e_payment_plan.test?
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement
    EPaymentPlan::Notification.any_instance.stubs(:ssl_post).returns('AUTHORISED')
    assert @e_payment_plan.acknowledge

    EPaymentPlan::Notification.any_instance.stubs(:ssl_post).returns('DECLINED')
    assert !@e_payment_plan.acknowledge
  end

  def test_respond_to_acknowledge
    assert @e_payment_plan.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "received_at=2011-05-24 23:55:52 UTC&status=completed&order_id=12345&transaction_id=789123456&security_key=xxxxxxxxxx&test=test"
  end
end
