require 'test_helper'

class ValitorModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    notification = Valitor.notification('ReferenceNumber=WEB-123', :credential2 => 'password')
    assert_instance_of Valitor::Notification, notification
    assert_equal 'password', notification.instance_eval{@options}[:credential2]
    assert_equal 'WEB-123', notification.item_id
    assert notification.test?

    ActiveMerchant::Billing::Base.integration_mode = :production
    assert !Valitor.notification('ReferenceNumber=WEB-123', :credential2 => 'password').test?
  ensure
    ActiveMerchant::Billing::Base.integration_mode = :test
  end

  def test_return_method
    ret = Valitor.return('ReferenceNumber=WEB-123', :credential2 => 'password')
    assert_instance_of Valitor::Return, ret
    assert_equal 'password', ret.instance_eval{@options}[:credential2]
    assert_equal 'WEB-123', ret.item_id
    assert ret.test?

    ActiveMerchant::Billing::Base.integration_mode = :production
    assert !Valitor.return('ReferenceNumber=WEB-123', :credential2 => 'password').test?
  ensure
    ActiveMerchant::Billing::Base.integration_mode = :test
  end
  
  def test_service_url
    assert_equal "https://testgreidslusida.valitor.is/", Valitor.service_url
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert_equal "https://greidslusida.valitor.is/", Valitor.service_url
  ensure
    ActiveMerchant::Billing::Base.integration_mode = :test
  end
end 
