require 'test_helper'

class CcavenueTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Ccavenue::Notification, Ccavenue.notification({"Merchant_Id"=>"M_demo1_1828","Order_Id"=>"2", "Checksum"=>"1336058061", "Amount"=>"100", "AuthDesc"=>"N" })
  end
end 
