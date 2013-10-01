require 'test_helper'

class MolpayModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_return_method
    assert_instance_of Molpay::Return, Molpay.return('name=eddy')
  end

  def test_service_url
    assert_equal "https://www.onlinepayment.com.my/MOLPay/API/shopify/pay.php", Molpay.service_url
  end
end
