require 'test_helper'

class PagSeguroHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = PagSeguro::Helper.new('order-500','cody@example.com', :credential2 => "USER_TOKEN", :amount => 55)
  end
 
  def test_basic_helper_fields
    assert_field 'email', 'cody@example.com'
    assert_field 'token', 'USER_TOKEN'

    assert_field 'itemAmount1', '55.00'
    assert_field 'reference', 'order-500'
    assert_field 'itemId1', '1'
    assert_field 'itemQuantity1', '1'
    assert_field 'shippingType', '3'
    assert_field 'currency', 'BRL'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com', phone: "7199223522"
    assert_field 'senderName', 'Cody Fauser'
    assert_field 'senderPhone', '7199223522'
    assert_field 'senderEmail', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Leeds',
                            :state => 'SP',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'
   
    assert_field 'shippingAddressStreet', '1 My Street'
    assert_field 'shippingAddressDistrict', 'Leeds'
    assert_field 'shippingAddressState', 'SP'
    assert_field 'shippingAddressPostalCode', 'LS2 7EE'
    assert_field 'shippingAddressCountry', 'CA'
  end
  
  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 8, @helper.fields.size
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

  def test_notification_mapping
    @helper.notify_url "https://notify_url.com"
    @helper.return_url "https://return_url.com"

    assert_field 'notificationURL', 'https://notify_url.com'
    assert_field 'redirectURL', 'https://return_url.com'
  end

  def test_description_mapping
    @helper.description "Some description"

    assert_field 'itemDescription1', 'Some description'
  end

  def test_get_token_should_get_the_token
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '<?xml version=\"1.0\" encoding=\"ISO-8859-1\" standalone=\"yes\"?><checkout><code>E20521EF6C6C159994DFFF8F5A4C3ED7</code><date>2014-02-12T02:10:25.000-02:00</date></checkout>"'))
    assert "E20521EF6C6C159994DFFF8F5A4C3ED7", @helper.fetch_token
  end
end
