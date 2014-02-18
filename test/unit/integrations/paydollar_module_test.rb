require 'test_helper'

class PaydollarModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method 
    assert_instance_of Paydollar::Notification, Paydollar::Notification.new(nil, options = {:credential2 => "", :hasSecureHashEnabled => false})
  end
end
