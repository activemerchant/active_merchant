require 'test_helper'

class PaysbuyModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Paysbuy::Notification, Paysbuy.notification('name=cody')
  end
end
