require 'test_helper'

class RavenPacNetTest < Test::Unit::TestCase
  def setup
    @gateway = RavenPacNetGateway.new(
                 :user => 'user',
                 :secret => 'secret',
                 :prn => 123456
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :billing_address => address
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal '123456789', response.authorization
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
    "RequestResult=ok&ApprovalCode=096685&Message=&Status=Approved&TrackingNumber=123456789"
  end

  def failed_purchase_response
    "RequestResult=ok&ApprovalCode=&Message=&Status=Declined&TrackingNumber=123456789"
  end
end
