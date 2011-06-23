require 'test_helper'

class EPaymentPlansModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of EPaymentPlans::Notification, EPaymentPlans.notification('name=cody')
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://test.epaymentplans.com/order/purchase', EPaymentPlans.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://www.epaymentplans.com/order/purchase', EPaymentPlans.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :coolmode
    assert_raise(StandardError){ EPaymentPlans.service_url }
  end
end
