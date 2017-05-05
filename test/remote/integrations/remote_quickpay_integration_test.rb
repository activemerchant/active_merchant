require 'test_helper'

class RemoteQuickPayIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @quickpay = Quickpay::Notification.new('')
  end

  def tear_down
    ActiveMerchant::Billing::Base.integration_mode = :test
  end

  def test_raw
    assert_equal "https://secure.quickpay.dk/form/", Quickpay.service_url
    assert_nothing_raised do
      assert_equal false, @quickpay.acknowledge
    end
  end

  def test_valid_sender_always_true
    ActiveMerchant::Billing::Base.integration_mode = :production
    assert @quickpay.valid_sender?(nil)
    assert @quickpay.valid_sender?('127.0.0.1')
  end
end
