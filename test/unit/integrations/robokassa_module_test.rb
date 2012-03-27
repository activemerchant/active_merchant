require 'test_helper'

class RobokassaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Robokassa::Helper, Robokassa.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Robokassa::Notification, Robokassa.notification('name=cody')
  end

  def test_return_method
    assert_instance_of Robokassa::Return, Robokassa.return('name=cody')
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'http://test.robokassa.ru/Index.aspx', Robokassa.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://merchant.roboxchange.com/Index.aspx', Robokassa.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :bro
    assert_raise(StandardError){ Robokassa.service_url }
  end
end
