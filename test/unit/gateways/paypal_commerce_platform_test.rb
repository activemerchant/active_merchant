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

  def test_successful_create_capture_order
    @paypal_customer.expects(:ssl_request).times(1).returns(successful_create_capture_order_response)
    success_create_order_assertions("CAPTURE")
  end

  def test_successful_create_authorize_order
    @paypal_customer.expects(:ssl_request).times(1).returns(successful_create_authorize_order_response)
    success_create_order_assertions("AUTHORIZE")
  end

  def test_successful_create_and_capture_order
    @paypal_customer.expects(:ssl_request).times(2).returns(successful_create_capture_order_response, successful_capture_order_response)
    create          = success_create_order_assertions("CAPTURE")
    order_id        = create.params["id"]
    success_capture_assertions(order_id)
  end

  def test_successful_create_and_authorize_order
    @paypal_customer.expects(:ssl_request).times(2).returns(successful_create_authorize_order_response, successful_authorize_order_response)
    create          = success_create_order_assertions("AUTHORIZE")
    order_id        = create.params["id"]
    success_authorize_assertions(order_id)
  end

  def test_successful_create_and_capture_and_refund_order
    @paypal_customer.expects(:ssl_request).times(3).returns(successful_create_capture_order_response, successful_capture_order_response, successful_refund_order_response)
    create          = success_create_order_assertions("CAPTURE")
    order_id        = create.params["id"]
    capture         = success_capture_assertions(order_id)
    capture_id      = capture.params["purchase_units"][0]["payments"]["captures"][0]["id"]
    success_refund_assertions(capture_id)
  end

  def test_successful_create_and_authorize_and_void_order
    @paypal_customer.expects(:ssl_request).times(3).returns(successful_create_authorize_order_response, successful_authorize_order_response, successful_void_order_response)
    create           = success_create_order_assertions("AUTHORIZE")
    order_id         = create.params["id"]
    authorize        = success_authorize_assertions(order_id)
    authorization_id = authorize.params["purchase_units"][0]["payments"]["authorizations"][0]["id"]
    success_void_assertions(authorization_id)
  end

  private

  def successful_create_capture_order_response
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

  def successful_create_authorize_order_response
    <<-RESPONSE
    {
        "id": "4JH59093WW6700247",
        "intent": "AUTHORIZE",
        "status": "CREATED",
        "purchase_units": [
            {
                "reference_id": "camera_shop_seller_1600759551",
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
                "description": "Camera Shop",
                "custom_id": "custom_value_1600759551",
                "invoice_id": "invoice_number_1600759551",
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
        "create_time": "2020-09-22T07:26:05Z",
        "links": [
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/4JH59093WW6700247",
                "rel": "self",
                "method": "GET"
            },
            {
                "href": "https://www.sandbox.paypal.com/checkoutnow?token=4JH59093WW6700247",
                "rel": "approve",
                "method": "GET"
            },
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/4JH59093WW6700247",
                "rel": "update",
                "method": "PATCH"
            },
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/4JH59093WW6700247/authorize",
                "rel": "authorize",
                "method": "POST"
            }
        ]
    }
    RESPONSE
  end

  def successful_capture_order_response
    <<-RESPONSE
     {
        "id": "4PB35597VW646211S",
        "intent": "CAPTURE",
        "status": "COMPLETED",
        "payment_source": {
            "card": {
                "last_digits": "4658",
                "brand": "VISA",
                "type": "CREDIT"
            }
        },
        "purchase_units": [
            {
                "reference_id": "camera_shop_seller_1600760302",
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
                        "insurance": {
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
                    "email_address": "sb-for7q2968277@personal.example.com",
                    "merchant_id": "3WK2L2WM58FGJ"
                },
                "payment_instruction": {
                    "platform_fees": [
                        {
                            "amount": {
                                "currency_code": "USD",
                                "value": "2.00"
                            }
                        }
                    ]
                },
                "description": "Camera Shop",
                "custom_id": "custom_value_1600760302",
                "invoice_id": "invoice_number_1600760302",
                "soft_descriptor": "PP*Payment Camera Shop",
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
                        "sku": "5158936"
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
                },
                "payments": {
                    "captures": [
                        {
                            "id": "99B31255NY205423M",
                            "status": "COMPLETED",
                            "amount": {
                                "currency_code": "USD",
                                "value": "25.00"
                            },
                            "final_capture": true,
                            "disbursement_mode": "INSTANT",
                            "seller_protection": {
                                "status": "NOT_ELIGIBLE"
                            },
                            "seller_receivable_breakdown": {
                                "gross_amount": {
                                    "currency_code": "USD",
                                    "value": "25.00"
                                },
                                "paypal_fee": {
                                    "currency_code": "USD",
                                    "value": "1.03"
                                },
                                "net_amount": {
                                    "currency_code": "USD",
                                    "value": "23.97"
                                }
                            },
                            "invoice_id": "invoice_number_1600760302",
                            "custom_id": "custom_value_1600760302",
                            "links": [
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/payments/captures/99B31255NY205423M",
                                    "rel": "self",
                                    "method": "GET"
                                },
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/payments/captures/99B31255NY205423M/refund",
                                    "rel": "refund",
                                    "method": "POST"
                                },
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/checkout/orders/4PB35597VW646211S",
                                    "rel": "up",
                                    "method": "GET"
                                }
                            ],
                            "create_time": "2020-09-22T07:38:47Z",
                            "update_time": "2020-09-22T07:38:47Z",
                            "processor_response": {
                                "avs_code": "A",
                                "cvv_code": "M",
                                "response_code": "0000"
                            }
                        }
                    ]
                }
            }
        ],
        "create_time": "2020-09-22T07:38:47Z",
        "update_time": "2020-09-22T07:38:47Z",
        "links": [
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/4PB35597VW646211S",
                "rel": "self",
                "method": "GET"
            }
        ]
    }
    RESPONSE
  end

  def successful_authorize_order_response
    <<-RESPONSE
    {
        "id": "0UX88842XW347023K",
        "intent": "AUTHORIZE",
        "status": "COMPLETED",
        "payment_source": {
            "card": {
                "last_digits": "4658",
                "brand": "VISA",
                "type": "CREDIT"
            }
        },
        "purchase_units": [
            {
                "reference_id": "camera_shop_seller_1600761634",
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
                        "insurance": {
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
                    "email_address": "sb-jnxjj3033194@business.example.com",
                    "merchant_id": "XC424JYN8FYUC"
                },
                "description": "Camera Shop",
                "custom_id": "custom_value_1600761634",
                "invoice_id": "invoice_number_1600761634",
                "soft_descriptor": "PP*Payment Camera Shop",
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
                        "sku": "5158936"
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
                },
                "payments": {
                    "authorizations": [
                        {
                            "status": "CREATED",
                            "id": "8SA13118FD156945S",
                            "amount": {
                                "currency_code": "USD",
                                "value": "25.00"
                            },
                            "invoice_id": "invoice_number_1600761634",
                            "custom_id": "custom_value_1600761634",
                            "seller_protection": {
                                "status": "NOT_ELIGIBLE"
                            },
                            "processor_response": {
                                "avs_code": "A",
                                "cvv_code": "M",
                                "response_code": "0000"
                            },
                            "expiration_time": "2020-10-21T08:03:10Z",
                            "links": [
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/payments/authorizations/8SA13118FD156945S",
                                    "rel": "self",
                                    "method": "GET"
                                },
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/payments/authorizations/8SA13118FD156945S/capture",
                                    "rel": "capture",
                                    "method": "POST"
                                },
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/payments/authorizations/8SA13118FD156945S/void",
                                    "rel": "void",
                                    "method": "POST"
                                },
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/payments/authorizations/8SA13118FD156945S/reauthorize",
                                    "rel": "reauthorize",
                                    "method": "POST"
                                },
                                {
                                    "href": "https://api.sandbox.paypal.com/v2/checkout/orders/0UX88842XW347023K",
                                    "rel": "up",
                                    "method": "GET"
                                }
                            ],
                            "create_time": "2020-09-22T08:03:10Z",
                            "update_time": "2020-09-22T08:03:10Z"
                        }
                    ]
                }
            }
        ],
        "create_time": "2020-09-22T08:03:10Z",
        "update_time": "2020-09-22T08:03:10Z",
        "links": [
            {
                "href": "https://api.sandbox.paypal.com/v2/checkout/orders/0UX88842XW347023K",
                "rel": "self",
                "method": "GET"
            }
        ]
    }
    RESPONSE
  end

  def successful_refund_order_response
    <<-RESPONSE
    {
        "id": "90E25538TL390384X",
        "status": "COMPLETED",
        "links": [
            {
                "href": "https://api.sandbox.paypal.com/v2/payments/refunds/90E25538TL390384X",
                "rel": "self",
                "method": "GET"
            },
            {
                "href": "https://api.sandbox.paypal.com/v2/payments/captures/00U22118MH8302016",
                "rel": "up",
                "method": "GET"
            }
        ]
    }
    RESPONSE
  end

  def successful_void_order_response
    <<-RESPONSE
    {}
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

  # <- ************************ Assertions ************************ >

  def success_create_order_assertions(order_type)
    assert create = @paypal_customer.create_order(order_type, options)
    assert_instance_of Response, create
    assert_success create

    assert_equal order_type, create.params["intent"]
    assert_equal "CREATED", create.params["status"]
    assert_equal "Transaction Successfully Completed", create.message
    create
  end

  def success_capture_assertions(order_id)
    assert capture = @paypal_customer.capture(order_id, @card_order_options)
    assert_instance_of Response, capture
    assert_success capture

    assert_equal "COMPLETED", capture.params["status"]
    assert_equal "Transaction Successfully Completed", capture.message
    capture
  end

  def success_authorize_assertions(order_id)
    assert authorize = @paypal_customer.authorize(order_id, @card_order_options)
    assert_instance_of Response, authorize
    assert_success authorize

    assert_equal "COMPLETED", authorize.params["status"]
    assert_equal "Transaction Successfully Completed", authorize.message
    authorize
  end

  def success_refund_assertions(capture_id)
    assert refund = @paypal_customer.refund(capture_id, options)
    assert_instance_of Response, refund
    assert_success refund

    assert_equal "COMPLETED", refund.params["status"]
    assert_equal "Transaction Successfully Completed", refund.message
    refund
  end

  def success_void_assertions(authorization_id)
    assert void = @paypal_customer.void(authorization_id, options)
    assert_instance_of Response, void
    assert_success void

    assert_empty void.params
    assert_equal "Transaction Successfully Completed", void.message
    void
  end


end
