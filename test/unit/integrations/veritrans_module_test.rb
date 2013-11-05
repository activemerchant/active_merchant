require 'test_helper'

class VeritransModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Veritrans::Notification, Veritrans.notification('{"name":"cody"}')
  end
end
