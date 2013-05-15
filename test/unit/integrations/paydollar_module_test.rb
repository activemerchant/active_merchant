require 'test_helper'

class PaydollarModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Paydollar::Notification, Paydollar.notification('Ref=Order100')
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://test.paydollar.com/b2cDemo/eng/payment/payForm.jsp', Paydollar.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://www.paydollar.com/b2c2/eng/payment/payForm.jsp', Paydollar.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :invalidmode
    assert_raise(StandardError){ Paydollar.service_url }
  end
end
