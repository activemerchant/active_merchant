require 'test_helper'

class FasapayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Fasapay::Helper, Fasapay.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Fasapay::Notification, Fasapay.notification('name=cody')
  end
end
