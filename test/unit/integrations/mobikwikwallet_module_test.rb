require 'test_helper'

class MobikwikwalletModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    ActiveMerchant::Billing::Base.integration_mode = :test
    @merchantname = 'Test Merchant'
    @secretkey = 'ju6tygh7u7tdg554k098ujd5468o'
    @options = {
      :credential2 => @secretkey,
      :credential3 => @merchantname
    }
  end

  def test_credential_based_url_method
    ActiveMerchant::Billing::Base.integration_mode = :test
    assert_equal 'https://test.mobikwik.com/mobikwik/wallet', Mobikwikwallet.service_url
  end

  def test_production_service_url_method
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal 'https://www.mobikwik.com/wallet', Mobikwikwallet.service_url
  end

  def test_helper_method
    assert_instance_of Mobikwikwallet::Helper, Mobikwikwallet.helper('ORD01','MBK9002', @options.merge(:amount => 10))
  end

  def test_checksum_method
    mobikwik_load = "'" + "9711429252" + "''" + "kanishk@mobikwik.com" + "''" + "10" + "''" + "order-500" + "''" + "some_return_url" + "''" + "MBK9002" + "'" 
    assert_equal "bc322adccedce0f96b97aaf55282e145ad709b492ef395f771b2d2f0b3314cc6", Mobikwikwallet.checksum(@secretkey, mobikwik_load)
  end

  def test_notification_method
    assert_instance_of Mobikwikwallet::Notification, Mobikwikwallet.notification('name=cody', {})
  end

  def test_return_method
    assert_instance_of Mobikwikwallet::Return, Mobikwikwallet.return('name=foo', {})
  end

end
