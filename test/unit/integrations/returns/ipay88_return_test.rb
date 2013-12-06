require "test_helper"

class Ipay88ReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @ipay = Ipay88::Return.new(http_raw_data, :credential2 => 'secret')
  end

  def test_success?
    assert @ipay.success?
  end

  def test_message_returns_error_description
    assert_equal 'Customer Cancel Transaction', @ipay.message
  end

  def test_cancelled
    assert @ipay.cancelled?
  end

  private
  def http_raw_data
    "Amount=0.10&AuthCode=12345678&Currency=USD&ErrDesc=Customer Cancel Transaction&MerchantCode=M00001&PaymentId=1&RefNo=10000001&Remark=&Signature=RWAehzFtiNCKQWpXheazrCF33J4%3D&Status=1&TransId=T123456789"
  end
end
