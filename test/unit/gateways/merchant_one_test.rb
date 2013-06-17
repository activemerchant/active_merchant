require 'test_helper'

class MerchantOneTest < Test::Unit::TestCase
  def setup
    @gateway = MerchantOneGateway.new(
                 :username => 'demo',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 1000

    @options = {
      :order_id => '1',
      :billing_address => {name: 'Jim Smith', address1: '1234 My Street', address2: 'Apt 1', city: 'Tampa', state: 'FL', zip: '33603', country: 'US', phone: '(813)421-4331'},
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal '281719471', response.authorization
    assert response.test?, response.test.to_s
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?, response.test.to_s
  end

  private

  # Place raw successful response from gateway here
  def successful_purchase_response
    "response=1&responsetext=SUCCESS&authcode=123456&transactionid=281719471&avsresponse=&cvvresponse=M&orderid=&type=sale&response_code=100"
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    "response=3&responsetext=DECLINE&authcode=123456&transactionid=281719471&avsresponse=&cvvresponse=M&orderid=&type=sale&response_code=300"
  end
end
