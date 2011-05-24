require 'test_helper'

class WorldPayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = WorldPay::Helper.new(1,'99999', :amount => '5.00', :currency => 'GBP')
  end
 
  def test_basic_helper_fields
    assert_field 'instId', '99999'
    assert_field 'amount', '5.00'
    assert_field 'cartId', '1'
    assert_field 'currency', 'GBP'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Andrew', 
                     :last_name => 'White', 
                     :phone => '024 7699 9999',
                     :email => 'andyw@example.com'
                     
    assert_field 'name', 'Andrew White'
    assert_field 'tel', '024 7699 9999'
    assert_field 'email', 'andyw@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 Nowhere Close',
                            :address2 => 'Electric Wharf',
                            :city => 'Coventry',
                            :state => 'Warwickshire',
                            :zip => 'CV1 1AA',
                            :country  => 'GB'
   
    assert_field 'address', '1 Nowhere Close&#10;Electric Wharf&#10;Coventry&#10;Warwickshire'
    assert_field 'postcode', 'CV1 1AA'
    assert_field 'country', 'GB'
  end

  def test_address_mapping_without_address1_and_state
    @helper.billing_address :address1 => 'Teststr. 1',
                            :city => 'Berlin',
                            :zip => '10000',
                            :country  => 'DE'
   
    assert_field 'address', 'Teststr. 1&#10;Berlin'
    assert_field 'postcode', '10000'
    assert_field 'country', 'DE'
  end
  
  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '1 Somewhere Else'
    end
  end
  
  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'Twilight Zone'
    assert_equal fields, @helper.fields
  end
  
  def test_encryption
    @helper.encrypt 'secret', [:amount, :currency, :account, :order]
    
    assert_field 'signatureFields', 'amount:currency:instId:cartId'
    assert_field 'signature', 'adbfc78d82c9a23cbc075f4dfe05daed'
  end

  def test_valid_from_time
    @helper.valid_from Time.utc('2007-01-01 00:00:00')
    assert_field 'authValidFrom', '1167609600000'
  end
  
  def test_valid_to_time
    @helper.valid_to Time.utc('2007-01-01 00:00:00')
    assert_field 'authValidTo', '1167609600000'
  end
  
  def test_custom_params
    @helper.response_params :custom_1 => 'Custom Value 1'
    @helper.callback_params :custom_2 => 'Custom Value 2'
    @helper.combined_params :custom_3 => 'Custom Value 3'
    
    assert_field 'C_custom_1', 'Custom Value 1'
    assert_field 'M_custom_2', 'Custom Value 2'
    assert_field 'MC_custom_3', 'Custom Value 3'
  end
end