require 'test_helper'

class DibsHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Dibs::Helper.new('order-100500', 123456789, :amount => 500, :currency => 208)
  end
 
  def test_basic_helper_fields
    assert_field 'orderid',  'order-100500'
    assert_field 'merchant', '123456789'
    assert_field 'amount',   '500'
    assert_field 'currency', '208'
  end

  def test_address_mapping
    @helper.billing_address :billingfirstname => 'John',
                            :billinglastname => 'Doe',
                            :billingaddress => '17 Rock Rd. Boston Mass',
                            :billingpostalcode => '04932',
                            :billingemail=> 'johndoe@gmail.com'
 
    assert_field 'billingfirstname', 'John'
    assert_field 'billinglastname',  'Doe'
    assert_field 'billingaddress', '17 Rock Rd. Boston Mass'
    assert_field 'billingpostalcode', '04932'
  end


  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

end
