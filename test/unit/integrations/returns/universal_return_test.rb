require 'test_helper'

class UniversalReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @secret = 'TO78ghHCfBQ6ZBw2Q2fJ3wRwGkWkUHVs'
    @return = Universal::Return.new(query_data, :credential2 => @secret)
  end

  def test_valid_return
    assert @return.success?
  end

  def test_invalid_return
    @return = Universal::Return.new('', :credential2 => @secret)
    assert !@return.success?
  end

  private

  def query_data
    'x-account-id=zork&x-reference=order-500&x-currency=USD&x-test=true&x-amount=123.45&x-gateway-reference=blorb123&x-timestamp=2014-03-24T12:15:41Z&x-result=success&x-signature=2859972ffaf1276bad5b7c2009fa55fff111c87946fcd0a32eb5c51601b4e68d'
  end

end