require 'test_helper'

class A1agregatorModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of A1agregator::Notification, A1agregator.notification('name=cody')
  end
end
