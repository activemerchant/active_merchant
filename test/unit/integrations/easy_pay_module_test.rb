require 'test_helper'

class EasyPayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of EasyPay::Helper, EasyPay.helper(123, 'test', :credential2 => 'secret')
  end

  def test_notification_method
    assert_instance_of EasyPay::Notification, EasyPay.notification('name=cody', :credential2 => '123')
  end

  def test_service_url
    url = 'https://ssl.easypay.by/weborder/'
    assert_equal url, EasyPay.service_url
  end
end
