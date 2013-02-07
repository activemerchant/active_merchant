require 'test_helper'

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
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
  
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141794', response.authorization
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141795', response.authorization
  end
  
  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)
  
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '508141794', response.authorization
  end
  
  def test_add_address_outsite_north_america
    result = {}
    
    @gateway.send(:add_address, result, :billing_address => {:address1 => '123 Test St.', :address2 => '5F', :city => 'Testville', :company => 'Test Company', :country => 'DE', :state => ''} )
    
    assert_equal ["ADDR1", "ADDR2", "CITY", "COMPANY_NAME", "COUNTRY", "NAME1", "NAME2", "PHONE", "STATE", "ZIP"], result.stringify_keys.keys.sort
    assert_equal 'n/a', result[:STATE]
    assert_equal '123 Test St.', result[:ADDR1] 
    assert_equal 'DE', result[:COUNTRY]     
  end
                                                             
  def test_add_address
    result = {}
  
    @gateway.send(:add_address, result, :billing_address => {:address1 => '123 Test St.', :address2 => '5F', :city => 'Testville', :company => 'Test Company', :country => 'US', :state => 'AK'} )  
   
    assert_equal ["ADDR1", "ADDR2", "CITY", "COMPANY_NAME", "COUNTRY", "NAME1", "NAME2", "PHONE", "STATE", "ZIP"], result.stringify_keys.keys.sort 
    assert_equal 'AK', result[:STATE]
    assert_equal '123 Test St.', result[:ADDR1]
    assert_equal 'US', result[:COUNTRY]
    
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
  
  def test_add_duplicate_window_without_duplicate_window
    result = {}
    @gateway.class.duplicate_window = nil
    @gateway.send(:add_duplicate_window, result)
    assert_nil result[:duplicate_window]
  end
  
  def test_add_duplicate_window_with_duplicate_window
    result = {}
    @gateway.class.duplicate_window = 0
    @gateway.send(:add_duplicate_window, result)
    assert_equal 0, result[:duplicate_window]
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
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.refund(@amount, '123456789', :card_number => @credit_card.number)
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
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
      assert_success response
      assert_equal 'This transaction has been approved', response.message
    end
  end
  
  def test_supported_countries
    assert_equal ['US'], BluePayGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb],  BluePayGateway.supported_cardtypes
  end
  
  def test_failure_without_response_reason_text
    assert_nothing_raised do
      assert_equal '', @gateway.send(:message_from, {})
    end
  end
  
  def test_response_under_review_by_fraud_service
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert response.fraud_review?
    assert_equal "Thank you! For security reasons your order is currently being reviewed", response.message
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'X', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(fraud_review_response)
    
    response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'M', response.cvv_result['code']
  end

  def test_message_from
    @gateway.class_eval {
      public :message_from
    }
    result = {
      :response_code => 2,
      :card_code => 'N',
      :avs_result_code => 'A',
      :response_reason_code => '27',
      :response_reason_text => 'Failure.',
    }
    assert_equal "No Match", @gateway.message_from(result)

    result[:card_code] = 'M'
    assert_equal "Street address matches, but 5-digit and 9-digit postal code do not match.", @gateway.message_from(result)

    result[:response_reason_code] = '22'
    assert_equal "Failure", @gateway.message_from(result)
  end
  
  # Recurring Billing Unit Tests

  def test_successful_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)

    response = @gateway.recurring(@amount, @credit_card,
      :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
      :rebill_start_date => '1 MONTH',
      :rebill_expression => '14 DAYS',
      :rebill_cycles     => '24',
      :rebill_amount     => @amount * 4
   )

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_id, response.authorization
  end

  def test_successful_update_recurring
    @gateway.expects(:ssl_post).returns(successful_update_recurring_response)

    response = @gateway.update_recurring(:rebill_id => @rebill_id, :rebill_amount => @amount * 2)

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_id, response.authorization
  end

  def test_successful_cancel_recurring
    @gateway.expects(:ssl_post).returns(successful_cancel_recurring_response)

    response = @gateway.cancel_recurring(@rebill_id)

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_id, response.authorization
  end

  def test_successful_status_recurring
    @gateway.expects(:ssl_post).returns(successful_status_recurring_response)

    response = @gateway.status_recurring(@rebill_id)
    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @rebill_status, response.params['status'][0]
  end

  def test_solution_id_is_added_to_post_data_parameters
    assert !@gateway.send(:post_data, 'AUTH_ONLY').include?("solution_ID=A1000000")
    ActiveMerchant::Billing::BluePayGateway.application_id = 'A1000000'
    assert @gateway.send(:post_data, 'AUTH_ONLY').include?("solution_ID=A1000000")
  ensure
    ActiveMerchant::Billing::BluePayGateway.application_id = nil
  end

  private
  def minimum_requirements
    %w(version delim_data relay_response login tran_key amount card_num exp_date type)
  end
  
  def failed_refund_response
    '$3$,$2$,$54$,$The referenced transaction does not meet the criteria for issuing a credit.$,$$,$P$,$0$,$$,$$,$1.00$,$CC$,$credit$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$39265D8BA0CDD4F045B5F4129B2AAA01$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
  
  def successful_authorization_response
    '$1$,$1$,$1$,$This transaction has been approved.$,$advE7f$,$Y$,$508141794$,$5b3fe66005f3da0ebe51$,$$,$1.00$,$CC$,$auth_only$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$2860A297E0FE804BCB9EF8738599645C$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
  
  def successful_purchase_response
    '$1$,$1$,$1$,$This transaction has been approved.$,$d1GENk$,$Y$,$508141795$,$32968c18334f16525227$,$Store purchase$,$1.00$,$CC$,$auth_capture$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$269862C030129C1173727CC10B1935ED$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
  
  def failed_authorization_response
    '$2$,$1$,$1$,$This transaction was declined.$,$advE7f$,$Y$,$508141794$,$5b3fe66005f3da0ebe51$,$$,$1.00$,$CC$,$auth_only$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$2860A297E0FE804BCB9EF8738599645C$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end
 
  def fraud_review_response
    '$4$,$$,$253$,$Thank you! For security reasons your order is currently being reviewed.$,$$,$X$,$0$,$$,$$,$1.00$,$$,$auth_capture$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$207BCBBF78E85CF174C87AE286B472D2$,$M$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
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
end
