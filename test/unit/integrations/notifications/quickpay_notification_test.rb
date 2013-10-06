require 'test_helper'

class QuickpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @quickpay = Quickpay::Notification.new(http_raw_data, :credential2 => "test", version: 7)
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
    <<-END_POST
------------------------------8a827a0e6829
Content-Disposition: form-data; name="msgtype"

authorize
------------------------------8a827a0e6829
Content-Disposition: form-data; name="ordernumber"

1353061158
------------------------------8a827a0e6829
Content-Disposition: form-data; name="amount"

123
------------------------------8a827a0e6829
Content-Disposition: form-data; name="currency"

DKK
------------------------------8a827a0e6829
Content-Disposition: form-data; name="time"

2012-11-16T10:19:36+00:00
------------------------------8a827a0e6829
Content-Disposition: form-data; name="state"

1
------------------------------8a827a0e6829
Content-Disposition: form-data; name="qpstat"

000
------------------------------8a827a0e6829
Content-Disposition: form-data; name="qpstatmsg"

OK
------------------------------8a827a0e6829
Content-Disposition: form-data; name="chstat"

000
------------------------------8a827a0e6829
Content-Disposition: form-data; name="chstatmsg"

OK
------------------------------8a827a0e6829
Content-Disposition: form-data; name="merchant"

Merchant #1
------------------------------8a827a0e6829
Content-Disposition: form-data; name="merchantemail"

merchant1@pil.dk
------------------------------8a827a0e6829
Content-Disposition: form-data; name="transaction"

4262
------------------------------8a827a0e6829
Content-Disposition: form-data; name="cardtype"

dankort
------------------------------8a827a0e6829
Content-Disposition: form-data; name="cardnumber"

XXXXXXXXXXXX9999
------------------------------8a827a0e6829
Content-Disposition: form-data; name="cardhash"


------------------------------8a827a0e6829
Content-Disposition: form-data; name="acquirer"

nets
------------------------------8a827a0e6829
Content-Disposition: form-data; name="splitpayment"

1
------------------------------8a827a0e6829
Content-Disposition: form-data; name="fraudprobability"


------------------------------8a827a0e6829
Content-Disposition: form-data; name="fraudremarks"


------------------------------8a827a0e6829
Content-Disposition: form-data; name="fraudreport"


------------------------------8a827a0e6829
Content-Disposition: form-data; name="fee"

0
------------------------------8a827a0e6829
Content-Disposition: form-data; name="md5check"

7caa0df7d17085206af135ed70d22cc9
------------------------------8a827a0e6829--
END_POST
  end
end
