require 'test_helper'

class WebmoneyModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of Webmoney::Helper, Webmoney.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of Webmoney::Notification, Webmoney.notification('name=cody')
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal "https://merchant.webmoney.ru/lmi/payment.asp", Webmoney.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal "https://merchant.webmoney.ru/lmi/payment.asp", Webmoney.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :bro
    assert_raise(StandardError){Webmoney.service_url}
  end
end
