require 'test_helper'

class CheckoutFinlandModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of CheckoutFinland::Notification, CheckoutFinland.notification({"VERSION" => "0001", "STAMP" => "1388998411", "REFERENCE" => "474738238", "PAYMENT" => "12288575", "STATUS" => "3", "ALGORITHM" => "3", "MAC" =>"2657BA96CC7879C79192547EB6C9D4082EA39CA52FE1DAD09CB1C632ECFDAE67"})
  end
end
