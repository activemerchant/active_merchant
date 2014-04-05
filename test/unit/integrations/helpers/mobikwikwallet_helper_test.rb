require 'test_helper'

class MobikwikwalletHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Mobikwikwallet::Helper.new('order-500','G0JW45KCS3630NX335YX', :credential2 => 'MBK9002', :credential3 => 'ju6tygh7u7tdg554k098ujd5468o', :credential4 => 'Test Merchant', :amount => 10)
  end
 
  def test_basic_helper_fields
    assert_equal '10', @helper.fields['amount']
    assert_equal 'order-500', @helper.fields['orderid']
    assert_equal 'MBK9002', @helper.fields['mid']
    assert_equal 'Test Merchant', @helper.fields['merchantname']
  end
  
  def test_customer_fields
    @helper.customer :email => 'kanishk@mobikwik.com', :phone => '9711429252'
    assert_field 'email', 'kanishk@mobikwik.com'
    assert_field 'cell', '9711429252'
  end

  def test_return_url_fields
    @helper.return_url 'some_return_url'
    assert_equal 'some_return_url', @helper.fields['redirecturl']
  end

  def test_form_fields
    @helper.customer :email => 'kanishk@mobikwik.com', :phone => '9711429252'
    @helper.return_url 'some_return_url'
    assert_equal 'bc322adccedce0f96b97aaf55282e145ad709b492ef395f771b2d2f0b3314cc6', @helper.form_fields["checksum"]
  end

end
