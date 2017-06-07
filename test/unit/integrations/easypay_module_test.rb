require 'test_helper'

class EasypayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Easypay::Helper, Easypay.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Easypay::Notification, Easypay.notification('name=cody')
  end

  def test_service_url
    url = 'https://ssl.easypay.by/weborder/'
    assert_equal url, Easypay.service_url
  end
end
