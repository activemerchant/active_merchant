require 'test_helper'

class PayzaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Payza::Helper.new('order-500', 'cody@example.com', :amount => 5, :currency => 'USD')
  end

  def test_basic_helper_fields
    assert_field 'ap_merchant', 'cody@example.com'

    assert_field 'ap_amount', '5'
    assert_field 'ap_itemcode', 'order-500'
    assert_field 'ap_currency', 'USD'
  end

end
