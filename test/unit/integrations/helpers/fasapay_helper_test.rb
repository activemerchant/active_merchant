require 'test_helper'

class FasapayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Fasapay::Helper.new(
      100500,
      123465,
      amount: 500,
      currency: 'USD',
      account_name: 'Company'
    )
  end

  def test_basic_helper_fields
    assert_field 'fp_merchant_ref', '100500'
    assert_field 'fp_acc', '123465'
    assert_field 'fp_amnt', '500'
    assert_field 'fp_currency', 'USD'
  end

end
