require 'test_helper'

class CentinelBuyerAuthTest < Test::Unit::TestCase

  def setup
    @gateway = CentinelBuyerAuthGateway.new(
                 :login => "merchant id",
                 :password => "tx password",
                 :processor => "1000"
               )
               
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @options = { :order_id => "1", :currency => "USD" }
  end

  def test_successful_verify_enrollment
    @gateway.expects(:ssl_post).returns(successful_verify_enrollment_response)

    response = @gateway.verify_enrollment(@amount, @credit_card, @options)

    assert_success response
    assert response.test?
    
    assert_equal "07", response.params["EciFlag"]
    assert_equal "eNpVUstygjAU3ecrnE7XJAHqFOeaGRUcdVpq0TKtO4QoWAUMUB9f3wR8tFndcx8n95wE5rHg3J7xsBKcwSsvimDNW0nUfXjyZ+nCGA6SF2pv++52pDvzBwbTnsf3DH64KJIsZVQjmg74CpGkEGEcpCWDINz3xy4z25SYBuALRLDjYmwz0hzADUSQBjvOZnGWJ6sT4BohCLMqLcWJPettwFeAoBJbFpdl3sH4cDhoRTOlhdkOsKohwPc9ppWKCinvmETM9Rfz5TY7e99uPreHztKZvC2d9cnz37uAVQeCKCg50wmxiEXNFrU6htUhFuA6jyDYqUXYo65rlhLWQAS5uqjXIF1Xpb8ZKaYSgqehVGNK3TeEgB/zLOVqCvAtlhrumw9Gys+wlE55E9ejUelTazNc9Y0PevjanN3hZ9xTHtctNWMinaKE0JoyqW3DigZfXhBfHltG/z7BL5gorGw=", response.params["Payload"]
    assert_equal "Y", response.params["Enrolled"]
    assert_equal "5VSnZ3FCiL1DlBNlH2ET", response.params["TransactionId"]
    assert_equal "3854668635669588", response.params["OrderId"]
    assert_equal nil, response.params["ErrorDesc"]
    assert_equal "0", response.params["ErrorNo"]
    assert_equal "https://testcustomer34.cardinalcommerce.com/V3DSStart?osb=visa-3&VAA=B", response.params["ACSUrl"]
  
    assert_equal CentinelBuyerAuthGateway::SUCCESS_MSG, response.message
    assert_equal response.params["TransactionId"], response.authorization
  end
  
  def test_error_verify_enrollment
    @gateway.expects(:ssl_post).returns(error_verify_enrollment_response)
    
    response = @gateway.verify_enrollment(@amount, @credit_card, @options)

    assert_failure response
    assert response.test?
    
    assert_equal "U", response.params["Enrolled"]
    assert_equal "2Zqy5Svlx0SSivIC0vaL", response.params["TransactionId"]
    assert_equal "Payment Initiative Not Supported", response.params["ErrorDesc"]
    assert_equal "1360", response.params["ErrorNo"]
    
    assert_equal response.params["ErrorDesc"], response.message
    assert_equal response.params["TransactionId"], response.authorization
  end
  
  def test_successful_validate_authentication
    @gateway.expects(:ssl_post).returns(successful_validate_authentication_response)
    
    response = @gateway.validate_authentication("pares", :order_id => "md")
    assert_success response
    
    assert_equal "05", response.params["EciFlag"]
    assert_equal "Y", response.params["PAResStatus"]
    assert_equal "Y", response.params["SignatureVerification"]
    assert_equal "R2Y4QXdCc1hiZWw5Y3lrZ29iZ1E=", response.params["Xid"]
    assert_equal nil, response.params["ErrorDesc"]
    assert_equal "0", response.params["ErrorNo"]
    assert_equal "AAABAlIFMAAAAAAAdgUwENiWiV+=", response.params["Cavv"]
  end
  
  def test_error_validate_authentication
    @gateway.expects(:ssl_post).returns(error_validate_authentication_response)
    
    response = @gateway.validate_authentication("pares", :order_id => "md")

    assert_failure response
    assert response.test?
    
    assert_equal "Error Processing Authenticate Request Message, Error Validating Message, Transaction Id is Empty", response.params["ErrorDesc"]
    assert_equal "1003, 4268", response.params["ErrorNo"]
    
    assert_equal response.params["ErrorDesc"], response.message
    assert_equal nil, response.authorization
  end
  
  private
  def successful_verify_enrollment_response
    <<-XML
<?xml version="1.0"?>
<CardinalMPI>
  <EciFlag>07</EciFlag>
  <Payload>eNpVUstygjAU3ecrnE7XJAHqFOeaGRUcdVpq0TKtO4QoWAUMUB9f3wR8tFndcx8n95wE5rHg3J7xsBKcwSsvimDNW0nUfXjyZ+nCGA6SF2pv++52pDvzBwbTnsf3DH64KJIsZVQjmg74CpGkEGEcpCWDINz3xy4z25SYBuALRLDjYmwz0hzADUSQBjvOZnGWJ6sT4BohCLMqLcWJPettwFeAoBJbFpdl3sH4cDhoRTOlhdkOsKohwPc9ppWKCinvmETM9Rfz5TY7e99uPreHztKZvC2d9cnz37uAVQeCKCg50wmxiEXNFrU6htUhFuA6jyDYqUXYo65rlhLWQAS5uqjXIF1Xpb8ZKaYSgqehVGNK3TeEgB/zLOVqCvAtlhrumw9Gys+wlE55E9ejUelTazNc9Y0PevjanN3hZ9xTHtctNWMinaKE0JoyqW3DigZfXhBfHltG/z7BL5gorGw=</Payload>
  <Enrolled>Y</Enrolled>
  <TransactionId>5VSnZ3FCiL1DlBNlH2ET</TransactionId>
  <OrderId>3854668635669588</OrderId>
  <ErrorDesc/>
  <ErrorNo>0</ErrorNo>
  <ACSUrl>https://testcustomer34.cardinalcommerce.com/V3DSStart?osb=visa-3&amp;VAA=B</ACSUrl>
</CardinalMPI>
    XML
  end

  def error_verify_enrollment_credit_card_response
    <<-XML
<?xml version="1.0"?>
<CardinalMPI>
  <ErrorDesc>Error Processing Lookup Request Message, Error Validating Credit Card Expiration Information Passed (YYMM) [0901] </ErrorDesc>
  <ErrorNo>1002, 4090</ErrorNo>
  <TransactionId>Q4IGfMSJmX1737vDn5TT</TransactionId>
  <Enrolled>U</Enrolled>
  <EciFlag/>
</CardinalMPI>
    XML
  end
  
  def error_verify_enrollment_response
    <<-XML
<?xml version="1.0"?>
<CardinalMPI>
  <ErrorDesc>Payment Initiative Not Supported</ErrorDesc>
  <ErrorNo>1360</ErrorNo>
  <TransactionId>2Zqy5Svlx0SSivIC0vaL</TransactionId>
  <Payload/>
  <Enrolled>U</Enrolled>
  <EciFlag/>
  <ACSUrl/>
</CardinalMPI>
    XML
  end
  
  def successful_validate_authentication_response
    <<-XML
<?xml version="1.0"?>
<CardinalMPI>
  <EciFlag>05</EciFlag>
  <PAResStatus>Y</PAResStatus>
  <SignatureVerification>Y</SignatureVerification>
  <Xid>R2Y4QXdCc1hiZWw5Y3lrZ29iZ1E=</Xid>
  <ErrorDesc/>
  <ErrorNo>0</ErrorNo>
  <Cavv>AAABAlIFMAAAAAAAdgUwENiWiV+=</Cavv>
</CardinalMPI>
    XML
  end
  
  def error_validate_authentication_response
    <<-XML
<?xml version="1.0"?>
<CardinalMPI>
  <ErrorDesc>Error Processing Authenticate Request Message, Error Validating Message, Transaction Id is Empty</ErrorDesc>
  <ErrorNo>1003, 4268</ErrorNo>
</CardinalMPI>
    XML
  end
end