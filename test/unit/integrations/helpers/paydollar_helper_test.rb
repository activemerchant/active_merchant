require 'test_helper'

class PaydollarHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Paydollar::Helper.new('order-500','', :amount => 500, :currency => 'HKD')
  end
 
  def test_basic_helper_fields
    assert_field 'currCode', 'HKD'
    assert_field 'amount', '500'
    assert_field 'orderRef', 'order-500'
  end
  
  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

  def test_secure_hash_generation
    @helper.merchant_id = 10001
    @helper.pay_type = "N"
    @helper.secret_hash("joshsoftware*123")
    assert_equal @helper.generate_secure_hash, "2436483d940e6234f1108af90a7a5ab356779391"
  end
end
