require 'test_helper'

class PayuInModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    ActiveMerchant::Billing::Base.integration_mode = :test
    ActiveMerchant::Billing::Integrations::PayuIn.merchant_id = 'C0Dr8m'
    ActiveMerchant::Billing::Integrations::PayuIn.secret_key = '3sf0jURk'
  end

  def test_merchant_id_and_secret_key    
    assert_equal 'C0Dr8m', PayuIn.merchant_id    
    assert_equal '3sf0jURk', PayuIn.secret_key
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

  def test_checksum_method
    payu_load = "4ba4afe87f7e73468f2a|10.00|Product Info|Payu-Admin|test@example.com||||||||||"
    assert_equal "cd324f64891b07d95492a2fd80ae469092e302faa3d3df5ba1b829936fd7497b6e89c3e48fd70e2a131cdd4f17d14bc20f292e9408650c085bc3bedb32f44266", PayuIn.checksum(PayuIn.merchant_id, PayuIn.secret_key, payu_load)
  end
end
