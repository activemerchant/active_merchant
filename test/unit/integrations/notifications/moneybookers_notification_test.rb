require 'test_helper'

class MoneybookersNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @moneybookers = Moneybookers::Notification.new(http_raw_data, :credential2 => 'secret')
  end

  def test_accessors
    assert @moneybookers.complete?
    assert_equal "2", @moneybookers.status
    assert_equal "1005", @moneybookers.transaction_id
    assert_equal nil, @moneybookers.item_id
    assert_equal "25.46", @moneybookers.gross
    assert_equal "GBP", @moneybookers.currency
    assert_equal nil, @moneybookers.received_at
  end

  def test_compositions
    assert_equal Money.new(2546, 'GBP'), @moneybookers.amount
  end
  
  def test_respond_to_acknowledge
    assert @moneybookers.respond_to?(:acknowledge)
  end

  def test_credential2_required
    assert_raises ArgumentError do
      Moneybookers::Notification.new(http_raw_data, {})
    end
    assert_nothing_raised do
      Moneybookers::Notification.new(http_raw_data, :credential2 => 'secret')
    end
  end
  
  private
  def http_raw_data
    "pay_to_email=merchant@merchant.com&pay_from_email=payer@moneybookers.com&merchant_id=100005&mb_transaction_id=200234&transaction_id=1005&mb_amount=25.46&mb_currency=GBP&status=2&md5sig=327638C253A4637199CEBA6642371F20&amount=39.60&currency=EUR"
  end  
end
