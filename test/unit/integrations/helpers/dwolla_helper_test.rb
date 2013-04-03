require 'test_helper'
require 'digest/sha1'

class DwollaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Dwolla::Helper.new('order-500','812-546-3855', :credential2 => 'mykey', :credential3 => 'mysecret', :amount => 500, :currency => 'USD')
  end

  def test_basic_helper_fields
    assert_field 'amount', '500'
    assert_field 'orderid', 'order-500'
    assert_field 'destinationid', '812-546-3855'
    assert_field 'key', 'mykey'
    assert_field 'timestamp', Time.now.to_i.to_s

    expected_signature = Digest::SHA1.hexdigest('mysecret' + 'mykey&' + Time.now.to_i.to_s() +'&order-500')
    assert_field 'signature', expected_signature
  end

  def test_other_fields
    @helper.return_url 'http://test.com/ecommerce/redirect.aspx'
    @helper.notify_url 'http://test.com/test/callback'
    @helper.test_mode true
    @helper.description 'Store Purchase Description'
    @helper.shipping 0.00
    @helper.tax 0.00

    assert_field 'key', 'mykey'
    assert_field 'destinationid', '812-546-3855'
    assert_field 'redirect', 'http://test.com/ecommerce/redirect.aspx'
    assert_field 'callback', 'http://test.com/test/callback'
    assert_field 'test', 'true'
    assert_field 'description', 'Store Purchase Description'
    assert_field 'destinationid', '812-546-3855'
    assert_field 'shipping', '0.0'
    assert_field 'tax', '0.0'
    assert_field 'allowFundingSources', 'true'
  end
end
