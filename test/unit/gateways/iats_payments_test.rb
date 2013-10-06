require 'test_helper'

class IatsPaymentsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = IatsPaymentsGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    @amount = 100
    @credit_card = credit_card
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141795', response.authorization
  end

  private
  def successful_purchase_response
    '1,1,1,This transaction has been approved.,d1GENk,Y,508141795,32968c18334f16525227,Store purchase,1.00,CC,auth_capture,,Longbob,Longsen,,,,,,,,,,,,,,,,,,,,,,,269862C030129C1173727CC10B1935ED,P,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,'
  end
end
