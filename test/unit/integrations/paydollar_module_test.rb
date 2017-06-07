require 'test_helper'

class PaydollarModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Paydollar::Notification, Paydollar.notification("prc=0&src=0&Ord=12345678&Ref=Order_PD_1000&PayRef=1151801&successcode=0&Amt=100.94&Cur=344&Holder=testing card&AuthId=151801&AlertCode=R14&remark=&eci=07&payerAuth=U&sourceIp=192.168.1.100&ipCountry=IN&payMethod=Master&TxTime=2013-06-05 20:25:38.0&panFirst4=5422&panLast4=0007&cardIssuingCountry=HK&channelType=SPC&MerchantId=1234&secureHash=13093E844878D1C40107681B02A0BEE9BD99146D")
  end

  def test_test_mode
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://test.paydollar.com/b2cDemo/eng/payment/payForm.jsp', Paydollar.service_url
  end

  def test_production_mode
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://www.paydollar.com/b2c2/eng/payment/payForm.jsp', Paydollar.service_url
  end

  def test_invalid_mode
    ActiveMerchant::Billing::Base.integration_mode = :invalidmode
    assert_raise(StandardError){ Paydollar.service_url }
  end
end
