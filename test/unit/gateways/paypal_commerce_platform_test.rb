require 'test_helper'

class PaypalCommercePlatformTest < Test::Unit::TestCase
  include CommStub

  def setup

    @paypal_customer        = ActiveMerchant::Billing::PaypalCommercePlatformGateway.new

    params                  = user_credentials

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

  def test_successful_create_and_confirm_intent
    @paypal_customer.expects(:ssl_request).times(1).returns(successful_create_intent_response)

    assert create = @paypal_customer.create_order("CAPTURE", options)
    assert_equal "Success", create[:message]

  end

  private

  def successful_create_intent_response
    <<-RESPONSE
    {
        "id": "9BT77635MT4641640",
        "intent": "CAPTURE",
        "status": "CREATED",
        "purchase_units": [
            {
                "reference_id": "camera_shop_seller_1600688584",
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
                            "value": "0.00"
                        },
                        "handling": {
                            "currency_code": "USD",
                            "value": "0.00"
                        },
                        "tax_total": {
                            "currency_code": "USD",
                            "value": "0.00"
                        },
                        "shipping_discount": {
                            "currency_code": "USD",
                            "value": "0.00"
                        }
                    }
                },
                "payee": {
                    "merchant_id": "3WK2L2WM58FGJ"
                },
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
                "description": "Camera Shop",
                "custom_id": "custom_value_1600688584",
                "invoice_id": "invoice_number_1600688584",
                "soft_descriptor": "Payment Camera Shop",
                "items": [
                    {
                        "name": "Levis 501 Selvedge STF",
                        "unit_amount": {
                            "currency_code": "USD",
                            "value": "25.00"
                        },
                        "tax": {
                            "currency_code": "USD",
                            "value": "0.00"
                        },
                        "quantity": "1",
                        "sku": "5158936",
                        "category": "PHYSICAL_GOODS"
                    }
                ],
                "shipping": {
                    "address": {
                        "address_line_1": "500 Hillside Street",
                        "address_line_2": "#1000",
                        "admin_area_2": "San Jose",
                        "admin_area_1": "CA",
                        "postal_code": "95131",
                        "country_code": "US"
                    }
                }
            }
        ],
        "create_time": "2020-09-21T11:43:18Z",
        "links": [
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/9BT77635MT4641640",
                "rel": "self",
                "method": "GET"
            },
            {
                "href": "https://www.sandbox.paypal.com/checkoutnow?token=9BT77635MT4641640",
                "rel": "approve",
                "method": "GET"
            },
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/9BT77635MT4641640",
                "rel": "update",
                "method": "PATCH"
            },
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/9BT77635MT4641640/capture",
                "rel": "capture",
                "method": "POST"
            }
        ]
    }
    RESPONSE
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

  def user_credentials
    {
        username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
        password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_"
    }
  end

  def options
    { headers: @headers }.merge(@body)
  end


end
