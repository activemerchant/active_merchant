require 'test_helper'

class AxcessModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Axcess::Notification, Axcess.notification('name=cody')
  end
end
