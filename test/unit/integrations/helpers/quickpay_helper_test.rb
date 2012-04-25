require 'test_helper'

class QuickpayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Quickpay::Helper.new('order-500','24352435', :amount => 500, :currency => 'USD')
    @helper.md5secret "mysecretmd5string"
    @helper.return_url 'http://example.com/ok'
    @helper.cancel_return_url 'http://example.com/cancel'
    @helper.notify_url 'http://example.com/notify'
  end
 
  def test_basic_helper_fields
    assert_field 'merchant', '24352435'
    assert_field 'amount', '500'
    assert_field 'ordernumber', 'order500'
  end
  
  def test_generate_md5string
    assert_equal '3authorize24352435daorder500500USDhttp://example.com/okhttp://example.com/cancelhttp://example.com/notify01mysecretmd5string', 
                 @helper.generate_md5string
  end
  
  def test_generate_md5check
    assert_equal '3dc7b51567c4911cc38511f796773366', @helper.generate_md5check
  end
  
  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end
  
  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end
end
