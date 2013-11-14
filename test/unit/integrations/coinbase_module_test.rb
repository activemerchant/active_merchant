require 'test_helper'

class CoinbaseModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_notification_method
    assert_instance_of Coinbase::Notification, Coinbase.notification('{"name":"cody"}')
  end
end
