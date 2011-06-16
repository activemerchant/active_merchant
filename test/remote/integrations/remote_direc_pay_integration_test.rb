require 'test_helper'

class RemoteDirecPayIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = DirecPay::Helper.new('#1234', fixtures(:direc_pay)[:mid], :amount => 500, :currency => 'INR')
    @notification = DirecPay::Notification.new('test=dummy-value')
  end

  def tear_down
    ActiveMerchant::Billing::Base.integration_mode = :test
  end
  
  def test_return_is_always_acknowledged
    assert_equal "https://test.timesofmoney.com/direcpay/secure/dpMerchantTransaction.jsp", DirecPay.service_url
    assert_nothing_raised do
      assert_equal true, @notification.acknowledge
    end
  end
  
end
