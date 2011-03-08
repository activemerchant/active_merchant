require 'test_helper'

class PpiPaymoverTest < Test::Unit::TestCase
  def setup
    @gateway = PpiPaymoverGateway.new(
                 :login => 'login'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
  
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
  end
  
  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
  
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
  
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_successful_void
    @gateway.stubs(:ssl_post).returns(successful_void_response)
  
    assert response = @gateway.void('1')
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
  end
  
  def test_failed_void
    @gateway.stubs(:ssl_post).returns(failed_void_response)
  
    assert response = @gateway.void('')
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_override_defaults
    result = {}
    @gateway.send(:add_default_options, result, {})
    assert_equal PpiPaymoverGateway::DEFAULT_INDUSTRY, result[:industry]
    assert_equal PpiPaymoverGateway::TRANSACTION_CONDITION_CODES[:secure_ecommerce], result[:transaction_condition_code]
    
    result_ovr = {}
    @gateway.send(:add_default_options, result, {:industry => 'RESTAURANT', :condition_code => PpiPaymoverGateway::TRANSACTION_CONDITION_CODES[:ach_web]})
    assert_equal 'RESTAURANT', result[:industry]
    assert_equal PpiPaymoverGateway::TRANSACTION_CONDITION_CODES[:ach_web], result[:transaction_condition_code]
  end

  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
    assert_success response
    assert_equal '1', response.authorization
  end
  
  def test_failed_credit
    @gateway.expects(:ssl_post).returns(failed_credit_response)
    
    assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
    assert_failure response
  end
  
  def test_supported_countries
    assert_equal ['US'], PpiPaymoverGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], PpiPaymoverGateway.supported_cardtypes
  end
  
  def test_response_fraud_review
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert response.fraud_review?
    assert_equal "Card declined: Test transaction response: Hold card and call issuer.", response.message
  end
  


  private
  
  # Place raw successful response from gateway here
  def successful_purchase_response
    "response_code=1\nresponse_code_text=Successful transaction: Test transaction response.\ntime_stamp=1299616619833\nretry_recommended=false\nsecondary_response_code=0\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=3\navs_code=\ncredit_card_verification_response=\n"
  end
  
  # Place raw failed response from gateway here
  def failed_purchase_response
    "response_code=100\nresponse_code_text=Card declined: Test transaction response.\ntime_stamp=1299616622275\nretry_recommended=false\nsecondary_response_code=0\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\n"
  end

  def successful_authorization_response
    "response_code=1\nresponse_code_text=Successful transaction: Test transaction response.\ntime_stamp=1299616617942\nretry_recommended=false\nsecondary_response_code=0\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\n"
  end
  
  def successful_void_response
    "response_code=1\nresponse_code_text=Successful transaction: Test transaction response.\ntime_stamp=1299616615843\nretry_recommended=false\nsecondary_response_code=0\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\n"
  end
  
  def failed_void_response
    "response_code=2\nresponse_code_text=Missing Required Request Field: Account Token.\ntime_stamp=1299616610288\nretry_recommended=false\nsecondary_response_code=0\n"
  end
  
  def successful_credit_response
    "response_code=1\nresponse_code_text=Successful transaction: Test transaction response.\ntime_stamp=1299616615843\nretry_recommended=false\nsecondary_response_code=0\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\n"
  end
  
  def failed_credit_response
    "response_code=3\nresponse_code_text=Invalid request field: Refund amount exceeds purchased amount.\ntime_stamp=1299619141880\nretry_recommended=false\nsecondary_response_code=0\norder_id=435184\ncapture_reference_id=\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\n"
  end
  
  def fraud_review_response
    "response_code=100\nresponse_code_text=Card declined: Test transaction response: Hold card and call issuer.\ntime_stamp=1299616609479\nretry_recommended=false\nsecondary_response_code=8\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\n"
  end
  
  def failed_authorization_response
    "response_code=100\nresponse_code_text=Card declined: Test transaction response.\ntime_stamp=1299616622275\nretry_recommended=false\nsecondary_response_code=0\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\n"
  end
end
