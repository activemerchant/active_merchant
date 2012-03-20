require 'test_helper'

class RobokassaHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Robokassa::Helper.new(123,'test_account', :amount => 500, :currency => 'USD', :secret => 'secret')
  end

  def test_basic_helper_fields
    assert_field 'MrchLogin', 'test_account'

    assert_field 'OutSum', '500'
    assert_field 'InvId', '123'
  end

  def test_signature_string
    assert_equal 'test_account:500:123:secret', @helper.generate_signature_string
  end

  def test_custom_fields
    @helper.shpa = '123'
    @helper.shpMySuperParam = '456'

    assert_field 'shpa', '123'
    assert_field 'shpMySuperParam', '456'
  end

  def test_signature_string_with_custom_fields
    @helper.shpb = '456'
    @helper.shpa = '123'

    assert_equal 'test_account:500:123:secret:shpa=123:shpb=456', @helper.generate_signature_string
  end
end
