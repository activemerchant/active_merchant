require 'test_helper'

class WebPayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_helper_method
    assert_instance_of WebPay::Helper, WebPay.helper(123, 'test')
  end

  def test_notification_method
    assert_instance_of WebPay::Notification, WebPay.notification('name=cody')
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://secure.sandbox.webpay.by:8843', WebPay.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://secure.webpay.by', WebPay.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :winterfell
    assert_raise(StandardError){WebPay.service_url}
  end
end
