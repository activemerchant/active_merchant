require 'test_helper'

class QuickpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @quickpay = Quickpay::Notification.new(http_raw_data, :credential2 => "test")
  end

  def test_accessors
    assert @quickpay.complete?
    assert_equal "000", @quickpay.status
    assert_equal "4262", @quickpay.transaction_id
    assert_equal "1353061158", @quickpay.item_id
    assert_equal "1.23", @quickpay.gross
    assert_equal "DKK", @quickpay.currency
    assert_equal Time.parse("2012-11-16 10:19:36+00:00"), @quickpay.received_at
  end

  def test_compositions
    assert_equal Money.new(123, 'DKK'), @quickpay.amount
  end

  def test_acknowledgement
    assert @quickpay.acknowledge
  end

  def test_failed_acknnowledgement
    @quickpay = Quickpay::Notification.new(http_raw_data, :credential2 => "badmd5string")
    assert !@quickpay.acknowledge
  end

  def test_quickpay_attributes
    assert_equal "1", @quickpay.state
    assert_equal "authorize", @quickpay.msgtype
  end

  def test_generate_md5string
    assert_equal "authorize1353061158123DKK2012-11-16T10:19:36+00:001000OK000OKMerchant #1merchant1@pil.dk4262dankortXXXXXXXXXXXX999910test",
                 @quickpay.generate_md5string
  end

  def test_generate_md5check
    assert_equal "7caa0df7d17085206af135ed70d22cc9", @quickpay.generate_md5check
  end

  def test_respond_to_acknowledge
    assert @quickpay.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "msgtype=authorize&ordernumber=1353061158&amount=123&currency=DKK&time=2012-11-16T10:19:36%2B00:00&state=1&" +
    "qpstat=000&qpstatmsg=OK&chstat=000&chstatmsg=OK&merchant=Merchant #1&merchantemail=merchant1@pil.dk&transaction=4262&" +
    "cardtype=dankort&cardnumber=XXXXXXXXXXXX9999&cardhash=&splitpayment=1&fraudprobability=&fraudremarks=&fraudreport=&" +
    "fee=0&md5check=7caa0df7d17085206af135ed70d22cc9"
  end
end
