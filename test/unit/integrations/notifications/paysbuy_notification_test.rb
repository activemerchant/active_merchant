require 'test_helper'

class PaysbuyNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_item_id
    @paysbuy = Paysbuy::Notification.new("result=00100013")
    assert_equal "100013", @paysbuy.item_id
  end

  def test_result_completed
    @paysbuy = Paysbuy::Notification.new("result=00100013")
    assert @paysbuy.complete?
    assert_equal "Completed", @paysbuy.status
  end

  def test_result_failed
    @paysbuy = Paysbuy::Notification.new("result=99100013")
    assert !@paysbuy.complete?
    assert_equal "Failed", @paysbuy.status
  end

  def test_result_pending
    @paysbuy = Paysbuy::Notification.new("result=02100013")
    assert !@paysbuy.complete?
    assert_equal "Pending", @paysbuy.status
  end
end
