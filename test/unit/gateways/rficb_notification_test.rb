class RficbNotificationTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def setup
    @rficb = Rficb::Notification.new(http_raw_data, :secret => 'some_secret')
  end

  def test_accessors
    assert @rficb.complete?
    assert_equal "132", @rficb.transaction_id
    assert_equal "ProductName", @rficb.title
    assert_equal "Comment", @rficb.comment
    assert_equal "234", @rficb.partner_id
    assert_equal "345", @rficb.service_id
    assert_equal "456", @rficb.item_id
    assert_equal "wm", @rficb.type
    assert_equal "99", @rficb.partner_income
    assert_equal "100", @rficb.system_income
    assert_equal "e7e634f0a068b29b5457a189396d2c78", @rficb.security_key

    assert_equal "100", @rficb.gross
    assert_false @rficb.test?
  end

  def test_compositions
    assert_equal Money.new(10000, 'RUB'), @rficb.amount
  end

  def test_acknowledgement
    assert @rficb.acknowledge
  end

  def test_respond_to_acknowledge
    assert @rficb.respond_to?(:acknowledge)
  end

  private

  def http_raw_data
    "tid=132&name=ProductName&comment=Comment&partner_id=234&service_id=345\
&order_id=456&type=wm&partner_income=99&system_income=100\
&check=e7e634f0a068b29b5457a189396d2c78"
  end
end
