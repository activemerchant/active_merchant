require 'test_helper'
require 'byebug'

class PaypalExpressRestTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @paypal_customer = ActiveMerchant::Billing::PaypalCustomerGateway.new
    params = { username: "ASs8Osqge6KT3OdLtkNhD20VP8lsrqRUlRjLo-e5s75SHz-2ffMMzCos_odQGjGYpPcGlxJVQ5fXMz9q",
               password: "EKj_bMZn0CkOhOvFwJMX2WwhtCq2A0OtlOd5T-zUhKIf9WQxvgPasNX0Kr1U4TjFj8ZN6XCMF5NM30Z_" }


    options = { "Content-Type": "application/json", authorization: params }
    bearer_token = @paypal_customer.get_token(options)
    @headers = { "Authorization": "Bearer #{ bearer_token[:access_token] }", "Content-Type": "application/json" }
    @capture_body = {
        "intent": "CAPTURE",
        "purchase_units": [
            {
                "reference_id": "camera_shop_seller_#{DateTime.now}",
                "description": "Camera Shop",
                "amount": {
                    "currency_code": "USD",
                    "value": "12.00",
                    "breakdown": {
                        "item_total": {
                            "currency_code": "USD",
                            "value": "12.00"
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
                            "value": "12.00"
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
                        "address_line_1": "123 Townsend St",
                        "address_line_2": "Floor 6",
                        "admin_area_2": "San Francisco",
                        "admin_area_1": "CA",
                        "postal_code": "94107",
                        "country_code": "US"
                    }
                },
                "shipping_method": "United Postal Service",
                "payment_instruction": {
                    "disbursement_mode": "INSTANT",
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
                "custom_id": "custom_value_#{DateTime.now}",
                "invoice_id": "invoice_number_#{DateTime.now}",
                "soft_descriptor": "Payment Camera Shop"
            }
        ],
        "application_context": {
            "return_url": "https://google.com",
            "cancel_url": "https://google.com"
        }
    }


    @authorize_body = {
            "intent": "AUTHORIZE",
            "purchase_units": [
                {
                    "reference_id": "camera_shop_seller_#{ DateTime.now }",
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
                        "email_address":"sb-jnxjj3033194@business.example.com"
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
                "return_url": "https://google.com",
                "cancel_url": "https://google.com"
            }
        }
  end

  def test_create_instant_order
    @options = { headers: @headers, body: @capture_body }
    response = @paypal_customer.create_order(@options)
    @order_id = response["id"]
    assert response.success?
    assert response.parsed_response["status"].eql?("CREATED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end

  def test_create_authorize_order
    @options = { headers: @headers, body: @authorize_body }
    response = @paypal_customer.create_order(@options)
    assert response.success?
    assert response.parsed_response["status"].eql?("CREATED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
    @order_id = response["id"]
  end

  def test_handle_approve_capture
    @order_id = "6EU99348TG513694H"
    @body = {}
    options = { headers: @headers, body: @body }
    response = @paypal_customer.handle_approve(@order_id,"capture",options)
    assert response.success?
    assert response.parsed_response["status"].eql?("COMPLETED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end

  def test_set_authorize_order
    @order_id = "5KP79474T6549011V"
    response = @paypal_customer.authorize(@order_id, { headers: @headers })
    assert response.success?
    assert response.parsed_response["status"].eql?("CREATED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end

  def test_set_authorize_order
    test_create_authorize_order
    response = @paypal_customer.authorize(@order_id, { headers: @headers })
    assert response.success?
    assert response.parsed_response["status"].eql?("CREATED")
    assert !response.parsed_response["id"].nil?
    assert !response.parsed_response['links'].blank?
  end
end
