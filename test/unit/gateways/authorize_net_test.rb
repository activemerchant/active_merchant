require 'test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AuthorizeNetGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    @amount = 100
    @credit_card = credit_card
    @check = check
  end

  def test_successful_echeck_authorization
    response = stub_comms do
      @gateway.authorize(@amount, @check)
    end.check_request do |endpoint, data, headers|
      assert_match(/x_method=ECHECK/, data)
      assert_match(/x_bank_aba_code=244183602/, data)
      assert_match(/x_bank_acct_num=15378535/, data)
      assert_match(/x_bank_name=Bank\+of\+Elbonia/, data)
      assert_match(/x_bank_acct_name=Jim\+Smith/, data)
      assert_match(/x_echeck_type=WEB/, data)
      assert_match(/x_bank_check_number=1/, data)
      assert_match(/x_recurring_billing=FALSE/, data)
    end.respond_with(successful_authorization_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141794', response.authorization
  end

  def test_successful_echeck_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @check)
    end.check_request do |endpoint, data, headers|
      assert_match(/x_method=ECHECK/, data)
      assert_match(/x_bank_aba_code=244183602/, data)
      assert_match(/x_bank_acct_num=15378535/, data)
      assert_match(/x_bank_name=Bank\+of\+Elbonia/, data)
      assert_match(/x_bank_acct_name=Jim\+Smith/, data)
      assert_match(/x_echeck_type=WEB/, data)
      assert_match(/x_bank_check_number=1/, data)
      assert_match(/x_recurring_billing=FALSE/, data)
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
    assert_equal '508141795', response.authorization
  end

  def test_echeck_passing_recurring_flag
    response = stub_comms do
      @gateway.purchase(@amount, @check, :recurring => true)
    end.check_request do |endpoint, data, headers|
      assert_match(/x_recurring_billing=TRUE/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_echeck_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @check)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '508141794', response.authorization
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

  def test_failed_already_actioned_capture
    @gateway.expects(:ssl_post).returns(already_actioned_capture_response)

    assert response = @gateway.capture(50, '123456789')
    assert_instance_of Response, response
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorization_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_failed_void
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response, failed_void_response)
    assert_success response
    assert_equal "This transaction has been approved", response.message
  end

  def test_unsuccessful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_authorization_response, successful_void_response)
    assert_failure response
    assert_equal "This transaction was declined", response.message
  end

  def test_add_address_outsite_north_america
    result = {}

    @gateway.send(:add_address, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => ''} )

    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'n/a', result[:state]
    assert_equal '164 Waverley Street', result[:address]
    assert_equal 'DE', result[:country]
  end

  def test_add_address
    result = {}

    @gateway.send(:add_address, result, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )

    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], result.stringify_keys.keys.sort
    assert_equal 'CO', result[:state]
    assert_equal '164 Waverley Street', result[:address]
    assert_equal 'US', result[:country]

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

  def test_add_cardholder_authentication_value
    result = {}
    params = {:cardholder_authentication_value => 'E0Mvq8AAABEiMwARIjNEVWZ3iJk=', :authentication_indicator => '2'}
    @gateway.send(:add_customer_data, result, params)
    assert_equal 'E0Mvq8AAABEiMwARIjNEVWZ3iJk=', result[:cardholder_authentication_value]
    assert_equal '2', result[:authentication_indicator]
  end

  def test_purchase_is_valid_csv
   params = { :amount => '1.01' }

   @gateway.send(:add_creditcard, params, @credit_card)

   assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
   assert_equal post_data_fixture.size, data.size
  end

  def test_purchase_meets_minimum_requirements
    params = {
      :amount => "1.01",
    }

    @gateway.send(:add_creditcard, params, @credit_card)

    assert data = @gateway.send(:post_data, 'AUTH_ONLY', params)
    minimum_requirements.each do |key|
      assert_not_nil(data =~ /x_#{key}=/)
    end
  end

  def test_action_included_in_params
   @gateway.expects(:ssl_post).returns(successful_purchase_response)

   response = @gateway.capture(50, '123456789')
   assert_equal('PRIOR_AUTH_CAPTURE', response.params['action'] )
  end

  def test_authorization_code_included_in_params
   @gateway.expects(:ssl_post).returns(successful_purchase_response)

   response = @gateway.capture(50, '123456789')
   assert_equal('d1GENk', response.params['authorization_code'] )
  end

  def test_cardholder_authorization_code_included_in_params
   @gateway.expects(:ssl_post).returns(successful_purchase_response)

   response = @gateway.capture(50, '123456789')
   assert_equal('2', response.params['cardholder_authentication_code'] )
  end

  def test_capture_passing_extra_info
    response = stub_comms do
      @gateway.capture(50, '123456789', :description => "Yo", :order_id => "Sweetness")
    end.check_request do |endpoint, data, headers|
      assert_match(/x_description=Yo/, data)
      assert_match(/x_invoice_num=Sweetness/, data)
    end.respond_with(successful_capture_response)
    assert_success response
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
      assert_match(/x_first_name=Bob/, data)
      assert_match(/x_last_name=Smith/, data)
      assert_match(/x_zip=12345/, data)
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
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE) do
      assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
      assert_success response
      assert_equal 'This transaction has been approved', response.message
    end
  end

  def test_supported_countries
    assert_equal 4,
      (['US', 'CA', 'AU', 'VA'] & AuthorizeNetGateway.supported_countries).size
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :diners_club, :jcb], AuthorizeNetGateway.supported_cardtypes
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

  def test_solution_id_is_added_to_post_data_parameters
    assert !@gateway.send(:post_data, 'AUTH_ONLY').include?("x_solution_ID=A1000000")
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = 'A1000000'
    assert @gateway.send(:post_data, 'AUTH_ONLY').include?("x_solution_ID=A1000000")
  ensure
    ActiveMerchant::Billing::AuthorizeNetGateway.application_id = nil
  end

  def test_bad_currency
    @gateway.expects(:ssl_post).returns(bad_currency_response)

    response = @gateway.purchase(@amount, @credit_card, {:currency => "XYZ"})
    assert_failure response
    assert_equal 'The supplied currency code is either invalid, not supported, not allowed for this merchant or doesn\'t have an exchange rate', response.message
  end

  def test_alternate_currency
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, {:currency => "GBP"})
    assert_success response
  end

  def test_include_cust_id_for_numeric_values
   stub_comms do
      @gateway.purchase(@amount, @credit_card, {:customer => "123"})
    end.check_request do |method, data|
      assert data =~ /x_cust_id=123/
    end.respond_with(successful_authorization_response)
  end

  def test_dont_include_cust_id_for_non_numeric_values
   stub_comms do
      @gateway.purchase(@amount, @credit_card, {:customer => "bob@test.com"})
    end.check_request do |method, data|
      assert data !~ /x_cust_id/
    end.respond_with(successful_authorization_response)
  end

  private

  def post_data_fixture
    'x_encap_char=%24&x_card_num=4242424242424242&x_exp_date=0806&x_card_code=123&x_type=AUTH_ONLY&x_first_name=Longbob&x_version=3.1&x_login=X&x_last_name=Longsen&x_tran_key=Y&x_relay_response=FALSE&x_delim_data=TRUE&x_delim_char=%2C&x_amount=1.01'
  end

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

  def successful_capture_response
    '$1$,$1$,$1$,$This transaction has been approved.$,$d1GENk$,$Y$,$508141795$,$32968c18334f16525227$,$Store purchase$,$1.00$,$CC$,$auth_capture$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$269862C030129C1173727CC10B1935ED$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end

  def successful_void_response
    '$1$,$1$,$1$,$This transaction has been approved.$,$O39YT0$,$P$,$2215573915$,$823f2867c0cd10cf6e7e$,$$,$0.00$,$CC$,$void$,$$,$$,$$,$$,$$,$$,$$,$K1C2N6$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$C9C5D270851F841D0CD9E64542D8D3BC$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$XXXX4242$,$Visa$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end

  def failed_authorization_response
    '$2$,$1$,$1$,$This transaction was declined.$,$advE7f$,$Y$,$508141794$,$5b3fe66005f3da0ebe51$,$$,$1.00$,$CC$,$auth_only$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$2860A297E0FE804BCB9EF8738599645C$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end

  def failed_void_response
    '$1$,$1$,$310$,$This transaction has already been voided.$,$$,$P$,$0$,$$,$$,$0.00$,$CC$,$void$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$02AA39F01BE7579FCBE318A14D516F9C$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$Visa$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end

  def already_actioned_capture_response
    '$1$,$2$,$311$,$This transaction has already been captured.$,$$,$P$,$0$,$$,$$,$1.00$,$CC$,$credit$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$39265D8BA0CDD4F045B5F4129B2AAA01$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
  end

  def fraud_review_response
    "$4$,$$,$253$,$Thank you! For security reasons your order is currently being reviewed.$,$$,$X$,$0$,$$,$$,$1.00$,$$,$auth_capture$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$207BCBBF78E85CF174C87AE286B472D2$,$M$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$"
  end

  def bad_currency_response
    "$3$,$1$,$39$,$The supplied currency code is either invalid, not supported, not allowed for this merchant or doesn't have an exchange rate.$,$$,$P$,$0$,$$,$$,$1.00$,$$,$auth_capture$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$207BCBBF78E85CF174C87AE286B472D2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$"
  end
end
