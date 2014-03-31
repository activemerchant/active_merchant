require 'test_helper'

class AuthorizeNetTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AuthorizeNetXmlGateway.new(
      :login => 'X',
      :password => 'Y'
    )

    @transaction = @gateway.send(:get_transaction, 'AUTH_CAPTURE')
    @amount = 100
    @credit_card = credit_card
    @subscription_id = '100748'
    @subscription_status = 'active'
    @check = check
  end

=begin
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
=end

  def test_add_address_outsite_north_america
    @gateway.send(:add_address, @transaction, :billing_address => {:address1 => '164 Waverley Street', :country => 'DE', :state => ''} )

    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], @transaction.fields.stringify_keys.keys.sort
    assert_equal 'n/a', @transaction.fields[:state]
    assert_equal '164 Waverley Street', @transaction.fields[:address]
    assert_equal 'DE', @transaction.fields[:country]
  end

  def test_add_address
    @gateway.send(:add_address, @transaction, :billing_address => {:address1 => '164 Waverley Street', :country => 'US', :state => 'CO'} )

    assert_equal ["address", "city", "company", "country", "phone", "state", "zip"], @transaction.fields.stringify_keys.keys.sort
    assert_equal 'CO', @transaction.fields[:state]
    assert_equal '164 Waverley Street', @transaction.fields[:address]
    assert_equal 'US', @transaction.fields[:country]
  end

  def test_add_invoice
    @gateway.send(:add_invoice, @transaction, :order_id => '#1001', :description => 'My Purchase is great')

    assert_equal '#1001', @transaction.fields[:invoice_num]
    assert_equal 'My Purchase is great', @transaction.fields[:description]
  end

  def test_add_duplicate_window_without_duplicate_window
    @gateway.class.duplicate_window = nil
    @gateway.send(:add_duplicate_window, @transaction)

    assert_nil @transaction.fields[:duplicate_window]
  end

  def test_add_duplicate_window_with_duplicate_window
    @gateway.class.duplicate_window = 0
    @gateway.send(:add_duplicate_window, @transaction)

    assert_equal 0, @transaction.fields[:duplicate_window]
  end

  def test_add_customer_data
    options = {:cardholder_authentication_value => 'E0Mvq8AAABEiMwARIjNEVWZ3iJk=',
               :authentication_indicator => '2',
               :ip => 'what is this?',
               :customer => 7.5,
               :email => 'none@noway.com'}
    @gateway.send(:add_customer_data, @transaction, options)

    assert_equal 'E0Mvq8AAABEiMwARIjNEVWZ3iJk=', @transaction.fields[:cardholder_authentication_value]
    assert_equal '2', @transaction.fields[:authentication_indicator]
    assert_equal 'what is this?', @transaction.fields[:customer_ip]
    assert_equal  7.5, @transaction.fields[:cust_id]
    assert_equal 'none@noway.com', @transaction.fields[:email]
    assert_equal false, @transaction.fields[:email_customer]
  end

  def test_add_customer_data_with_bad_data
    options = {:customer => 'x'}
    @gateway.send(:add_customer_data, @transaction, options)

    assert_equal  nil, @transaction.fields[:cust_id]
  end

=begin

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
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      assert response = @gateway.credit(@amount, '123456789', :card_number => @credit_card.number)
      assert_success response
      assert_equal 'This transaction has been approved', response.message
    end
  end

  def test_supported_countries
    assert_equal ['US', 'CA', 'GB'], AuthorizeNetGateway.supported_countries
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

  # ARB Unit Tests

  def test_successful_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)

    response = @gateway.recurring(@amount, @credit_card,
      :billing_address => address.merge(:first_name => 'Jim', :last_name => 'Smith'),
      :interval => {
        :length => 10,
        :unit => :days
      },
      :duration => {
        :start_date => Time.now.strftime("%Y-%m-%d"),
        :occurrences => 30
      }
   )

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_id, response.authorization
  end

  def test_successful_update_recurring
    @gateway.expects(:ssl_post).returns(successful_update_recurring_response)

    response = @gateway.update_recurring(:subscription_id => @subscription_id, :amount => @amount * 2)

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_id, response.authorization
  end

  def test_successful_cancel_recurring
    @gateway.expects(:ssl_post).returns(successful_cancel_recurring_response)

    response = @gateway.cancel_recurring(@subscription_id)

    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_id, response.authorization
  end

  def test_successful_status_recurring
    @gateway.expects(:ssl_post).returns(successful_status_recurring_response)

    response = @gateway.status_recurring(@subscription_id)
    assert_instance_of Response, response
    assert response.success?
    assert response.test?
    assert_equal @subscription_status, response.params['status']
  end

  def test_expdate_formatting
    assert_equal '2009-09', @gateway.send(:arb_expdate, credit_card('4111111111111111', :month => "9", :year => "2009"))
    assert_equal '2013-11', @gateway.send(:arb_expdate, credit_card('4111111111111111', :month => "11", :year => "2013"))
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
=end
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

  def failed_authorization_response
    '$2$,$1$,$1$,$This transaction was declined.$,$advE7f$,$Y$,$508141794$,$5b3fe66005f3da0ebe51$,$$,$1.00$,$CC$,$auth_only$,$$,$Longbob$,$Longsen$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$2860A297E0FE804BCB9EF8738599645C$,$P$,$2$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$,$$'
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

  def successful_recurring_response
    <<-XML
<ARBCreateSubscriptionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <subscriptionId>#{@subscription_id}</subscriptionId>
</ARBCreateSubscriptionResponse>
    XML
  end

  def successful_update_recurring_response
    <<-XML
<ARBUpdateSubscriptionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <subscriptionId>#{@subscription_id}</subscriptionId>
</ARBUpdateSubscriptionResponse>
    XML
  end

  def successful_cancel_recurring_response
    <<-XML
<ARBCancelSubscriptionResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <subscriptionId>#{@subscription_id}</subscriptionId>
</ARBCancelSubscriptionResponse>
    XML
  end

  def successful_status_recurring_response
    <<-XML
<ARBGetSubscriptionStatusResponse xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
  <refId>Sample</refId>
  <messages>
    <resultCode>Ok</resultCode>
    <message>
      <code>I00001</code>
      <text>Successful.</text>
    </message>
  </messages>
  <Status>#{@subscription_status}</Status>
</ARBGetSubscriptionStatusResponse>
    XML
  end
end
