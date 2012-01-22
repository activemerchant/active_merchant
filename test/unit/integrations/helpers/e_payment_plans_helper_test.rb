require 'test_helper'

class EPaymentPlansHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = EPaymentPlans::Helper.new('order-500','cody@example.com', :amount => 500, :currency => 'USD')
  end

  def test_basic_helper_fields
    assert_field 'order[account]', 'cody@example.com'

    assert_field 'order[amount]', '500'
    assert_field 'order[num]', 'order-500'
  end

  def test_customer_fields
    @helper.customer :first_name => 'Cody', :last_name => 'Fauser', :email => 'cody@example.com'
    assert_field 'order[first_name]', 'Cody'
    assert_field 'order[last_name]', 'Fauser'
    assert_field 'order[email]', 'cody@example.com'
  end

  def test_address_mapping
    @helper.billing_address :address1 => '1 My Street',
                            :address2 => '',
                            :company => 'Shopify',
                            :city => 'Leeds',
                            :state => 'Yorkshire',
                            :zip => 'LS2 7EE',
                            :country  => 'CA'

    assert_field 'order[address1]', '1 My Street'
    assert_field 'order[city]', 'Leeds'
    assert_field 'order[company]', 'Shopify'
    assert_field 'order[state]', 'Yorkshire'
    assert_field 'order[zip]', 'LS2 7EE'
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
end
