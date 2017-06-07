require 'test_helper'

class RobokassaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Robokassa::Helper.new(
      123, 'test_account',
      :description => "Order description",
      :amount => 500,
      :currency => 'USD',
      :fail_url => "http://example.com/fail_url",
      :success_url => "http://example.com/success_url",
      :result_url => "http://example.com/result_url"
    )
  end

  def test_basic_helper_fields
    assert_field 'business_email', 'test_account'

    assert_field 'amount', '500'
    assert_field 'item_id', '123'
    assert_field 'currency', 'USD'
    assert_field 'description', 'Order description'
    assert_field 'success_url', 'http://example.com/success_url'
    assert_field 'fail_url', 'http://example.com/fail_url'
    assert_field 'result_url', 'http://example.com/result_url'
  end

end
