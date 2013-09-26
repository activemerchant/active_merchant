require 'test_helper'

class WebmoneyHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Webmoney::Helper.new(
      123, 'test_account',
      :description => "Order description",
      :amount => 500,
      :fail_url => "http://example.com/fail_url",
      :success_url => "http://example.com/success_url",
      :result_url => "http://example.com/result_url"
    )
  end

  def test_basic_helper_fields
    assert_field 'LMI_PAYEE_PURSE', 'test_account'

    assert_field 'LMI_PAYMENT_AMOUNT', '500'
    assert_field 'LMI_PAYMENT_NO', '123'
  end
end
