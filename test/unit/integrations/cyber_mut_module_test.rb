require 'test_helper'

class CyberMutModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of CyberMut::Notification, CyberMut.notification('name=cody')
  end
end
