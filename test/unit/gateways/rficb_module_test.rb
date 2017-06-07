require 'test_helper'

class RficbModuleTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def test_notification_method
    assert_instance_of Rficb::Notification, Rficb.notification('name=cody')
  end
end
