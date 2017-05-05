require 'test_helper'

class MoneybookersHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    Moneybookers::Helper.application_id = 'ActiveMerchant'
    @helper = Moneybookers::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD')
  end
 
  def test_basic_helper_fields
    assert_field 'hide_login', '1'
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
  
  def test_tracking_token
    Moneybookers::Helper.application_id = '123'
    @helper = Moneybookers::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD')
    assert_field 'merchant_fields', 'platform'
    assert_field 'platform', '123'
  end

  def test_tracking_token_not_added_by_default
    assert_nil @helper.fields['merchant_fields']
    assert_nil @helper.fields['platform']
  end
  
  def test_country
    @helper = Moneybookers::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD', :country => 'GBR')
    assert_field 'country', 'GBR'
    
    @helper = Moneybookers::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD', :country => 'GB')
    assert_field 'country', 'GBR'
    
    @helper = Moneybookers::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD', :country => 'United Kingdom')
    assert_field 'country', 'GBR'
  end
  
  def test_account_name
    @helper = Moneybookers::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD', :account_name => 'My account name')
    assert_field 'recipient_description', "My account name"
  end

  def test_language

    @helper = Moneybookers::Helper.new('order-500', 'cody@example.com', :amount => 500, :currency => 'USD', :country => 'DK')
    assert_field 'language', 'DA'

    # Country with supported language (non-mapped)
    @helper = Moneybookers::Helper.new('order-500', 'cody@example.com', :amount => 500, :currency => 'USD', :country => 'PL')
    assert_field 'language', 'PL'

    # Country with unsupported language
    @helper = Moneybookers::Helper.new('order-500', 'cody@example.com', :amount => 500, :currency => 'USD', :country => 'CA')
    assert_field 'language', 'EN'
  end
end
