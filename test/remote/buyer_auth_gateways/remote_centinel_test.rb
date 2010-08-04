require 'test_helper'

class CentinelBuyerAuthTest < Test::Unit::TestCase

  CentinelBuyerAuthGateway.logger = Logger.new(STDOUT)

  def setup
    @gateway = CentinelBuyerAuthGateway.new(fixtures(:centinel))               
    @amount = rand(10000)
    @enrolled = credit_card('4000000000000002')
    @options = { :order_id => generate_unique_id, :currency => "USD" }
  end

  def test_successful_verify_enrollment
    response = @gateway.verify_enrollment(@amount, @enrolled, @options)

    assert_success response
    assert response.test?

    p response
    
    assert_equal CentinelBuyerAuthGateway::SUCCESS_MSG, response.message
    assert_equal response.params["TransactionId"], response.authorization
  end
  
  # def test_error_verify_enrollment
  #   @gateway.expects(:ssl_post).returns(error_verify_enrollment_response)
  #   
  #   response = @gateway.verify_enrollment(@amount, @credit_card, @options)
  # 
  #   assert_failure response
  #   assert response.test?
  #   
  #   assert_equal "U", response.params["Enrolled"]
  #   assert_equal "2Zqy5Svlx0SSivIC0vaL", response.params["TransactionId"]
  #   assert_equal "Payment Initiative Not Supported", response.params["ErrorDesc"]
  #   assert_equal "1360", response.params["ErrorNo"]
  #   
  #   assert_equal response.params["ErrorDesc"], response.message
  #   assert_equal response.params["TransactionId"], response.authorization
  # end
  # 
  # def test_successful_validate_authentication
  #   @gateway.expects(:ssl_post).returns(successful_validate_authentication_response)
  #   
  #   response = @gateway.validate_authentication("pares", :order_id => "md")
  #   assert_success response
  #   
  #   assert_equal "05", response.params["EciFlag"]
  #   assert_equal "Y", response.params["PAResStatus"]
  #   assert_equal "Y", response.params["SignatureVerification"]
  #   assert_equal "R2Y4QXdCc1hiZWw5Y3lrZ29iZ1E=", response.params["Xid"]
  #   assert_equal nil, response.params["ErrorDesc"]
  #   assert_equal "0", response.params["ErrorNo"]
  #   assert_equal "AAABAlIFMAAAAAAAdgUwENiWiV+=", response.params["Cavv"]
  # end
  # 
  # def test_error_validate_authentication
  #   @gateway.expects(:ssl_post).returns(error_validate_authentication_response)
  #   
  #   response = @gateway.validate_authentication("pares", :order_id => "md")
  # 
  #   assert_failure response
  #   assert response.test?
  #   
  #   assert_equal "Error Processing Authenticate Request Message, Error Validating Message, Transaction Id is Empty", response.params["ErrorDesc"]
  #   assert_equal "1003, 4268", response.params["ErrorNo"]
  #   
  #   assert_equal response.params["ErrorDesc"], response.message
  #   assert_equal nil, response.authorization
  # end
  # 
end