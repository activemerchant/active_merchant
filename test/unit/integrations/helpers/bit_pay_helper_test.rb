require 'test_helper'

class BitPayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = BitPay::Helper.new(1234, 'cody@example.com', :amount => 500, :currency => 'USD')
  end
 
  def test_basic_helper_fields
    assert_field 'orderID', "1234"
    assert_field 'price', "500"
    assert_field 'currency', 'USD'
  end
  
  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'buyerName', 'Cody'
    assert_field 'buyerEmail', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'
   
    assert_field 'buyerAddress1', '1 My Street'
    assert_field 'buyerCity', 'Leeds'
    assert_field 'buyerState', 'Yorkshire'
    assert_field 'buyerZip', 'LS2 7EE'
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
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{"id": "98kui1gJ7FocK41gUaBZxG"}'))

    assert_equal '98kui1gJ7FocK41gUaBZxG', @helper.form_fields['id']
  end

  def test_raises_when_invalid_json_returned
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => 'Invalid JSON'))

    assert_raises(ActionViewHelperError) { @helper.form_fields['id'] }
  end
end
