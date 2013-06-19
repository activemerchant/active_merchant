require 'test_helper'

class EProcessingNetworkTest < Test::Unit::TestCase
  def setup
    @gateway = EProcessingNetworkGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @pass_amount = 100
    @fail_amount = 101

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@pass_amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '20130618211654-080880-151234', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@fail_amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    '"YAPPROVED 535624","AVS Match 9 Digit Zip and Address (X)","CVV2 Match (M)","151234","20130618211654-080880-151234"'
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    '"NDECLINED","AVS Match 9 Digit Zip and Address (X)","CVV2 Match (M)","151235","20130618211737-080880-151235-0"'
  end
end
