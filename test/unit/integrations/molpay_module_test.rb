require 'test_helper'

class MolpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Molpay::Notification, Molpay.notification('name=cody')
  end

  def test_return_method
    assert_instance_of Molpay::Return, Molpay.return('name=cody')
  end

  def test_acknowledge_url
    assert_equal 'https://www.onlinepayment.com.my/MOLPay/API/chkstat/returnipn.php', Molpay.acknowledge_url
  end
end
