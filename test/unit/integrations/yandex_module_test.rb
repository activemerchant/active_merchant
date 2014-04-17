require 'test_helper'

class YandexModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Yandex::Notification, Yandex.notification('name=cody')
  end
end
