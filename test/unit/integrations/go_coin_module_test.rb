require 'test_helper'

class GoCoinModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of GoCoin::Notification, GoCoin.notification('name=cody')
  end
end
