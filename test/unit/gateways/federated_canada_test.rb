require 'test_helper'

class FederatedCanadaTest < Test::Unit::TestCase
  def setup
    @gateway = FederatedCanadaGateway.new(
                 :login => 'demo',
                 :password => 'password'
               )

    @credit_card = credit_card
		@credit_card.number = '4111111111111111'
		@credit_card.month = '11'
		@credit_card.year = '2011'
		
		@credit_card.verification_value = '999'
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
    assert_equal '100', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
		"response=1&responsetext=SUCCESS&authcode=123456&transactionid=1346648416&avsresponse=N&cvvresponse=N&orderid=&type=auth&response_code=100"
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
		"response=2&responsetext=DECLINE&authcode=&transactionid=1346648595&avsresponse=N&cvvresponse=N&orderid=&type=sale&response_code=200"
  end
end
