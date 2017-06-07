require 'test_helper'

class RedDotPaymentModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_service_url
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'http://test.reddotpayment.com/merchant/cgi-bin', RedDotPayment.service_url

    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://connect.reddotpayment.com/merchant/cgi-bin-live', RedDotPayment.service_url
  end

  def test_helper_method
    assert_instance_of RedDotPayment::Helper, RedDotPayment.helper('reddot', 'test', {credential2: 123, credential3: 123})
  end

  def test_return_method
    assert_instance_of RedDotPayment::Return, RedDotPayment.return('order_number=123', {account: 'Merchant2', credential3: 12345})
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :unknown
    assert_raise(StandardError) { RedDotPayment.service_url }
  end
end
