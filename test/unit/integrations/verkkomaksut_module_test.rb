require 'test_helper'

class VerkkomaksutModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Verkkomaksut::Notification, Verkkomaksut.notification({"ORDER_NUMBER"=>"2", "TIMESTAMP"=>"1336058061", "PAID"=>"3DF5BB7E26", "METHOD"=>"4", "RETURN_AUTHCODE"=>"6B40F9B939D03EFE7573D61708FA4126"})
  end
end 
