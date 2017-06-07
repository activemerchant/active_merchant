require 'test_helper'

class RedDotPaymentHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = RedDotPayment::Helper.new('12345','0000021999',
                                        :amount => '9.50',
                                        :currency => 'SGD',
                                        :credential2 => 'merchant_key',
                                        :credential3 => 'REDDOT')

    @helper.customer :email => 'test@reddotpayment.com'
    @helper.return_url 'http://www.reddotpayment.com'
  end
 
  def test_basic_helper_fields
    assert_field 'order_number', '12345'
    assert_field 'merchant_id', '0000021999'
    assert_field 'key', 'merchant_key'
    assert_field 'amount', '9.50'
    assert_field 'currency_code', 'SGD'
    assert_field 'email', 'test@reddotpayment.com'
    assert_field 'return_url', 'http://www.reddotpayment.com'

    assert_field 'transaction_type', 'sale'
  end

  def test_secret_key_in_form_fields
    assert_equal '7e6f4d8dad5223250614cc146561926c', @helper.form_fields['signature']
  end
end
