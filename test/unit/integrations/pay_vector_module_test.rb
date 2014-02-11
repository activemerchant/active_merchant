require 'test_helper'

class PayVectorModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of PayVector::Notification, PayVector.notification('name=Walter White', {})
  end
end
