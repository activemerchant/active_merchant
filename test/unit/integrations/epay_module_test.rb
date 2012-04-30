require 'test_helper'

class EpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Epay::Notification, Epay.notification('name=cody', {})
  end
end 
