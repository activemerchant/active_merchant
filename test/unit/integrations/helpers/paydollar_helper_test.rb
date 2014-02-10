require 'test_helper'

class PaydollarHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Paydollar::Helper.new('order-500', '0987654321', :amount => '123.45', :currency => 'HKD')
  end

  def test_basic_helper_fields
    assert_field 'merchantId', '0987654321'
    assert_field 'amount', '123.45'
    assert_field 'orderRef', 'order-500'
    assert_field 'currCode', '344'
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

end
