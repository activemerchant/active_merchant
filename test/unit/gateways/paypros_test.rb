require 'test_helper'

class PayprosTest < Test::Unit::TestCase
  def setup
    @gateway = PayprosGateway.new(
                 :login => 'login'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
    
    @card_swipe = "000|111|222|333|444|555|666|777|888|999|101010|111111|121212"
    
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
    assert_equal PayprosGateway::DEFAULT_INDUSTRY, result[:industry]
    assert_equal PayprosGateway::TRANSACTION_CONDITION_CODES[:secure_ecommerce], result[:transaction_condition_code]
    
    result_ovr = {}
    @gateway.send(:add_default_options, result, {:industry => 'RESTAURANT', :condition_code => PayprosGateway::TRANSACTION_CONDITION_CODES[:ach_web]})
    assert_equal 'RESTAURANT', result[:industry]
    assert_equal PayprosGateway::TRANSACTION_CONDITION_CODES[:ach_web], result[:transaction_condition_code]
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
    assert_equal ['US'], PayprosGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], PayprosGateway.supported_cardtypes
  end
  
  def test_response_fraud_review
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert response.fraud_review?
    assert_equal "Card declined: Test transaction response: Hold card and call issuer.", response.message
  end
  
  def test_invalid_cardswipe
    assert_raise ArgumentError do
      @gateway.purchase(@amount, "bad swipe data")
    end
    
    assert_raise ArgumentError do
      @gateway.purchase(@amount, "000|111|222|333|444|555|666|777|888|999|101010|111111")
    end
    
    assert_raise ArgumentError do
      @gateway.purchase(@amount, "000|111|222|333|444|555|666|777|888|999|101010|111111|121212|131313")
    end
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
  
    assert response = @gateway.authorize(@amount, @card_swipe)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
  end
  
  def test_successful_purchase_swipe
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    assert response = @gateway.purchase(@amount, @card_swipe)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
  end
  
  def test_successful_query
    @gateway.expects(:ssl_post).returns(successful_query_response)
  
    assert response = @gateway.query_purchase('1')
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
  end
  
  def test_successful_mpd_authorization
    @gateway.expects(:ssl_post).returns(successful_mpd_authorization_response)
    @options[:manage_payer_data] = true
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
    assert_equal '00000000-1111-2222-3333-444444444444', response.params['payer_identifier']
    assert_equal @credit_card.last_digits, response.params['span']
  end
  
  def test_successful_mpd_purchase
    @gateway.expects(:ssl_post).returns(successful_mpd_purchase_response)
    @options[:manage_payer_data] = true
    @options[:span] = @credit_card.last_digits
    @options[:payer_identifier] = '00000000-1111-2222-3333-444444444444'
    
    assert response = @gateway.purchase(@amount, nil, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1', response.authorization
    assert_equal '00000000-1111-2222-3333-444444444444', response.params['payer_identifier']
    assert_equal @credit_card.last_digits, response.params['span']
    assert_equal "%.2f" % (@amount / 100.0), response.params['captured_amount']
  end
  
  def test_failured_mpd_purchase
    @gateway.expects(:ssl_post).returns(failed_mpd_purchase_response)
    @options[:manage_payer_data] = true
    @options[:span] = @credit_card.last_digits
    @options[:payer_identifier] = '00000000-1111-2222-3333-444444444444'
    
    assert response = @gateway.purchase(@amount, nil, @options)
    assert_instance_of Response, response
    assert_failure response
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
  
  def successful_mpd_authorization_response
    "response_code=1\nresponse_code_text=Successful transaction: Test transaction response.\ntime_stamp=1325184123822\nretry_recommended=false\nsecondary_response_code=0\npayer_identifier=00000000-1111-2222-3333-444444444444\nmanage_until=1327603323878\nmpd_response_code=1\nmpd_response_code_text=Success\nspan=4242\nexpire_month=9\nexpire_year=2012\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=\navs_code=\ncredit_card_verification_response=\nrequested_amount=0.01\nauthorized_amount=0.01\ncaptured_amount=0.00\n"
  end
  
  def successful_mpd_purchase_response
    "response_code=1\nresponse_code_text=Successful transaction: Test transaction response.\ntime_stamp=1325184493835\nretry_recommended=false\nsecondary_response_code=0\npayer_identifier=00000000-1111-2222-3333-444444444444\nmanage_until=1327603693881\nmpd_response_code=1\nmpd_response_code_text=Success\nspan=4242\nexpire_month=9\nexpire_year=2012\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=29\navs_code=\ncredit_card_verification_response=\nrequested_amount=1.00\nauthorized_amount=1.00\ncaptured_amount=1.00\n"
  end
  
  def failed_mpd_purchase_response
    "response_code=6\nresponse_code_text=Transaction Not Possible: specified payer data is not under management\ntime_stamp=1325184663794\nretry_recommended=false\nsecondary_response_code=0\n"
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
  
  def successful_query_response
    "response_code=1\nresponse_code_text=Successful transaction: The transaction completed successfully.\ntime_stamp=1300484952005\nretry_recommended=false\nsecondary_response_code=0\norder_id=1\ncapture_reference_id=1\niso_code=\nbank_approval_code=\nbank_transaction_id=\nbatch_id=7\navs_code=\ncredit_card_verification_response=\ntime_stamp_created=1300484951000\nstate=payment_deposited\ncaptured_amount=0.01\nauthorized_amount=0.01\noriginal_authorized_amount=0.01\nrequested_amount=0.01\n"
  end
end
