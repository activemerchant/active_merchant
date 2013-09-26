require 'test_helper'

class DibsPaymentTest < Test::Unit::TestCase
  
  def setup
    @gateway = DibsGateway.new(
      :login => 12356012, 
      :password =>'5168216856327a756834793a463025577c5e6b487d582d63294f262a6725483f4d30696c377b3f2b29304c2921546e6b52497378645d71377d594d522c576c3f'
    )

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number             => 54130300033444,
      :month              => 6,
      :year               => 24,
      :verification_value => 684
    )

    @amount = 100

    @options = {
      :orderId     =>  generate_unique_id[0...10],
      :currency    =>  'DKK',
      :clientIp    =>  "10.10.10.10",
      :issueNumber =>  5 
   }
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-RESPONSE
      {"transactionId":"696639873","status":"ACCEPT","acquirer":"test"}
    RESPONSE
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-RESPONSE
      {"status":"DECLINE","declineReason":"REJECTED_BY_ACQUIRER"}
    RESPONSE
  end
end
