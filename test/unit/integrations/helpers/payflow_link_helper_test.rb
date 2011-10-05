require 'test_helper'

class PayflowLinkHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = PayflowLink::Helper.new(1121,'loginname', :amount => 500, :currency => 'CAD', :credential2 => 'PayPal')
    @url = 'http://example.com'
  end

  def test_basic_helper_fields
    assert_field 'login', 'loginname'
    assert_field 'partner', 'PayPal'
    assert_field 'amount', '500'
    assert_field 'type', 'S'
    assert_field 'user1', '1121'
    assert_field 'invoice', '1121'
  end

  def test_description
    @helper.description = "my order"
    assert_field 'description', 'my order'
  end

  def test_name
    @helper.customer :first_name => "John", :last_name => "Doe"

    assert_field 'name', 'John Doe'
  end

  def test_billing_information
    @helper.billing_address :country => 'CA',
                             :address1 => '1 My Street',
                             :address2 => 'APT. 2',
                             :city => 'Ottawa',
                             :state => 'ON',
                             :zip => '90210',
                             :phone => '(555)123-4567'

    assert_field 'address', '1 My Street APT. 2'
    assert_field 'city', 'Ottawa'
    assert_field 'state', 'ON'
    assert_field 'zip', '90210'
    assert_field 'country', 'CA'
    assert_field 'phone', '(555)123-4567'
  end
  
  def test_province
    @helper.billing_address :country => 'CA',
                             :state => 'On'

    assert_field 'country', 'CA'
    assert_field 'state', 'ON'
  end

  def test_state
    @helper.billing_address :country => 'US',
                             :state => 'TX'

    assert_field 'country', 'US'
    assert_field 'state', 'TX'
  end

  def test_country_code
    @helper.billing_address :country => 'CAN'
    assert_field 'country', 'CA'
  end

  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    fields["state"] = 'N/A'
    
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end
  
  def test_uk_shipping_address_with_no_state
    @helper.billing_address :country => 'GB',
                             :state => ''

    assert_field 'state', 'N/A'
  end
end
