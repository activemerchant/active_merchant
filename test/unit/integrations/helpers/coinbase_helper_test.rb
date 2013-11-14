require 'test_helper'

class CoinbaseHelperTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def setup
    @helper = Coinbase::Helper.new('order-500','api_key', :amount => 500, :currency => 'USD')
  end
 
  def test_helper_id
    Net::HTTP.any_instance.expects(:request).returns(stub(:body => '{"success":true,"button":{"code":"test123"}}'))

    assert_equal 'test123', @helper.form_fields['id']
  end
end
