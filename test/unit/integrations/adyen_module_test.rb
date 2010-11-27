require 'test_helper'

class AdyenModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Adyen::Notification, Adyen.notification('name=cody')
  end
end 
