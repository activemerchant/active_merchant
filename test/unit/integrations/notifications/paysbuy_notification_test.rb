require 'test_helper'

class PaysbuyNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paysbuy = Paysbuy::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @paysbuy.complete?
    assert_equal "Completed", @paysbuy.status
    assert_equal "100013", @paysbuy.item_id
  end

  private

  def http_raw_data
    "result=00100013"
  end
end
