require 'test_helper'

class StripeTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = StripeGateway.new(:login => 'login')

    @credit_card = credit_card()
    @amount = 400
    @refund_amount = 200

    @options = {
      :billing_address => address(),
      :description => 'Test Purchase'
    }
  end

  def test_successful_new_customer_with_card
    @gateway.expects(:ssl_request).returns(successful_new_customer_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M', response.authorization
    assert response.test?
  end

  def test_successful_new_card
    @gateway.expects(:ssl_request).returns(successful_new_card_response)

    assert response = @gateway.store(@credit_card, :customer => 'cus_3sgheFxeBgTQ3M')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_card_and_customer_update
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)

    assert response = @gateway.store(@credit_card, :customer => 'cus_3sgheFxeBgTQ3M', :email => 'test@test.com')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_default_card
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)

    assert response = @gateway.store(@credit_card, @options.merge(:customer => 'cus_3sgheFxeBgTQ3M', :set_default => true))
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, "ch_test_charge")
    assert_success response
    assert response.test?
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_amount_localization
    @gateway.expects(:ssl_request).returns(successful_purchase_response(true))
    @gateway.expects(:post_data).with do |params|
      assert_equal '4', params[:amount]
    end

    @options[:currency] = 'JPY'

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_purchase_with_token
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, "tok_xxx")
    end.check_request do |method, endpoint, data, headers|
      assert_match(/card=tok_xxx/, data)
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def test_successful_purchase_with_statement_description
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, statement_description: '5K RACE TICKET')
    end.check_request do |method, endpoint, data, headers|
      assert_match(/statement_description=5K\+RACE\+TICKET/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_purchase_response(true))

    assert response = @gateway.void('ch_test_charge')
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(generic_error_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_failure response
  end

  def test_successful_refund_with_refund_application_fee
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert post.include?("refund_application_fee=true")
    end.returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', :refund_application_fee => true)
    assert_success response
  end

  def test_successful_refund_with_refund_fee_amount
    s = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_application_fee_list_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_refunded_application_fee_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', :refund_fee_amount => 100)
    assert_success response
  end

  def test_refund_with_fee_response_gives_a_charge_authorization
    s = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_application_fee_list_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_refunded_application_fee_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', :refund_fee_amount => 100)
    assert_success response
    assert_equal 'ch_test_charge', response.authorization
  end

  def test_unsuccessful_refund_with_refund_fee_amount_when_application_fee_id_not_found
    s = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(unsuccessful_application_fee_list_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', :refund_fee_amount => 100)
    assert_failure response
    assert_match(/^Application fee id could not be found/, response.message)
  end

  def test_unsuccessful_refund_with_refund_fee_amount_when_refunding_application_fee
    s = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_application_fee_list_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(generic_error_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', :refund_fee_amount => 100)
    assert_failure response
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorization_response, failed_void_response)
    assert_success response
    assert_equal "Transaction approved", response.message
  end

  def test_unsuccessful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(declined_authorization_response, successful_void_response)
    assert_failure response
    assert_equal "Your card was declined.", response.message
  end

  def test_successful_request_always_uses_live_mode_to_determine_test_request
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response(:livemode => true))

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_success response

    assert !response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert !response.test? # unsuccessful request defaults to live
    assert_nil response.authorization
  end

  def test_declined_request
    @gateway.expects(:ssl_request).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert !response.test? # unsuccessful request defaults to live
    assert_equal 'ch_test_charge', response.authorization
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/^Invalid response received from the Stripe API/, response.message)
  end

  def test_add_creditcard_with_credit_card
    post = {}
    @gateway.send(:add_creditcard, post, @credit_card, {})
    assert_equal @credit_card.number, post[:card][:number]
    assert_equal @credit_card.month, post[:card][:exp_month]
    assert_equal @credit_card.year, post[:card][:exp_year]
    assert_equal @credit_card.verification_value, post[:card][:cvc]
    assert_equal @credit_card.name, post[:card][:name]
  end

  def test_add_creditcard_with_track_data
    post = {}
    @credit_card.stubs(:track_data).returns("Tracking data")
    @gateway.send(:add_creditcard, post, @credit_card, {})
    assert_equal @credit_card.track_data, post[:card][:swipe_data]
    assert_nil post[:card][:number]
    assert_nil post[:card][:exp_year]
    assert_nil post[:card][:exp_month]
    assert_nil post[:card][:cvc]
    assert_nil post[:card][:name]
  end

  def test_add_creditcard_with_token
    post = {}
    credit_card_token = "card_2iD4AezYnNNzkW"
    @gateway.send(:add_creditcard, post, credit_card_token, {})
    assert_equal credit_card_token, post[:card]
  end

  def test_add_creditcard_with_token_and_track_data
    post = {}
    credit_card_token = "card_2iD4AezYnNNzkW"
    @gateway.send(:add_creditcard, post, credit_card_token, :track_data => "Tracking data")
    assert_equal "Tracking data", post[:card][:swipe_data]
  end

  def test_add_customer
    post = {}
    @gateway.send(:add_customer, post, nil, {:customer => "test_customer"})
    assert_equal "test_customer", post[:customer]
  end

  def test_application_fee_is_submitted_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({:application_fee => 144}))
    end.check_request do |method, endpoint, data, headers|
      assert_match(/application_fee=144/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_application_fee_is_submitted_for_capture
    stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, "ch_test_charge", @options.merge({:application_fee => 144}))
    end.check_request do |method, endpoint, data, headers|
      assert_match(/application_fee=144/, data)
    end.respond_with(successful_capture_response)
  end

  def test_client_data_submitted_with_purchase
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({:description => "a test customer",:ip => "127.127.127.127", :user_agent => "some browser", :order_id => "42", :email => "foo@wonderfullyfakedomain.com", :referrer =>"http://www.shopify.com"})
      @gateway.purchase(@amount,@credit_card,updated_options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/description=a\+test\+customer/, data)
      assert_match(/ip=127\.127\.127\.127/, data)
      assert_match(/user_agent=some\+browser/, data)
      assert_match(/external_id=42/, data)
      assert_match(/referrer=http\%3A\%2F\%2Fwww\.shopify\.com/, data)
      assert_match(/payment_user_agent=Stripe\%2Fv1\+ActiveMerchantBindings\%2F\d+\.\d+\.\d+/, data)
      assert_match(/metadata\[email\]=foo\%40wonderfullyfakedomain\.com/, data)
      assert_match(/metadata\[order_id\]=42/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_client_data_submitted_with_purchase_without_email_or_order
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({:description => "a test customer",:ip => "127.127.127.127", :user_agent => "some browser", :referrer =>"http://www.shopify.com"})
      @gateway.purchase(@amount,@credit_card,updated_options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/description=a\+test\+customer/, data)
      assert_match(/ip=127\.127\.127\.127/, data)
      assert_match(/user_agent=some\+browser/, data)
      assert_match(/referrer=http\%3A\%2F\%2Fwww\.shopify\.com/, data)
      assert_match(/payment_user_agent=Stripe\%2Fv1\+ActiveMerchantBindings\%2F\d+\.\d+\.\d+/, data)
      refute_match(/metadata/, data)
    end.respond_with(successful_purchase_response)
  end


  def test_add_address
    post = {:card => {}}
    @gateway.send(:add_address, post, @options)
    assert_equal @options[:billing_address][:zip], post[:card][:address_zip]
    assert_equal @options[:billing_address][:state], post[:card][:address_state]
    assert_equal @options[:billing_address][:address1], post[:card][:address_line1]
    assert_equal @options[:billing_address][:address2], post[:card][:address_line2]
    assert_equal @options[:billing_address][:country], post[:card][:address_country]
    assert_equal @options[:billing_address][:city], post[:card][:address_city]
  end

  def test_ensure_does_not_respond_to_credit
    assert !@gateway.respond_to?(:credit)
  end

  def test_gateway_without_credentials
    assert_raises ArgumentError do
      StripeGateway.new
    end
  end

  def test_metadata_header
    @gateway.expects(:ssl_request).once.with {|method, url, post, headers|
      headers && headers['X-Stripe-Client-User-Metadata'] == {:ip => '1.1.1.1'}.to_json
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options.merge(:ip => '1.1.1.1'))
  end

  def test_optional_version_header
    @gateway.expects(:ssl_request).once.with {|method, url, post, headers|
      headers && headers['Stripe-Version'] == '2013-10-29'
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options.merge(:version => '2013-10-29'))
  end

  def test_initialize_gateway_with_version
    @gateway = StripeGateway.new(:login => 'login', :version => '2013-12-03')
    @gateway.expects(:ssl_request).once.with {|method, url, post, headers|
      headers && headers['Stripe-Version'] == '2013-12-03'
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_track_data_and_traditional_should_be_mutually_exclusive
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert data =~ /card\[name\]/
      assert data !~ /card\[swipe_data\]/
    end.respond_with(successful_purchase_response)

    stub_comms(@gateway, :ssl_request) do
      @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert data !~ /card\[name\]/
      assert data =~ /card\[swipe_data\]/
    end.respond_with(successful_purchase_response)
  end

  def test_address_is_included_with_card_data
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert data =~ /card\[address_line1\]/
    end.respond_with(successful_purchase_response)
  end

  def generate_options_should_allow_key
    assert_equal({:key => '12345'}, generate_options({:key => '12345'}))
  end

  def test_passing_expand_parameters
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert post.include?("expand[]=balance_transaction")
    end.returns(successful_authorization_response)

    @options.merge!(:expand => :balance_transaction)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_expand_parameters_as_array
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert post.include?("expand[]=balance_transaction&expand[]=customer")
    end.returns(successful_authorization_response)

    @options.merge!(:expand => [:balance_transaction, :customer])

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_recurring_flag_not_set_by_default
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert !post.include?("recurring")
    end.returns(successful_authorization_response)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_recurring_eci_sets_recurring_flag
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert post.include?("recurring=true")
    end.returns(successful_authorization_response)

    @options.merge!(eci: 'recurring')

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_unknown_eci_does_not_set_recurring_flag
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert !post.include?("recurring")
    end.returns(successful_authorization_response)

    @options.merge!(eci: 'installment')

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_recurring_true_option_sets_recurring_flag
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert post.include?("recurring=true")
    end.returns(successful_authorization_response)

    @options.merge!(recurring: true)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_recurring_false_option_does_not_set_recurring_flag
    @gateway.expects(:ssl_request).with do |method, url, post, headers|
      assert !post.include?("recurring")
    end.returns(successful_authorization_response)

    @options.merge!(recurring: false)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_new_attributes_are_included_in_update
    stub_comms(@gateway, :ssl_request) do
      @gateway.send(:update, "cus_3sgheFxeBgTQ3M", "card_483etw4er9fg4vF3sQdrt3FG", { :name => "John Smith", :exp_year => 2021, :exp_month => 6 })
    end.check_request do |method, endpoint, data, headers|
      assert data == "name=John+Smith&exp_year=2021&exp_month=6"
      assert endpoint.include? "/customers/cus_3sgheFxeBgTQ3M/cards/card_483etw4er9fg4vF3sQdrt3FG"
    end.respond_with(successful_update_credit_card_response)
  end

  private

  def successful_new_customer_response
    <<-RESPONSE
    {
      "object": "customer",
      "created": 1383137317,
      "id": "cus_3sgheFxeBgTQ3M",
      "livemode": false,
      "description": null,
      "email": null,
      "delinquent": false,
      "metadata": {},
      "subscription": null,
      "discount": null,
      "account_balance": 0,
      "cards":
      {
        "object": "list",
        "count": 1,
        "url": "/v1/customers/cus_3sgheFxeBgTQ3M/cards",
        "data":
        [
          {
            "id": "card_483etw4er9fg4vF3sQdrt3FG",
            "object": "card",
            "last4": "4242",
            "type": "Visa",
            "exp_month": 11,
            "exp_year": 2020,
            "fingerprint": "5dgRQ3dVRGaQWDFb",
            "customer": "cus_3sgheFxeBgTQ3M",
            "country": "US",
            "name": "John Doe",
            "address_line1": null,
            "address_line2": null,
            "address_city": null,
            "address_state": null,
            "address_zip": null,
            "address_country": null,
            "cvc_check": null,
            "address_line1_check": null,
            "address_zip_check": null
          }
        ]
      },
      "default_card": "card_483etw4er9fg4vF3sQdrt3FG"
    }
    RESPONSE
  end

  def successful_new_card_response
    <<-RESPONSE
    {
      "id": "card_483etw4er9fg4vF3sQdrt3FG",
      "livemode": false,
      "object": "card",
      "last4": "4242",
      "type": "Visa",
      "exp_month": 11,
      "exp_year": 2020,
      "fingerprint": "5dgRQ3dVRGaQWDFb",
      "customer": "cus_3sgheFxeBgTQ3M",
      "country": "US",
      "name": "John Doe",
      "address_line1": null,
      "address_line2": null,
      "address_city": null,
      "address_state": null,
      "address_zip": null,
      "address_country": null,
      "cvc_check": null,
      "address_line1_check": null,
      "address_zip_check": null
    }
    RESPONSE
  end

  def successful_authorization_response
    <<-RESPONSE
    {
      "id": "ch_test_charge",
      "object": "charge",
      "created": 1309131571,
      "livemode": false,
      "paid": true,
      "amount": 400,
      "currency": "usd",
      "refunded": false,
      "fee": 0,
      "fee_details": [],
      "card": {
        "country": "US",
        "exp_month": 9,
        "exp_year": #{Time.now.year + 1},
        "last4": "4242",
        "object": "card",
        "type": "Visa"
      },
      "captured": false,
      "description": "ActiveMerchant Test Purchase",
      "dispute": null,
      "uncaptured": true,
      "disputed": false
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "id": "ch_test_charge",
      "object": "charge",
      "created": 1309131571,
      "livemode": false,
      "paid": true,
      "amount": 400,
      "currency": "usd",
      "refunded": false,
      "fee": 0,
      "fee_details": [],
      "card": {
        "country": "US",
        "exp_month": 9,
        "exp_year": #{Time.now.year + 1},
        "last4": "4242",
        "object": "card",
        "type": "Visa"
      },
      "captured": true,
      "description": "ActiveMerchant Test Purchase",
      "dispute": null,
      "uncaptured": false,
      "disputed": false
    }
    RESPONSE
  end

  def successful_purchase_response(refunded=false)
    <<-RESPONSE
    {
      "amount": 400,
      "created": 1309131571,
      "currency": "usd",
      "description": "Test Purchase",
      "id": "ch_test_charge",
      "livemode": false,
      "object": "charge",
      "paid": true,
      "refunded": #{refunded},
      "card": {
        "country": "US",
        "exp_month": 9,
        "exp_year": #{Time.now.year + 1},
        "last4": "4242",
        "object": "card",
        "type": "Visa"
      }
    }
    RESPONSE
  end

  def successful_partially_refunded_response(options = {})
    options = {:livemode=>false}.merge!(options)
    <<-RESPONSE
    {
      "amount": 400,
      "amount_refunded": 200,
      "created": 1309131571,
      "currency": "usd",
      "description": "Test Purchase",
      "id": "ch_test_charge",
      "livemode": #{options[:livemode]},
      "object": "charge",
      "paid": true,
      "refunded": true,
      "card": {
        "country": "US",
        "exp_month": 9,
        "exp_year": #{Time.now.year + 1},
        "last4": "4242",
        "object": "card",
        "type": "Visa"
      }
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "id": "ch_4IrhQMqukqu7C2",
      "object": "charge",
      "created": 1403816613,
      "livemode": false,
      "paid": true,
      "amount": 50,
      "currency": "usd",
      "refunded": true,
      "card": {
        "id": "card_4IKht2vQlbJms9",
        "object": "card",
        "last4": "4242",
        "brand": "Visa",
        "funding": "credit",
        "exp_month": 9,
        "exp_year": 2015,
        "fingerprint": "6nTaMxIBAdBvfy2i",
        "country": "US",
        "name": "Longbob Longsen",
        "address_city": null,
        "cvc_check": "pass",
        "customer": null,
        "type": "Visa"
      },
      "captured": false,
      "balance_transaction": null,
      "failure_code": null,
      "description": "ActiveMerchant Test Purchase",
      "dispute": null,
      "metadata": {
        "email": "wow@example.com"
      },
      "statement_description": null,
      "receipt_email": null,
      "fee": 0,
      "fee_details": [],
      "uncaptured": true,
      "disputed": false
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "error": {
        "type": "invalid_request_error",
        "message": "Charge ch_4IL0vZWdcx45qO has already been refunded."
      }
    }
    RESPONSE
  end

  def successful_refunded_application_fee_response
    <<-RESPONSE
    {
      "id": "fee_id",
      "object": "application_fee",
      "created": 1375375417,
      "livemode": false,
      "amount": 10,
      "currency": "usd",
      "user": "acct_id",
      "user_email": "acct_id",
      "application": "ca_application",
      "charge": "ch_test_charge",
      "refunded": false,
      "amount_refunded": 10
    }
    RESPONSE
  end

  def successful_application_fee_list_response
    <<-RESPONSE
    {
      "object": "list",
      "count": 2,
      "url": "/v1/application_fees",
      "data": [
        {
          "object": "application_fee",
          "id": "application_fee_id"
        },
        {
          "object": "another_fee",
          "id": "another_fee_id"
        }
      ]
    }
    RESPONSE
  end

  def unsuccessful_application_fee_list_response
    <<-RESPONSE
    {
      "object": "list",
      "count": 0,
      "url": "/v1/application_fees",
      "data": []
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "error": {
        "code": "incorrect_number",
        "param": "number",
        "type": "card_error",
        "message": "Your card number is incorrect"
      }
    }
    RESPONSE
  end

  def declined_purchase_response
    <<-RESPONSE
    {
      "error": {
        "message": "Your card was declined.",
        "type": "card_error",
        "code": "card_declined",
        "charge": "ch_test_charge"
      }
    }
    RESPONSE
  end

  def declined_authorization_response
    <<-RESPONSE
    {
      "error": {
        "message": "Your card was declined.",
        "type": "card_error",
        "code": "card_declined",
        "charge": "ch_4IKxffGOKVRJ4l"
      }
    }
    RESPONSE
  end

  def successful_update_credit_card_response
    <<-RESPONSE
    {
      "id": "card_483etw4er9fg4vF3sQdrt3FG",
      "object": "card",
      "last4": "4242",
      "type": "Visa",
      "exp_month": 6,
      "exp_year": 2021,
      "fingerprint": "5dgRQ3dVRGaQWDFb",
      "customer": "cus_3sgheFxeBgTQ3M",
      "country": "US",
      "name": "John Smith",
      "address_line1": null,
      "address_line2": null,
      "address_city": null,
      "address_state": null,
      "address_zip": null,
      "address_country": null,
      "cvc_check": null,
      "address_line1_check": null,
      "address_zip_check": null
    }
    RESPONSE
  end

  def invalid_json_response
    <<-RESPONSE
    {
       foo : bar
    }
    RESPONSE
  end

  def generic_error_response
    <<-RESPONSE
    {
      "error": {
        "code": "generic",
        "message": "This is a generic error response"
      }
    }
    RESPONSE
  end
end
