require 'test_helper'

class PayinlineModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Payonline::Helper, Payonline.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Payonline::Notification, Payonline.notification('name=cody')
  end
end
