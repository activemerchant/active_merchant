require 'test_helper'

class PayFastHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = PayFast::Helper.new(123, '10000100', :amount => 500, :credential2 => '46f0cd694581a', :credential3 => '0a1e2e10-03a7-4928-af8a-fbdfdfe31d43')
  end

  def assing_required_fields
    @helper.item_name = 'ZOMG'
    @helper.notify_url = 'http://test.com/pay_fast/paid'
  end

  def test_basic_helper_fields
    assing_required_fields

    assert_field 'merchant_id', '10000100'
    assert_field 'merchant_key', '46f0cd694581a'
    assert_field 'notify_url', 'http://test.com/pay_fast/paid'
    assert_field 'amount', '500'
    assert_field 'm_payment_id', '123'
    assert_field 'item_name', 'ZOMG'
  end

  def test_request_signature_string
    assing_required_fields

    assert_equal 'merchant_id=10000100&merchant_key=46f0cd694581a&notify_url=http%3A%2F%2Ftest.com%2Fpay_fast%2Fpaid&m_payment_id=123&amount=500&item_name=ZOMG', @helper.request_signature_string
  end

  def test_request_generated_signature
    assert_equal '60117d6d87ef8fb297e9811479d892e6', @helper.generate_signature(:request)
  end
end
