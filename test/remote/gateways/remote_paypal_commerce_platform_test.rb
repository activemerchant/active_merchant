require "test_helper"

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode               = :test
    @gateway                = ActiveMerchant::Billing::PaypalCommercePlatformGateway.new
    @ppcp_credentials        = fixtures(:ppcp)

    options                 = { "Content-Type": "application/json", authorization: user_credentials }
    access_token            = @gateway.get_access_token(options)
    missing_password_params = { username: @ppcp_credentials[:username] }
    missing_username_params = { password: @ppcp_credentials[:password] }

    @headers = { "Authorization": "Bearer #{ access_token }", "Content-Type": "application/json" }
    @body    = body

    @additional_params =  {
        "payment_instruction": {
            "platform_fees": [
                {
                    "amount": {
                        "currency_code": "USD",
                        "value": "2.00"
                    },
                    "payee": {
                        "email_address": "sb-c447ox3078929@business.example.com"
                    }
                }
            ]
        }
    }

    @card_order_options = {
        "payment_source": {
            "card": {
                "name": "John Doe",
                "number": "4032039317984658",
                "expiry": "2023-07",
                "security_code": "111",
                "billing_address": {
                    "address_line_1": "12312 Port Grace Blvd",
                    "admin_area_2": "La Vista",
                    "admin_area_1": "NE",
                    "postal_code": "68128",
                    "country_code": "US"
                }
            }
        },
        "headers": @headers
    }

    @get_token_missing_password_options = { "Content-Type": "application/json", authorization: missing_password_params }

    @get_token_missing_username_options = { "Content-Type": "application/json", authorization: missing_username_params }

    @approved_billing_token = "BA-55S78277CF410190G"
  end

  def test_access_token
    options       = { "Content-Type": "application/json", authorization: user_credentials }
    access_token  = @gateway.get_access_token(options)
    # assert access_token.include?("basic")
    assert !access_token.nil?
  end

  def test_create_capture_instant_order_direct_merchant
    response = create_order("CAPTURE")
    puts "Capture Order Id (Instant) - PPCP: #{ response.params["id"] }"
    success_status_assertions(response, "CREATED")
  end

  def test_create_capture_instant_order_ppcp
    response = create_order("CAPTURE", "PPCP")
    puts "Capture Order Id (Instant) - PPCP: #{ response.params["id"] }"
    success_status_assertions(response, "CREATED")
  end

  def test_create_authorize_order
    response = create_order("AUTHORIZE")
    puts "Authorize Order Id: #{ response.params["id"] }"
    success_status_assertions(response, "CREATED")
  end

  def test_capture_order_with_card
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    response = @gateway.capture(order_id, @card_order_options)
    success_status_assertions(response, "COMPLETED")
  end

  def test_capture_order_with_payment_instruction_through_card
    response = create_order("CAPTURE", "PPCP")
    order_id = response.params["id"]
    response = @gateway.capture(order_id, @card_order_options)
    success_status_assertions(response, "COMPLETED")
  end

  def test_authorize_order_with_card
    response = create_order("AUTHORIZE")
    order_id = response.params["id"]
    response = @gateway.authorize(order_id, @card_order_options)
    success_status_assertions(response, "COMPLETED")
  end

  def test_create_order_for_internal_server_error
    options[:headers].merge!({ "PayPal-Mock-Response": "{\"mock_application_codes\": \"INTERNAL_SERVER_ERROR\"}"})
    response = @gateway.create_order("CAPTURE", options)

    server_side_failure_assertions(response,
                                   "INTERNAL_SERVER_ERROR",
                                   nil,
                                   "An internal server error occurred."
    )
  end

  def test_capture_order_for_invalid_request
    response        = @gateway.create_order("CAPTURE", options)
    order_id        = response.params["id"]
    @card_order_options[:headers].merge!({ "PayPal-Mock-Response": "{\"mock_application_codes\": \"INVALID_PARAMETER_VALUE\"}"})
    response        = @gateway.capture(order_id, @card_order_options)

    server_side_failure_assertions(response,
                                   "INVALID_REQUEST",
                                   nil,
                                   "The request is not well-formed, is syntactically incorrect, or violates schema."
    )
  end

  def test_authorize_order_failure_on_missing_required_parameters
    response = create_order("AUTHORIZE")
    order_id = response.params["id"]
    @card_order_options[:headers].merge!({ "PayPal-Mock-Response": "{\"mock_application_codes\": \"MISSING_REQUIRED_PARAMETER\"}"})
    response = @gateway.authorize(order_id, @card_order_options)

    server_side_failure_assertions(response,
                                   "INVALID_REQUEST",
                                   nil,
                                   "The request is not well-formed, is syntactically incorrect, or violates schema."
    )
  end

  def test_partial_refund_not_allowed
    response        = create_order("CAPTURE")
    order_id        = response.params["id"]
    response        = @gateway.capture(order_id, @card_order_options)
    capture_id      = response.params["purchase_units"][0]["payments"]["captures"][0]["id"]
    options[:headers].merge!("PayPal-Mock-Response": "{\"mock_application_codes\": \"PARTIAL_REFUND_NOT_ALLOWED\"}")
    response        = @gateway.refund(capture_id, options)

    server_side_failure_assertions(response,
                                   "UNPROCESSABLE_ENTITY",
                                   "PARTIAL_REFUND_NOT_ALLOWED",
                                   "The requested action could not be completed, was semantically incorrect, or failed business validation."
    )
  end

  def test_transaction_refused_for_void_authorized
    response         = create_order("AUTHORIZE")
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    options[:headers].merge!("PayPal-Mock-Response": "{\"mock_application_codes\": \"PREVIOUSLY_VOIDED\"}")
    response    = @gateway.void(authorization_id, options)

    server_side_failure_assertions(response,
                                   "UNPROCESSABLE_ENTITY",
                                   "PREVIOUSLY_VOIDED",
                                   "The requested action could not be performed, semantically incorrect, or failed business validation."
    )
  end

  def test_capture_authorized_order_with_card
    response         = create_order("AUTHORIZE")
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    response         = @gateway.do_capture(authorization_id,options)
    success_status_assertions(response, "COMPLETED")
  end

  def test_refund_captured_order_with_card
    response        = create_order("CAPTURE")
    order_id        = response.params["id"]
    response        = @gateway.capture(order_id, @card_order_options)
    capture_id      = response.params["purchase_units"][0]["payments"]["captures"][0]["id"]
    refund_response = @gateway.refund(capture_id, options)
    success_status_assertions(refund_response, "COMPLETED")
  end

  def test_void_authorized_order_with_card
    response         = create_order("AUTHORIZE")
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, @card_order_options)
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    void_response    = @gateway.void(authorization_id, options)
    success_empty_assertions(void_response)
  end

  def test_update_shipping_amount_order
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_amount_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_replace_shipping_address_order
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_shipping_address_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_add_shipping_address_order
    @body[:purchase_units][0].delete(:shipping)
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_shipping_address_body}
    @body[:body][0].update( op: "add" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_platform_fee_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_platform_fee_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_replace_soft_descriptor_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_soft_descriptor_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_remove_soft_descriptor_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_soft_descriptor_body}
    @body[:body][0].update( op: "remove" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_replace_invoice_id_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_invoice_id_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_remove_and_add_invoice_id_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_invoice_id_body}
    @body[:body][0].update( op: "remove" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body[:body][0].update( op: "add" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_intent_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_intent_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_replace_shipping_name_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_shipping_name_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_add_shipping_name_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_shipping_name_body}
    @body[:body][0].update( op: "add" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_replace_description_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_description_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_remove_and_add_description_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_description_body}
    @body[:body][0].update( op: "remove" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body[:body][0].update( op: "add" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_replace_update_custom_id_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_custom_id_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_remove_and_add_update_custom_id_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_custom_id_body}
    @body[:body][0].update( op: "remove" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body[:body][0].update( op: "add" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_replace_payee_email_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_payee_email_body}
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_replace_update_purchase_unit_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = { body: update_purchase_unit_body }
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_update_add_purchase_unit_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_purchase_unit_body}
    @body[:body][0].update( op: "add" )
    response = @gateway.update_order(order_id, options)
    success_empty_assertions(response)
    @body = body
  end

  def test_create_billing_agreement_token
    @body    = billing_agreement_body
    response = @gateway.create_billing_agreement_token(options)
    assert_success response
    assert !response.params["token_id"].nil?
    assert !response.params["links"].nil?
    @body = body
  end

  def test_create_billing_agreement
    @body    = { "token_id": @approved_billing_token }
    response = @gateway.create_agreement_for_approval(options)
    assert_success response
    assert_equal "ACTIVE", response.params["state"]
    assert !response.params["id"].nil?
    assert !response.params["links"].nil?
  end

  def test_capture_order_with_billing
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_agreement_for_approval(options)
    billing_id = response.params["id"]
    @body      = body
    response   = create_order("CAPTURE")
    order_id   = response.params["id"]
    response   = @gateway.capture(order_id, billing_options(billing_id))
    success_status_assertions(response, "COMPLETED")
  end

  def test_authorize_order_with_billing
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_agreement_for_approval(options)
    billing_id = response.params["id"]
    @body      = body
    @intent    = "AUTHORIZE"
    response   = create_order("AUTHORIZE")
    order_id   = response.params["id"]
    response   = @gateway.authorize(order_id, billing_options(billing_id))
    success_status_assertions(response, "COMPLETED")
  end

  def test_capture_authorized_order_with_billing
    @body            = { "token_id": @approved_billing_token }
    response         = @gateway.create_agreement_for_approval(options)
    billing_id       = response.params["id"]
    @body            = body
    response         = create_order("AUTHORIZE")
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, billing_options(billing_id))
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    response         = @gateway.do_capture(authorization_id, billing_options(billing_id))
    success_status_assertions(response, "COMPLETED")
  end

  def test_void_authorized_order_with_billing
    @body            = { "token_id": @approved_billing_token }
    response         = @gateway.create_agreement_for_approval(options)
    billing_id       = response.params["id"]
    @body            = body
    response         = create_order("AUTHORIZE")
    order_id         = response.params["id"]
    response         = @gateway.authorize(order_id, billing_options(billing_id))
    authorization_id = response.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    response         = @gateway.void(authorization_id, options)
    success_empty_assertions(response)
  end

  def test_refund_captured_order_with_billing
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_agreement_for_approval(options)
    billing_id = response.params["id"]
    @body      = body
    response   = create_order("CAPTURE")
    order_id   = response.params["id"]
    response   = @gateway.capture(order_id, billing_options(billing_id))
    capture_id = response.params["purchase_units"][0]["payments"]["captures"][0]["id"]
    response   = @gateway.refund(capture_id, options)
    success_status_assertions(response, "COMPLETED")
  end

  def test_update_billing_description_and_merchant_custom
    @body      = { "token_id": @approved_billing_token }
    response   = @gateway.create_agreement_for_approval(options)
    billing_id = response.params["id"]
    @body      = { "body": billing_update_body }
    response   = @gateway.update_billing_agreement(billing_id, options)
    success_empty_assertions(response)
  end

  def test_missing_password_argument_to_get_access_token
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: password"
      @gateway.get_access_token(@get_token_missing_password_options)
    end
  end

  def test_missing_username_argument_to_get_access_token
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: username"
      @gateway.get_access_token(@get_token_missing_username_options)
    end
  end

  def test_missing_intent_argument_for_order_creation
    @body.delete(
        :intent
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: intent"
      @gateway.create_order(nil, options)
    end
  end

  def test_missing_purchase_units_argument_for_order_creation
    @body.delete(
        :purchase_units
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: purchase_units"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_amount_in_purchase_units_argument
    @body[:purchase_units][0].delete(
        :amount
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: amount in purchase_units"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_currency_code_in_amount_argument
    @body[:purchase_units][0][:amount].delete(
        :currency_code
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: currency_code in amount"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_value_in_amount_argument
    @body[:purchase_units][0][:amount].delete(
        :value
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: value in amount"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_name_in_items
    @body[:purchase_units][0][:items][0].delete(
        :name
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: name in items"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_quantity_in_items
    @body[:purchase_units][0][:items][0].delete(
        :quantity
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: quantity in items"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_unit_amount_in_items
    @body[:purchase_units][0][:items][0].delete(
        :name
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: unit_amount in items"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_admin_area_2_in_address
    @body[:purchase_units][0][:shipping][:address].delete(
        :admin_area_2
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: admin_area_2 in address"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_postal_code_in_address
    @body[:purchase_units][0][:shipping][:address].delete(
        :postal_code
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: postal code in address"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_country_code_in_address
    @body[:purchase_units][0][:shipping][:address].delete(
        :country_code
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: country code in address"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_amount_in_platform_fee
    @body[:purchase_units][0].update(
        @additional_params
    )

    @body[:purchase_units][0][:payment_instruction][:platform_fees][0].delete(
        :amount
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: amount in platform fee"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_payee_in_platform_fee
    @body[:purchase_units][0].update(
        @additional_params
    )

    @body[:purchase_units][0][:payment_instruction][:platform_fees][0].delete(
        :payee
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: payee in platform fee"
      @gateway.create_order("CAPTURE", options)
    end
  end

  def test_missing_operator_arguments_in_handle_approve
    response  = create_order("AUTHORIZE")
    order_id  = response.params["id"]

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: operator"
      @gateway.handle_approve(order_id, options)
    end
  end

  def test_missing_operator_required_id_arguments_in_handle_approve
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: operator_required_id"
      @gateway.handle_approve(nil, options)
    end
  end

  def test_missing_order_id_in_update_body
    assert_raise(ArgumentError) do

      puts "*** ArgumentError Exception: Missing required parameter: order_id in update_order"
      @body    = {body: update_amount_body}
      @gateway.update_order(nil, options)
    end
  end

  def test_missing_body_in_update_body
    assert_raise(ArgumentError) do
      response = create_order("CAPTURE")
      order_id = response.params["id"]
      puts "*** ArgumentError Exception: Missing required parameter: body in update_order"
      @body    = {}
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_op_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_amount_body}
    @body[:body][0].delete(
        :op
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: op in update field"
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_path_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_amount_body}
    @body[:body][0].delete(
        :path
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: op in update field"
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_value_in_update_body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    @body    = {body: update_amount_body}
    @body[:body][0].delete(
        :value
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: op in update field"
      @gateway.update_order(order_id, options)
    end
  end

  def test_missing_payer_in_create_billing_agreement
    @body = billing_agreement_body
    @body.delete(
        :payer
    )
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: payer in create_billing"
      @gateway.create_billing_agreement_token(options)
    end
    @body = body
  end

  def test_missing_plan_in_create_billing_agreement
    @body = billing_agreement_body
    @body.delete(
        :plan
    )
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: plan in create_billing"
      @gateway.create_billing_agreement_token(options)
    end
    @body = body
  end

  def test_missing_line1_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(
        :line1
    )
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: line1 in shipping_address"
      @gateway.create_billing_agreement_token(options)
    end
    @body = body
  end

  def test_missing_postal_code_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(
        :postal_code
    )
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: postal_code in shipping_address"
      @gateway.create_billing_agreement_token(options)
    end
    @body = body
  end

  def test_missing_country_code_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(
        :country_code
    )
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: country_code in shipping_address"
      @gateway.create_billing_agreement_token(options)
    end
    @body = body
  end

  def test_missing_city_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(
        :city
    )
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: city in shipping_address"
      @gateway.create_billing_agreement_token(options)
    end
    @body = body
  end

  def test_missing_state_in_create_billing_agreement
    @body = billing_agreement_body
    @body[:shipping_address].delete(
        :state
    )
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: state in shipping_address"
      @gateway.create_billing_agreement_token(options)
    end
    @body = body
  end

  def test_missing_token_id_in_create_billing_agreement_approval
    @body = { }
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: token_id in create_billing_agreement_approval"
      @gateway.create_agreement_for_approval(options)
    end
    @body = body
  end

  def test_missing_id_in_billing_token
    @body = { "token_id": @approved_billing_token }
    response = @gateway.create_agreement_for_approval(options)
    billing_id = response.params["id"]
    @body = body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: id in billing_token"
      billing_body = billing_options(billing_id)
      billing_body[:payment_source][:token].delete(:id)
      @gateway.capture(order_id, billing_body)
    end
    @body = body
  end

  def test_missing_type_in_billing_token
    @body = { "token_id": @approved_billing_token }
    response = @gateway.create_agreement_for_approval(options)
    billing_id = response.params["id"]
    @body = body
    response = create_order("CAPTURE")
    order_id = response.params["id"]
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: id in billing_token"
      billing_body = billing_options(billing_id)
      billing_body[:payment_source][:token].delete(:type)
      @gateway.capture(order_id, billing_body)
    end
    @body = body
  end
  def test_transcript_scrubbing
    @three_ds_credit_card = credit_card('4000000000003220',
                                        verification_value: '737',
                                        month: 10,
                                        year: 2020
    )

    response = create_order("CAPTURE")
    order_id = response.params["id"]

    transcript = capture_transcript(@gateway) do
      @gateway.capture(order_id, @card_order_options)
    end

    transcript = @gateway.scrub(transcript)
    assert_scrubbed(@three_ds_credit_card.number, transcript)
    assert_scrubbed(@three_ds_credit_card.verification_value, transcript)
  end

  private

  def create_order(order_type, type="DIRECT")
    if type.eql?("PPCP")
      @body[:purchase_units].each.with_index do |value, index|
        @body[:purchase_units][index].update(
            @additional_params
        )
      end
    else
      @body[:purchase_units].each.with_index do |value, index|
        @body[:purchase_units][index].delete(:payment_instructions)
      end
    end

    @gateway.create_order(order_type, options)
  end

  def options
    { headers: @headers }.merge(@body)
  end

  def body
    @reference_id = "camera_shop_seller_#{ DateTime.now }"

    {
        "description": "PPCP",
        "intent": @intent || "CAPTURE",
        "purchase_units": [
            {
              "reference_id": @reference_id,
              "description": "Camera Shop",
              "amount": {
                "currency_code": "USD",
                "value": "25.00",
                "breakdown": {
                "item_total": {
                    "currency_code": "USD",
                    "value": "25.00"
                },
                "shipping": {
                    "currency_code": "USD",
                    "value": "0"
                },
                "handling": {
                    "currency_code": "USD",
                    "value": "0"
                },
                "tax_total": {
                    "currency_code": "USD",
                    "value": "0"
                },
                "gift_wrap": {
                    "currency_code": "USD",
                    "value": "0"
                },
                "shipping_discount": {
                    "currency_code": "USD",
                    "value": "0"
                }
            }
        },
        "payee": {
            "email_address": "sb-jnxjj3033194@business.example.com"
        },
        "items": [
            {
                "name": "Levis 501 Selvedge STF",
                "sku": "5158936",
                "unit_amount": {
                    "currency_code": "USD",
                    "value": "25.00"
                },
                "tax": {
                    "currency_code": "USD",
                    "value": "0.00"
                },
                "quantity": "1",
                "category": "PHYSICAL_GOODS"
            }
        ],
        "shipping": {
            "address": {
                "address_line_1": "500 Hillside Street",
                "address_line_2": "#1000",
                "admin_area_1": "CA",
                "admin_area_2": "San Jose",
                "postal_code": "95131",
                "country_code": "US"
            }
        },
        "shipping_method": "United Postal Service",
        "payment_group_id": 1,
        "custom_id": "custom_value_#{ DateTime.now }",
        "invoice_id": "invoice_number_#{ DateTime.now }",
        "soft_descriptor": "Payment Camera Shop"
    }
    ],
        "payer": payer_hash,
        "application_context": application_context
    }
  end

  def update_amount_body
    [
        {
            "op": "replace",
            "path": "/purchase_units/@reference_id=='#{ @reference_id }'/amount",
            "value": {
                "currency_code": "USD",
                "value": "27.00",
                "breakdown": {
                    "item_total": {
                        "currency_code": "USD",
                        "value": "25.00"
                    },
                    "shipping": {
                        "currency_code": "USD",
                        "value": "2.00"
                    }
                }
            }
        }
    ]
  end

  def update_shipping_address_body
    [
        {
            "op": "replace",
            "path": "/purchase_units/@reference_id=='#{ @reference_id }'/shipping/address",
            "value": {
                "address_line_1": "123 Townsend St",
                "address_line_2": "Floor 6",
                "admin_area_2": "San Francisco",
                "admin_area_1": "CA",
                "postal_code": "94107",
                "country_code": "US"
            }
        }
    ]
  end

  def update_intent_body
    [
        {
            path: "/intent",
            value: "CAPTURE",
            op:    "replace"
        }
    ]
  end

  def update_platform_fee_body
    [ {
          "op": "add",
          "path": "/purchase_units/@reference_id=='#{ @reference_id }'/payment_instruction",
          "value": {
              "platform_fees": [
                  {
                      "amount": {
                          "currency_code": "USD",
                          "value": "3.00"
                      },
                      "payee": {
                          "email_address": "service.connected@partnerplace.example.com"
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
            value: "INVOICE_ID_123",
            op:    "replace"
        }
    ]
  end

  def update_custom_id_body
    [
        {
         path: "/purchase_units/@reference_id=='#{@reference_id}'/custom_id",
         value: "CUSTOM_ID_123",
         op:    "replace"
        }
    ]
  end

  def update_payee_email_body
    [
        {
            path: "/purchase_units/@reference_id=='#{@reference_id}'/payee/email_address",
            value: "test@test.com",
            op:    "replace"
        }
    ]
  end

  def update_shipping_name_body
    [
        {
            path: "/purchase_units/@reference_id=='#{@reference_id}'/shipping/name",
            value: {
                :full_name => "TEST SHIPPING"
            },
            op:    "replace"
        }
    ]
  end

  def update_description_body
    [{
         path: "/purchase_units/@reference_id=='#{@reference_id}'/description",
         value: "UPDATED DESCRIPTION",
         op:    "replace"
     }]
  end

  def update_soft_descriptor_body
    [
        {
            path: "/purchase_units/@reference_id=='#{@reference_id}'/soft_descriptor",
            value: "Description Changed.",
            op:    "replace"
        }
    ]
  end

  def update_purchase_unit_body
    [
        {
            "path": "/purchase_units/@reference_id=='#{@reference_id}'",
            "op":   "replace",
            "value": {
                "reference_id": "camera_shop_seller_{{$timestamp}}",
                "description": "Camera Shop CHANGED",
                "amount": {
                    "currency_code": "USD",
                    "value": "25.00",
                    "breakdown": {
                        "item_total": {
                            "currency_code": "USD",
                            "value": "25.00"
                        },
                        "shipping": {
                            "currency_code": "USD",
                            "value": "0"
                        },
                        "handling": {
                            "currency_code": "USD",
                            "value": "0"
                        },
                        "tax_total": {
                            "currency_code": "USD",
                            "value": "0"
                        },
                        "gift_wrap": {
                            "currency_code": "USD",
                            "value": "0"
                        },
                        "shipping_discount": {
                            "currency_code": "USD",
                            "value": "0"
                        }
                    }
                },
                "payee": {
                    "email_address": "sb-jnxjj3033194@business.example.com"
                },
                "items": [
                    {
                        "name": "Levis 501 Selvedge STF",
                        "sku": "5158936",
                        "unit_amount": {
                            "currency_code": "USD",
                            "value": "25.00"
                        },
                        "tax": {
                            "currency_code": "USD",
                            "value": "0.00"
                        },
                        "quantity": "1",
                        "category": "PHYSICAL_GOODS"
                    }
                ],
                "shipping": {
                    "address": {
                        "address_line_1": "500 Hillside Street",
                        "address_line_2": "#1000",
                        "admin_area_1": "CA",
                        "admin_area_2": "San Jose",
                        "postal_code": "95131",
                        "country_code": "US"
                    }
                },
                "shipping_method": "United Postal Service",
                "payment_instruction": {
                    "platform_fees": [
                        {
                            "amount": {
                                "currency_code": "USD",
                                "value": "2.00"
                            },
                            "payee": {
                                "email_address": "sb-jnxjj3033194@business.example.com"
                            }
                        }
                    ]
                },
                "payment_group_id": 1,
                "custom_id": "custom_value_{{$timestamp}}",
                "invoice_id": "invoice_number_{{$timestamp}}",
                "soft_descriptor": "Payment Camera Shop"
            }
        }
    ]
  end

  def billing_agreement_body
    {
        "description": "Billing Agreement",
        "shipping_address":
            {
                "line1": "1350 North First Street",
                "city": "San Jose",
                "state": "CA",
                "postal_code": "95112",
                "country_code": "US",
                "recipient_name": "John Doe"
            },
        "payer":
            {
                "payment_method": "PAYPAL"
            },
        "plan":
            {
                "type": "MERCHANT_INITIATED_BILLING",
                "merchant_preferences":
                    {
                        "return_url": "https://google.com",
                        "cancel_url": "https://google.com",
                        "accepted_pymt_type": "INSTANT",
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
                "type": "BILLING_AGREEMENT"
            }
        },
        application_context: application_context,
        "headers": @headers
    }
  end

  def billing_update_body
    [
        {
            "op": "replace",
            "path": "/",
            "value": {
                "description": "Updated Billing Agreement",
                "merchant_custom_data": "INV-003"
            }
        },
        {
            "op": "replace",
            "path": "/plan/merchant_preferences/",
            "value": {
                    "notify_url": "https://example.com/notification"
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
        username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXM==",
        password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM3=="
    }
  end

  # Assertions private methods

  def success_status_assertions(response, status)
    assert_success response
    assert_equal status, response.params["status"]
    assert !response.params["id"].nil?
    assert !response.params["links"].nil?
  end

  def server_side_failure_assertions(response, name, issue_msg, message)
    assert !response.params["name"].nil?
    assert response.params["name"] == name
    assert response.params["details"][0]["issue"] == issue_msg unless issue_msg.nil?
    assert response.params["message"] == message
  end

  def success_empty_assertions(response)
    assert_success response
    assert_empty   response.params
  end

  def payer_hash
    # Regex for national_number: ^[0-9]{1,14}?$.
    { name: name, email_address: "sb-feqsa3029697@personal.example.com", payer_id: "QYR5Z8XDVJNXQ", phone: phone, birth_date: "1990-08-31", tax_info: tax_info, address: address }
  end
  def address
    { address_line_1: "2211 N First Street", address_line_2: "Building 17", admin_area_2: "21 N First Street", admin_area_1: "2211 N First Street", postal_code: "95131", country_code: "US" }
  end
  def tax_info
    ## Tax ID Type = Possible values: BR_CPF, BR_CNPJ
    { tax_id: "000000000", tax_id_type: "BR_CPF" }
  end
  def phone
    { phone_type: "FAX", phone_number: { national_number: "(123) 456-7890" } }
  end
  def name
    { given_name: "Ali Hassan", surname: "Mirza" }
  end
  def application_context
    # The possible values are:
    #                         GET_FROM_FILE. Use the customer-provided shipping address on the PayPal site.
    #     NO_SHIPPING. Redact the shipping address from the PayPal site. Recommended for digital goods.
    #     SET_PROVIDED_ADDRESS. Use the merchant-provided address. The customer cannot change this address on the PayPal site.
    #     Default: GET_FROM_FILE.

    { return_url: "https://paypal.com",cancel_url: "https://paypal.com", landing_page: "LOGIN", locale: "en", user_action: "PAY_NOW",
      brand_name: "PPCP", shipping_preference: "NO_SHIPPING", payment_method: payment_method, stored_payment_source: stored_payment_source  }
  end
  def payment_method
    { payer_selected: "PAYPAL", payee_preferred: "UNRESTRICTED", standard_entry_class_code: "WEB" }
  end
  def stored_payment_source
    { payment_initiator: "MERCHANT", payment_type: "ONE_TIME", usage: "FIRST", previous_network_transaction_reference: previous_network_transaction_reference }
  end
  def previous_network_transaction_reference
    { id: "1111111111", date: "2020-10-01T21:20:49Z", network: "MASTERCARD" }
  end
  def purchase_units
    {
        "purchase_units": [
          {
          "reference_id": @reference_id,
          "description": "Camera Shop",
          "amount": {
              "currency_code": "USD",
              "value": "25.00",
              "breakdown": {
                  "item_total": {
                      "currency_code": "USD",
                      "value": "25.00"
                  },
                  "shipping": {
                      "currency_code": "USD",
                      "value": "0"
                  },
                  "handling": {
                      "currency_code": "USD",
                      "value": "0"
                  },
                  "tax_total": {
                      "currency_code": "USD",
                      "value": "0"
                  },
                  "gift_wrap": {
                      "currency_code": "USD",
                      "value": "0"
                  },
                  "shipping_discount": {
                      "currency_code": "USD",
                      "value": "0"
                  }
              }
          },
          "payee": {
              "email_address": "sb-jnxjj3033194@business.example.com"
          },
          "items": [
              {
                  "name": "Levis 501 Selvedge STF",
                  "sku": "5158936",
                  "unit_amount": {
                      "currency_code": "USD",
                      "value": "25.00"
                  },
                  "tax": {
                      "currency_code": "USD",
                      "value": "0.00"
                  },
                  "quantity": "1",
                  "category": "PHYSICAL_GOODS"
              }
          ],
          "shipping": {
              "address": {
                  "address_line_1": "500 Hillside Street",
                  "address_line_2": "#1000",
                  "admin_area_1": "CA",
                  "admin_area_2": "San Jose",
                  "postal_code": "95131",
                  "country_code": "US"
              }
          },
          "shipping_method": "United Postal Service",
          "payment_group_id": 1,
          "custom_id": "custom_value_#{ DateTime.now }",
          "invoice_id": "invoice_number_#{ DateTime.now }",
          "soft_descriptor": "Payment Camera Shop"
        }
      ]
    }
  end
end
