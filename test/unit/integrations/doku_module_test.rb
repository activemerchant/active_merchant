require 'test_helper'

class DokuModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Doku::Notification, Doku.notification('TRANSIDMERCHANT=ORD12345&AMOUNT=165000&RESULT=Success')
  end
end
