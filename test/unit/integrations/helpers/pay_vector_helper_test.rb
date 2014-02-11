require 'test_helper'

class PayVectorHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = PayVector::Helper.new('order-500','TestMerchantID', :amount => 500, :currency => 'USD')
  end
 
  def test_basic_helper_fields
    assert_field 'MerchantID', 'TestMerchantID'

    assert_field 'Amount', '50000'
    assert_field 'OrderID', 'order-500'
    assert_field 'CurrencyCode', '840'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Walter', :last_name => 'White', :email => 'walter.white@example.com'
    assert_field 'CustomerName', 'Walter White'
    assert_field 'EmailAddress', 'walter.white@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '308',
                            :address2 => 'Negra Arroyo Lane',
                            :city => 'Albuquerque',
                            :state => 'New Mexico',
                            :zip => '87104',
                            :country  => 'US'
   
    assert_field 'Address1', '308'
    assert_field 'Address2', 'Negra Arroyo Lane'
    assert_field 'City', 'Albuquerque'
    assert_field 'State', 'New Mexico'
    assert_field 'PostCode', '87104'
    assert_field 'CountryCode', '840'
  end
  
  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_nil @helper.fields['farm']
    #assert_equal 3, @helper.fields.size
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end
  
  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_nil @helper.fields['street']
    #assert_equal fields, @helper.fields
  end
end
