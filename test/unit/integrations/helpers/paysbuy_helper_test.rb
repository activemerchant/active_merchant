require 'test_helper'

class PaysbuyHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @helper = Paysbuy::Helper.new('order-500','cody@example.com', :amount => 5)
  end

  def test_basic_helper_fields
    assert_field 'biz', 'cody@example.com'

    assert_field 'amt', '5'
    assert_field 'inv', 'order-500'
  end
end
