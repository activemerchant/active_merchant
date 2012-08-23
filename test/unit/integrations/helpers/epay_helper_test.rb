require 'test_helper'

class EpayHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Epay::Helper.new('order-500','99999999', :amount => 500, :currency => 'DKK')
    @helper.md5secret "secretmd5"
    @helper.return_url 'http://example.com/ok'
    @helper.cancel_return_url 'http://example.com/cancel'
    @helper.notify_url 'http://example.com/notify'
  end

  def test_basic_helper_fields
    assert_field 'merchantnumber', '99999999'
    assert_field 'amount', '500'
    assert_field 'orderid', 'order500'
  end

  def test_generate_md5string
    assert_equal 'http://example.com/ok500http://example.com/notifyhttp://example.com/cancelDKK099999999order5003secretmd5', @helper.generate_md5string
  end

  def test_generate_md5hash
    assert_equal '251c2f80d1dcd120a87a2480025714cb', @helper.generate_md5hash
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

  def test_setting_invalid_address_field
    fields = @helper.fields.dup
    @helper.billing_address :street => 'My Street'
    assert_equal fields, @helper.fields
  end
end
