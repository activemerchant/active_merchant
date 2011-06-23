require 'test_helper'

class EPaymentPlansNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @e_payment_plan = EPaymentPlans::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @e_payment_plan.complete?
    assert_equal "Completed", @e_payment_plan.status
    assert_equal "12345", @e_payment_plan.item_id
    assert_equal "35.52", @e_payment_plan.gross
    assert_equal "USD", @e_payment_plan.currency
    assert_equal Time.utc(2011,05,24,23,55,52), @e_payment_plan.received_at
    assert_equal "789123456", @e_payment_plan.transaction_id
    assert_equal "xxxxxxxxxx", @e_payment_plan.security_key
    assert @e_payment_plan.test?
  end

  def test_acknowledgement
    EPaymentPlans::Notification.any_instance.stubs(:ssl_post).returns('AUTHORISED')
    assert @e_payment_plan.acknowledge

    EPaymentPlans::Notification.any_instance.stubs(:ssl_post).returns('DECLINED')
    assert !@e_payment_plan.acknowledge
  end

  private
  def http_raw_data
    "received_at=2011-05-24 23:55:52 UTC&status=completed&item_id=12345&transaction_id=789123456&security_key=xxxxxxxxxx&currency=USD&gross=35.52&test=test"
  end
end
