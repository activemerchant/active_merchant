require 'test_helper'

class PaxumModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Paxum::Helper, Paxum.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Paxum::Notification, Paxum.notification('name=cody')
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://paxum.com/payment/phrame.php?action=displayProcessPaymentLogin', Paxum.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://paxum.com/payment/phrame.php?action=displayProcessPaymentLogin', Paxum.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :bro
    assert_raise(StandardError){Paxum.service_url}
  end
end
