require 'test_helper'

class DirecPayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of DirecPay::Notification, DirecPay.notification('name=me', {})
  end
  
  def test_return
    assert_instance_of DirecPay::Return, DirecPay.return("name=me", {})
  end
  
  def test_status_update_instantiates_status_class
    DirecPay::Status.any_instance.expects(:update).with('authorization', 'http://localhost/return')
    DirecPay.request_status_update('mid', 'authorization', 'http://localhost/return')
  end
end 
