require 'test_helper'

class PayboxSystemHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = PayboxSystem::Helper.new('order-500', '107904482',
                                       :amount => 500,
                                       :currency => '978',
                                       :credential3 => '1999888',
                                       :credential4 => '32'
                                      )
  end

  def test_static_fields
    assert_field 'PBX_HASH', 'SHA512'
    assert_field 'PBX_RETOUR', "amount:M;reference:R;autorization:A;error:E;sign:K"
    assert_match(/(\d){4}-(\d){2}-(\d){2}T(\d){2}:(\d){2}:(\d){2}Z/, @helper.fields['PBX_TIME'])
    assert_equal 128, @helper.fields['PBX_HMAC'].size
  end

  def test_basic_helper_fields
    assert_field 'PBX_IDENTIFIANT', '107904482'
    assert_field 'PBX_DEVISE', '978'
    assert_field 'PBX_TOTAL', '500'
    assert_field 'PBX_CMD', 'order-500'
  end

  def test_options_fields
    assert_field 'PBX_SITE', @helper.credential3
    assert_field 'PBX_RANG', @helper.credential4
  end
end
