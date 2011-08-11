require 'test_helper'

class MoneybookersModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of Moneybookers::Notification, Moneybookers.notification('name=cody', :credential2 => 'secret')
  end

  def test_service_url
    url = 'https://www.moneybookers.com/app/payment.pl'
    assert_equal url, Moneybookers.service_url
  end
end 
