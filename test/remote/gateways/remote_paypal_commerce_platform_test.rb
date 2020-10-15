# frozen_string_literal: true

require 'test_helper'

class PaypalExpressRestTest < Test::Unit::TestCase
  # This gateway uses v2 APIs for more details please check legacy API documentations https://developer.paypal.com/docs/api/payments/v2/
  # Billing Agreement using V1.
  # Get Access Token is using V1.
  # AM standards method are not being used for purchase as on order creation we used manual approval for the order.
  # Server-side APIs are used in this implementation for PayPal Checkout

  # Note: To run Billing Agreement test cases we have to do some process manually, We have to create the billing agreement manually and in its response there must be an approve billing agreement URL \
  # Which needs to be open and needs to pay the amount through personal paypal account once approved then we have to pass that BA token in fixtures.yml under \
  # ppcp block by assigning the value to approved_billing_token.

  def setup
    Base.mode               = :test
    @gateway                = ActiveMerchant::Billing::PaypalCommercePlatformGateway.new
    @ppcp_credentials       = fixtures(:ppcp)

    access_token            = @gateway.get_access_token({ authorization: user_credentials }).params['access_token']
    missing_password_params = { username: @ppcp_credentials[:username] }
    missing_username_params = { password: @ppcp_credentials[:password] }

    @headers = { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' }
    @body    = body

    @additional_params = { "payment_instruction": { "platform_fees": [{ "amount": { "currency_code": 'USD', "value": '2.00' }, "payee": { "email_address": @ppcp_credentials[:platform_payee_email] } }] } }

    @card_order_options = { "payment_source": { "card": { "name": 'John Doe', "number": @ppcp_credentials[:card_number], "expiry": "#{@ppcp_credentials[:year]}-#{@ppcp_credentials[:month]}", "security_code": @ppcp_credentials[:cvc],
                                                          "billing_address": { "address_line_1": '12312 Port Grace Blvd', "admin_area_2": 'La Vista', "admin_area_1": 'NE', "postal_code": '68128', "country_code": 'US' } } }, "headers": @headers }

    @get_token_missing_password_options = { "Content-Type": 'application/json', authorization: missing_password_params }
    @get_token_missing_username_options = { "Content-Type": 'application/json', authorization: missing_username_params }
    @approved_billing_token = @ppcp_credentials[:approved_billing_token]
  end

  # It will test and verify get access token.
  def test_access_token
    options       = { "Content-Type": 'application/json', authorization: user_credentials }
    access_token  = @gateway.get_access_token(options)
    assert !access_token.nil?
  end

  # It will test create the order with intent capture for direct merhcant
  def test_create_capture_instant_order_direct_merchant
    response = create_order('CAPTURE')
    success_status_assertions(response, 'CREATED')
  end

  # It will test order details
  def test_get_order_details
    response      = create_order('CAPTURE')
    order_id      = response.params['id']
    response      = @gateway.get_order_details(order_id, options)
    assert_success response
    assert_equal order_id, response.params['id']
  end

  # It will test capture order details
  def test_get_capture_details
    response   = create_order('CAPTURE')
    order_id   = response.params['id']
    response   = @gateway.capture(order_id, @card_order_options)
    capture_id = response.params['purchase_units'][0]['payments']['captures'][0]['id']
    response   = @gateway.get_capture_details(capture_id, options)
    assert_success response
    success_status_assertions(response, 'COMPLETED')
  end

  # It will test the order authorization details
  def test_get_authorization_details
    response         = create_order('AUTHORIZE')
    order_id         = response.params['id']
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params['purchase_units'][0]['payments']['authorizations'][0]['id']
    response         = @gateway.get_authorization_details(authorization_id, options)
    assert_success response
    success_status_assertions(response, 'CREATED')
  end

  # It will test the refund details of an order
  def test_get_refund_details
    response        = create_order('CAPTURE')
    order_id        = response.params['id']
    response        = @gateway.capture(order_id, @card_order_options)
    capture_id      = response.params['purchase_units'][0]['payments']['captures'][0]['id']
    response        = @gateway.refund(capture_id, options)
    refund_id       = response.params['id']
    response        = @gateway.get_refund_details(refund_id, options)
    assert_success response
    success_status_assertions(response, 'COMPLETED')
  end

  # It will test create order with intent capture for PPCP
  def test_create_capture_instant_order_ppcp
    response = create_order('CAPTURE', 'PPCP')
    success_status_assertions(response, 'CREATED')
  end

  # It will test purchase with credit card
  def test_purchase_with_card
    response = @gateway.purchase(options.merge(@card_order_options))
    success_status_assertions(response, 'COMPLETED')
  end

  # It will test create order with intent authorization
  def test_create_authorize_order
    response = create_order('AUTHORIZE')
    success_status_assertions(response, 'CREATED')
  end

  # It will test create order with intent capture along with the card.
  def test_capture_order_with_card
    response = create_order('CAPTURE')
    order_id = response.params['id']
    response = @gateway.capture(order_id, @card_order_options)
    success_status_assertions(response, 'COMPLETED')
  end

  # It will create ordrer with intent capture using payment instructions
  def test_capture_order_with_payment_instruction_through_card
    response = create_order('CAPTURE', 'PPCP')
    order_id = response.params['id']
    response = @gateway.capture(order_id, @card_order_options)
    success_status_assertions(response, 'COMPLETED')
  end

  # It will test create order with intent authorize
  def test_authorize_order_with_card
    response = create_order('AUTHORIZE')
    order_id = response.params['id']
    response = @gateway.authorize(order_id, @card_order_options)
    success_status_assertions(response, 'COMPLETED')
  end

  def test_create_order_for_internal_server_error
    params = options
    params[:headers][:'PayPal-Mock-Response'] = '{"mock_application_codes": "INTERNAL_SERVER_ERROR"}'
    response = @gateway.create_order('CAPTURE', params)

    server_side_failure_assertions(response, 'INTERNAL_SERVER_ERROR', nil, 'An internal server error occurred.')
  end

  def test_capture_order_for_invalid_request
    response        = @gateway.create_order('CAPTURE', options)
    order_id        = response.params['id']
    @card_order_options[:headers][:'PayPal-Mock-Response'] = '{"mock_application_codes": "INVALID_PARAMETER_VALUE"}'
    response = @gateway.capture(order_id, @card_order_options)

    server_side_failure_assertions(response,
      'INVALID_REQUEST',
      nil,
      'The request is not well-formed, is syntactically incorrect, or violates schema.')
  end

  def test_authorize_order_failure_on_missing_required_parameters
    response = create_order('AUTHORIZE')
    order_id = response.params['id']
    @card_order_options[:headers][:'PayPal-Mock-Response'] = '{"mock_application_codes": "MISSING_REQUIRED_PARAMETER"}'
    response = @gateway.authorize(order_id, @card_order_options)

    server_side_failure_assertions(
      response,
      'INVALID_REQUEST',
      nil,
      'The request is not well-formed, is syntactically incorrect, or violates schema.'
    )
  end

  def test_partial_refund_not_allowed
    response        = create_order('CAPTURE')
    order_id        = response.params['id']
    response        = @gateway.capture(order_id, @card_order_options)
    capture_id      = response.params['purchase_units'][0]['payments']['captures'][0]['id']
    params = options
    params[:headers][:'PayPal-Mock-Response'] = '{"mock_application_codes": "PARTIAL_REFUND_NOT_ALLOWED"}'
    response = @gateway.refund(capture_id, params)

    server_side_failure_assertions(
      response,
      'UNPROCESSABLE_ENTITY',
      'PARTIAL_REFUND_NOT_ALLOWED',
      'The requested action could not be completed, was semantically incorrect, or failed business validation.'
    )
  end

  def test_transaction_refused_for_void_authorized
    response         = create_order('AUTHORIZE')
    order_id         = response.params['id']
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params['purchase_units'][0]['payments']['authorizations'][0]['id']
    params = options
    params[:headers][:'PayPal-Mock-Response'] = '{"mock_application_codes": "PREVIOUSLY_VOIDED"}'
    response = @gateway.void(authorization_id, params)

    server_side_failure_assertions(
      response,
      'UNPROCESSABLE_ENTITY',
      'PREVIOUSLY_VOIDED',
      'The requested action could not be performed, semantically incorrect, or failed business validation.'
    )
  end

  def test_capture_authorized_order_with_card
    response         = create_order('AUTHORIZE')
    order_id         = response.params['id']
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params['purchase_units'][0]['payments']['authorizations'][0]['id']
    response         = @gateway.capture_authorization(authorization_id, options)
    success_status_assertions(response, 'COMPLETED')
  end

  def test_refund_captured_order_with_card
    response        = create_order('CAPTURE')
    order_id        = response.params['id']
    response        = @gateway.capture(order_id, @card_order_options)
    capture_id      = response.params['purchase_units'][0]['payments']['captures'][0]['id']
    refund_response = @gateway.refund(capture_id, options)
    success_status_assertions(refund_response, 'COMPLETED')
  end

  def test_void_authorized_order_with_card
    response         = create_order('AUTHORIZE')
    order_id         = response.params['id']
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params['purchase_units'][0]['payments']['authorizations'][0]['id']
    void_response    = @gateway.void(authorization_id, options)
    success_empty_assertions(void_response)
  end

  def test_update_shipping_amount_order
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_amount_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_replace_shipping_address_order
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_shipping_address_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_add_shipping_address_order
    @body[:purchase_units][0].delete(:shipping)
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_shipping_address_body }
    @body[:body][0].update(op: 'add')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_platform_fee_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_platform_fee_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_replace_soft_descriptor_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_soft_descriptor_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_remove_soft_descriptor_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_soft_descriptor_body }
    @body[:body][0].update(op: 'remove')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_replace_invoice_id_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_invoice_id_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_remove_and_add_invoice_id_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_invoice_id_body }
    @body[:body][0].update(op: 'remove')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body[:body][0].update(op: 'add')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_intent_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_intent_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_replace_shipping_name_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_shipping_name_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_add_shipping_name_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_shipping_name_body }
    @body[:body][0].update(op: 'add')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_replace_description_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_description_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_remove_and_add_description_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_description_body }
    @body[:body][0].update(op: 'remove')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body[:body][0].update(op: 'add')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_replace_update_custom_id_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_custom_id_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_remove_and_add_update_custom_id_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_custom_id_body }
    @body[:body][0].update(op: 'remove')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body[:body][0].update(op: 'add')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_replace_payee_email_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_payee_email_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_replace_update_purchase_unit_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_purchase_unit_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_update_add_purchase_unit_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_purchase_unit_body }
    @body[:body][0].update(op: 'add')
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
  end

  def test_create_billing_agreement_token
    @body    = billing_agreement_body
    response = @gateway.create_billing_agreement_token(options)
    assert_success response
    assert !response.params['token_id'].nil?
    assert !response.params['links'].nil?
  end

  def test_create_billing_agreement
    @body    = { "token_id": @approved_billing_token }
    response = @gateway.create_billing_agreement(options)
    assert_success response
    assert_equal 'ACTIVE', response.params['state']
    assert !response.params['id'].nil?
    assert !response.params['links'].nil?
  end

  def test_capture_order_with_billing
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_billing_agreement(options)
    billing_id = response.params['id']
    @body      = body
    response   = create_order('CAPTURE')
    order_id   = response.params['id']
    response   = @gateway.capture(order_id, billing_options(billing_id))
    success_status_assertions(response, 'COMPLETED')
  end

  def test_authorize_order_with_billing
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_billing_agreement(options)
    billing_id = response.params['id']
    @body      = body
    @intent    = 'AUTHORIZE'
    response   = create_order('AUTHORIZE')
    order_id   = response.params['id']
    response   = @gateway.authorize(order_id, billing_options(billing_id))
    success_status_assertions(response, 'COMPLETED')
  end

  def test_capture_authorized_order_with_billing
    @body            = { "token_id": @approved_billing_token }
    response         = @gateway.create_billing_agreement(options)
    billing_id       = response.params['id']
    @body            = body
    response         = create_order('AUTHORIZE')
    order_id         = response.params['id']
    response         = @gateway.authorize(order_id, billing_options(billing_id))
    authorization_id = response.params['purchase_units'][0]['payments']['authorizations'][0]['id']
    response         = @gateway.capture_authorization(authorization_id, billing_options(billing_id))
    success_status_assertions(response, 'COMPLETED')
  end

  def test_void_authorized_order_with_billing
    @body            = { "token_id": @approved_billing_token }
    response         = @gateway.create_billing_agreement(options)
    billing_id       = response.params['id']
    @body            = body
    response         = create_order('AUTHORIZE')
    order_id         = response.params['id']
    response         = @gateway.authorize(order_id, billing_options(billing_id))
    authorization_id = response.params['purchase_units'][0]['payments']['authorizations'][0]['id']
    response         = @gateway.void(authorization_id, options)
    success_empty_assertions(response)
  end

  def test_refund_captured_order_with_billing
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_billing_agreement(options)
    billing_id = response.params['id']
    @body      = body
    response   = create_order('CAPTURE')
    order_id   = response.params['id']
    response   = @gateway.capture(order_id, billing_options(billing_id))
    capture_id = response.params['purchase_units'][0]['payments']['captures'][0]['id']
    response   = @gateway.refund(capture_id, options)
    success_status_assertions(response, 'COMPLETED')
  end

  def test_update_billing_description_and_merchant_custom_and_notify
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_billing_agreement(options)
    billing_id = response.params['id']
    @body      = { "body": billing_update_body }
    response   = @gateway.update_billing_agreement(billing_id, options)
    success_empty_assertions(response)
  end

  def test_get_billing_token_details
    @body             = billing_agreement_body
    response          = @gateway.create_billing_agreement_token(options)
    agreement_token   = response.params['token_id']
    response          = @gateway.get_billing_agreement_token_details(agreement_token, options)
    assert_success response
    assert_equal agreement_token, response.params['token_id']
    assert_equal 'PENDING', response.params['token_status']
  end

  def test_get_billing_agreement_details
    @body    = { "token_id": @approved_billing_token }
    response = @gateway.create_billing_agreement(options)
    token_id = response.params['id']
    response = @gateway.get_billing_agreement_details(token_id, options)
    assert_success response
    assert_equal token_id, response.params['id']
    assert_equal 'ACTIVE', response.params['state']
  end

  def test_missing_password_argument_to_get_access_token
    assert_raise(ArgumentError) do
      @gateway.get_access_token(@get_token_missing_password_options)
    end
  end

  def test_missing_username_argument_to_get_access_token
    assert_raise(ArgumentError) do
      @gateway.get_access_token(@get_token_missing_username_options)
    end
  end

  def test_missing_intent_argument_for_order_creation
    @body.delete(:intent)
    assert_raise(ArgumentError) do
      @gateway.create_order(nil, options)
    end
  end

  def test_missing_purchase_units_argument_for_order_creation
    @body.delete(:purchase_units)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_amount_in_purchase_units_argument
    @body[:purchase_units][0].delete(:amount)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_currency_code_in_amount_argument
    @body[:purchase_units][0][:amount].delete(:currency_code)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_value_in_amount_argument
    @body[:purchase_units][0][:amount].delete(:value)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_name_in_items
    @body[:purchase_units][0][:items][0].delete(:name)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_quantity_in_items
    @body[:purchase_units][0][:items][0].delete(:quantity)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_unit_amount_in_items
    @body[:purchase_units][0][:items][0].delete(:name)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_admin_area_2_in_address
    @body[:purchase_units][0][:shipping][:address].delete(:admin_area_2)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_postal_code_in_address
    @body[:purchase_units][0][:shipping][:address].delete(:postal_code)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_country_code_in_address
    @body[:purchase_units][0][:shipping][:address].delete(:country_code)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_amount_in_platform_fee
    @body[:purchase_units][0].update(@additional_params)
    @body[:purchase_units][0][:payment_instruction][:platform_fees][0].delete(:amount)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_payee_in_platform_fee
    @body[:purchase_units][0].update(@additional_params)
    @body[:purchase_units][0][:payment_instruction][:platform_fees][0].delete(:payee)
    assert_raise(ArgumentError) do
      @gateway.create_order('CAPTURE', options)
    end
  end

  def test_missing_order_id_in_update_body
    assert_raise(ArgumentError) do
      @body = { body: update_amount_body }
      @gateway.update_order(nil, options)
    end
  end

  def test_missing_body_in_update_body
    assert_raise(ArgumentError) do
      response = create_order('CAPTURE')
      order_id = response.params['id']
      @body = {}
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_op_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_amount_body }
    @body[:body][0].delete(:op)
    assert_raise(ArgumentError) do
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_path_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_amount_body }
    @body[:body][0].delete(:path)
    assert_raise(ArgumentError) do
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_value_in_update_body
    response = create_order('CAPTURE')
    order_id = response.params['id']
    @body    = { body: update_amount_body }
    @body[:body][0].delete(:value)
    assert_raise(ArgumentError) do
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_payer_in_create_billing_agreement
    @body = billing_agreement_body
    @body.delete(:payer)
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement_token(options)
    end
  end

  def test_missing_plan_in_create_billing_agreement
    @body = billing_agreement_body
    @body.delete(:plan)
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement_token(options)
    end
  end

  def test_missing_line1_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(:line1)
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement_token(options)
    end
  end

  def test_missing_postal_code_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(:postal_code)
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement_token(options)
    end
  end

  def test_missing_country_code_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(:country_code)
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement_token(options)
    end
  end

  def test_missing_city_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(:city)
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement_token(options)
    end
  end

  def test_missing_state_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(:state)
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement_token(options)
    end
  end

  def test_missing_token_id_in_create_billing_agreement
    @body = {}
    assert_raise(ArgumentError) do
      @gateway.create_billing_agreement(options)
    end
  end

  def test_missing_id_in_billing_token
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_billing_agreement(options)
    billing_id = response.params['id']
    @body      = body
    response   = create_order('CAPTURE')
    order_id   = response.params['id']
    assert_raise(ArgumentError) do
      billing_body = billing_options(billing_id)
      billing_body[:payment_source][:token].delete(:id)
      @gateway.capture(order_id, billing_body)
    end
  end

  def test_missing_type_in_billing_token
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_billing_agreement(options)
    billing_id = response.params['id']
    @body      = body
    response   = create_order('CAPTURE')
    order_id   = response.params['id']
    assert_raise(ArgumentError) do
      billing_body = billing_options(billing_id)
      billing_body[:payment_source][:token].delete(:type)
      @gateway.capture(order_id, billing_body)
    end
  end

  private

  def create_order(order_type, type = 'DIRECT')
    if type.eql?('PPCP')
      @body[:purchase_units].each.with_index do |_value, index|
        @body[:purchase_units][index].update(@additional_params)
      end
    else
      @body[:purchase_units].each.with_index do |_value, index|
        @body[:purchase_units][index].delete(:payment_instructions)
      end
    end
    @gateway.create_order(order_type, options)
  end

  def options
    { headers: @headers }.merge(@body)
  end

  def body
    @reference_id = "camera_shop_seller_#{Time.now}"
    {
      "description": 'PPCP',
        "intent": @intent || 'CAPTURE',
        "purchase_units": [
          {
            "reference_id": @reference_id,
              "description": 'Camera Shop',
              "amount": {
                "currency_code": 'USD',
                  "value": '25.00',
                  "breakdown": {
                    "item_total": {
                      "currency_code": 'USD',
                          "value": '25.00'
                    },
                      "shipping": {
                        "currency_code": 'USD',
                          "value": '0'
                      },
                      "handling": {
                        "currency_code": 'USD',
                          "value": '0'
                      },
                      "tax_total": {
                        "currency_code": 'USD',
                          "value": '0'
                      },
                      "gift_wrap": {
                        "currency_code": 'USD',
                          "value": '0'
                      },
                      "shipping_discount": {
                        "currency_code": 'USD',
                          "value": '0'
                      }
                  }
              },
              "payee": {
                "email_address": @ppcp_credentials[:payee_email]
              },
              "items": [
                {
                  "name": 'Levis 501 Selvedge STF',
                      "sku": '5158936',
                      "unit_amount": {
                        "currency_code": 'USD',
                          "value": '25.00'
                      },
                      "tax": {
                        "currency_code": 'USD',
                          "value": '0.00'
                      },
                      "quantity": '1',
                      "category": 'PHYSICAL_GOODS'
                }
              ],
              "shipping": {
                "address": {
                  "address_line_1": '500 Hillside Street',
                      "address_line_2": '#1000',
                      "admin_area_1": 'CA',
                      "admin_area_2": 'San Jose',
                      "postal_code": '95131',
                      "country_code": 'US'
                }
              },
              "shipping_method": 'United Postal Service',
              "payment_group_id": 1,
              "custom_id": "custom_value_#{Time.now}",
              "invoice_id": "invoice_number_#{Time.now}",
              "soft_descriptor": 'Payment Camera Shop'
          }
        ],
        "payer": payer_hash,
        "application_context": application_context
    }
  end

  def update_amount_body
    [
      {
        "op": 'replace',
          "path": "/purchase_units/@reference_id=='#{@reference_id}'/amount",
          "value": {
            "currency_code": 'USD',
              "value": '27.00',
              "breakdown": {
                "item_total": {
                  "currency_code": 'USD',
                      "value": '25.00'
                },
                  "shipping": {
                    "currency_code": 'USD',
                      "value": '2.00'
                  }
              }
          }
      }
    ]
  end

  def update_shipping_address_body
    [
      {
        "op": 'replace',
          "path": "/purchase_units/@reference_id=='#{@reference_id}'/shipping/address",
          "value": {
            "address_line_1": '123 Townsend St',
              "address_line_2": 'Floor 6',
              "admin_area_2": 'San Francisco',
              "admin_area_1": 'CA',
              "postal_code": '94107',
              "country_code": 'US'
          }
      }
    ]
  end

  def update_intent_body
    [
      {
        path: '/intent',
          value: 'CAPTURE',
          op: 'replace'
      }
    ]
  end

  def update_platform_fee_body
    [{
      "op": 'add',
         "path": "/purchase_units/@reference_id=='#{@reference_id}'/payment_instruction",
         "value": {
           "platform_fees": [
             {
               "amount": {
                 "currency_code": 'USD',
                     "value": '3.00'
               },
                   "payee": {
                     "email_address": @ppcp_credentials[:platform_payee_email]
                   }
             }
           ]
         }
    }]
  end

  def update_invoice_id_body
    [
      {
        path: "/purchase_units/@reference_id=='#{@reference_id}'/invoice_id",
          value: 'INVOICE_ID_123',
          op: 'replace'
      }
    ]
  end

  def update_custom_id_body
    [
      {
        path: "/purchase_units/@reference_id=='#{@reference_id}'/custom_id",
          value: 'CUSTOM_ID_123',
          op: 'replace'
      }
    ]
  end

  def update_payee_email_body
    [
      {
        path: "/purchase_units/@reference_id=='#{@reference_id}'/payee/email_address",
          value: 'test@test.com',
          op: 'replace'
      }
    ]
  end

  def update_shipping_name_body
    [
      {
        path: "/purchase_units/@reference_id=='#{@reference_id}'/shipping/name",
          value: {
            full_name: 'TEST SHIPPING'
          },
          op: 'replace'
      }
    ]
  end

  def update_description_body
    [{
      path: "/purchase_units/@reference_id=='#{@reference_id}'/description",
         value: 'UPDATED DESCRIPTION',
         op: 'replace'
    }]
  end

  def update_soft_descriptor_body
    [
      {
        path: "/purchase_units/@reference_id=='#{@reference_id}'/soft_descriptor",
          value: 'Description Changed.',
          op: 'replace'
      }
    ]
  end

  def update_purchase_unit_body
    [
      {
        "path": "/purchase_units/@reference_id=='#{@reference_id}'",
          "op": 'replace',
          "value": body[:purchase_units][0]
      }
    ]
  end

  def billing_agreement_body
    {
      "description": 'Billing Agreement',
        "shipping_address":
            {
              "line1": '1350 North First Street',
                "city": 'San Jose',
                "state": 'CA',
                "postal_code": '95112',
                "country_code": 'US',
                "recipient_name": 'John Doe'
            },
        "payer":
            {
              "payment_method": 'PAYPAL'
            },
        "plan":
            {
              "type": 'MERCHANT_INITIATED_BILLING',
                "merchant_preferences":
                    {
                      "return_url": 'https://google.com',
                        "cancel_url": 'https://google.com',
                        "accepted_pymt_type": 'INSTANT',
                        "skip_shipping_address": false,
                        "immutable_shipping_address": true
                    }
            }
    }
  end

  def billing_options(billing_token)
    {
      "payment_source": {
        "token": {
          "id": billing_token,
              "type": 'BILLING_AGREEMENT'
        }
      },
        application_context: application_context,
        "headers": @headers
    }
  end

  def billing_update_body
    [
      {
        "op": 'replace',
          "path": '/',
          "value": {
            "description": 'Updated Billing Agreement',
              "merchant_custom_data": 'INV-003'
          }
      },
      {
        "op": 'replace',
          "path": '/plan/merchant_preferences/',
          "value": {
            "notify_url": 'https://example.com/notification'
          }
      }
    ]
  end

  def user_credentials
    {
      username: @ppcp_credentials[:username],
        password: @ppcp_credentials[:password]
    }
  end

  def invalid_user_credentials
    {
      username: 'ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXM==',
        password: 'EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM3=='
    }
  end

  # Assertions private methods

  def success_status_assertions(response, status)
    assert_success response
    assert_equal status, response.params['status']
    assert !response.params['id'].nil?
    assert !response.params['links'].nil?
  end

  def server_side_failure_assertions(response, name, issue_msg, message)
    assert !response.params['name'].nil?
    assert response.params['name'] == name
    assert response.params['details'][0]['issue'] == issue_msg unless issue_msg.nil?
    assert response.params['message'] == message
  end

  def success_empty_assertions(response)
    assert_success response
    assert_empty   response.params
  end

  def payer_hash
    # Regex for national_number: ^[0-9]{1,14}?$.
    { name: name, email_address: @ppcp_credentials[:payer_email], payer_id: @ppcp_credentials[:payer_id], phone: phone, birth_date: '1990-08-31', tax_info: tax_info, address: address }
  end

  def address
    { address_line_1: '2211 N First Street', address_line_2: 'Building 17', admin_area_2: '21 N First Street', admin_area_1: '2211 N First Street', postal_code: '95131', country_code: 'US' }
  end

  def tax_info
    ## Tax ID Type = Possible values: BR_CPF, BR_CNPJ
    { tax_id: '000000000', tax_id_type: 'BR_CPF' }
  end

  def phone
    { phone_type: 'FAX', phone_number: { national_number: '(123) 456-7890' } }
  end

  def name
    { given_name: 'John', surname: 'Doe' }
  end

  def application_context
    # The possible values are:
    #                         GET_FROM_FILE. Use the customer-provided shipping address on the PayPal site.
    #     NO_SHIPPING. Redact the shipping address from the PayPal site. Recommended for digital goods.
    #     SET_PROVIDED_ADDRESS. Use the merchant-provided address. The customer cannot change this address on the PayPal site.
    #     Default: GET_FROM_FILE.
    { return_url: 'https://paypal.com', cancel_url: 'https://paypal.com', landing_page: 'LOGIN', locale: 'en', user_action: 'PAY_NOW',
      brand_name: 'PPCP', shipping_preference: 'NO_SHIPPING', payment_method: payment_method, stored_payment_source: stored_payment_source }
  end

  def payment_method
    { payer_selected: 'PAYPAL', payee_preferred: 'UNRESTRICTED', standard_entry_class_code: 'WEB' }
  end

  def stored_payment_source
    { payment_initiator: 'MERCHANT', payment_type: 'ONE_TIME', usage: 'FIRST', previous_network_transaction_reference: previous_network_transaction_reference }
  end

  def previous_network_transaction_reference
    { id: '1111111111', date: '2020-10-01T21:20:49Z', network: 'MASTERCARD' }
  end
end
