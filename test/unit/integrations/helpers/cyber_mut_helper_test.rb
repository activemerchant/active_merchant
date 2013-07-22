require 'test_helper'

class CyberMutHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = CyberMut::Helper.new('order-500', 'cody@example.com', :amount => 500, :currency => 'EUR')
  end

  def test_static_fields
    assert_field 'version', '3.0'
    assert_field 'montant', '500.00EUR'
    assert_field 'lgue', 'FR'
    assert_field 'reference', 'order-500'
    assert_field 'societe', 'masociete'
    assert_field 'TPE', '123456'
  end

  def test_basic_helper_fields
    assert_field 'account', 'cody@example.com'

    assert_field 'amount', '500'
    assert_field 'order', 'order-500'
  end
end
