require 'test_helper'

class BitPayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of BitPay::Notification, BitPay.notification('{"name":"cody"}', {})
  end

  def test_return_method
    assert_instance_of BitPay::Return, BitPay.return('{"name":"cody"}', {})
  end
end
