require 'test_helper'

class DengionlineModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Dengionline::Helper, Dengionline.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Dengionline::Notification, Dengionline.notification('name=cody')
  end

  def test_service_url
    assert_equal 'http://www.onlinedengi.ru/wmpaycheck.php', Dengionline.service_url
  end
end
