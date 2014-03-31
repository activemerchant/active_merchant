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
    'x_account_id=zork&x_reference=order-500&x_currency=USD&x_test=true&x_amount=123.45&x_gateway_reference=blorb123&x_timestamp=2014-03-24T12:15:41Z&x_result=success&x_signature=4365fef32f5309845052b728c8cbe962e583ecaf62bf1cdec91f248162b7f65e'
  end
end
