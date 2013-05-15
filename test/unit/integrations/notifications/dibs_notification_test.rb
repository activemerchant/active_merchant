require 'test_helper'

class DibsNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @dibs = Dibs::Notification.new(http_raw_data)
  end

  def test_accessors
    assert_equal 'ACCEPTED', @dibs.status
    assert_equal '3.75', @dibs.gross
    assert_equal '704030920', @dibs.transaction_id
    assert_equal '100500', @dibs.item_id
    assert_equal 'DKK', @dibs.currency
  end
  
  def test_compositions
    assert_equal Money.new(375, 'DKK'), @dibs.amount
  end

  def test_acknowledgement
    assert @dibs.acknowledge
  end
  
  private
  def http_raw_data
    "acceptreturnurl=http://yourdomain.com/acceptreturnurl&acquirer=test&actionCode=d100&addfee=1&amount=375&"+
    "billingemail=maxwhite1983@gmail.com&billingfirstname=Max&billinglastname=White&billingmobile=B380661788009&"+
    "billingpostalcode=49051&callbackurl=http://yourdomain.com/callbackurl"+
    "&cancelreturnurl=http://yourdomain.com/cancelReturnUrl&capturenow=1&cardNumberMasked=471110XXXXXX0000&cardTypeName=VISA&currency"+
    "=DKK&expMonth=06&expYear=24&fee=195&language=da_DK&merchant=12345678&orderid=100500&paytype=MC,VISA&"+
    "status=ACCEPTED&test=1&transaction=704030920&captureStatus=ACCEPTED&MAC=e54123310776f5818c094a687ab809d9504ad790a1e66cd6fccdca246bd207f"
  end
end
