#MOLPay test scripts
require 'test_helper'

class MolpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  #Test the notification method
  def test_notification_method
    assert_instance_of Molpay::Notification, Molpay.notification('name=test5620', :credential2 => '1a2d20c7150f42e37cfe1b87879fe5cb')
  end

  #Test the service URLS
  def test_service_url
    assert_equal "https://www.onlinepayment.com.my/MOLPay/API/shopify/pay.php", Molpay.service_url
  end
end
