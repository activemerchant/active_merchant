require 'test_helper'

class A1agregatorNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @a1agregator = A1agregator::Notification.new(http_raw_data, :secret => 'some_secret')
  end

  def test_accessors
    assert @a1agregator.complete?
    assert_equal "132", @a1agregator.transaction_id
    assert_equal "ProductName", @a1agregator.title
    assert_equal "Comment", @a1agregator.comment
    assert_equal "234", @a1agregator.partner_id
    assert_equal "345", @a1agregator.service_id
    assert_equal "456", @a1agregator.item_id
    assert_equal "wm", @a1agregator.type
    assert_equal "99", @a1agregator.partner_income
    assert_equal "100", @a1agregator.system_income
    assert_equal "e7e634f0a068b29b5457a189396d2c78", @a1agregator.security_key

    assert_equal "100", @a1agregator.gross
    assert_false @a1agregator.test?
  end

  def test_compositions
    assert_equal Money.new(10000, 'RUB'), @a1agregator.amount
  end

  def test_acknowledgement
    assert @a1agregator.acknowledge
  end

  def test_respond_to_acknowledge
    assert @a1agregator.respond_to?(:acknowledge)
  end

private

  def http_raw_data
    "tid=132&name=ProductName&comment=Comment&partner_id=234&service_id=345\
&order_id=456&type=wm&partner_income=99&system_income=100\
&check=e7e634f0a068b29b5457a189396d2c78"
  end
end
