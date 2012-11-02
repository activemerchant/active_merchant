require 'test_helper'

class LiqpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Liqpay::Helper, Liqpay.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Liqpay::Notification, Liqpay.notification('name=cody')
  end
end
