require 'test_helper'

class WirecardCheckoutPageModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of WirecardCheckoutPage::Notification, WirecardCheckoutPage.notification('name=cody', {})
  end
end
