require 'test_helper'

class MoneybookersHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Moneybookers::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD')
  end
 
  def test_basic_helper_fields
    assert_field 'pay_to_email', 'cody@example.com'
    assert_field 'amount', '500'
    assert_field 'transaction_id', 'order-500'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'firstname', 'Cody'
    assert_field 'lastname', 'Fauser'
    assert_field 'pay_to_email', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'
   
    assert_field 'address', '1 My Street'
    assert_field 'city', 'Leeds'
    assert_field 'state', 'Yorkshire'
    assert_field 'postal_code', 'LS2 7EE'
  end
  
  def test_unknown_address_mapping
    total_fields = @helper.fields.size
    @helper.billing_address :farm => 'CA'
    assert_equal total_fields, @helper.fields.size
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
