require 'test_helper'

class FinansbankTest < Test::Unit::TestCase
  def setup
    @gateway = FinansbankGateway.new(
                 :login => 'login',
                 :password => 'password',
                 :client_id => 'client_id'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '1', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  def successful_purchase_response
    <<-EOF
<CC5Response>
      <OrderId>1</OrderId>
      <GroupId>2</GroupId>
      <Response>Approved</Response>
      <AuthCode>123456</AuthCode>
      <HostRefNum>123456</HostRefNum>
      <ProcReturnCode>00</ProcReturnCode>
      <TransId>123456</TransId>
      <ErrMsg></ErrMsg>
</CC5Response>
    EOF
  end

  def failed_purchase_response
    <<-EOF
<CC5Response>
      <OrderId>1</OrderId>
      <GroupId>2</GroupId>
      <Response>Declined</Response>
      <AuthCode></AuthCode>
      <HostRefNum>123456</HostRefNum>
      <ProcReturnCode>12</ProcReturnCode>
      <TransId>123456</TransId>
      <ErrMsg>Not enough credit</ErrMsg>
</CC5Response>
    EOF
  end
end
