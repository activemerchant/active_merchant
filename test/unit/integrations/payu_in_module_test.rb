require 'test_helper'

class PayuInModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    ActiveMerchant::Billing::Base.integration_mode = :test
    @merchant_id = 'merchant_id'
    @secret_key = 'secret'
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
    payu_load = "order_id|10.00|Product Info|Payu-Admin|test@example.com||||||||||"
    checksum = Digest::SHA512.hexdigest([@merchant_id, payu_load, @secret_key].join("|"))
    assert_equal checksum, PayuIn.checksum(@merchant_id, @secret_key, payu_load.split("|", -1))
  end
end
