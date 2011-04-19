require 'test_helper'

class ChronopayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Chronopay::Helper.new('order-500','003176-0001-0001', :amount => 500, :currency => 'CAD')
  end
 
  def test_basic_helper_fields
    assert_field 'cs1', 'order-500'
    assert_field 'product_id', '003176-0001-0001'
    assert_field 'product_price', '500'
    assert_field 'product_price_currency', 'CAD'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser'
    assert_field 'f_name', 'Cody'
    assert_field 's_name', 'Fauser'
  end

  def test_address_mapping
    @helper.billing_address :country => 'CAN',
                            :address1 => '1 My Street',
                            :city => 'Ottawa',
                            :state => 'On',
                            :zip => '90210'
   
    assert_field 'country', 'CAN'
    assert_field 'street', '1 My Street'
    assert_field 'state', 'On'
    assert_field 'zip', '90210'
  end

  def test_country_code_mapping
    @helper.billing_address :country => 'CA'
    assert_field 'country', 'CAN'
  end

  def test_province_code_mapping_non_us
    @helper.billing_address :country => 'DE', :state => 'Berlin'
    assert_field 'country', 'DEU'
    assert_field 'state', 'XX'
  end

  def test_state_code_mapping_us
    @helper.billing_address :country => 'US', :state => 'CA'
    assert_field 'country', 'USA'
    assert_field 'state', 'CA'
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end
  
  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    
    # Will still set the state code to 'XX' and language to 'EN'
    fields['state']    = 'XX'
    fields['language'] = 'EN'
    assert_equal fields, @helper.fields
  end
  
  
  def test_sets_corresponding_checkout_language_for_country
    @helper.billing_address :country => 'DEU'
    assert_field 'language', 'DE'

    @helper.billing_address :country => 'RUS'
    assert_field 'language', 'RU'

    @helper.billing_address :country => 'Spain'
    assert_field 'language', 'ES'

    @helper.billing_address :country => 'Venezuela'
    assert_field 'language', 'ES'

    @helper.billing_address :country => 'Portugal'
    assert_field 'language', 'PT'

    @helper.billing_address :country => 'China'
    assert_field 'language', 'CN1'

    @helper.billing_address :country => 'Latvia'
    assert_field 'language', 'LV'
  end

  def test_checkout_language_defaults_to_english
    @helper.billing_address :country => 'USA'   
    assert_field 'language', 'EN'

    @helper.billing_address :country => 'Canada'
    assert_field 'language', 'EN'

    @helper.billing_address :country => 'Great Britain'
    assert_field 'language', 'EN'

    @helper.billing_address :country => 'Italy'
    assert_field 'language', 'EN'

    @helper.billing_address :country => 'Japan'
    assert_field 'language', 'EN'
  end
  
end
