require "test_helper"
require "byebug"

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode         = :test
    @paypal_customer  = ActiveMerchant::Billing::PaypalCommercePlatformGateway.new

    params                  = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
                                password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }
    options                 = { "Content-Type": "application/json", authorization: params }
    access_token            = @paypal_customer.get_token(options)
    missing_password_params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q" }
    missing_username_params = { password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }

    @headers      = { "Authorization": access_token, "Content-Type": "application/json" }

    @body = body

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

    @card = {
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

    @card_order_options = {
        "payment_source": {
            "card": @card
        },
        "headers": @headers
    }

    @get_token_missing_password_options = { "Content-Type": "application/json", authorization: missing_password_params }

    @get_token_missing_username_options = { "Content-Type": "application/json", authorization: missing_username_params }

  end


  def test_create_capture_instant_order_direct_merchant
    response = create_order("CAPTURE")
    puts "Capture Order Id (Instant) - Direct Merchant: #{ response[:id] }"
    assert response[:status].eql?("CREATED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end


  def test_create_capture_instant_order_ppcp
    response = create_order("CAPTURE", "PPCP")
    puts "Capture Order Id (Instant) - PPCP: #{ response[:id] }"
    assert response[:status].eql?("CREATED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end


  def test_create_authorize_order
    response = create_order("AUTHORIZE")
    puts "Authorize Order Id: #{ response[:id] }"
    assert response[:status].eql?("CREATED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end


  def test_capture_order_with_card
    response = create_order("CAPTURE")
    order_id = response[:id]
    response = @paypal_customer.capture(order_id, @card_order_options)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end


  def test_authorize_order_with_card
    response = create_order("AUTHORIZE")
    order_id = response[:id]
    response = @paypal_customer.authorize(order_id, @card_order_options)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end


  def test_capture_authorized_order_with_card
    response         = create_order("AUTHORIZE")
    order_id         = response[:id]
    response         = @paypal_customer.authorize(order_id, @card_order_options)
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    response         = @paypal_customer.do_capture(authorization_id,options)
    assert response[:status].eql?("COMPLETED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end


  def test_refund_captured_order_with_card
    response        = create_order("CAPTURE")
    order_id        = response[:id]
    response        = @paypal_customer.capture(order_id, @card_order_options)
    capture_id      = response[:purchase_units][0][:payments][:captures][0][:id]
    refund_response = @paypal_customer.refund(capture_id, options)
    assert refund_response[:status].eql?("COMPLETED")
    assert !refund_response[:id].nil?
    assert !refund_response[:links].blank?
  end


  def test_void_authorized_order_with_card
    response         = create_order("AUTHORIZE")
    order_id         = response[:id]
    response         = @paypal_customer.authorize(order_id, @card_order_options)
    authorization_id = response[:purchase_units][0][:payments][:authorizations][0][:id]
    void_response    = @paypal_customer.void(authorization_id, options)
    assert void_response.empty?
  end


  def test_update_shipping_amount_order
    response = create_order("CAPTURE")
    order_id = response[:id]
    @body    = {body: update_amount_body}
    response = @paypal_customer.update_order(order_id, options)
    assert response.empty?
    @body = body
  end


  def test_update_shipping_address_order
    response = create_order("CAPTURE")
    order_id = response[:id]
    @body    = {body: update_shipping_address_body}
    response = @paypal_customer.update_order(order_id, options)
    assert response.empty?
    @body = body
  end


  def test_missing_password_argument_to_get_access_token
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: password"
      @paypal_customer.get_token(@get_token_missing_password_options)
    end
  end


  def test_missing_username_argument_to_get_access_token
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: username"
      @paypal_customer.get_token(@get_token_missing_username_options)
    end
  end


  def test_missing_intent_argument_for_order_creation
    @body.delete(
        :intent
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: intent"
      @paypal_customer.create_order(nil, options)
    end
  end


  def test_mismissing_intent_argument_for_order_creation
    @body[:intent] = "CAPTU"

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Intent is mismatched please check your intent: #{ @body[:intent] }"
      @paypal_customer.create_order("CAPTU", options)
    end
  end


  def test_missing_purchase_units_argument_for_order_creation
    @body.delete(
        :purchase_units
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: purchase_units"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_amount_in_purchase_units_argument_for_order_creation
    @body[:purchase_units][0].delete(
        :amount
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: amount in purchase_units"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_currency_code_in_amount_argument_for_order_creation
    @body[:purchase_units][0][:amount].delete(
        :currency_code
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: currency_code in amount"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_value_in_amount_argument_for_order_creation
    @body[:purchase_units][0][:amount].delete(
        :value
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: value in amount"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_name_in_items
    @body[:purchase_units][0][:items][0].delete(
        :name
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: name in items"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_quantity_in_items
    @body[:purchase_units][0][:items][0].delete(
        :quantity
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: quantity in items"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_unit_amount_in_items
    @body[:purchase_units][0][:items][0].delete(
        :name
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: unit_amount in items"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_admin_area_2_in_address
    @body[:purchase_units][0][:shipping][:address].delete(
        :admin_area_2
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: admin_area_2 in address"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_postal_code_in_address
    @body[:purchase_units][0][:shipping][:address].delete(
        :postal_code
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: postal code in address"
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_country_code_in_address
    @body[:purchase_units][0][:shipping][:address].delete(
        :country_code
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: country code in address"
      @paypal_customer.create_order("CAPTURE", options)
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
      @paypal_customer.create_order("CAPTURE", options)
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
      @paypal_customer.create_order("CAPTURE", options)
    end
  end


  def test_missing_operator_arguments_in_handle_approve
    response  = create_order("AUTHORIZE")
    @order_id = response[:id]

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: operator"
      @paypal_customer.handle_approve(@order_id, options)
    end
  end


  def test_missing_operator_required_id_arguments_in_handle_approve
    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: operator_required_id"
      @paypal_customer.handle_approve(nil, options)
    end
  end


  def test_missing_order_id_in_update_body
    assert_raise(ArgumentError) do

      puts "*** ArgumentError Exception: Missing required parameter: order_id in update_order"
      @body    = {body: update_amount_body}
      @paypal_customer.update_order(nil, options)
    end
  end


  def test_missing_body_in_update_body
    assert_raise(ArgumentError) do
      response = create_order("CAPTURE")
      order_id = response[:id]
      puts "*** ArgumentError Exception: Missing required parameter: body in update_order"
      @body    = {}
      @paypal_customer.update_order(order_id, options)
    end
  end


  def test_missing_op_in_update_body
    response = create_order("CAPTURE")
    order_id = response[:id]
    @body    = {body: update_amount_body}
    @body[:body][0].delete(
        :op
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: op in update field"
      @paypal_customer.update_order(order_id, options)
    end
  end


  def test_missing_path_in_update_body
    response = create_order("CAPTURE")
    order_id = response[:id]
    @body    = {body: update_amount_body}
    @body[:body][0].delete(
        :path
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: op in update field"
      @paypal_customer.update_order(order_id, options)
    end
  end


  def test_missing_value_in_update_body
    response = create_order("CAPTURE")
    order_id = response[:id]
    @body    = {body: update_amount_body}
    @body[:body][0].delete(
        :value
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: op in update field"
      @paypal_customer.update_order(order_id, options)
    end
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

    @paypal_customer.create_order(order_type, options)
  end


  def options
    { headers: @headers }.merge(@body)
  end


  def body
    @reference_id = "camera_shop_seller_#{ DateTime.now }"

    {
        "intent": "CAPTURE",
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
        "application_context": {
            "return_url": "https://www.google.com/",
            "cancel_url": "https://www.google.com/"
        }
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


end
