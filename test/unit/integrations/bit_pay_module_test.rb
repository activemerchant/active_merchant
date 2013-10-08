require 'test_helper'

class BitPayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of BitPay::Notification, BitPay.notification('name=cody')
  end
end
