require 'test_helper'

class PaydollarHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Paydollar::Helper.new('order-001', '1234', :amount => 100, :credential2 => '')
    @helper.payment_method = 'ALL'
    @helper.payment_type = 'N'
    @helper.currency = '344'
    @helper.language = 'E'
    @helper.success_url = 'http://www.yourdomain.com/success.html'
    @helper.fail_url = 'http://www.yourdomain.com/fail.html'
    @helper.cancel_url = 'http://www.yourdomain.com/cancel.html'
    @helper.description = 'For order id number X'
    @helper.secure_hash_enabled = 'no'
  end
 
  def test_basic_helper_fields
    assert_field 'orderRef', 'order-001'
    assert_field 'merchantId', '1234'
    assert_field 'amount', '100'    
    assert_field 'payMethod', 'ALL'
    assert_field 'payType', 'N'
    assert_field 'currCode', '344'
    assert_field 'lang', 'E'
    assert_field 'successUrl', 'http://www.yourdomain.com/success.html'
    assert_field 'failUrl', 'http://www.yourdomain.com/fail.html'
    assert_field 'cancelUrl', 'http://www.yourdomain.com/cancel.html'
    assert_field 'remark', 'For order id number X'
  end
  
end
