require 'test_helper'

class FocalPaymentModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of FocalPayment::Helper, FocalPayment.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of FocalPayment::Notification, FocalPayment.notification('name=cody')
  end
end
