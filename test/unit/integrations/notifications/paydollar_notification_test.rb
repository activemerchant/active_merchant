require 'test_helper'

class PaydollarNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @paydollar = Paydollar::Notification.new(http_raw_data, options = {:credential2 => "", :hasSecureHashEnabled => false})
  end

  def test_accessors
    assert @paydollar.complete?
    assert @paydollar.status
    assert_equal "8", @paydollar.item_id
    assert_equal "8", @paydollar.order_number
    assert_equal "1346892", @paydollar.transaction_id
    assert_equal "2014-01-08 16:30:18.0", @paydollar.received_at
    assert_equal "10.00", @paydollar.gross    
    assert_equal "0", @paydollar.primary_response_code
    assert_equal "0", @paydollar.secondary_response_code
    assert_equal "12345678", @paydollar.bank_reference
    assert_equal "AsiaPay Test", @paydollar.holder_name
    assert_equal "HKD", @paydollar.currency
    assert_equal "Test Payment", @paydollar.description
    assert_equal "346892", @paydollar.approval_code
    assert_equal "07", @paydollar.eci_value
    assert_equal "U", @paydollar.payer_auth_status
    assert_equal "121.96.170.140", @paydollar.payer_ip
    assert_equal "HK", @paydollar.card_issuing_country
    assert_equal "4918", @paydollar.pan_first4
    assert_equal "5005", @paydollar.pan_last4
  end

  def test_compositions
    #assert_equal "10.00", @paydollar.amount
  end

  private
  def http_raw_data
    "prc=0&src=0&Ord=12345678&Ref=8&PayRef=1346892&successcode=0&Amt=10.00&Cur=344&Holder=AsiaPay Test&AuthId=346892&AlertCode=R14&remark=Test Payment&eci=07&payerAuth=U&sourceIp=121.96.170.140&ipCountry=PH&payMethod=VISA&TxTime=2014-01-08 16:30:18.0&panFirst4=4918&panLast4=5005&cardIssuingCountry=HK&channelType=SPC&MerchantId=18100230&secureHash=80b694e3a777b59ef004aa2ae1fbc01205e77150,486f04293e09cf38d413daf416a99cb7fbe6d2fa"
  end
end
