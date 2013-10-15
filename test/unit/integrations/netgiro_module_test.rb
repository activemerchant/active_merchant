require 'test_helper'

class NetgiroModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    notification = Netgiro.notification('orderid=WEB-123', :credential2 => 'password')
    assert_instance_of Netgiro::Notification, notification
    assert_equal 'password', notification.instance_eval{@options}[:credential2]
    assert_equal 'WEB-123', notification.item_id
  ensure
    ActiveMerchant::Billing::Base.integration_mode = :test
  end

  def test_return_method
    ret = Netgiro::Return.new('orderid=WEB-123', :credential2 => 'password')
    assert_instance_of Netgiro::Return, ret
    assert_equal 'password', ret.instance_eval{@options}[:credential2]
    assert_equal 'WEB-123', ret.item_id
  ensure
    ActiveMerchant::Billing::Base.integration_mode = :test
  end

  def test_service_url
    assert_equal "http://test.netgiro.is/user/securepay", Netgiro.service_url
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal "https://www.netgiro.is/SecurePay", Netgiro.service_url
  ensure
    ActiveMerchant::Billing::Base.integration_mode = :test
  end
end 
