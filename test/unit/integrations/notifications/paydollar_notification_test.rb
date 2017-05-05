require 'test_helper'

class PaydollarNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @secret = 'TO78ghHCfBQ6ZBw2Q2fJ3wRwGkWkUHVs'
    @paydollar = Paydollar::Notification.new(http_raw_data, {:credential2 => @secret})
  end

  def test_accessors
    assert @paydollar.complete?
    assert_equal 'Completed', @paydollar.status
    assert_equal '1384996', @paydollar.transaction_id
    assert_equal '9', @paydollar.item_id
    assert_equal '139.62', @paydollar.gross
    assert_equal 'HKD', @paydollar.currency
  end

  def test_compositions
    assert_equal Money.new(13962, 'HKD'), @paydollar.amount
  end

  def test_acknowledgement
    assert @paydollar.acknowledge
  end

  def test_unsigned_acknowledgement
    @notification = Paydollar::Notification.new(unsigned_http_raw_data, {:credential2 => @secret})
    assert !@notification.acknowledge
  end

  private
  def http_raw_data
    'prc=0&src=0&Ord=12345678&Ref=9&PayRef=1384996&successcode=0&Amt=139.62&Cur=344&Holder=Test Card&AuthId=384996&AlertCode=R14&remark=Shop One store purchase. Order #9&eci=07&payerAuth=U&sourceIp=216.191.231.218&ipCountry=CA&payMethod=VISA&TxTime=2014-02-14 23:53:27.0&panFirst4=4918&panLast4=5005&cardIssuingCountry=HK&channelType=SPC&MerchantId=18100230&secureHash=0b9b2664b48eebfd40a6d9ad027ed1ee673ad574,36177307e270a7d7de59fe84d013d40911b3fc71'
  end

  def unsigned_http_raw_data
    'prc=0&src=0&Ord=12345678&Ref=9&PayRef=1384996&successcode=0&Amt=139.62&Cur=344&Holder=Test Card&AuthId=384996&AlertCode=R14&remark=Shop One store purchase. Order #9&eci=07&payerAuth=U&sourceIp=216.191.231.218&ipCountry=CA&payMethod=VISA&TxTime=2014-02-14 23:53:27.0&panFirst4=4918&panLast4=5005&cardIssuingCountry=HK&channelType=SPC&MerchantId=18100230'
  end
end
