require 'test_helper'

class FocalPaymentHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = FocalPayment::Helper.new(
      100500,
      123465,
      amount: 500,
      currency: 'USD',
      account_name: 'Company'
    )
  end

  def test_basic_helper_fields
    assert_field 'TransRef', '100500'
    assert_field 'Amount', '500'
    assert_field 'Currency', 'USD'
  end

end
