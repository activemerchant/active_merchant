require 'test_helper'

class PayuInPaisaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = PayuInPaisa::Helper.new( 'order_id', 'merchant_id', :amount => '10.00', :credential2 => 'secret')
  end

  def test_basic_helper_fields
    assert_equal '10.00', @helper.fields['amount']
    assert_equal 'merchant_id', @helper.fields['key']
    assert_equal 'order_id', @helper.fields['txnid']
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
    @helper.return_url 'some_return_url'

    assert_equal 'some_return_url', @helper.fields['surl']
    assert_equal 'some_return_url', @helper.fields['furl']
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

  def test_add_checksum_method
    @helper.customer :first_name => 'Payu-Admin', :email => 'test@example.com'
    @helper.user_defined :var1 => 'var_one', :var2 => 'var_two', :var3 => 'var_three', :var4 => 'var_four', :var5 => 'var_five', :var6 => 'var_six', :var7 => 'var_seven', :var8 => 'var_eight', :var9 => 'var_nine', :var10 => 'var_ten'
    @helper.description 'Product Info'

    payload = 'merchant_id|order_id|10.00|Product Info|Payu-Admin|test@example.com|var_one|var_two|var_three|var_four|var_five|var_six|var_seven|var_eight|var_nine|var_ten|secret'
    checksum = Digest::SHA512.hexdigest(payload)
    assert_equal checksum, @helper.form_fields["hash"]
  end
end
