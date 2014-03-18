require 'test_helper'

class GoCoinHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = GoCoin::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD')
  end
 
  def test_basic_helper_fields
    assert_field 'base_price_currency', 'USD'
    assert_field 'base_price', '500'
    assert_field 'order_id', 'order-500'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'customer_name', 'Cody'
    assert_field 'customer_email', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'
   
    assert_field 'customer_address_1', '1 My Street'
    assert_field 'customer_city', 'Leeds'
    assert_field 'customer_region', 'Yorkshire'
    assert_field 'customer_postal_code', 'LS2 7EE'
    assert_field 'customer_country', 'CA'
  end
  
  def test_unknown_address_mapping
    @helper.billing_address :farm => 'CA'
    assert_equal 3, @helper.fields.size
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

  def test_form_fields_uses_invoice_id
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{"id": "12345invoice_id"}'))
    assert_equal '12345invoice_id', @helper.form_fields['invoice_id']
  end

  def test_raises_when_invalid_json_returned
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => 'Invalid JSON'))
    assert_raises(StandardError) { @helper.form_fields['invoice_id'] }
  end
end
