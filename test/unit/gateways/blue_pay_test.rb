require 'test_helper'

RSP = {
  :approved_auth => "AUTH_CODE=XCADZ&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=AUTH&REBID=&STATUS=1&AVS=_&TRANS_ID=100134203758&CVV2=_&MESSAGE=Approved%20Auth",
  :approved_capture => "AUTH_CODE=CHTHX&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=CAPTURE&REBID=&STATUS=1&AVS=_&TRANS_ID=100134203760&CVV2=_&MESSAGE=Approved%20Capture",
  :approved_void => "AUTH_CODE=KTMHB&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=VOID&REBID=&STATUS=1&AVS=_&TRANS_ID=100134203763&CVV2=_&MESSAGE=Approved%20Void",
  :declined => "TRANS_ID=100000000150&STATUS=0&AVS=0&CVV2=7&MESSAGE=Declined&REBID=",
  :approved_purchase => "AUTH_CODE=GYRUY&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=SALE&REBID=&STATUS=1&AVS=_&TRANS_ID=100134203767&CVV2=_&MESSAGE=Approved%20Sale"
}

class BluePayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = BluePayGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    @amount = 100
    @credit_card = credit_card
    @rebill_id = '100096219669'
    @rebill_status = 'active'
  end

  def test_successful_authorization
    #@gateway.expects(:ssl_post).returns(successful_authorization_response)
    @gateway.expects(:ssl_post).returns(RSP[:approved_auth])
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100134203758', response.authorization
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(RSP[:approved_purchase])

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '100134203767', response.authorization
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(RSP[:declined])

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '100000000150', response.authorization
  end

  def test_add_address_outsite_north_america
    result = {}

    @gateway.send(:add_address, result, :billing_address => {:address1 => '123 Test St.', :address2 => '5F', :city => 'Testville', :company => 'Test Company', :country => 'DE', :state => ''} )
    assert_equal ["ADDR1", "ADDR2", "CITY", "COMPANY_NAME", "COUNTRY", "PHONE", "STATE", "ZIP"], result.stringify_keys.keys.sort
    assert_equal 'n/a', result[:STATE]
    assert_equal '123 Test St.', result[:ADDR1]
    assert_equal 'DE', result[:COUNTRY]
  end

  def test_add_address
    result = {}

    @gateway.send(:add_address, result, :billing_address => {:address1 => '123 Test St.', :address2 => '5F', :city => 'Testville', :company => 'Test Company', :country => 'US', :state => 'AK'} )

    assert_equal ["ADDR1", "ADDR2", "CITY", "COMPANY_NAME", "COUNTRY", "PHONE", "STATE", "ZIP"], result.stringify_keys.keys.sort
    assert_equal 'AK', result[:STATE]
    assert_equal '123 Test St.', result[:ADDR1]
    assert_equal 'US', result[:COUNTRY]

  end

  def test_name_comes_from_payment_method
    result = {}

    @gateway.send(:add_creditcard, result, @credit_card)
    @gateway.send(:add_address, result, :billing_address => {:address1 => '123 Test St.', :address2 => '5F', :city => 'Testville', :company => 'Test Company', :country => 'US', :state => 'AK'} )

    assert_equal @credit_card.first_name, result[:NAME1]
    assert_equal @credit_card.last_name, result[:NAME2]
  end

  def test_add_invoice
    result = {}
    @gateway.send(:add_invoice, result, :order_id => '#1001')
    assert_equal '#1001', result[:invoice_num]
  end

  def test_add_description
    result = {}
    @gateway.send(:add_invoice, result, :description => 'My Purchase is great')
    assert_equal 'My Purchase is great', result[:description]
  end

  def test_purchase_meets_minimum_requirements
    params = {
      :amount => "1.01",
    }

    @gateway.send(:add_creditcard, params, @credit_card)

    assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
    minimum_requirements.each do |key|
      assert_not_nil(data =~ /#{key}=/)
    end
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert response = @gateway.refund(@amount, '100134230412', :card_number => @credit_card.number)
    assert_success response
    assert_equal 'This transaction has been approved', response.message
  end

  def test_refund_passing_extra_info
    response = stub_comms do
      @gateway.refund(50, '123456789', :card_number => @credit_card.number, :first_name => "Bob", :last_name => "Smith", :zip => "12345")
    end.check_request do |endpoint, data, headers|
      assert_match(/NAME1=Bob/, data)
      assert_match(/NAME2=Smith/, data)
      assert_match(/ZIP=12345/, data)
    end.respond_with(successful_purchase_response)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    assert response = @gateway.refund(@amount, '123456789', :card_number => @credit_card.number)
    assert_failure response
    assert_equal 'The referenced transaction does not meet the criteria for issuing a credit', response.message
  end

  def test_deprecated_credit
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert_deprecation_warning("credit should only be used to credit a payment method") do
      assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
      assert_success response
      assert_equal 'This transaction has been approved', response.message
    end
  end

  def test_supported_countries
    assert_equal ['US', 'CA'], BluePayGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb],  BluePayGateway.supported_cardtypes
  end

  def test_parser_extracts_exactly_the_keys_in_gateway_response
    assert_nothing_raised do
      response = @gateway.send(:parse, "NEW_IMPORTANT_FIELD=value_on_fire")
      assert_equal response.params.keys, ['NEW_IMPORTANT_FIELD']
      assert_equal response.params['NEW_IMPORTANT_FIELD'], "value_on_fire"
    end
  end

  def test_failure_without_response_reason_text
    assert_nothing_raised do
      assert_equal '', @gateway.send(:parse, "MESSAGE=").message
    end
  end

  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal '_', response.avs_result['code']
  end

  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    response = @gateway.purchase(@amount, @credit_card)
    assert_equal '_', response.cvv_result['code']
  end

  def test_message_from

    def get_msg(query)
      @gateway.send(:parse, query).message
    end
    assert_equal "CVV does not match", get_msg('STATUS=2&CVV2=N&AVS=A&MESSAGE=FAILURE')
    assert_equal "Street address matches, but 5-digit and 9-digit postal code do not match.",
                   get_msg('STATUS=2&CVV2=M&AVS=A&MESSAGE=FAILURE')
  end

  # Recurring Billing Unit Tests
  def test_successful_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.recurring(@amount, @credit_card,
        :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
        :rebill_start_date => '1 MONTH',
        :rebill_expression => '14 DAYS',
        :rebill_cycles     => '24',
        :rebill_amount     => @amount * 4
     )
    end

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_id, response.authorization
  end

  def test_successful_update_recurring
    @gateway.expects(:ssl_post).returns(successful_update_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.update_recurring(:rebill_id => @rebill_id, :rebill_amount => @amount * 2)
    end

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_id, response.authorization
  end

  def test_successful_cancel_recurring
    @gateway.expects(:ssl_post).returns(successful_cancel_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.cancel_recurring(@rebill_id)
    end

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_id, response.authorization
  end

  def test_successful_status_recurring
    @gateway.expects(:ssl_post).returns(successful_status_recurring_response)

    response = assert_deprecation_warning(Gateway::RECURRING_DEPRECATION_MESSAGE) do
      @gateway.status_recurring(@rebill_id)
    end
    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_status, response.params['status']
  end

  def test_solution_id_is_added_to_post_data_parameters
    assert !@gateway.send(:post_data, 'AUTH_ONLY').include?("solution_ID=A1000000")
    ActiveMerchant::Billing::BluePayGateway.application_id = 'A1000000'
    assert @gateway.send(:post_data, 'AUTH_ONLY').include?("solution_ID=A1000000")
  ensure
    ActiveMerchant::Billing::BluePayGateway.application_id = nil
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def minimum_requirements
    %w(version delim_data relay_response login tran_key amount card_num exp_date type)
  end

  def successful_refund_response
    "AUTH_CODE=GFOCD&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=CREDIT&REBID=&STATUS=1&AVS=_&TRANS_ID=100134230412&CVV2=_&MESSAGE=Approved%20Credit"
  end

  def failed_refund_response
    'AUTH_CODE=&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=CREDIT&REBID=&STATUS=0&AVS=_&TRANS_ID=100134229326&CVV2=_&MESSAGE=The%20referenced%20transaction%20does%20not%20meet%20the%20criteria%20for%20issuing%20a%20credit'
  end

  def successful_authorization_response
    "AUTH_CODE=RSWUC&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=AUTH&REBID=&STATUS=1&AVS=_&TRANS_ID=100134229528&CVV2=_&MESSAGE=Approved%20Auth"
  end

  def successful_purchase_response
    "AUTH_CODE=KHJMY&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=SALE&REBID=&STATUS=1&AVS=_&TRANS_ID=100134229668&CVV2=_&MESSAGE=Approved%20Sale"
  end

  def failed_authorization_response
    "AUTH_CODE=&PAYMENT_ACCOUNT_MASK=xxxxxxxxxxxx4242&CARD_TYPE=VISA&TRANS_TYPE=AUTH&REBID=&STATUS=0&AVS=_&TRANS_ID=100134229728&CVV2=_&MESSAGE=Declined%20Auth"
  end

  def successful_recurring_response
    'last_date=2012-04-13%2009%3A49%3A27&usual_date=2012-04-13%2000%3A00%3A00&template_id=100096219668&status=active&account_id=100096218902&rebill_id=100096219669&reb_amount=2.00&creation_date=2012-04-13%2009%3A49%3A19&sched_expr=1%20DAY&next_date=2012-04-13%2000%3A00%3A00&next_amount=&user_id=100096218903&cycles_remain=4'
  end

  def successful_update_recurring_response
    'last_date=2012-04-13%2009%3A49%3A27&usual_date=2012-04-13%2000%3A00%3A00&template_id=100096219668&status=active&account_id=100096218902&rebill_id=100096219669&reb_amount=2.00&creation_date=2012-04-13%2009%3A49%3A19&sched_expr=1%20DAY&next_date=2012-04-13%2000%3A00%3A00&next_amount=&user_id=100096218903&cycles_remain=4'
  end

  def successful_cancel_recurring_response
    'last_date=2012-04-13%2009%3A49%3A27&usual_date=2012-04-13%2000%3A00%3A00&template_id=100096219668&status=stopped&account_id=100096218902&rebill_id=100096219669&reb_amount=2.00&creation_date=2012-04-13%2009%3A49%3A19&sched_expr=1%20DAY&next_date=2012-04-13%2000%3A00%3A00&next_amount=&user_id=100096218903&cycles_remain=4'
  end

  def successful_status_recurring_response
    'last_date=2012-04-13%2009%3A49%3A27&usual_date=2012-04-13%2000%3A00%3A00&template_id=100096219668&status=active&account_id=100096218902&rebill_id=100096219669&reb_amount=2.00&creation_date=2012-04-13%2009%3A49%3A19&sched_expr=1%20DAY&next_date=2012-04-13%2000%3A00%3A00&next_amount=&user_id=100096218903&cycles_remain=4'
  end

  def transcript
    "card_num=4111111111111111&exp_date=1212&MASTER_ID=&PAYMENT_TYPE=CREDIT&PAYMENT_ACCOUNT=4242424242424242&CARD_CVV2=123&CARD_EXPIRE=0916&NAME1=Longbob&NAME2=Longsen&ORDER_ID=78c40687dd55dbdc140df777b0e8ece3&INVOICE_ID=&invoice_num=78c40687dd55dbdc140df777b0e8ece3&EMAIL=&CUSTOM_ID=&DUPLICATE_OVERRIDE=&TRANS_TYPE=SALE&AMOUNT=1.00&MODE=TEST&ACCOUNT_ID=100096218902&TAMPER_PROOF_SEAL=55624458ce3e15fa8e33e6f2d784bbcb"
  end

  def scrubbed_transcript
    "card_num=[FILTERED]&exp_date=1212&MASTER_ID=&PAYMENT_TYPE=CREDIT&PAYMENT_ACCOUNT=[FILTERED]&CARD_CVV2=[FILTERED]&CARD_EXPIRE=0916&NAME1=Longbob&NAME2=Longsen&ORDER_ID=78c40687dd55dbdc140df777b0e8ece3&INVOICE_ID=&invoice_num=78c40687dd55dbdc140df777b0e8ece3&EMAIL=&CUSTOM_ID=&DUPLICATE_OVERRIDE=&TRANS_TYPE=SALE&AMOUNT=1.00&MODE=TEST&ACCOUNT_ID=100096218902&TAMPER_PROOF_SEAL=[FILTERED]"
  end
end
