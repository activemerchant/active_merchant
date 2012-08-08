require 'test_helper'

class EasyPayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = EasyPay::Helper.new(123, 'test_account', :amount => 500, :credential2 => 'secret')
  end

  def test_basic_helper_fields
    assert_field 'EP_MerNo', 'test_account'
    assert_field 'EP_Sum', '500'
    assert_field 'EP_OrderNo', '123'
  end

  def test_request_signature_string
    assert_equal 'test_accountsecret123500', @helper.request_signature_string
  end
end
