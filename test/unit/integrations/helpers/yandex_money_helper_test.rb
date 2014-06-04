require 'test_helper'

class YandexMoneyHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = YandexMoney::Helper.new('order-500','cody@example.com', :amount => 5.0, :currency => 'RUB')
  end
 
  def test_basic_helper_fields
    assert_field 'customerNumber', 'cody@example.com'

    assert_field 'sum', '5.0'
    assert_field 'orderNumber', 'order-500'
  end
  
  def test_customer_fields
    @helper.customer :email => 'cody@example.com'
    assert_field 'cps_email', 'cody@example.com'
  end

  def test_unknown_mapping
    assert_nothing_raised do
      @helper.company_address :address => '500 Dwemthy Fox Road'
    end
  end

end