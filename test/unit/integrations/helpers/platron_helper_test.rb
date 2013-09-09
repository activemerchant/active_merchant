require 'test_helper'

class PlatronHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Platron::Helper.new(
      '123',
      'test_account',
      :amount => 200,
      :currency => 'USD',
      :description => 'payment description',
      :secret => 'secret',
      :path => 'payment.php'
    )
  end

  def test_helper_fields
    assert_field 'pg_merchant_id', 'test_account'
    assert_field 'pg_amount', '200'
    assert_field 'pg_order_id', '123'
    assert_field 'pg_currency', 'USD'
    assert_field 'pg_description', 'payment description'
  end
end
