require 'test_helper'


class DwollaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Dwolla::Notification, Dwolla.notification('{"OrderId":"order-1", "Result": "Error", "Message": "Invalid Credentials", "TestMode":true}')
  end

  def test_return
    assert_instance_of Dwolla::Return, Dwolla.return("dwolla=awesome")
  end
end 
