require 'test/unit'
require './lib/payu_in'

class PayuInHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup    
  	@helper = PayuIn::Helper.new( 'jh34h53kj4h5hj34kh5', 'C0Dr8m', :amount => '10.00', :credential2 => 'Product Info')        
  end

  def test_basic_helper_fields
    assert_equal '10.00', @helper.fields['amount']
    assert_equal 'C0Dr8m', @helper.fields['key']
    assert_equal 'jh34h53kj4h5hj34kh5', @helper.fields['txnid']
    assert_equal 'Product Info', @helper.fields['productinfo'] 		            
  end

  def test_customer_fields 
    @helper.customer :first_name => 'Payu-Admin', :last_name => '', :email => 'test@example.com', :phone => '1234567890'
    
    assert_equal 'Payu-Admin', @helper.fields['firstname']
    assert_equal 'test@example.com', @helper.fields['email']
    assert_equal '1234567890', @helper.fields['phone']
  end

  def test_billing_address_fields 
    @helper.billing_address :city => 'New Delhi', :address1 => '666, Wooo', :address2 => 'EEE Street', :state => 'New Delhi', :zip => '110001', :country => 'india'
    
    assert_equal 'New Delhi', @helper.fields['city']
    assert_equal '666, Wooo', @helper.fields['address1'] 
    assert_equal 'EEE Street', @helper.fields['address2']
    assert_equal 'New Delhi', @helper.fields['state']
    assert_equal '110001', @helper.fields['zip']
    assert_equal 'india', @helper.fields['country']
  end

  def test_return_url_fields 
    @helper.return_url :success => 'some_success_url', :failure => 'some_failure_url'
    
    assert_equal 'some_success_url', @helper.fields['surl']
    assert_equal 'some_failure_url', @helper.fields['furl']
  end

  def test_user_defined_fields 
    @helper.user_defined :var1 => 'var_one', :var2 => 'var_two', :var3 => 'var_three', :var4 => 'var_four', :var5 => 'var_five', :var6 => 'var_six', :var7 => 'var_seven', :var8 => 'var_eight', :var9 => 'var_nine', :var10 => 'var_ten'
    
    assert_equal 'var_one', @helper.fields['udf1']
    assert_equal 'var_two', @helper.fields['udf2']
    assert_equal 'var_three', @helper.fields['udf3']
    assert_equal 'var_four', @helper.fields['udf4']
    assert_equal 'var_five', @helper.fields['udf5']
    assert_equal 'var_six', @helper.fields['udf6']
    assert_equal 'var_seven', @helper.fields['udf7']
    assert_equal 'var_eight', @helper.fields['udf8']
    assert_equal 'var_nine', @helper.fields['udf9']
    assert_equal 'var_ten', @helper.fields['udf10']
  end

  def test_other_fields    
    
    @helper.mode 'CC'
    @helper.notify_url 'http://notify.payu.in'
    @helper.cancel_return_url 'http://cancel_return.payu.in'
    @helper.checksum 'jk4j5454545j4k'

    fields = @helper.fields.dup
    assert_equal fields, @helper.fields
  end

  def test_add_checksum_method

    options = { :mode => 'CC' }
    @helper.customer :first_name => 'Payu-Admin', :email => 'test@example.com'
    @helper.user_defined :var1 => 'var_one', :var2 => 'var_two', :var3 => 'var_three', :var4 => 'var_four', :var5 => 'var_five', :var6 => 'var_six', :var7 => 'var_seven', :var8 => 'var_eight', :var9 => 'var_nine', :var10 => 'var_ten'    
        
    assert_equal ["jh34h53kj4h5hj34kh5", "10.00", "Product Info", "Payu-Admin", "test@example.com", "var_one", "var_two", "var_three", "var_four", "var_five", "var_six", "var_seven", "var_eight", "var_nine", "var_ten", {:mode=>"CC"}], @helper.add_checksum(options)    
  end
  
end 
