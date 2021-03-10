require File.dirname(__FILE__) + '/../../test_helper'

class RocketgateTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = RocketgateGateway.new(
                 :login => '1',
                 :password => 'testpassword'
               )

    
    @amount = 100
    @credit_card = credit_card('4111111111111111')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :currency => 'USD'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'Transaction Successful', response.message
    assert_success response
    
    # Replace with authorization number from the successful response
    # assert_equal '1000121571773B1', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @amount=5
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?><gatewayResponse><cardType>VISA</cardType><cardCountry>US</cardCountry><approvedAmount>100</approvedAmount><approvedCurrency>USD</approvedCurrency><reasonCode>0</reasonCode><merchantAccount>3</merchantAccount><version>1.0</version><cardLastFour>1111</cardLastFour><cardHash>m77xlHZiPKVsF9p1/VdzTb+CUwaGBDpuSRxtcb7+j24=</cardHash><guidNo>1000121571773B1</guidNo><responseCode>0</responseCode><authNo>822766</authNo><cardExpiration>1012</cardExpiration></gatewayResponse>
    XML
  end

  
  # Place raw failed response from gateway here
  def failed_purchase_response
    <<-XML
<?xml version="1.0" encoding="UTF-8"?><gatewayResponse><version>1.0</version><responseCode>4</responseCode><guidNo>100012157177326</guidNo><reasonCode>411</reasonCode></gatewayResponse>
    XML
  end
end
