require 'test_helper'

class CyberMutHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = CyberMut::Helper.new('order-500', 'ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ',
                                   :amount => 500, :currency => 'EUR')
  end

  def test_static_fields
    assert_field 'version', '3.0'
    assert_field 'montant', '500.00EUR'
    assert_field 'lgue', 'FR'
    assert_field 'reference', 'order-500'
    assert_field 'TPE', '123456'
    assert_equal @helper.fields['MAC'].size, 40
  end

  def test_basic_helper_fields
    assert_field 'montant', '500.00EUR'
  end
end
