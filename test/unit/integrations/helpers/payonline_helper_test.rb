require 'test_helper'

class PayonlineHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Payonline::Helper.new(
      100500,
      123465,
      :amount => "%.2f" % 100,
      :currency => 'USD'
    )
  end

  def test_basic_helper_fields
    assert_field 'OrderId', '100500'
    assert_field 'MerchantId', '123465'
    assert_field 'Amount', '100.00'
    assert_field 'Currency', 'USD'
  end

end
