require 'test_helper'

class PayboxSystemModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of PayboxSystem::Notification, PayboxSystem.notification('name=cody')
  end
end
