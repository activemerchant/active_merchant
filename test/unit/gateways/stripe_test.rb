require 'test_helper'

class StripeTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = StripeGateway.new(login: 'sk_test_login')

    @credit_card = credit_card()
    @threeds_card = credit_card('4000000000003063')
    @non_3ds_card = credit_card('378282246310005')
    @amount = 400
    @refund_amount = 200

    @options = {
      billing_address: address(),
      statement_address: statement_address(),
      shipping_address: shipping_address(),
      description: 'Test Purchase'
    }

    @threeds_options = {
      execute_threed: true,
      callback_url: 'http://www.example.com/callback'
    }

    @apple_pay_payment_token = apple_pay_payment_token
    @emv_credit_card = credit_card_with_icc_data
    @payment_token = StripeGateway::StripePaymentToken.new(token_params)
    @token_string = @payment_token.payment_data['id']

    @check = check({
      bank_name: 'STRIPE TEST BANK',
      account_number: '000123456789',
      routing_number: '110000000'
    })
  end

  def test_successful_new_customer_with_card
    @gateway.expects(:ssl_request).returns(successful_new_customer_response)
    @gateway.expects(:add_creditcard)

    assert response = @gateway.store(@credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_customer_with_apple_pay_payment_token
    @gateway.expects(:ssl_request).returns(successful_new_customer_response)
    @gateway.expects(:tokenize_apple_pay_token).returns(Response.new(true, nil, token: successful_apple_pay_token_exchange))

    assert response = @gateway.store(@apple_pay_payment_token, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_customer_with_emv_credit_card
    @gateway.expects(:ssl_request).returns(successful_new_customer_response)

    assert response = @gateway.store(@emv_credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_customer_with_bank_account
    @gateway.expects(:ssl_request).twice.returns(successful_bank_token_request, successful_new_customer_bank_account_response)

    response = @gateway.store(@check, @options)
    assert_success response
    assert_equal 'cus_7s6levMt8IqhTR|ba_17cMXgAWOtgoysog7UDWXbn4', response.authorization
  end

  def test_successful_new_card
    @gateway.expects(:ssl_request).returns(successful_new_card_response)
    @gateway.expects(:add_creditcard)

    assert response = @gateway.store(@credit_card, customer: 'cus_3sgheFxeBgTQ3M')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_card_via_apple_pay_payment_token
    @gateway.expects(:ssl_request).returns(successful_new_card_response)
    @gateway.expects(:tokenize_apple_pay_token).returns(Response.new(true, nil, token: successful_apple_pay_token_exchange))

    assert response = @gateway.store(@apple_pay_payment_token, customer: 'cus_3sgheFxeBgTQ3M')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_card_with_emv_credit_card
    @gateway.expects(:ssl_request).returns(successful_new_card_response)
    @gateway.expects(:add_creditcard)

    assert response = @gateway.store(@emv_credit_card, customer: 'cus_3sgheFxeBgTQ3M')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_card_with_token_string
    @gateway.expects(:ssl_request).returns(successful_new_card_response)
    @gateway.expects(:add_creditcard)

    assert response = @gateway.store(@token_string, customer: 'cus_3sgheFxeBgTQ3M')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_card_with_payment_token
    @gateway.expects(:ssl_request).returns(successful_new_card_response)
    @gateway.expects(:add_payment_token)

    assert response = @gateway.store(@payment_token, customer: 'cus_3sgheFxeBgTQ3M')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert response.test?
  end

  def test_successful_new_card_and_customer_update
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)
    @gateway.expects(:add_creditcard)

    assert response = @gateway.store(@credit_card, customer: 'cus_3sgheFxeBgTQ3M', email: 'test@test.com')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_card_and_customer_update_via_apple_pay_payment_token
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)
    @gateway.expects(:tokenize_apple_pay_token).returns(Response.new(true, nil, token: successful_apple_pay_token_exchange))

    assert response = @gateway.store(@apple_pay_payment_token, customer: 'cus_3sgheFxeBgTQ3M', email: 'test@test.com')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_card_and_customer_update_with_emv_credit_card
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)

    assert response = @gateway.store(@emv_credit_card, customer: 'cus_3sgheFxeBgTQ3M', email: 'test@test.com')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_card_and_customer_update_with_token_string
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)

    assert response = @gateway.store(@token_string, customer: 'cus_3sgheFxeBgTQ3M', email: 'test@test.com')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_card_and_customer_update_with_payment_token
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)

    assert response = @gateway.store(@payment_token, customer: 'cus_3sgheFxeBgTQ3M', email: 'test@test.com')
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_default_card
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)
    @gateway.expects(:add_creditcard)

    assert response = @gateway.store(@credit_card, @options.merge(customer: 'cus_3sgheFxeBgTQ3M', set_default: true))
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_default_card_via_apple_pay_payment_token
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)
    @gateway.expects(:tokenize_apple_pay_token).returns(Response.new(true, nil, token: successful_apple_pay_token_exchange))

    assert response = @gateway.store(@apple_pay_payment_token, @options.merge(customer: 'cus_3sgheFxeBgTQ3M', set_default: true))
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_default_card_with_emv_credit_card
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)

    assert response = @gateway.store(@emv_credit_card, @options.merge(customer: 'cus_3sgheFxeBgTQ3M', set_default: true))
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_default_card_with_token_string
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)
    @gateway.expects(:add_creditcard)

    assert response = @gateway.store(@token_string, @options.merge(customer: 'cus_3sgheFxeBgTQ3M', set_default: true))
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_successful_new_default_card_with_payment_token
    @gateway.expects(:ssl_request).twice.returns(successful_new_card_response, successful_new_customer_response)
    @gateway.expects(:add_payment_token)

    assert response = @gateway.store(@payment_token, @options.merge(customer: 'cus_3sgheFxeBgTQ3M', set_default: true))
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.authorization
    assert_equal 2, response.responses.size
    assert_equal 'cus_3sgheFxeBgTQ3M|card_483etw4er9fg4vF3sQdrt3FG', response.responses[0].authorization
    assert_equal 'cus_3sgheFxeBgTQ3M', response.responses[1].authorization
    assert response.test?
  end

  def test_passing_validate_false_on_store
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, validate: false)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/validate=false/, data)
    end.respond_with(successful_new_customer_response)

    assert_success response
  end

  def test_empty_values_not_sent
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, referrer: '')
    end.check_request do |_method, _endpoint, data, _headers|
      refute_match(/referrer/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_authorization
    @gateway.expects(:add_creditcard)
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_authorization_with_token_string
    @gateway.expects(:add_creditcard)
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @token_string, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_authorization_with_payment_token
    @gateway.expects(:add_payment_token)
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @payment_token, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_authorization_with_apple_pay_token_exchange
    @gateway.expects(:tokenize_apple_pay_token).returns(Response.new(true, nil, token: successful_apple_pay_token_exchange))
    @gateway.expects(:ssl_request).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @apple_pay_payment_token, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_authorization_with_emv_credit_card
    @gateway.expects(:ssl_request).returns(successful_authorization_response_with_icc_data)

    assert response = @gateway.authorize(@amount, @emv_credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_emv_charge', response.authorization
    assert response.emv_authorization, 'Response should include emv_authorization containing the EMV ARPC'
  end

  def test_contains_statement_descriptor_suffix
    options = @options.merge(statement_descriptor_suffix: 'suffix')

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/statement_descriptor_suffix=suffix/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_connected_account
    destination = 'account_27701'
    amount = 8000
    on_behalf_of = 'account_27704'
    transfer_group = 'TG1000'
    application_fee_amount = 100

    options = @options.merge(
      transfer_destination: destination,
      transfer_amount: amount,
      on_behalf_of: on_behalf_of,
      transfer_group: transfer_group,
      application_fee_amount: application_fee_amount
    )

    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/transfer_data\[destination\]=#{destination}/, data)
      assert_match(/transfer_data\[amount\]=#{amount}/, data)
      assert_match(/on_behalf_of=#{on_behalf_of}/, data)
      assert_match(/transfer_group=#{transfer_group}/, data)
      assert_match(/application_fee_amount=#{application_fee_amount}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_declined_authorization_with_emv_credit_card
    @gateway.expects(:ssl_request).returns(declined_authorization_response_with_emv_auth_data)

    assert response = @gateway.authorize(@amount, @emv_credit_card, @options)
    assert_instance_of Response, response
    assert_failure response

    assert_equal 'ch_declined_auth', response.authorization
    assert response.emv_authorization, 'Response should include emv_auth_data containing the EMV ARC'
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert response = @gateway.capture(@amount, 'ch_test_charge')
    assert_success response
    assert response.test?
  end

  def test_successful_capture_with_emv_credit_card_tc
    stripe_charge_id = 'ch_test_emv_charge'
    tc_emv_response = 'mock_icc_data'
    @gateway.
      expects(:ssl_request).
      with(
        :post,
        "https://api.stripe.com/v1/charges/#{stripe_charge_id}",
        "card[emv_approval_data]=#{tc_emv_response}",
        anything
      ).returns(successful_capture_response_with_icc_data)

    @gateway.
      expects(:ssl_request).
      with(:post, 'https://api.stripe.com/v1/charges/ch_test_emv_charge/capture', '', anything).
      returns(successful_capture_response_without_icc_data)

    assert response = @gateway.capture(@amount, stripe_charge_id, icc_data: tc_emv_response)
    assert_success response
    assert response.emv_authorization, 'Response should include emv_authorization containing the EMV TC'
  end

  def test_successful_purchase
    @gateway.expects(:add_creditcard)
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token_string
    @gateway.expects(:add_creditcard)
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @token_string, @options)
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_payment_token
    @gateway.expects(:add_payment_token)
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @payment_token, @options)
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_apple_pay_token_exchange
    @gateway.expects(:tokenize_apple_pay_token).returns(Response.new(true, nil, token: successful_apple_pay_token_exchange))
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @apple_pay_payment_token, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_level3_data
    @gateway.expects(:add_creditcard)

    @options[:merchant_reference] = 123
    @options[:customer_reference] = 456
    @options[:shipping_address_zip] = 98765
    @options[:shipping_from_zip] = 54321
    @options[:shipping_amount] = 40
    @options[:line_items] = [
      {
        'product_code' => 1234,
        'product_description' => 'An item',
        'unit_cost' => 60,
        'quantity' => 7,
        'tax_amount' => 0
      },
      {
        'product_code' => 999,
        'tax_amount' => 888
      }
    ]

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      if %r{/charges}.match?(endpoint)
        assert_match('level3[merchant_reference]=123', data)
        assert_match('level3[customer_reference]=456', data)
        assert_match('level3[shipping_address_zip]=98765', data)
        assert_match('level3[shipping_amount]=40', data)
        assert_match('level3[shipping_from_zip]=54321', data)
        assert_match('level3[line_items][0][product_description]=An+item', data)
        assert_match('level3[line_items][1][product_code]=999', data)
      end
    end.respond_with(successful_purchase_response)

    assert_success response
    assert response.test?
  end

  def test_amount_localization
    @gateway.expects(:ssl_request).returns(successful_purchase_response(true))
    @gateway.expects(:post_data).with do |params|
      params[:amount] == '4'
    end

    @options[:currency] = 'JPY'

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_adds_application_to_x_stripe_client_user_agent_header
    application = {
      name: 'app',
      version: '1.0',
      url: 'https://example.com'
    }

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, 'cus_xxx|card_xxx', @options.merge({ application: application }))
    end.check_request do |_method, _endpoint, _data, headers|
      assert_match(/\"application\"/, headers['X-Stripe-Client-User-Agent'])
      assert_match(/\"name\":\"app\"/, headers['X-Stripe-Client-User-Agent'])
      assert_match(/\"version\":\"1.0\"/, headers['X-Stripe-Client-User-Agent'])
      assert_match(/\"url\":\"https:\/\/example.com\"/, headers['X-Stripe-Client-User-Agent'])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_token_including_customer
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, 'cus_xxx|card_xxx')
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/customer=cus_xxx/, data)
      assert_match(/card=card_xxx/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_token
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, 'card_xxx')
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/card=card_xxx/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_statement_description
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, statement_description: '5K RACE TICKET')
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/statement_descriptor=5K\+RACE\+TICKET/, data)
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

  def test_void_contains_charge_expand
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      post.include?('expand[0]=charge')
    end.returns(successful_purchase_response(true))

    assert response = @gateway.void('ch_test_charge')
    assert_success response
  end

  def test_void_with_additional_expand_contains_two_expands
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      parsed = CGI.parse(post)
      parsed['expand[0]'] = 'balance_transaction'
      parsed['expand[1]'] = 'charge'
    end.returns(successful_purchase_response(true))

    assert response = @gateway.void('ch_test_charge', expand: :balance_transaction)
    assert_success response
  end

  def test_void_with_expand_charge_only_sends_one_charge_expand
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      parsed = CGI.parse(post)
      parsed['expand[0]'] == ['charge']
    end.returns(successful_purchase_response(true))

    assert response = @gateway.void('ch_test_charge', expand: ['charge'])
    assert_success response
  end

  def test_successful_void_with_metadata
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      post.include?('metadata[first_value]=true')
    end.returns(successful_purchase_response(true))

    assert response = @gateway.void('ch_test_charge', { metadata: { first_value: true } })
    assert_success response
  end

  def test_successful_void_with_reason
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      post.include?('reason=fraudulent')
    end.returns(successful_purchase_response(true))

    assert response = @gateway.void('ch_test_charge', { reason: 'fraudulent' })
    assert_success response
  end

  def test_successful_void_with_reverse_transfer
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      post.include?('reverse_transfer=true')
    end.returns(successful_purchase_response(true))

    assert response = @gateway.void('ch_test_charge', { reverse_transfer: true })
    assert_success response
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_success response

    assert_equal 're_test_refund', response.authorization
  end

  def test_successful_refund_with_reason
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', reason: 'fraudulent')
    assert_success response

    assert_equal 're_test_refund', response.authorization
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(generic_error_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_failure response
  end

  def test_successful_refund_with_refund_application_fee
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      post.include?('refund_application_fee=true')
    end.returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', refund_application_fee: true)
    assert_success response
  end

  def test_refund_contains_charge_expand
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      post.include?('expand[0]=charge')
    end.returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge')
    assert_success response
  end

  def test_refund_with_additional_expand_contains_two_expands
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      parsed = CGI.parse(post)
      parsed['expand[0]'] = 'balance_transaction'
      parsed['expand[1]'] = 'charge'
    end.returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', expand: :balance_transaction)
    assert_success response
  end

  def test_refund_with_expand_charge_only_sends_one_charge_expand
    @gateway.expects(:ssl_request).with do |_, _, post, _|
      parsed = CGI.parse(post)
      parsed['expand[0]'] == ['charge']
    end.returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', expand: ['charge'])
    assert_success response
  end

  def test_successful_refund_with_metadata
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      post.include?('metadata[first_value]=true')
    end.returns(successful_partially_refunded_response)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', { metadata: { first_value: true } })
    assert_success response
  end

  def test_successful_refund_with_reverse_transfer
    stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, 'auth', reverse_transfer: true)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/reverse_transfer=true/, data)
    end.respond_with(successful_partially_refunded_response)
  end

  def test_successful_refund_with_refund_fee_amount
    s = sequence('request')
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_fetch_application_fee_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_application_fee_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', refund_fee_amount: 100)
    assert_success response
  end

  def test_refund_with_fee_response_responds_with_the_refund_authorization
    s = sequence('request')
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_fetch_application_fee_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_application_fee_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', refund_fee_amount: 100)
    assert_success response
    assert_equal 're_test_refund', response.authorization
  end

  def test_successful_refund_with_failed_fee_refund_fetch
    s = sequence('request')
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(unsuccessful_fetch_application_fee_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', refund_fee_amount: 100)
    assert_success response
  end

  def test_successful_refund_with_failed_fee_refund
    s = sequence('request')
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_fetch_application_fee_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(generic_error_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', refund_fee_amount: 100)
    assert_success response
  end

  def test_unsuccessful_refund_does_not_refund_fee
    s = sequence('request')
    @gateway.expects(:ssl_request).returns(generic_error_response).in_sequence(s)

    assert response = @gateway.refund(@refund_amount, 'ch_test_charge', refund_fee_amount: 100)
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
    assert_equal 'Transaction approved', response.message
  end

  def test_unsuccessful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(declined_authorization_response, successful_void_response)
    assert_failure response
    assert_equal 'Your card was declined.', response.message
  end

  def test_successful_request_always_uses_live_mode_to_determine_test_request
    @gateway.expects(:ssl_request).returns(successful_partially_refunded_response)

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

    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    refute response.test? # unsuccessful request defaults to live
    assert_equal 'ch_test_charge', response.authorization
  end

  def test_declined_request_advanced_decline_codes
    @gateway.expects(:ssl_request).returns(declined_call_issuer_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal Gateway::STANDARD_ERROR_CODE[:call_issuer], response.error_code
    refute response.test? # unsuccessful request defaults to live
    assert_equal 'ch_test_charge', response.authorization
  end

  def test_declined_request_advanced_pickup_card_code
    @gateway.expects(:ssl_request).returns(declined_pickup_card_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal Gateway::STANDARD_ERROR_CODE[:pickup_card], response.error_code
    refute response.test? # unsuccessful request defaults to live
    assert_equal 'ch_test_charge', response.authorization
  end

  def test_declined_request_advanced_decline_code_not_in_standard_mapping
    @gateway.expects(:ssl_request).returns(declined_generic_decline_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert !response.test? # unsuccessful request defaults to live
    assert_equal 'ch_test_charge', response.authorization
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/^Invalid response received from the Stripe API/, response.message)
  end

  def test_invalid_login_test_transaction
    gateway = StripeGateway.new(login: 'sk_live_3422')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'Invalid API Key provided', response.message
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
    @credit_card.stubs(:track_data).returns('Swipe data')
    @credit_card.stubs(:read_method).returns('contactless_magstripe')
    @gateway.send(:add_creditcard, post, @credit_card, {})
    assert_equal @credit_card.track_data, post[:card][:swipe_data]
    assert_equal 'contactless_magstripe_mode', post[:card][:read_method]
    assert_nil post[:card][:number]
    assert_nil post[:card][:exp_year]
    assert_nil post[:card][:exp_month]
    assert_nil post[:card][:cvc]
    assert_nil post[:card][:name]
  end

  def test_add_creditcard_with_fallback_no_chip
    post = {}
    @credit_card.stubs(:track_data).returns('Swipe data')
    @credit_card.stubs(:read_method).returns('fallback_no_chip')
    @gateway.send(:add_creditcard, post, @credit_card, {})
    assert_equal @credit_card.track_data, post[:card][:swipe_data]
    assert_equal 'no_chip', post[:card][:fallback_reason]
    assert_nil post[:card][:number]
    assert_nil post[:card][:exp_year]
    assert_nil post[:card][:exp_month]
    assert_nil post[:card][:cvc]
    assert_nil post[:card][:name]
  end

  def test_add_creditcard_with_fallback_chip_error
    post = {}
    @credit_card.stubs(:track_data).returns('Swipe data')
    @credit_card.stubs(:read_method).returns('fallback_chip_error')
    @gateway.send(:add_creditcard, post, @credit_card, {})
    assert_equal @credit_card.track_data, post[:card][:swipe_data]
    assert_equal 'chip_error', post[:card][:fallback_reason]
    assert_nil post[:card][:number]
    assert_nil post[:card][:exp_year]
    assert_nil post[:card][:exp_month]
    assert_nil post[:card][:cvc]
    assert_nil post[:card][:name]
  end

  def test_add_creditcard_with_card_token
    post = {}
    credit_card_token = 'card_2iD4AezYnNNzkW'
    @gateway.send(:add_creditcard, post, credit_card_token, {})
    assert_equal 'card_2iD4AezYnNNzkW', post[:card]
  end

  def test_add_creditcard_with_card_token_and_customer
    post = {}
    credit_card_token = 'cus_3sgheFxeBgTQ3M|card_2iD4AezYnNNzkW'
    @gateway.send(:add_creditcard, post, credit_card_token, {})
    assert_equal 'cus_3sgheFxeBgTQ3M', post[:customer]
    assert_equal 'card_2iD4AezYnNNzkW', post[:card]
  end

  def test_add_creditcard_with_card_token_and_track_data
    post = {}
    credit_card_token = 'card_2iD4AezYnNNzkW'
    @gateway.send(:add_creditcard, post, credit_card_token, track_data: 'Tracking data')
    assert_equal 'Tracking data', post[:card][:swipe_data]
  end

  def test_add_creditcard_with_emv_credit_card
    post = {}
    @gateway.send(:add_creditcard, post, @emv_credit_card, {})

    assert_equal @emv_credit_card.icc_data, post[:card][:emv_auth_data]
  end

  def test_add_creditcard_pads_eci_value
    post = {}
    credit_card = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: '111111111100cryptogram',
      verification_value: nil,
      eci: '7'
    )

    @gateway.send(:add_creditcard, post, credit_card, {})

    assert_equal '07', post[:card][:eci]
  end

  def test_application_fee_is_submitted_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ application_fee: 144 }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/application_fee=144/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_application_fee_is_submitted_for_capture
    stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, 'ch_test_charge', @options.merge({ application_fee: 144 }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/application_fee=144/, data)
    end.respond_with(successful_capture_response)
  end

  def test_exchange_rate_is_submitted_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ exchange_rate: 0.96251 }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/exchange_rate=0.96251/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_exchange_rate_is_submitted_for_capture
    stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, 'ch_test_charge', @options.merge({ exchange_rate: 0.96251 }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/exchange_rate=0.96251/, data)
    end.respond_with(successful_capture_response)
  end

  def test_destination_is_submitted_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ destination: 'subaccountid' }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/destination\[account\]=subaccountid/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_destination_amount_is_submitted_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ destination: 'subaccountid', destination_amount: @amount - 20 }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/destination\[amount\]=#{@amount - 20}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_radar_session_is_submitted_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, {
        radar_session_id: 'test_radar_session_id'
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/radar_options\[session\]=test_radar_session_id/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_radar_session_is_submitted_for_authorize
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, {
        radar_session_id: 'test_radar_session_id'
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/radar_options\[session\]=test_radar_session_id/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_skip_rules_is_submitted_for_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, {
        skip_radar_rules: true
      })
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/radar_options\[skip_rules\]\[0\]=all/, data)
    end.respond_with(successful_authorization_response)
  end

  def test_client_data_submitted_with_purchase
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({ description: 'a test customer', ip: '127.127.127.127', user_agent: 'some browser', order_id: '42', email: 'foo@wonderfullyfakedomain.com', receipt_email: 'receipt-receiver@wonderfullyfakedomain.com', referrer: 'http://www.shopify.com' })
      @gateway.purchase(@amount, @credit_card, updated_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/description=a\+test\+customer/, data)
      assert_match(/ip=127\.127\.127\.127/, data)
      assert_match(/user_agent=some\+browser/, data)
      assert_match(/external_id=42/, data)
      assert_match(/referrer=http\%3A\%2F\%2Fwww\.shopify\.com/, data)
      assert_match(/payment_user_agent=Stripe\%2Fv1\+ActiveMerchantBindings\%2F\d+\.\d+\.\d+/, data)
      assert_match(/metadata\[email\]=foo\%40wonderfullyfakedomain\.com/, data)
      assert_match(/receipt_email=receipt-receiver\%40wonderfullyfakedomain\.com/, data)
      assert_match(/metadata\[order_id\]=42/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_client_data_submitted_with_purchase_without_email_or_order
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({ description: 'a test customer', ip: '127.127.127.127', user_agent: 'some browser', referrer: 'http://www.shopify.com' })
      @gateway.purchase(@amount, @credit_card, updated_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/description=a\+test\+customer/, data)
      assert_match(/ip=127\.127\.127\.127/, data)
      assert_match(/user_agent=some\+browser/, data)
      assert_match(/referrer=http\%3A\%2F\%2Fwww\.shopify\.com/, data)
      assert_match(/payment_user_agent=Stripe\%2Fv1\+ActiveMerchantBindings\%2F\d+\.\d+\.\d+/, data)
      refute data.include?('metadata')
    end.respond_with(successful_purchase_response)
  end

  def test_client_data_submitted_with_metadata_in_options
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({ metadata: { this_is_a_random_key_name: 'with a random value', i_made_up_this_key_too: 'canyoutell' }, order_id: '42', email: 'foo@wonderfullyfakedomain.com' })
      @gateway.purchase(@amount, @credit_card, updated_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/metadata\[this_is_a_random_key_name\]=with\+a\+random\+value/, data)
      assert_match(/metadata\[i_made_up_this_key_too\]=canyoutell/, data)
      assert_match(/metadata\[email\]=foo\%40wonderfullyfakedomain\.com/, data)
      assert_match(/metadata\[order_id\]=42/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_client_data_submitted_with_metadata_in_options_with_emv_credit_card_purchase
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({ metadata: { this_is_a_random_key_name: 'with a random value', i_made_up_this_key_too: 'canyoutell' }, order_id: '42', email: 'foo@wonderfullyfakedomain.com' })
      @gateway.purchase(@amount, @emv_credit_card, updated_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/metadata\[this_is_a_random_key_name\]=with\+a\+random\+value/, data)
      assert_match(/metadata\[i_made_up_this_key_too\]=canyoutell/, data)
      assert_match(/metadata\[email\]=foo\%40wonderfullyfakedomain\.com/, data)
      assert_match(/metadata\[order_id\]=42/, data)
      assert_match(/metadata\[card_read_method\]=contact/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_client_data_submitted_with_metadata_in_options_with_emv_credit_card_authorize
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({ metadata: { this_is_a_random_key_name: 'with a random value', i_made_up_this_key_too: 'canyoutell' }, order_id: '42', email: 'foo@wonderfullyfakedomain.com' })
      @gateway.authorize(@amount, @emv_credit_card, updated_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/metadata\[this_is_a_random_key_name\]=with\+a\+random\+value/, data)
      assert_match(/metadata\[i_made_up_this_key_too\]=canyoutell/, data)
      assert_match(/metadata\[email\]=foo\%40wonderfullyfakedomain\.com/, data)
      assert_match(/metadata\[order_id\]=42/, data)
      assert_match(/metadata\[card_read_method\]=contact/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_quickchip_is_set_on_purchase
    stub_comms(@gateway, :ssl_request) do
      @emv_credit_card.read_method = 'contact_quickchip'
      @gateway.purchase(@amount, @emv_credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/card\[processing_method\]=quick_chip/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_quickchip_is_not_set_on_authorize
    stub_comms(@gateway, :ssl_request) do
      @emv_credit_card.read_method = 'contact_quickchip'
      @gateway.authorize(@amount, @emv_credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      refute_match(/card\[processing_method\]=quick_chip/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_add_address
    post = { card: {} }
    @gateway.send(:add_address, post, @options)
    assert_equal @options[:billing_address][:zip], post[:card][:address_zip]
    assert_equal @options[:billing_address][:state], post[:card][:address_state]
    assert_equal @options[:billing_address][:address1], post[:card][:address_line1]
    assert_equal @options[:billing_address][:address2], post[:card][:address_line2]
    assert_equal @options[:billing_address][:country], post[:card][:address_country]
    assert_equal @options[:billing_address][:city], post[:card][:address_city]
  end

  def test_add_statement_address
    post = {}

    @gateway.send(:add_statement_address, post, @options)

    assert_equal @options[:statement_address][:zip], post[:statement_address][:postal_code]
    assert_equal @options[:statement_address][:state], post[:statement_address][:state]
    assert_equal @options[:statement_address][:address1], post[:statement_address][:line1]
    assert_equal @options[:statement_address][:address2], post[:statement_address][:line2]
    assert_equal @options[:statement_address][:country], post[:statement_address][:country]
    assert_equal @options[:statement_address][:city], post[:statement_address][:city]
  end

  def test_add_shipping_address
    post = {}

    @gateway.send(:add_shipping_address, post, @credit_card, @options)

    assert_equal @options[:shipping_address][:zip], post[:shipping][:address][:postal_code]
    assert_equal @options[:shipping_address][:state], post[:shipping][:address][:state]
    assert_equal @options[:shipping_address][:address1], post[:shipping][:address][:line1]
    assert_equal @options[:shipping_address][:address2], post[:shipping][:address][:line2]
    assert_equal @options[:shipping_address][:country], post[:shipping][:address][:country]
    assert_equal @options[:shipping_address][:city], post[:shipping][:address][:city]
    assert_equal @options[:shipping_address][:name], post[:shipping][:name]
    assert_equal @options[:shipping_address][:phone_number], post[:shipping][:phone]
  end

  def test_shipping_address_not_added_if_no_name_present
    post = {}

    options = @options.dup
    options[:shipping_address] = options[:shipping_address].except(:name)
    @gateway.send(:add_shipping_address, post, @credit_card, options)

    assert_empty post
  end

  def test_add_statement_address_returns_nil_if_required_fields_missing
    post = {}
    %i[address1 city zip state].each do |required_key|
      missing_required = @options.tap do |options|
        options[:statement_address].delete_if { |k| k == required_key }
      end

      @gateway.send(:add_statement_address, post, missing_required)

      assert_equal nil, post[:statement_address]
    end
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
    @gateway.expects(:ssl_request).once.with { |_method, _url, _post, headers|
      headers && headers['X-Stripe-Client-User-Metadata'] == { ip: '1.1.1.1' }.to_json
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options.merge(ip: '1.1.1.1'))
  end

  def test_optional_version_header
    @gateway.expects(:ssl_request).once.with { |_method, _url, _post, headers|
      headers && headers['Stripe-Version'] == '2013-10-29'
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options.merge(version: '2013-10-29'))
  end

  def test_optional_idempotency_key_header
    @gateway.expects(:ssl_request).once.with { |_method, _url, _post, headers|
      headers && headers['Idempotency-Key'] == 'test123'
    }.returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options.merge(idempotency_key: 'test123'))
    assert_success response
  end

  def test_optional_idempotency_on_void
    @gateway.expects(:ssl_request).once.with { |_method, _url, _post, headers|
      headers && headers['Idempotency-Key'] == 'test123'
    }.returns(successful_purchase_response(true))

    response = @gateway.void('ch_test_charge', @options.merge(idempotency_key: 'test123'))
    assert_success response
  end

  def test_optional_idempotency_on_verify
    @gateway.expects(:ssl_request).with do |_method, _url, _post, headers|
      headers && headers['Idempotency-Key'] == nil
    end.returns(successful_void_response)

    @gateway.expects(:ssl_request).with do |_method, _url, _post, headers|
      headers && headers['Idempotency-Key'] == 'test123'
    end.returns(successful_authorization_response)

    response = @gateway.verify(@credit_card, @options.merge(idempotency_key: 'test123'))
    assert_success response
  end

  def test_initialize_gateway_with_version
    @gateway = StripeGateway.new(login: 'sk_test_login', version: '2013-12-03')
    @gateway.expects(:ssl_request).once.with { |_method, _url, _post, headers|
      headers && headers['Stripe-Version'] == '2013-12-03'
    }.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_track_data_and_traditional_should_be_mutually_exclusive
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /card\[name\]/
      assert data !~ /card\[swipe_data\]/
    end.respond_with(successful_purchase_response)

    stub_comms(@gateway, :ssl_request) do
      @credit_card.track_data = '%B378282246310005^LONGSON/LONGBOB^1705101130504392?'
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data !~ /card\[name\]/
      assert data =~ /card\[swipe_data\]/
    end.respond_with(successful_purchase_response)
  end

  def test_address_is_included_with_card_data
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /card\[address_line1\]/
    end.respond_with(successful_purchase_response)
  end

  def test_contactless_flag_is_included_with_emv_card_data
    stub_comms(@gateway, :ssl_request) do
      @emv_credit_card.read_method = 'contactless'
      @gateway.purchase(@amount, @emv_credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /card\[read_method\]=contactless/
    end.respond_with(successful_purchase_response)
  end

  def test_contactless_magstripe_flag_is_included_with_emv_card_data
    stub_comms(@gateway, :ssl_request) do
      @emv_credit_card.read_method = 'contactless_magstripe'
      @gateway.purchase(@amount, @emv_credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /card\[read_method\]=contactless_magstripe_mode/
    end.respond_with(successful_purchase_response)
  end

  def test_contactless_flag_is_not_included_with_emv_card_data_by_default
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @emv_credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data !~ /card\[read_method\]=contactless/ && data !~ /card\[read_method\]=contactless_magstripe_mode/
    end.respond_with(successful_purchase_response)
  end

  def test_encrypted_pin_is_included_with_emv_card_data
    stub_comms(@gateway, :ssl_request) do
      @emv_credit_card.encrypted_pin_cryptogram = '8b68af72199529b8'
      @emv_credit_card.encrypted_pin_ksn = 'ffff0102628d12000001'
      @gateway.purchase(@amount, @emv_credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /card\[encrypted_pin\]=8b68af72199529b8/
      assert data =~ /card\[encrypted_pin_key_id\]=ffff0102628d12000001/
    end.respond_with(successful_purchase_response)
  end

  def generate_options_should_allow_key
    assert_equal({ key: '12345' }, generate_options({ key: '12345' }))
  end

  def test_passing_expand_parameters
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      post.include?('expand[0]=balance_transaction')
    end.returns(successful_authorization_response)

    @options[:expand] = :balance_transaction

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_expand_parameters_as_array
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      post.include?('expand[0]=balance_transaction&expand[1]=customer')
    end.returns(successful_authorization_response)

    @options[:expand] = %i[balance_transaction customer]

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_recurring_flag_not_set_by_default
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      !post.include?('recurring')
    end.returns(successful_authorization_response)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_recurring_eci_sets_recurring_flag
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      post.include?('recurring=true')
    end.returns(successful_authorization_response)

    @options[:eci] = 'recurring'

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_unknown_eci_does_not_set_recurring_flag
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      !post.include?('recurring')
    end.returns(successful_authorization_response)

    @options[:eci] = 'installment'

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_recurring_true_option_sets_recurring_flag
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      post.include?('recurring=true')
    end.returns(successful_authorization_response)

    @options[:recurring] = true

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_passing_recurring_false_option_does_not_set_recurring_flag
    @gateway.expects(:ssl_request).with do |_method, _url, post, _headers|
      !post.include?('recurring')
    end.returns(successful_authorization_response)

    @options[:recurring] = false

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_new_attributes_are_included_in_update
    stub_comms(@gateway, :ssl_request) do
      @gateway.send(:update, 'cus_3sgheFxeBgTQ3M', 'card_483etw4er9fg4vF3sQdrt3FG', { name: 'John Smith', exp_year: 2021, exp_month: 6 })
    end.check_request do |_method, endpoint, data, _headers|
      assert data == 'name=John+Smith&exp_year=2021&exp_month=6'
      assert endpoint.include? '/customers/cus_3sgheFxeBgTQ3M/cards/card_483etw4er9fg4vF3sQdrt3FG'
    end.respond_with(successful_update_credit_card_response)
  end

  def test_scrub
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
    assert_equal @gateway.scrub(pre_scrubbed_nested_payment_method_data), post_scrubbed_nested_payment_method_data
  end

  def test_scrubs_track_data
    assert_equal @gateway.scrub(pre_scrubbed_with_track_data), post_scrubbed_with_track_data
  end

  def test_scrubs_emv_data
    assert_equal @gateway.scrub(pre_scrubbed_with_emv_data), post_scrubbed_with_emv_data
  end

  def test_scrubs_account_number
    assert_equal @gateway.scrub(pre_scrubbed_with_account_number), post_scrubbed_with_account_number
  end

  def test_supports_scrubbing?
    assert @gateway.supports_scrubbing?
  end

  def test_successful_auth_with_network_tokenization_apple_pay
    @gateway.expects(:ssl_request).with do |method, _endpoint, data, _headers|
      assert_equal :post, method
      assert_match %r'card\[cryptogram\]=111111111100cryptogram&card\[eci\]=05&card\[tokenization_method\]=apple_pay', data
      true
    end.returns(successful_authorization_response)

    credit_card = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: '111111111100cryptogram',
      verification_value: nil,
      eci: '05'
    )

    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_auth_with_network_tokenization_android_pay
    @gateway.expects(:ssl_request).with do |method, _endpoint, data, _headers|
      assert_equal :post, method
      assert_match %r'card\[cryptogram\]=111111111100cryptogram&card\[eci\]=05&card\[tokenization_method\]=android_pay', data
      true
    end.returns(successful_authorization_response)

    credit_card = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: '111111111100cryptogram',
      verification_value: nil,
      eci: '05',
      source: :android_pay
    )

    assert response = @gateway.authorize(@amount, credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_network_tokenization_apple_pay
    @gateway.expects(:ssl_request).with do |method, _endpoint, data, _headers|
      assert_equal :post, method
      assert_match %r'card\[cryptogram\]=111111111100cryptogram&card\[eci\]=05&card\[tokenization_method\]=apple_pay', data
      true
    end.returns(successful_authorization_response)

    credit_card = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: '111111111100cryptogram',
      verification_value: nil,
      eci: '05'
    )

    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_network_tokenization_android_pay
    @gateway.expects(:ssl_request).with do |method, _endpoint, data, _headers|
      assert_equal :post, method
      assert_match %r'card\[cryptogram\]=111111111100cryptogram&card\[eci\]=05&card\[tokenization_method\]=android_pay', data
      true
    end.returns(successful_authorization_response)

    credit_card = network_tokenization_credit_card(
      '4242424242424242',
      payment_cryptogram: '111111111100cryptogram',
      verification_value: nil,
      eci: '05',
      source: :android_pay
    )

    assert response = @gateway.purchase(@amount, credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'ch_test_charge', response.authorization
    assert response.test?
  end

  def test_supports_network_tokenization
    assert_instance_of TrueClass, @gateway.supports_network_tokenization?
  end

  def test_emv_capture_application_fee_ignored
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, 'ch_test_charge', application_fee: 100, icc_data: @emv_credit_card.icc_data)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data !~ /application_fee/, 'request should not include application_fee'
    end.respond_with(successful_capture_response_with_icc_data)

    assert_success response
  end

  def test_authorization_with_emv_payment_application_fee_included
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, 'ch_test_charge', application_fee: 100, icc_data: @emv_credit_card.icc_data)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /application_fee/, 'request should include application_fee'
    end.respond_with(successful_capture_response_with_icc_data)

    assert_success response
  end

  def test_authorization_with_emv_payment_sets_capture_to_false
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, 'ch_test_charge', application_fee: 100, icc_data: @emv_credit_card.icc_data)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /capture\=false/, 'request should set capture to false'
    end.respond_with(successful_capture_response_with_icc_data)

    assert_success response
  end

  def test_passing_stripe_account_header
    @gateway.expects(:ssl_request).with do |_method, _url, _post, headers|
      headers.include?('Stripe-Account')
    end.returns(successful_authorization_response)

    @options[:stripe_account] = fixtures(:stripe_destination)[:stripe_user_id]

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_3ds_source_creation
    @gateway.expects(:ssl_request).twice.returns(threeds_first_sources_created_response, threeds_second_sources_created_response)
    card_source = @gateway.send(:create_source, @amount, @threeds_card, 'card', @options.merge(@threeds_options))
    assert_success card_source
    response = @gateway.send(:create_source, @amount, card_source.params['id'], 'three_d_secure', @options)
    assert_equal 'source', response.params['object']
    assert_equal 'pending', response.params['status']
    assert_equal 'three_d_secure', response.params['type']
    assert_equal false, response.params['three_d_secure']['authenticated']
  end

  def test_non3ds_card_source_creation
    @gateway.expects(:ssl_request).returns(non_3ds_sources_create_response)
    response = @gateway.send(:create_source, @amount, @non_3ds_card, 'card', @options.merge(@threeds_options))
    assert_equal 'source', response.params['object']
    assert_equal 'chargeable', response.params['status']
    assert_equal 'card', response.params['type']
    assert_equal 'not_supported', response.params['card']['three_d_secure']
  end

  def test_webhook_creation
    @gateway.expects(:ssl_request).returns(webhook_event_creation_response)
    response = @gateway.send(:create_webhook_endpoint, @options.merge(@threeds_options), ['source.chargeable'])
    assert_includes response.params['enabled_events'], 'source.chargeable'
    assert_equal @options.merge(@threeds_options)[:callback_url], response.params['url']
  end

  def test_webhook_deletion
    @gateway.expects(:ssl_request).twice.returns(webhook_event_creation_response, webhook_event_deletion_response)
    webhook = @gateway.send(:create_webhook_endpoint, @options.merge(@threeds_options), ['source.chargeable'])
    response = @gateway.send(:delete_webhook_endpoint, @options.merge(webhook_id: webhook.params['id']))
    assert_equal response.params['id'], webhook.params['id']
    assert_equal true, response.params['deleted']
  end

  def test_verify_good_credentials
    @gateway.expects(:raw_ssl_request).returns(credentials_are_legit_response)
    assert @gateway.verify_credentials
  end

  def test_verify_bad_credentials
    @gateway.expects(:raw_ssl_request).returns(credentials_are_bogus_response)
    assert !@gateway.verify_credentials
  end

  def test_stripe_internal_error_fails
    @gateway.expects(:add_creditcard)
    @gateway.expects(:ssl_request).returns(stripe_internal_error_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal response.message, 'No error details'
    assert response.test?
  end

  private

  # this mock is only useful with unit tests, as cryptograms generated by an EMV terminal
  # are specific to the target acquirer, so remote tests using this mock will fail elsewhere.
  def credit_card_with_icc_data
    ActiveMerchant::Billing::CreditCard.new(read_method: 'contact', icc_data: '500B56495341204352454449545F201A56495341204143515549524552205445535420434152442030315F24031512315F280208405F2A0208265F300202015F34010182025C008407A0000000031010950502000080009A031408259B02E8009C01009F02060000000734499F03060000000000009F0607A00000000310109F0902008C9F100706010A03A080009F120F4352454449544F20444520564953419F1A0208269F1C0831373030303437309F1E0831373030303437309F2608EB2EC0F472BEA0A49F2701809F3303E0B8C89F34031E03009F3501229F360200C39F37040A27296F9F4104000001319F4502DAC5DFAE5711476173FFFFFF0119D15122011758989389DFAE5A08476173FFFFFF011957114761739001010119D151220117589893895A084761739001010119')
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic c2tfdGVzdF9oQkwwTXF6ZGZ6Rnk3OXU0cFloUmVhQlo6\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.45.0\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.45.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.3 p242 (2014-09-19)\",\"platform\":\"x86_64-linux\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 270\r\n\r\n"
      <- "amount=100&currency=usd&card[number]=4242424242424242&card[exp_month]=9&card[exp_year]=2015&card[cvc]=123&card[name]=Longbob+Longsen&description=ActiveMerchant+Test+Purchase&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.45.0&metadata[email]=wow%40example.com&card[cryptogram]=sensitive_data&three_d_secure[cryptogram]=123456789abcdefghijklmnop&three_d_secure[apple_pay]=true"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Tue, 02 Dec 2014 19:44:17 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 1303\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: 89de951c-f880-4c39-93b0-832b3cc6dd32\r\n"
      -> "Stripe-Version: 2013-12-03\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains\r\n"
      -> "\r\n"
      reading 1303 bytes...
      -> "{\n  \"id\": \"ch_155MZJ2gKyKnHxtY1dGqFhSb\",\n  \"object\": \"charge\",\n  \"created\": 1417549457,\n  \"livemode\": false,\n  \"paid\": true,\n  \"amount\": 100,\n  \"currency\": \"usd\",\n  \"refunded\": false,\n  \"captured\": true,\n  \"refunds\": [],\n  \"card\": {\n    \"id\": \"card_155MZJ2gKyKnHxtYihrJ8z94\",\n    \"object\": \"card\",\n    \"last4\": \"4242\",\n    \"brand\": \"Visa\",\n    \"funding\": \"credit\",\n    \"exp_month\": 9,\n    \"exp_year\": 2015,\n    \"fingerprint\": \"944LvWcY01HVTbVc\",\n    \"country\": \"US\",\n    \"name\": \"Longbob Longsen\",\n    \"address_line1\": null,\n    \"address_line2\": null,\n    \"address_city\": null,\n    \"address_state\": null,\n    \"address_zip\": null,\n    \"address_country\": null,\n    \"cvc_check\": \"pass\",\n    \"address_line1_check\": null,\n    \"address_zip_check\": null,\n    \"dynamic_last4\": null,\n    \"customer\": null,\n    \"type\": \"Visa\"\n  },\n  \"balance_transaction\": \"txn_155MZJ2gKyKnHxtYxpYDI5OW\",\n  \"failure_message\": null,\n  \"failure_code\": null,\n  \"amount_refunded\": 0,\n  \"customer\": null,\n  \"invoice\": null,\n  \"description\": \"ActiveMerchant Test Purchase\",\n  \"dispute\": null,\n  \"metadata\": {\n    \"email\": \"wow@example.com\"\n  },\n  \"statement_description\": null,\n  \"fraud_details\": {\n    \"stripe_report\": \"unavailable\",\n    \"user_report\": null\n  },\n  \"receipt_email\": null,\n  \"receipt_number\": null,\n  \"shipping\": null\n}\n"
      read 1303 bytes
      Conn close
    PRE_SCRUBBED
  end

  def pre_scrubbed_nested_payment_method_data
    <<-PRE_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic c2tfdGVzdF9oQkwwTXF6ZGZ6Rnk3OXU0cFloUmVhQlo6\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.45.0\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.45.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.3 p242 (2014-09-19)\",\"platform\":\"x86_64-linux\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 270\r\n\r\n"
      <- "amount=100&currency=usd&payment_method_data[card][number]=4242424242424242&payment_method_data[card][exp_month]=9&payment_method_data[card][exp_year]=2015&payment_method_data[card][cvc]=123&payment_method_data[card][name]=Longbob+Longsen&description=ActiveMerchant+Test+Purchase&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.45.0&metadata[email]=wow%40example.com&payment_method_data[card][cryptogram]=sensitive_data&three_d_secure[cryptogram]=123456789abcdefghijklmnop&three_d_secure[apple_pay]=true"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Tue, 02 Dec 2014 19:44:17 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 1303\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: 89de951c-f880-4c39-93b0-832b3cc6dd32\r\n"
      -> "Stripe-Version: 2013-12-03\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains\r\n"
      -> "\r\n"
      reading 1303 bytes...
      -> "{\n  \"id\": \"ch_155MZJ2gKyKnHxtY1dGqFhSb\",\n  \"object\": \"charge\",\n  \"created\": 1417549457,\n  \"livemode\": false,\n  \"paid\": true,\n  \"amount\": 100,\n  \"currency\": \"usd\",\n  \"refunded\": false,\n  \"captured\": true,\n  \"refunds\": [],\n  \"card\": {\n    \"id\": \"card_155MZJ2gKyKnHxtYihrJ8z94\",\n    \"object\": \"card\",\n    \"last4\": \"4242\",\n    \"brand\": \"Visa\",\n    \"funding\": \"credit\",\n    \"exp_month\": 9,\n    \"exp_year\": 2015,\n    \"fingerprint\": \"944LvWcY01HVTbVc\",\n    \"country\": \"US\",\n    \"name\": \"Longbob Longsen\",\n    \"address_line1\": null,\n    \"address_line2\": null,\n    \"address_city\": null,\n    \"address_state\": null,\n    \"address_zip\": null,\n    \"address_country\": null,\n    \"cvc_check\": \"pass\",\n    \"address_line1_check\": null,\n    \"address_zip_check\": null,\n    \"dynamic_last4\": null,\n    \"customer\": null,\n    \"type\": \"Visa\"\n  },\n  \"balance_transaction\": \"txn_155MZJ2gKyKnHxtYxpYDI5OW\",\n  \"failure_message\": null,\n  \"failure_code\": null,\n  \"amount_refunded\": 0,\n  \"customer\": null,\n  \"invoice\": null,\n  \"description\": \"ActiveMerchant Test Purchase\",\n  \"dispute\": null,\n  \"metadata\": {\n    \"email\": \"wow@example.com\"\n  },\n  \"statement_description\": null,\n  \"fraud_details\": {\n    \"stripe_report\": \"unavailable\",\n    \"user_report\": null\n  },\n  \"receipt_email\": null,\n  \"receipt_number\": null,\n  \"shipping\": null\n}\n"
      read 1303 bytes
      Conn close
    PRE_SCRUBBED
  end

  def pre_scrubbed_with_track_data
    <<-PRE_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic c2tfdGVzdF8zT0Q0VGRLU0lPaERPTDIxNDZKSmNDNzk6\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.54.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.54.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.1 p76 (2014-02-24)\",\"platform\":\"x86_64-darwin12.0\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 165\r\n\r\n"
      <- "card[swipe_data]=%25B378282246310005%5ELONGSON%2FLONGBOB%5E1705101130504392%3F&amount=100&currency=usd&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.54.0"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 21 Oct 2015 17:22:09 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1446\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: req_7CpxqdRGPV3xWh\r\n"
      -> "Stripe-Version: 2015-04-07\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains\r\n"
      -> "\r\n"
      reading 1446 bytes...
      -> "{\n  \"id\": \"ch_16yQHtAWOtgoysogh1YOAtDB\",\n  \"object\": \"charge\",\n  \"amount\": 100,\n  \"amount_refunded\": 0,\n  \"application_fee\": null,\n  \"balance_transaction\": \"txn_16yQHtAWOtgoysogTNhtGJBn\",\n  \"captured\": true,\n  \"created\": 1445448129,\n  \"currency\": \"usd\",\n  \"customer\": null,\n  \"description\": null,\n  \"destination\": null,\n  \"dispute\": null,\n  \"failure_code\": null,\n  \"failure_message\": null,\n  \"fraud_details\": {},\n  \"invoice\": null,\n  \"livemode\": false,\n  \"metadata\": {},\n  \"paid\": true,\n  \"receipt_email\": null,\n  \"receipt_number\": null,\n  \"refunded\": false,\n  \"refunds\": {\n    \"object\": \"list\",\n    \"data\": [],\n    \"has_more\": false,\n    \"total_count\": 0,\n    \"url\": \"/v1/charges/ch_16yQHtAWOtgoysogh1YOAtDB/refunds\"\n  },\n  \"shipping\": null,\n  \"source\": {\n    \"id\": \"card_16yQHtAWOtgoysogdSGVCkXK\",\n    \"object\": \"card\",\n    \"address_city\": null,\n    \"address_country\": null,\n    \"address_line1\": null,\n    \"address_line1_check\": null,\n    \"address_line2\": null,\n    \"address_state\": null,\n    \"address_zip\": null,\n    \"address_zip_check\": null,\n    \"brand\": \"American Express\",\n    \"country\": \"US\",\n    \"customer\": null,\n    \"cvc_check\": null,\n    \"dynamic_last4\": null,\n    \"exp_month\": 5,\n    \"exp_year\": 2017,\n    \"fingerprint\": \"DjZpoV89lmOMsJLF\",\n    \"funding\": \"credit\",\n    \"last4\": \"0005\",\n    \"metadata\": {},\n    \"name\": \"LONGSON/LONGBOB\",\n    \"tokenization_method\": null\n  },\n  \"statement_descriptor\": null,\n  \"status\": \"succeeded\"\n}\n"
      read 1446 bytes
      Conn close
    PRE_SCRUBBED
  end

  def pre_scrubbed_with_emv_data
    <<-PRE_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic c2tfdGVzdF8zT0Q0VGRLU0lPaERPTDIxNDZKSmNDNzk6\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.54.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.54.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.1 p76 (2014-02-24)\",\"platform\":\"x86_64-darwin12.0\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 713\r\n\r\n"
      <- "card[emv_auth_data]=500B56495341204352454449545F201A56495341204143515549524552205445535420434152442030315F24031512315F280208405F2A0208265F300202015F34010182025C008407A0000000031010950502000080009A031408259B02E8009C01009F02060000000734499F03060000000000009F0607A00000000310109F0902008C9F100706010A03A080009F120F4352454449544F20444520564953419F1A0208269F1C0831373030303437309F1E0831373030303437309F2608EB2EC0F472BEA0A49F2701809F3303E0B8C89F34031E03009F3501229F360200C39F37040A27296F9F4104000001319F4502DAC5DFAE5711476173FFFFFF0119D15122011758989389DFAE5A08476173FFFFFF011957114761739001010119D151220117589893895A084761739001010119&card[emv_approval_data]=garbage&card[encrypted_pin]=8b68af72199529b8&card[encrypted_pin_key_id]=ffff0102628d12000001"
      -> "HTTP/1.1 402 Payment Required\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 21 Oct 2015 17:39:02 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 195\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: req_7CqEdcyzeRNGQO\r\n"
      -> "Stripe-Version: 2015-04-07\r\n"
      -> "\r\n"
      reading 195 bytes...
      -> "{\n  \"error\": {\n    \"message\": \"Your card was declined.\",\n    \"type\": \"card_error\",\n    \"code\": \"card_declined\",\n    \"charge\": \"ch_16yQYEAWOtgoysogscsBRQwg\",\n    \"emv_auth_data\": \"8A023035\"\n  }\n}\n"
      read 195 bytes
      Conn close
    PRE_SCRUBBED
  end

  def pre_scrubbed_with_account_number
    <<-PRE_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /v1/tokens?bank_account[account_number]=000123456789&bank_account[country]=US&bank_account[currency]=usd&bank_account[routing_number]=110000000&bank_account[name]=Jim+Smith&bank_account[account_holder_type]=individual HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic c2tfdGVzdF8zT0Q0VGRLU0lPaERPTDIxNDZKSmNDNzk6\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.123.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.123.0\",\"lang\":\"ruby\",\"lang_version\":\"2.6.6 p146 (2020-03-31)\",\"platform\":\"x86_64-darwin20\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.stripe.com\r\nContent-Length: 0\r\n\r\n"
      <- ""
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 06 Oct 2021 18:51:30 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 610\r\n"
      -> "Connection: close\r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "access-control-allow-methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "access-control-expose-headers: Request-Id, Stripe-Manage-Version, X-Stripe-External-Auth-Required, X-Stripe-Privileged-Session-Required\r\n"
      -> "access-control-max-age: 300\r\n"
      -> "cache-control: no-cache, no-store\r\n"
      -> "request-id: req_cueTxQR09SjIOA\r\n"
      -> "stripe-version: 2015-04-07\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains; preload\r\n"
      -> "\r\n"
      reading 610 bytes...
      -> "{\n  \"id\": \"btok_1JhfDCAWOtgoysogF0IbYRWH\",\n  \"object\": \"token\",\n  \"bank_account\": {\n    \"id\": \"ba_1JhfDCAWOtgoysogLB5vljcp\",\n    \"object\": \"bank_account\",\n    \"account_holder_name\": \"Jim Smith\",\n    \"account_holder_type\": \"individual\",\n    \"account_type\": null,\n    \"bank_name\": \"STRIPE TEST BANK\",\n    \"country\": \"US\",\n    \"currency\": \"usd\",\n    \"fingerprint\": \"uCkXlMFxqys7GosR\",\n    \"last4\": \"6789\",\n    \"name\": \"Jim Smith\",\n    \"routing_number\": \"110000000\",\n    \"status\": \"new\"\n  },\n  \"client_ip\": \"172.74.90.160\",\n  \"created\": 1633546290,\n  \"livemode\": false,\n  \"type\": \"bank_account\",\n  \"used\": false\n}\n"
      read 610 bytes
      Conn close
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /v1/customers HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic c2tfdGVzdF8zT0Q0VGRLU0lPaERPTDIxNDZKSmNDNzk6\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.123.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.123.0\",\"lang\":\"ruby\",\"lang_version\":\"2.6.6 p146 (2020-03-31)\",\"platform\":\"x86_64-darwin20\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.stripe.com\r\nContent-Length: 36\r\n\r\n"
      <- "source=btok_1JhfDCAWOtgoysogF0IbYRWH"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 06 Oct 2021 18:51:31 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1713\r\n"
      -> "Connection: close\r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "access-control-allow-methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "access-control-expose-headers: Request-Id, Stripe-Manage-Version, X-Stripe-External-Auth-Required, X-Stripe-Privileged-Session-Required\r\n"
      -> "access-control-max-age: 300\r\n"
      -> "cache-control: no-cache, no-store\r\n"
      -> "request-id: req_CfMAs2B351RDr0\r\n"
      -> "stripe-version: 2015-04-07\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains; preload\r\n"
      -> "\r\n"
      reading 1713 bytes...
      -> "{\n  \"id\": \"cus_KMNzQZK4SN7Agn\",\n  \"object\": \"customer\",\n  \"account_balance\": 0,\n  \"address\": null,\n  \"balance\": 0,\n  \"created\": 1633546290,\n  \"currency\": null,\n  \"default_source\": \"ba_1JhfDCAWOtgoysogLB5vljcp\",\n  \"delinquent\": false,\n  \"description\": null,\n  \"discount\": null,\n  \"email\": null,\n  \"invoice_prefix\": \"02D58981\",\n  \"invoice_settings\": {\n    \"custom_fields\": null,\n    \"default_payment_method\": null,\n    \"footer\": null\n  },\n  \"livemode\": false,\n  \"metadata\": {\n  },\n  \"name\": null,\n  \"next_invoice_sequence\": 1,\n  \"phone\": null,\n  \"preferred_locales\": [\n\n  ],\n  \"shipping\": null,\n  \"sources\": {\n    \"object\": \"list\",\n    \"data\": [\n      {\n        \"id\": \"ba_1JhfDCAWOtgoysogLB5vljcp\",\n        \"object\": \"bank_account\",\n        \"account_holder_name\": \"Jim Smith\",\n        \"account_holder_type\": \"individual\",\n        \"account_type\": null,\n        \"bank_name\": \"STRIPE TEST BANK\",\n        \"country\": \"US\",\n        \"currency\": \"usd\",\n        \"customer\": \"cus_KMNzQZK4SN7Agn\",\n        \"fingerprint\": \"uCkXlMFxqys7GosR\",\n        \"last4\": \"6789\",\n        \"metadata\": {\n        },\n        \"name\": \"Jim Smith\",\n        \"routing_number\": \"110000000\",\n        \"status\": \"new\"\n      }\n    ],\n    \"has_more\": false,\n    \"total_count\": 1,\n    \"url\": \"/v1/customers/cus_KMNzQZK4SN7Agn/sources\"\n  },\n  \"subscriptions\": {\n    \"object\": \"list\",\n    \"data\": [\n\n    ],\n    \"has_more\": false,\n    \"total_count\": 0,\n    \"url\": \"/v1/customers/cus_KMNzQZK4SN7Agn/subscriptions\"\n  },\n  \"tax_exempt\": \"none\",\n  \"tax_ids\": {\n    \"object\": \"list\",\n    \"data\": [\n\n    ],\n    \"has_more\": false,\n    \"total_count\": 0,\n    \"url\": \"/v1/customers/cus_KMNzQZK4SN7Agn/tax_ids\"\n  },\n  \"tax_info\": null,\n  \"tax_info_verification\": null\n}\n"
      read 1713 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed_with_emv_data
    <<-POST_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.54.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.54.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.1 p76 (2014-02-24)\",\"platform\":\"x86_64-darwin12.0\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 713\r\n\r\n"
      <- "card[emv_auth_data]=[FILTERED]&card[emv_approval_data]=[FILTERED]&card[encrypted_pin]=[FILTERED]&card[encrypted_pin_key_id]=[FILTERED]"
      -> "HTTP/1.1 402 Payment Required\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 21 Oct 2015 17:39:02 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 195\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: req_7CqEdcyzeRNGQO\r\n"
      -> "Stripe-Version: 2015-04-07\r\n"
      -> "\r\n"
      reading 195 bytes...
      -> "{\n  \"error\": {\n    \"message\": \"Your card was declined.\",\n    \"type\": \"card_error\",\n    \"code\": \"card_declined\",\n    \"charge\": \"ch_16yQYEAWOtgoysogscsBRQwg\",\n    \"emv_auth_data\": \"8A023035\"\n  }\n}\n"
      read 195 bytes
      Conn close
    POST_SCRUBBED
  end

  def post_scrubbed_with_track_data
    <<-POST_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.54.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.54.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.1 p76 (2014-02-24)\",\"platform\":\"x86_64-darwin12.0\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 165\r\n\r\n"
      <- "card[swipe_data]=[FILTERED]&amount=100&currency=usd&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.54.0"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 21 Oct 2015 17:22:09 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1446\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: req_7CpxqdRGPV3xWh\r\n"
      -> "Stripe-Version: 2015-04-07\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains\r\n"
      -> "\r\n"
      reading 1446 bytes...
      -> "{\n  \"id\": \"ch_16yQHtAWOtgoysogh1YOAtDB\",\n  \"object\": \"charge\",\n  \"amount\": 100,\n  \"amount_refunded\": 0,\n  \"application_fee\": null,\n  \"balance_transaction\": \"txn_16yQHtAWOtgoysogTNhtGJBn\",\n  \"captured\": true,\n  \"created\": 1445448129,\n  \"currency\": \"usd\",\n  \"customer\": null,\n  \"description\": null,\n  \"destination\": null,\n  \"dispute\": null,\n  \"failure_code\": null,\n  \"failure_message\": null,\n  \"fraud_details\": {},\n  \"invoice\": null,\n  \"livemode\": false,\n  \"metadata\": {},\n  \"paid\": true,\n  \"receipt_email\": null,\n  \"receipt_number\": null,\n  \"refunded\": false,\n  \"refunds\": {\n    \"object\": \"list\",\n    \"data\": [],\n    \"has_more\": false,\n    \"total_count\": 0,\n    \"url\": \"/v1/charges/ch_16yQHtAWOtgoysogh1YOAtDB/refunds\"\n  },\n  \"shipping\": null,\n  \"source\": {\n    \"id\": \"card_16yQHtAWOtgoysogdSGVCkXK\",\n    \"object\": \"card\",\n    \"address_city\": null,\n    \"address_country\": null,\n    \"address_line1\": null,\n    \"address_line1_check\": null,\n    \"address_line2\": null,\n    \"address_state\": null,\n    \"address_zip\": null,\n    \"address_zip_check\": null,\n    \"brand\": \"American Express\",\n    \"country\": \"US\",\n    \"customer\": null,\n    \"cvc_check\": null,\n    \"dynamic_last4\": null,\n    \"exp_month\": 5,\n    \"exp_year\": 2017,\n    \"fingerprint\": \"DjZpoV89lmOMsJLF\",\n    \"funding\": \"credit\",\n    \"last4\": \"0005\",\n    \"metadata\": {},\n    \"name\": \"LONGSON/LONGBOB\",\n    \"tokenization_method\": null\n  },\n  \"statement_descriptor\": null,\n  \"status\": \"succeeded\"\n}\n"
      read 1446 bytes
      Conn close
    POST_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.45.0\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.45.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.3 p242 (2014-09-19)\",\"platform\":\"x86_64-linux\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 270\r\n\r\n"
      <- "amount=100&currency=usd&card[number]=[FILTERED]&card[exp_month]=9&card[exp_year]=2015&card[cvc]=[FILTERED]&card[name]=Longbob+Longsen&description=ActiveMerchant+Test+Purchase&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.45.0&metadata[email]=wow%40example.com&card[cryptogram]=[FILTERED]&three_d_secure[cryptogram]=[FILTERED]&three_d_secure[apple_pay]=true"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Tue, 02 Dec 2014 19:44:17 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 1303\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: 89de951c-f880-4c39-93b0-832b3cc6dd32\r\n"
      -> "Stripe-Version: 2013-12-03\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains\r\n"
      -> "\r\n"
      reading 1303 bytes...
      -> "{\n  \"id\": \"ch_155MZJ2gKyKnHxtY1dGqFhSb\",\n  \"object\": \"charge\",\n  \"created\": 1417549457,\n  \"livemode\": false,\n  \"paid\": true,\n  \"amount\": 100,\n  \"currency\": \"usd\",\n  \"refunded\": false,\n  \"captured\": true,\n  \"refunds\": [],\n  \"card\": {\n    \"id\": \"card_155MZJ2gKyKnHxtYihrJ8z94\",\n    \"object\": \"card\",\n    \"last4\": \"4242\",\n    \"brand\": \"Visa\",\n    \"funding\": \"credit\",\n    \"exp_month\": 9,\n    \"exp_year\": 2015,\n    \"fingerprint\": \"944LvWcY01HVTbVc\",\n    \"country\": \"US\",\n    \"name\": \"Longbob Longsen\",\n    \"address_line1\": null,\n    \"address_line2\": null,\n    \"address_city\": null,\n    \"address_state\": null,\n    \"address_zip\": null,\n    \"address_country\": null,\n    \"cvc_check\": \"pass\",\n    \"address_line1_check\": null,\n    \"address_zip_check\": null,\n    \"dynamic_last4\": null,\n    \"customer\": null,\n    \"type\": \"Visa\"\n  },\n  \"balance_transaction\": \"txn_155MZJ2gKyKnHxtYxpYDI5OW\",\n  \"failure_message\": null,\n  \"failure_code\": null,\n  \"amount_refunded\": 0,\n  \"customer\": null,\n  \"invoice\": null,\n  \"description\": \"ActiveMerchant Test Purchase\",\n  \"dispute\": null,\n  \"metadata\": {\n    \"email\": \"wow@example.com\"\n  },\n  \"statement_description\": null,\n  \"fraud_details\": {\n    \"stripe_report\": \"unavailable\",\n    \"user_report\": null\n  },\n  \"receipt_email\": null,\n  \"receipt_number\": null,\n  \"shipping\": null\n}\n"
      read 1303 bytes
      Conn close
    POST_SCRUBBED
  end

  def post_scrubbed_nested_payment_method_data
    <<-POST_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.45.0\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.45.0\",\"lang\":\"ruby\",\"lang_version\":\"2.1.3 p242 (2014-09-19)\",\"platform\":\"x86_64-linux\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api.stripe.com\r\nContent-Length: 270\r\n\r\n"
      <- "amount=100&currency=usd&payment_method_data[card][number]=[FILTERED]&payment_method_data[card][exp_month]=9&payment_method_data[card][exp_year]=2015&payment_method_data[card][cvc]=[FILTERED]&payment_method_data[card][name]=Longbob+Longsen&description=ActiveMerchant+Test+Purchase&payment_user_agent=Stripe%2Fv1+ActiveMerchantBindings%2F1.45.0&metadata[email]=wow%40example.com&payment_method_data[card][cryptogram]=[FILTERED]&three_d_secure[cryptogram]=[FILTERED]&three_d_secure[apple_pay]=true"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Tue, 02 Dec 2014 19:44:17 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 1303\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "Access-Control-Max-Age: 300\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Request-Id: 89de951c-f880-4c39-93b0-832b3cc6dd32\r\n"
      -> "Stripe-Version: 2013-12-03\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains\r\n"
      -> "\r\n"
      reading 1303 bytes...
      -> "{\n  \"id\": \"ch_155MZJ2gKyKnHxtY1dGqFhSb\",\n  \"object\": \"charge\",\n  \"created\": 1417549457,\n  \"livemode\": false,\n  \"paid\": true,\n  \"amount\": 100,\n  \"currency\": \"usd\",\n  \"refunded\": false,\n  \"captured\": true,\n  \"refunds\": [],\n  \"card\": {\n    \"id\": \"card_155MZJ2gKyKnHxtYihrJ8z94\",\n    \"object\": \"card\",\n    \"last4\": \"4242\",\n    \"brand\": \"Visa\",\n    \"funding\": \"credit\",\n    \"exp_month\": 9,\n    \"exp_year\": 2015,\n    \"fingerprint\": \"944LvWcY01HVTbVc\",\n    \"country\": \"US\",\n    \"name\": \"Longbob Longsen\",\n    \"address_line1\": null,\n    \"address_line2\": null,\n    \"address_city\": null,\n    \"address_state\": null,\n    \"address_zip\": null,\n    \"address_country\": null,\n    \"cvc_check\": \"pass\",\n    \"address_line1_check\": null,\n    \"address_zip_check\": null,\n    \"dynamic_last4\": null,\n    \"customer\": null,\n    \"type\": \"Visa\"\n  },\n  \"balance_transaction\": \"txn_155MZJ2gKyKnHxtYxpYDI5OW\",\n  \"failure_message\": null,\n  \"failure_code\": null,\n  \"amount_refunded\": 0,\n  \"customer\": null,\n  \"invoice\": null,\n  \"description\": \"ActiveMerchant Test Purchase\",\n  \"dispute\": null,\n  \"metadata\": {\n    \"email\": \"wow@example.com\"\n  },\n  \"statement_description\": null,\n  \"fraud_details\": {\n    \"stripe_report\": \"unavailable\",\n    \"user_report\": null\n  },\n  \"receipt_email\": null,\n  \"receipt_number\": null,\n  \"shipping\": null\n}\n"
      read 1303 bytes
      Conn close
    POST_SCRUBBED
  end

  def post_scrubbed_with_account_number
    <<-POST_SCRUBBED
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /v1/tokens?bank_account[account_number]=[FILTERED]&bank_account[country]=US&bank_account[currency]=usd&bank_account[routing_number]=110000000&bank_account[name]=Jim+Smith&bank_account[account_holder_type]=individual HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.123.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.123.0\",\"lang\":\"ruby\",\"lang_version\":\"2.6.6 p146 (2020-03-31)\",\"platform\":\"x86_64-darwin20\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.stripe.com\r\nContent-Length: 0\r\n\r\n"
      <- ""
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 06 Oct 2021 18:51:30 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 610\r\n"
      -> "Connection: close\r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "access-control-allow-methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "access-control-expose-headers: Request-Id, Stripe-Manage-Version, X-Stripe-External-Auth-Required, X-Stripe-Privileged-Session-Required\r\n"
      -> "access-control-max-age: 300\r\n"
      -> "cache-control: no-cache, no-store\r\n"
      -> "request-id: req_cueTxQR09SjIOA\r\n"
      -> "stripe-version: 2015-04-07\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains; preload\r\n"
      -> "\r\n"
      reading 610 bytes...
      -> "{\n  \"id\": \"btok_1JhfDCAWOtgoysogF0IbYRWH\",\n  \"object\": \"token\",\n  \"bank_account\": {\n    \"id\": \"ba_1JhfDCAWOtgoysogLB5vljcp\",\n    \"object\": \"bank_account\",\n    \"account_holder_name\": \"Jim Smith\",\n    \"account_holder_type\": \"individual\",\n    \"account_type\": null,\n    \"bank_name\": \"STRIPE TEST BANK\",\n    \"country\": \"US\",\n    \"currency\": \"usd\",\n    \"fingerprint\": \"uCkXlMFxqys7GosR\",\n    \"last4\": \"6789\",\n    \"name\": \"Jim Smith\",\n    \"routing_number\": \"110000000\",\n    \"status\": \"new\"\n  },\n  \"client_ip\": \"172.74.90.160\",\n  \"created\": 1633546290,\n  \"livemode\": false,\n  \"type\": \"bank_account\",\n  \"used\": false\n}\n"
      read 610 bytes
      Conn close
      opening connection to api.stripe.com:443...
      opened
      starting SSL for api.stripe.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /v1/customers HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Stripe/v1 ActiveMerchantBindings/1.123.0\r\nStripe-Version: 2015-04-07\r\nX-Stripe-Client-User-Agent: {\"bindings_version\":\"1.123.0\",\"lang\":\"ruby\",\"lang_version\":\"2.6.6 p146 (2020-03-31)\",\"platform\":\"x86_64-darwin20\",\"publisher\":\"active_merchant\"}\r\nX-Stripe-Client-User-Metadata: {\"ip\":null}\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.stripe.com\r\nContent-Length: 36\r\n\r\n"
      <- "source=btok_1JhfDCAWOtgoysogF0IbYRWH"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Wed, 06 Oct 2021 18:51:31 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 1713\r\n"
      -> "Connection: close\r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "access-control-allow-methods: GET, POST, HEAD, OPTIONS, DELETE\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "access-control-expose-headers: Request-Id, Stripe-Manage-Version, X-Stripe-External-Auth-Required, X-Stripe-Privileged-Session-Required\r\n"
      -> "access-control-max-age: 300\r\n"
      -> "cache-control: no-cache, no-store\r\n"
      -> "request-id: req_CfMAs2B351RDr0\r\n"
      -> "stripe-version: 2015-04-07\r\n"
      -> "Strict-Transport-Security: max-age=31556926; includeSubDomains; preload\r\n"
      -> "\r\n"
      reading 1713 bytes...
      -> "{\n  \"id\": \"cus_KMNzQZK4SN7Agn\",\n  \"object\": \"customer\",\n  \"account_balance\": 0,\n  \"address\": null,\n  \"balance\": 0,\n  \"created\": 1633546290,\n  \"currency\": null,\n  \"default_source\": \"ba_1JhfDCAWOtgoysogLB5vljcp\",\n  \"delinquent\": false,\n  \"description\": null,\n  \"discount\": null,\n  \"email\": null,\n  \"invoice_prefix\": \"02D58981\",\n  \"invoice_settings\": {\n    \"custom_fields\": null,\n    \"default_payment_method\": null,\n    \"footer\": null\n  },\n  \"livemode\": false,\n  \"metadata\": {\n  },\n  \"name\": null,\n  \"next_invoice_sequence\": 1,\n  \"phone\": null,\n  \"preferred_locales\": [\n\n  ],\n  \"shipping\": null,\n  \"sources\": {\n    \"object\": \"list\",\n    \"data\": [\n      {\n        \"id\": \"ba_1JhfDCAWOtgoysogLB5vljcp\",\n        \"object\": \"bank_account\",\n        \"account_holder_name\": \"Jim Smith\",\n        \"account_holder_type\": \"individual\",\n        \"account_type\": null,\n        \"bank_name\": \"STRIPE TEST BANK\",\n        \"country\": \"US\",\n        \"currency\": \"usd\",\n        \"customer\": \"cus_KMNzQZK4SN7Agn\",\n        \"fingerprint\": \"uCkXlMFxqys7GosR\",\n        \"last4\": \"6789\",\n        \"metadata\": {\n        },\n        \"name\": \"Jim Smith\",\n        \"routing_number\": \"110000000\",\n        \"status\": \"new\"\n      }\n    ],\n    \"has_more\": false,\n    \"total_count\": 1,\n    \"url\": \"/v1/customers/cus_KMNzQZK4SN7Agn/sources\"\n  },\n  \"subscriptions\": {\n    \"object\": \"list\",\n    \"data\": [\n\n    ],\n    \"has_more\": false,\n    \"total_count\": 0,\n    \"url\": \"/v1/customers/cus_KMNzQZK4SN7Agn/subscriptions\"\n  },\n  \"tax_exempt\": \"none\",\n  \"tax_ids\": {\n    \"object\": \"list\",\n    \"data\": [\n\n    ],\n    \"has_more\": false,\n    \"total_count\": 0,\n    \"url\": \"/v1/customers/cus_KMNzQZK4SN7Agn/tax_ids\"\n  },\n  \"tax_info\": null,\n  \"tax_info_verification\": null\n}\n"
      read 1713 bytes
      Conn close
    POST_SCRUBBED
  end

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
      "sources":
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

  def successful_bank_token_request
    <<-RESPONSE
    {
      "id": "btok_7s6lmOv1DRUpyG",
      "object": "token",
      "bank_account": {
        "id": "ba_17cMXgAWOtgoysog7UDWXbn4",
        "object": "bank_account",
        "account_holder_type": "individual",
        "bank_name": "STRIPE TEST BANK",
        "country": "US",
        "currency": "usd",
        "fingerprint": "uCkXlMFxqys7GosR",
        "last4": "6789",
        "name": "Jim Smith",
        "routing_number": "110000000",
        "status": "new"
      },
      "client_ip": "24.142.217.2",
      "created": 1454966852,
      "livemode": false,
      "type": "bank_account",
      "used": false
    }
    RESPONSE
  end

  def successful_new_customer_bank_account_response
    <<-RESPONSE
    {
      "id": "cus_7s6levMt8IqhTR",
      "object": "customer",
      "account_balance": 0,
      "created": 1454966853,
      "currency": null,
      "default_source": "ba_17cMXgAWOtgoysog7UDWXbn4",
      "delinquent": false,
      "description": null,
      "discount": null,
      "email": null,
      "livemode": false,
      "metadata": {},
      "shipping": null,
      "sources": {
        "object": "list",
        "data": [
          {
            "id": "ba_17cMXgAWOtgoysog7UDWXbn4",
            "object": "bank_account",
            "account_holder_type": "individual",
            "bank_name": "STRIPE TEST BANK",
            "country": "US",
            "currency": "usd",
            "customer": "cus_7s6levMt8IqhTR",
            "fingerprint": "uCkXlMFxqys7GosR",
            "last4": "6789",
            "metadata": {},
            "name": "Jim Smith",
            "routing_number": "110000000",
            "status": "new"
          }
        ],
        "has_more": false,
        "total_count": 1,
        "url": "/v1/customers/cus_7s6levMt8IqhTR/sources"
      },
      "subscriptions": {
        "object": "list",
        "data": [],
        "has_more": false,
        "total_count": 0,
        "url": "/v1/customers/cus_7s6levMt8IqhTR/subscriptions"
      }
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

  def successful_authorization_response_with_icc_data
    <<-RESPONSE
    {
      "id": "ch_test_emv_charge",
      "object": "charge",
      "created": 1429642948,
      "livemode": true,
      "paid": true,
      "status": "succeeded",
      "amount": 1000,
      "currency": "usd",
      "refunded": false,
      "source": {
        "id": "card_15u6dcHMpVh8I77hUfAVAfsK",
        "object": "card",
        "last4": "8123",
        "brand": "MasterCard",
        "funding": "unknown",
        "exp_month": 12,
        "exp_year": 2025,
        "fingerprint": "tdVpM3XDe3H4juSD",
        "country": "US",
        "name": null,
        "address_line1": null,
        "address_line2": null,
        "address_city": null,
        "address_state": null,
        "address_zip": null,
        "address_country": null,
        "cvc_check": null,
        "address_line1_check": null,
        "address_zip_check": null,
        "dynamic_last4": null,
        "metadata": {},
        "customer": null,
        "emv_auth_data": "8A023835910AF7F7BA77D7ACCFAB0012710F860D8424000008C1EFF627EAE08933"
      },
      "captured": false,
      "balance_transaction": null,
      "failure_message": null,
      "failure_code": null,
      "amount_refunded": 0,
      "customer": null,
      "invoice": null,
      "description": null,
      "dispute": null,
      "metadata": {},
      "statement_descriptor": null,
      "fraud_details": {},
      "receipt_email": null,
      "receipt_number": null,
      "authorization_code": "816826",
      "shipping": null,
      "application_fee": null,
      "refunds": {
        "object": "list",
        "total_count": 0,
        "has_more": false,
        "url": "/v1/charges/ch_15u6dcHMpVh8I77hdIKNQ1jH/refunds",
        "data": []
      }
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

  def successful_capture_response_without_icc_data
    <<-RESPONSE
    {
      "id": "ch_test_emv_charge",
      "object": "charge",
      "amount": 1000,
      "amount_refunded": 0,
      "application": "ca_37BT8jOfv0Cu42Vfd",
      "application_fee": "fee_test_fee",
      "application_fee_amount": 55,
      "authorization_code": "123456",
      "balance_transaction": {
        "id": "txn_1FSQUtFwNjfzuchLeWPB9X8K",
        "object": "balance_transaction",
        "amount": 1000,
        "available_on": 1571184000,
        "created": 1570809463,
        "currency": "usd",
        "description": null,
        "exchange_rate": null,
        "fee": 55,
        "fee_details": [
          {
            "amount": 55,
            "application": "ca_37BT8jOfv0Cu42Vfd",
            "currency": "usd",
            "description": "application fee",
            "type": "application_fee"
          }
        ],
        "net": 945,
        "source": "ch_test_emv_charge",
        "sourced_transfers": {
          "object": "list",
          "data": [
          ],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/transfers?source_transaction=ch_test_emv_charge"
        },
        "status": "pending",
        "type": "charge"
      },
      "billing_details": {
        "address": {
          "city": null,
          "country": null,
          "line1": null,
          "line2": null,
          "postal_code": null,
          "state": null
        },
        "email": null,
        "name": null,
        "phone": null
      },
      "captured": true,
      "created": 1570809458,
      "currency": "usd",
      "customer": null,
      "description": null,
      "destination": null,
      "dispute": null,
      "failure_code": null,
      "failure_message": null,
      "fraud_details": {
      },
      "invoice": null,
      "livemode": false,
      "metadata": {
        "card_read_method": "contact",
        "shop_id": "1",
        "shop_name": "Shop 1",
        "transaction_fee_total_amount": "55",
        "transaction_fee_tax_amount": "0",
        "payments_charge_id": "86",
        "order_transaction_id": "149",
        "order_id": "c62.1"
      },
      "on_behalf_of": null,
      "order": null,
      "outcome": {
        "network_status": "approved_by_network",
        "reason": null,
        "risk_level": "normal",
        "risk_score": 2,
        "seller_message": "Payment complete.",
        "type": "authorized"
      },
      "paid": true,
      "payment_intent": null,
      "payment_method": "card_1FSQUo",
      "payment_method_details": {
        "card": {
          "brand": "visa",
          "checks": {
            "address_line1_check": null,
            "address_postal_code_check": null,
            "cvc_check": null
          },
          "country": "US",
          "ds_transaction_id": null,
          "exp_month": 12,
          "exp_year": 2022,
          "fingerprint": "PgHpMSUia1FIuXM6",
          "funding": "unknown",
          "installments": null,
          "last4": "0119",
          "moto": null,
          "network": "visa",
          "network_transaction_id": "ihQUSGFPfpVpg6J3",
          "three_d_secure": null,
          "wallet": null
        },
        "type": "card"
      },
      "receipt_email": null,
      "receipt_number": null,
      "receipt_url": "https://pay.stripe.com/receipts/acct_1FPxOBFwNjfzuchL/ch_test_emv_charge/rcpt_FyNFASxNs66DXe7zTe9jW9hpYZkQda9",
      "refunded": false,
      "refunds": {
        "object": "list",
        "data": [
        ],
        "has_more": false,
        "total_count": 0,
        "url": "/v1/charges/ch_test_emv_charge/refunds"
      },
      "review": null,
      "shipping": null,
      "source": {
        "id": "card_1FSQUo",
        "object": "card",
        "address_city": null,
        "address_country": null,
        "address_line1": null,
        "address_line1_check": null,
        "address_line2": null,
        "address_state": null,
        "address_zip": null,
        "address_zip_check": null,
        "brand": "Visa",
        "country": "US",
        "customer": null,
        "cvc_check": null,
        "dynamic_last4": null,
        "emv_auth_data": "8A023030",
        "exp_month": 12,
        "exp_year": 2022,
        "fingerprint": "ihQUSGFPfpVpg6J3",
        "funding": "unknown",
        "last4": "0119",
        "metadata": {
        },
        "name": null,
        "tokenization_method": null
      },
      "source_transfer": null,
      "statement_descriptor": null,
      "statement_descriptor_suffix": null,
      "status": "succeeded",
      "transfer_data": null,
      "transfer_group": null
    }
    RESPONSE
  end

  def successful_capture_response_with_icc_data
    <<-RESPONSE
    {
      "id": "ch_test_emv_charge",
      "object": "charge",
      "created": 1429643380,
      "livemode": true,
      "paid": true,
      "status": "succeeded",
      "amount": 1000,
      "currency": "usd",
      "refunded": false,
      "source": {
        "id": "card_15u6kaHMpVh8I77htEt6tgX4",
        "object": "card",
        "last4": "8123",
        "brand": "MasterCard",
        "funding": "unknown",
        "exp_month": 12,
        "exp_year": 2025,
        "fingerprint": "tdVpM3XDe3H4juSD",
        "country": "US",
        "name": null,
        "address_line1": null,
        "address_line2": null,
        "address_city": null,
        "address_state": null,
        "address_zip": null,
        "address_country": null,
        "cvc_check": null,
        "address_line1_check": null,
        "address_zip_check": null,
        "dynamic_last4": null,
        "metadata": {},
        "customer": null,
        "emv_auth_data": "8A023835910AF7F7BA77D7ACCFAB0012710F860D8424000008C1EFF627EAE08933"
      },
      "captured": true,
      "balance_transaction": "txn_15u6kbHMpVh8I77hA79CanC2",
      "failure_message": null,
      "failure_code": null,
      "amount_refunded": 900,
      "customer": null,
      "invoice": null,
      "description": null,
      "dispute": null,
      "metadata": {},
      "statement_descriptor": null,
      "fraud_details": {},
      "receipt_email": null,
      "receipt_number": null,
      "authorization_code": "662021",
      "shipping": null,
      "application_fee": null,
      "refunds": {
        "object": "list",
        "total_count": 1,
        "has_more": false,
        "url": "/v1/charges/ch_15u6kaHMpVh8I77hrF9XY8bG/refunds",
        "data": [
          {
            "id": "re_15u6kbHMpVh8I77h2o6RsdQq",
            "amount": 900,
            "currency": "usd",
            "created": 1429643381,
            "object": "refund",
            "balance_transaction": "txn_15u6kbHMpVh8I77hXqAYL6kZ",
            "metadata": {},
            "charge": "ch_15u6kaHMpVh8I77hrF9XY8bG",
            "receipt_number": null,
            "reason": null
          }
        ]
      }
    }
    RESPONSE
  end

  def successful_purchase_response(refunded = false)
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

  def successful_partially_refunded_response
    <<-RESPONSE
    {
      "id": "re_test_refund",
      "object": "refund",
      "amount": 80,
      "balance_transaction": "txn_1737ZdAWOtgoysogRvA3jg6b",
      "charge": "ch_1737ZcAWOtgoysogGRRsFjN9",
      "created": 1446567833,
      "currency": "usd",
      "metadata": {},
      "reason": null,
      "receipt_number": null
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "id": "re_173VMpAWOtgoysogOSE7Hzss",
      "object": "refund",
      "amount": 100,
      "balance_transaction": "txn_173VMpAWOtgoysog3QNrt0xD",
      "charge": "ch_173VMpAWOtgoysogrTPZT1YP",
      "created": 1446659295,
      "currency": "usd",
      "metadata": {},
      "reason": null,
      "receipt_number": null
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "error": {
        "type": "invalid_request_error",
        "message": "Charge ch_173VPSAWOtgoysoggGxIDRIq has already been refunded."
      }
    }
    RESPONSE
  end

  def successful_partially_refunded_application_fee_response
    <<-RESPONSE
    {
      "id": "fr_C8qmJKrZVMTjjF",
      "object": "fee_refund",
      "amount": 10,
      "balance_transaction": "txn_1BkZ4uAWOtgoysognvusG5N5",
      "created": 1516027008,
      "currency": "usd",
      "fee": "fee_1BkZ4rIPBJTitsenGWcxYWCZ",
      "metadata": {}
    }
    RESPONSE
  end

  def successful_fetch_application_fee_response
    <<-RESPONSE
    {
      "id": "ch_1Bja3MIPBJTitsenv28Gy6iN",
      "object": "charge",
      "amount": 100,
      "amount_refunded": 100,
      "application": "ca_6E9gvTfZGEMknxpoHhC8xoeyMit55FAV",
      "application_fee": "fee_1Bja3MIPBJTitsenKqV8Hc6R",
      "balance_transaction": "txn_1Bja3OIPBJTitsenJ5amtW58",
      "captured": true,
      "created": 1515792428,
      "currency": "usd",
      "customer": null,
      "description": "ActiveMerchant Test Purchase",
      "destination": null,
      "dispute": null,
      "failure_code": null,
      "failure_message": null,
      "fraud_details": {},
      "invoice": null,
      "livemode": false
    }
    RESPONSE
  end

  def unsuccessful_fetch_application_fee_response
    <<-RESPONSE
    {
      "error": {
        "type": "invalid_request_error",
        "message": "No such charge: bad_auth",
        "param": "id"
      }
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

  def declined_call_issuer_purchase_response
    <<-RESPONSE
    {
      "error": {
        "message": "Your card was declined.",
        "type": "card_error",
        "code": "card_declined",
        "decline_code": "call_issuer",
        "charge": "ch_test_charge"
      }
    }
    RESPONSE
  end

  def declined_pickup_card_purchase_response
    <<-RESPONSE
    {
      "error": {
        "message": "Your card was declined.",
        "type": "card_error",
        "code": "card_declined",
        "decline_code": "pickup_card",
        "charge": "ch_test_charge"
      }
    }
    RESPONSE
  end

  def declined_generic_decline_purchase_response
    <<-RESPONSE
    {
      "error": {
        "message": "Your card was declined.",
        "type": "card_error",
        "code": "card_declined",
        "decline_code": "generic_decline",
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

  def declined_authorization_response_with_emv_auth_data
    <<-RESPONSE
    {
     "error": {
       "message": "Your card was declined.",
       "type": "card_error",
       "code": "card_declined",
       "decline_code": "generic_decline",
       "charge": "ch_declined_auth",
       "emv_auth_data": "8A023531910ACD16B371D277FDB90000"
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

  def successful_apple_pay_token_exchange
    <<-RESPONSE
    {
      "id": "tok_14uq3k2gKyKnHxtYUAZZZlH3",
      "livemode": false,
      "created": 1415041212,
      "used": false,
      "object": "token",
      "type": "card",
      "card": {
          "id": "card_483etw4er9fg4vF3sQdrt3FG",
          "object": "card",
          "last4": "0000",
          "brand": "Visa",
          "funding": "credit",
          "exp_month": 6,
          "exp_year": 2019,
          "fingerprint": "HOh74kZU387WlUvy",
          "country": "US",
          "name": null,
          "address_line1": null,
          "address_line2": null,
          "address_city": null,
          "address_state": null,
          "address_zip": null,
          "address_country": null,
          "dynamic_last4": "4242",
          "customer": null,
          "type": "Visa"
      }
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

  def credentials_are_legit_response
    body = <<-JSON
    {
      "error": {
        "type": "invalid_request_error",
        "message": "No such charge: nonexistent",
        "param": "id"
        }
    }
    JSON
    MockResponse.new(404, body)
  end

  def credentials_are_bogus_response
    body = <<-JSON
    {
      "error": {
        "type": "invalid_request_error",
        "message": "Invalid API Key provided: an_unknown_***_key"
      }
    }
    JSON
    MockResponse.new(401, body)
  end

  def stripe_internal_error_response
    <<-RESPONSE
      {
        "id": "ch_1CSa8KL6Z03PTOVWo9B3qYCI",
        "object": "charge",
        "amount": 900,
        "amount_refunded": 0,
        "application": null,
        "application_fee": null,
        "balance_transaction": null,
        "captured": false,
        "created": 1526517494,
        "currency": "usd",
        "customer": null,
        "description": null,
        "destination": null,
        "dispute": null,
        "failure_code": null,
        "failure_message": null,
        "fraud_details": {},
        "invoice": null,
        "livemode": true,
        "metadata": {
          "product_name": "1 month",
          "vendor_id": "12345",
          "connect_agent": "Spreedly",
          "email": "someone@example.com",
          "order_id": "3193747-1568289"
        },
        "on_behalf_of": null,
        "order": null,
        "outcome": {
          "network_status": "approved_by_network",
          "reason": null,
          "seller_message": "Payment complete.",
          "type": "authorized"
        },
        "paid": false,
        "receipt_email": null,
        "receipt_number": null,
        "refunded": false,
        "refunds": {
          "object": "list",
          "data": [],
          "has_more": false,
          "total_count": 0,
          "url": "/v1/charges/ch_1CSa8KL6Z03PTOVWo9B3qYCI/refunds"
        },
        "review": null,
        "shipping": null,
        "source": {
          "id": "card_1a2b3c4d5e6f7g8h9j",
          "object": "card",
          "address_city": null,
          "address_country": null,
          "address_line1": null,
          "address_line1_check": null,
          "address_line2": null,
          "address_state": null,
          "address_zip": null,
          "address_zip_check": null,
          "brand": "Visa",
          "country": "MX",
          "customer": null,
          "cvc_check": null,
          "dynamic_last4": null,
          "exp_month": 11,
          "exp_year": 2021,
          "fingerprint": "ABCDEFGHIJKLMNO",
          "funding": "credit",
          "last4": "0123",
          "metadata": {},
          "name": null,
          "tokenization_method": null
        },
        "source_transfer": null,
        "statement_descriptor": "MAGIC*TEST*STUFF",
        "status": "failed",
        "transfer_group": null,
        "livemode": false
      }
    RESPONSE
  end

  def token_params
    {
      'id' => 'tok_14uq3k2gKyKnHxtYUAZZZlH3',
      'object' => 'token',
      'card' => {
        'id' => 'card_189f8n2eZvKYlo2CgvOd3Vtn',
        'object' => 'card',
        'address_city' => nil,
        'address_country' => nil,
        'address_line1' => nil,
        'address_line1_check' => nil,
        'address_line2' => nil,
        'address_state' => nil,
        'address_zip' => nil,
        'address_zip_check' => nil,
        'brand' => 'Visa',
        'country' => 'US',
        'cvc_check' => nil,
        'dynamic_last4' => nil,
        'exp_month' => 8,
        'exp_year' => 2017,
        'funding' => 'credit',
        'last4' => '4242',
        'metadata' => {
        },
        'name' => nil,
        'tokenization_method' => nil
      },
      'client_ip' => nil,
      'created' => 1462903169,
      'livemode' => false,
      'type' => 'card',
      'used' => false
    }
  end

  def threeds_first_sources_created_response
    <<-RESPONSE
      {
        "id": "src_1Dj5lqAWOtgoysogqA4CJX9Y",
        "object": "source",
        "amount": null,
        "card": {
          "exp_month": 9,
          "exp_year": 2019,
          "brand": "Visa",
          "country": "US",
          "cvc_check": "unchecked",
          "fingerprint": "53W491Mwz0OMuEJr",
          "funding": "credit",
          "last4": "3063",
          "three_d_secure": "required",
          "name": null,
          "address_line1_check": null,
          "address_zip_check": null,
          "tokenization_method": null,
          "dynamic_last4": null
        },
        "client_secret": "src_client_secret_EBShsJorDXd6WD521kRIQlbP",
        "created": 1545228694,
        "currency": null,
        "flow": "none",
        "livemode": false,
        "metadata": {
        },
        "owner": {
          "address": null,
          "email": null,
          "name": null,
          "phone": null,
          "verified_address": null,
          "verified_email": null,
          "verified_name": null,
          "verified_phone": null
        },
        "statement_descriptor": null,
        "status": "chargeable",
        "type": "card",
        "usage": "reusable"
      }
    RESPONSE
  end

  def threeds_second_sources_created_response
    <<-RESPONSE
      {
        "id": "src_1Dj5lrAWOtgoysog910mc8oS",
        "object": "source",
        "amount": 100,
        "client_secret": "src_client_secret_EBShU4HfxQAw2bVGMxvRECO1",
        "created": 1545228695,
        "currency": "usd",
        "flow": "redirect",
        "livemode": false,
        "metadata": {
        },
        "owner": {
          "address": {
            "city": null,
            "country": null,
            "line1": "",
            "line2": null,
            "postal_code": null,
            "state": null
          },
          "email": null,
          "name": null,
          "phone": null,
          "verified_address": null,
          "verified_email": null,
          "verified_name": null,
          "verified_phone": null
        },
        "redirect": {
          "failure_reason": null,
          "return_url": "http://www.example.com/callback",
          "status": "pending",
          "url": "https://hooks.stripe.com/redirect/authenticate/src_1Dj5lrAWOtgoysog910mc8oS?client_secret=src_client_secret_EBShU4HfxQAw2bVGMxvRECO1"
        },
        "statement_descriptor": null,
        "status": "pending",
        "three_d_secure": {
          "card": "src_1Dj5lqAWOtgoysogqA4CJX9Y",
          "brand": "Visa",
          "country": "US",
          "cvc_check": "unchecked",
          "exp_month": 9,
          "exp_year": 2019,
          "fingerprint": "53W491Mwz0OMuEJr",
          "funding": "credit",
          "last4": "3063",
          "three_d_secure": "required",
          "customer": null,
          "authenticated": false,
          "name": null,
          "address_line1_check": null,
          "address_zip_check": null,
          "tokenization_method": null,
          "dynamic_last4": null
        },
        "type": "three_d_secure",
        "usage": "single_use"
      }
    RESPONSE
  end

  def non_3ds_sources_create_response
    <<-RESPONSE
      {
        "id": "src_1Dj5yAAWOtgoysogPB6hwOa1",
        "object": "source",
        "amount": null,
        "card": {
          "exp_month": 9,
          "exp_year": 2019,
          "brand": "American Express",
          "country": "US",
          "cvc_check": "unchecked",
          "fingerprint": "DjZpoV89lmOMsJLF",
          "funding": "credit",
          "last4": "0005",
          "three_d_secure": "not_supported",
          "name": null,
          "address_line1_check": null,
          "address_zip_check": null,
          "tokenization_method": null,
          "dynamic_last4": null
        },
        "client_secret": "src_client_secret_EBStgH6cBMsODApAChcj9Kkq",
        "created": 1545229458,
        "currency": null,
        "flow": "none",
        "livemode": false,
        "metadata": {
        },
        "owner": {
          "address": null,
          "email": null,
          "name": null,
          "phone": null,
          "verified_address": null,
          "verified_email": null,
          "verified_name": null,
          "verified_phone": null
        },
        "statement_descriptor": null,
        "status": "chargeable",
        "type": "card",
        "usage": "reusable"
      }
    RESPONSE
  end

  def webhook_event_creation_response
    <<-RESPONSE
      {
        "id": "we_1Dj8GvAWOtgoysogAW1V5FFm",
        "object": "webhook_endpoint",
        "application": null,
        "created": 1545238309,
        "enabled_events": [
          "source.chargeable",
          "source.failed",
          "source.canceled"
        ],
        "livemode": false,
        "secret": "whsec_sJVAv7f1rddt1bNhouoDvxwQbZ8t0Pgn",
        "status": "enabled",
        "url": "http://www.example.com/callback"
      }
    RESPONSE
  end

  def webhook_event_deletion_response
    <<-RESPONSE
      {
        "id": "we_1Dj8GvAWOtgoysogAW1V5FFm",
        "object": "webhook_endpoint",
        "deleted": true
      }
    RESPONSE
  end
end
