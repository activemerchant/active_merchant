require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode         = :test
    @paypal_customer  = ActiveMerchant::Billing::PaypalCommercePlateformCustomerGateway.new

    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
               password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }

    options       = { "Content-Type": "application/json", authorization: params }
    access_token  = @paypal_customer.get_token(options)
    @headers      = { "Authorization": access_token, "Content-Type": "application/json" }

    @body = {
        "purchase_units": [
            {
                "reference_id": "camera_shop_seller_#{ DateTime.now }",
                "amount": {
                    "currency_code": "USD",
                    "value": "56.00"
                },
              "payee": {
                  "email_address": "sb-jnxjj3033194@business.example.com"
              }
            }
        ]
    }

    @authorize_additional_params =  {
                                      payment_instruction: {
                                      "disbursement_mode": "INSTANT",
                                      "platform_fees": [
                                        {
                                            "amount": {
                                                "currency_code": "USD",
                                                "value": "2.00"
                                            },
                                            "payee": {
                                                "email_address": "sb-feqsa3029697@personal.example.com"
                                            }
                                        }
                                        ]
                                      }
                                    }
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

  def test_create_capture_delayed_order_direct_merchant
    response = create_order("CAPTURE", mode = "DELAYED")
    puts "Capture Order Id (Delayed) - Direct Merchant: #{ response[:id] }"
    assert response[:status].eql?("CREATED")
    assert !response[:id].nil?
    assert !response[:links].blank?
  end

  def test_create_capture_delayed_order_ppcp
    response = create_order("CAPTURE", "PPCP", "DELAYED")
    puts "Capture Order Id (Delayed) - PPCP: #{ response[:id] }"
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

  def test_missing_password_argument_to_get_access_token
    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q" }
    options = { "Content-Type": "application/json", authorization: params }

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: password"
      @paypal_customer.get_token(options)
    end
  end

  def test_missing_username_argument_to_get_access_token
    params = { password: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q" }
    options = { "Content-Type": "application/json", authorization: params }

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: username"
      @paypal_customer.get_token(options)
    end
  end

  def test_missing_intent_argument_for_order_creation
    @body.delete(
        :intent
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: intent"
      @paypal_customer.create_order(options)
    end
  end

  def test_missing_purchase_units_argument_for_order_creation
    @body.delete(
        :purchase_units
    )

    assert_raise(ArgumentError) do
      puts "*** ArgumentError Exception: Missing required parameter: purchase_units"
      @paypal_customer.create_order(options)
    end
  end

  def test_missing_operator_arguments_in_handle_approve
    response = create_order("AUTHORIZE")
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

  private
  def create_order(order_type, type="DIRECT", mode="INSTANT")
    @body.update(
        intent: order_type
    )

    if type.eql?("PPCP")
      @body.update(
          "payment_instruction": {
              "disbursement_mode": mode,
              "platform_fees": [
                  {
                      "amount": {
                          "currency_code": "USD",
                          "value": "10.00"
                      },
                      "payee": {
                          "email_address": "sb-jnxjj3033194@business.example.com"
                      }
                  }
              ]
          }
      )
    else
      @body.delete("payment_instruction")
    end

    @paypal_customer.create_order(options)
  end

  def options
    { headers: @headers, body: @body }
  end
end
