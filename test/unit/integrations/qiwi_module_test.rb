require 'test_helper'

class QiwiModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Qiwi::Notification, Qiwi.notification('name=cody')
  end
end
