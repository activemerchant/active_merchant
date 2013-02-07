require 'test_helper'

class FirstDataHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    # currency is currently ignored...
    @helper = FirstData::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD')
  end

  def test_basic_helper_fields
    assert_field 'x_login', 'cody@example.com'
    assert_field 'x_amount', '500.0'
    assert_field 'x_fp_sequence', 'order-500'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'x_first_name', 'Cody'
    assert_field 'x_last_name', 'Fauser'
    assert_field 'x_email', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'
    assert_field 'x_address', '1 My Street'
    assert_field 'x_city', 'Leeds'
    assert_field 'x_state', 'Yorkshire'
    assert_field 'x_zip', 'LS2 7EE'
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
end
