require 'test_helper'

class DirecPayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of DirecPay::Notification, DirecPay.notification('name=me')
  end  
end 
