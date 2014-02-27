require 'test_helper'

class UniversalModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Universal::Notification, Universal.notification('name=cody')
  end
end
