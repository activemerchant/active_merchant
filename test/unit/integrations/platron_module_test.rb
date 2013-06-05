require 'test_helper'

class PlatronModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Platron::Notification, Platron.notification('name=cody')
  end
end
