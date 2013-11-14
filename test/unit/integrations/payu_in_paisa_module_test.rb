require 'test_helper'

class PayuInPaisaModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    ActiveMerchant::Billing::Base.integration_mode = :test
  end

  def test_service_url_method
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal "https://test.payu.in/_payment.php", PayuIn.service_url

    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal "https://secure.payu.in/_payment.php", PayuIn.service_url
  end

  def test_return_method
    assert_instance_of PayuIn::Return, PayuIn.return('name=foo', {})
  end

  def test_notification_method
    assert_instance_of PayuIn::Notification, PayuIn.notification('name=foo', {})
  end
end
