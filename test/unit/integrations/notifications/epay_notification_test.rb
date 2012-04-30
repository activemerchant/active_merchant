require 'test_helper'

class EpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @epay = Epay::Notification.new(http_raw_data, :credential3 => "secretmd5")
  end

  def test_accessors
    assert @epay.complete?
    assert_equal "9572252", @epay.transaction_id
    assert_equal "189139", @epay.item_id
    assert_equal "3987.50", @epay.gross
    assert_equal "DKK", @epay.currency
    assert_equal Time.parse("2012-04-03 14:42:00"), @epay.received_at
    assert !@epay.test?
  end

  def test_compositions
    assert_equal Money.new(398750, 'DKK'), @epay.amount
  end

  def test_acknowledgement    
    assert @epay.acknowledge
  end
  
  def test_failed_acknnowledgement
    @epay = Epay::Notification.new(http_raw_data, :credential3 => "badmd5string")
    assert !@epay.acknowledge
  end

  def test_generate_md5string
    assert_equal "1957225218913939875020820120403144203453903XXXXXX9862secretmd5", 
                 @epay.generate_md5string
  end

  def test_generate_md5hash
    assert_equal "6f81086c474f03af80ef894e48f81f99", @epay.generate_md5hash
  end

  def test_respond_to_acknowledge
    assert @epay.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "language=1&txnid=9572252&orderid=189139&amount=398750&currency=208&date=20120403&time=1442&txnfee=0&paymenttype=3&cardno=453903XXXXXX9862&hash=6f81086c474f03af80ef894e48f81f99"
  end  

end
