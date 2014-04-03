require 'test_helper'

class PagSeguroModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of PagSeguro::Notification, PagSeguro.notification('name=cody')
  end
end
