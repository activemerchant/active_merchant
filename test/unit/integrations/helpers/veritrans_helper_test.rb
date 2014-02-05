require 'test_helper'

class VeritransHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Veritrans::Helper.new('order-500','A11231253123162', :amount => 500, :merchant_hash_key => '121adwywdfqytwrdvq12351731ghasfdv651')
  end

  def test_inst_variable_unfields
    assert_equal '121adwywdfqytwrdvq12351731ghasfdv651', @helper.instance_variable_get(:@mhaskey)
  end

  def test_basic_helper_fields
    assert_field 'MERCHANT_ID',   'A11231253123162'
    assert_field 'ORDER_ID',      'order-500'
  end

  def test_customer_fields
    @helper.customer  email:         'john.doe@example.com',
                      first_name:    'John',
                      last_name:     'Doe',
                      address_1:     'Midplaza 2',
                      address_2:     'Jl. Jendral Sudirman',
                      country_code:  'IDN',
                      zip:           '15132',
                      phone:         '02112345678'

    assert_field 'EMAIL', 'john.doe@example.com'
    assert_field 'FIRST_NAME', 'John'
    assert_field 'LAST_NAME', 'Doe'
    assert_field 'ADDRESS1', 'Midplaza 2'
    assert_field 'ADDRESS2', 'Jl. Jendral Sudirman'
    assert_field 'COUNTRY_CODE', 'IDN'
    assert_field 'POSTAL_CODE', '15132'
    assert_field 'PHONE', '02112345678'
  end

  def test_shipping_fields
    assert_field 'CUSTOMER_SPECIFICATION_FLAG', '0'

    @helper.shipping  first_name:    'John',
                      last_name:     'Doe',
                      address_1:     'Midplaza 2',
                      address_2:     'Jl. Jendral Sudirman',
                      country_code:  'IDN',
                      zip:           '15132',
                      phone:         '02112345678'

    assert_field 'CUSTOMER_SPECIFICATION_FLAG', '1'

    assert_field 'SHIPPING_FIRST_NAME', 'John'
    assert_field 'SHIPPING_LAST_NAME', 'Doe'
    assert_field 'SHIPPING_ADDRESS1', 'Midplaza 2'
    assert_field 'SHIPPING_ADDRESS2', 'Jl. Jendral Sudirman'
    assert_field 'SHIPPING_COUNTRY_CODE', 'IDN'
    assert_field 'SHIPPING_POSTAL_CODE', '15132'
    assert_field 'SHIPPING_PHONE', '02112345678'
  end

  def test_shipping_as_billing
    helper  = @helper
    @helper = Veritrans::Helper.new('order-500','A11231253123162', :amount => 500, :merchant_hash_key => '121adwywdfqytwrdvq12351731ghasfdv651')

    assert_field 'CUSTOMER_SPECIFICATION_FLAG' ,'0'

    @helper.shipping_same_as_billing = false
    assert_field 'CUSTOMER_SPECIFICATION_FLAG' ,'1'

    @helper.shipping_same_as_billing = true
    assert_field 'CUSTOMER_SPECIFICATION_FLAG' ,'0'

    @helper = helper
  end

  def test_merchanthash
    fields = @helper.instance_variable_get(:@fields)
    eccpected_hash = Digest::SHA512.hexdigest("#{@helper.instance_variable_get(:@mhaskey)},#{fields['MERCHANT_ID']},#{fields['SETTLEMENT_TYPE']},#{fields['ORDER_ID']},#{fields['GROSS_AMOUNT']}")

    assert_equal eccpected_hash, @helper.send(:merchanthash)
  end
end
