require 'test_helper'

class PayzaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Payza::Notification, Payza.notification('name=cody')
  end
end
