require 'test_helper'

class QiwiHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Qiwi::Helper.new('order-500', 'cody@example.com', :amount => 500, :currency => 'USD')
  end

  def test_basic_helper_fields
    assert_field 'account', 'cody@example.com'

    assert_field 'amount', '500'
    assert_field 'id', 'order-500'
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
