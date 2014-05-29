require 'test_helper'

class YandexMoneyModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of YandexMoney::Notification, YandexMoney.notification('name=cody')
  end
end
