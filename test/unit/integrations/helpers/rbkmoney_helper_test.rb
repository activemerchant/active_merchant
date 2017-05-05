require 'test_helper'

class RbkmoneyHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Rbkmoney::Helper.new(
      100500,
      123465,
      :amount => 500,
      :currency => 'USD',
      :credential2 => 'awesome stuff',
      :credential3 => 'http://somewhere.com/success',
      :credential4 => 'http://somewhere.com/cancel'
    )
  end

  def test_basic_helper_fields
    assert_field 'orderId', '100500'
    assert_field 'eshopId', '123465'

    assert_field 'recipientAmount', '500'
    assert_field 'recipientCurrency', 'USD'
    assert_field 'successUrl', 'http://somewhere.com/success'
    assert_field 'failUrl', 'http://somewhere.com/cancel'
    assert_field 'serviceName', 'awesome stuff'
  end

  def test_customer_fields
    @helper.customer(:email => 'cody@example.com')
    assert_field 'user_email', 'cody@example.com'
  end

end
