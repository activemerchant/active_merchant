require 'test_helper'
require 'digital_river'

class DigitalRiverTest < Test::Unit::TestCase
  def setup
    @gateway = DigitalRiverGateway.new(token: 'test')

    @store_options = {
      email: 'test@example.com',
      billing_address: {
        name: 'Joe Doe',
        organization: "Joe's",
        phone: '123',
        address1: 'Some Street',
        city: 'San Francisco',
        state: 'CA',
        zip: '61156',
        country: 'US'
      }
    }
  end

  def test_successful_store_with_customer_vault_token
    DigitalRiver::ApiClient
      .expects(:get)
      .with("/customers/123", anything)
      .returns(succcessful_customer_response)

    DigitalRiver::ApiClient
      .expects(:post)
      .with("/customers/123/sources/456", anything)
      .returns(successful_attach_source_response)

    assert response = @gateway.store('456', @store_options.merge(customer_vault_token: '123'))
    assert_success response
    assert_instance_of MultiResponse, response
    assert_equal "123", response.primary_response.params["customer_vault_token"]
    assert_equal "456", response.primary_response.params["payment_profile_token"]
    assert_equal response.message, "OK"
    assert_equal "123", response.authorization
  end

  def test_successful_store_without_customer_vault_token
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/customers", anything)
      .returns(succcessful_customer_response)

    DigitalRiver::ApiClient
      .expects(:post)
      .with("/customers/123/sources/456", anything)
      .returns(successful_attach_source_response)

    assert response = @gateway.store('456', @store_options)
    assert_success response
    assert_instance_of MultiResponse, response
    assert_equal "123", response.primary_response.params["customer_vault_token"]
    assert_equal "456", response.primary_response.params["payment_profile_token"]
    assert_equal response.message, "OK"
    assert_equal "123", response.authorization
  end

  def test_unsuccessful_store_when_customer_vault_token_not_exist
    DigitalRiver::ApiClient
      .expects(:get)
      .with("/customers/123", anything)
      .returns(unsuccessful_customer_find_response)

    assert response = @gateway.store('456', @store_options.merge(customer_vault_token: '123'))
    assert_failure response
    assert_instance_of MultiResponse, response
    assert_equal "Customer '123' not found", response.primary_response.message
    assert_equal false, response.primary_response.params["exists"]
  end

  def test_unsuccessful_store_when_customer_create_fails
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/customers", anything)
      .returns(unsucccessful_customer_response)

    assert response = @gateway.store('456', { address: ""})
    assert_failure response
    assert_equal "A parameter is missing. (missing_parameter)", response.message
  end

  def test_unsuccessful_store_when_source_already_attached
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/customers", anything)
      .returns(succcessful_customer_response)

    DigitalRiver::ApiClient
      .expects(:post)
      .with("/customers/123/sources/456", anything)
      .returns(source_already_attached_response)

    assert response = @gateway.store('456', @store_options)
    assert_failure response
    assert_equal "Source '456' is attached to another customer. A source cannot be attached to more than one customer. (invalid_parameter)", response.message
  end

  def test_successful_purchase
    DigitalRiver::ApiClient
      .expects(:get)
      .twice
      .with("/orders/123", anything)
      .returns(successful_order_exists_response)

    DigitalRiver::ApiClient
      .expects(:post)
      .with("/fulfillments", anything)
      .returns(successful_fulfillment_create_response)

    DigitalRiver::ApiClient
      .expects(:get)
      .with("/charges/456", anything)
      .returns(successful_charge_find_response)

    assert response = @gateway.purchase(order_id: '123')
    assert_success response
    assert_equal "OK", response.message
    assert_equal "123", response.params["order_id"]
    assert_equal "source", response.params["source_id"]
    assert_equal "456", response.params["charge_id"]
    assert_equal "789", response.params["capture_id"]
  end

  def test_unsuccessful_purchase_order_not_exist
    DigitalRiver::ApiClient
      .expects(:get)
      .with("/orders/123", anything)
      .returns(unsuccessful_order_not_exists_response)

    assert response = @gateway.purchase(order_id: '123')
    assert_failure response
    assert_equal "Order '123' not found. (not_found)", response.message
  end

  def test_unsuccessful_purchase_fulfillment_fails
    DigitalRiver::ApiClient
      .expects(:get)
      .with("/orders/123", anything)
      .returns(successful_order_exists_response)

    DigitalRiver::ApiClient
      .expects(:post)
      .with("/fulfillments", anything)
      .returns(unsuccessful_fulfillment_create_response)

    assert response = @gateway.purchase(order_id: '123')
    assert_failure response
    assert_equal "A parameter is missing. (missing_parameter)", response.message
  end

  def test_unsuccessful_purchase_passed_order_failure_message
    assert response = @gateway.purchase(order_failure_message: 'Order failed')
    assert_failure response
    assert_equal "Order failed", response.message
  end

  def test_purchase_with_order_in_review_state
    DigitalRiver::ApiClient
      .expects(:get)
      .with("/orders/123", anything)
      .returns(order_in_pending_state_response)

    assert response = @gateway.purchase(order_id: '123')
    assert_failure response
    assert_equal "Order not in 'accepted' state", response.message
    assert_equal "123", response.params["order_id"]
    assert_equal "in_review", response.params["order_state"]
  end

  def test_successful_full_refund
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/refunds", anything)
      .returns(successful_full_refund_response)

    options = { order_id: '123456780012', currency: 'USD' }
    assert response = @gateway.refund(9.99, nil, options)
    assert_success response
    assert_equal "OK", response.message
    assert_equal "re_123", response.params['refund_id']
  end

  def test_successful_partial_refund
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/refunds", anything)
      .returns(successful_partial_refund_response)

    options = { order_id: '123456780012', currency: 'USD' }
    assert response = @gateway.refund(1.99, nil, options)
    assert_success response
    assert_equal "OK", response.message
    assert_equal "re_456", response.params['refund_id']
  end

  def test_unsuccessful_refund_order_doesnt_exist
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/refunds", anything)
      .returns(unsuccessful_refund_order_doesnt_exist_response)

    options = { order_id: '123456780012', currency: 'USD' }
    assert response = @gateway.refund(9.99, nil, options)
    assert_failure response
    assert_equal "Requisition not found. (invalid_parameter)", response.message
  end

  def test_unsuccessful_refund_order_in_fulfilled_state
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/refunds", anything)
      .returns(unsuccessful_refund_order_in_fulfilled_state_response)

    options = { order_id: '123456780012', currency: 'USD' }
    assert response = @gateway.refund(9.99, nil, options)
    assert_failure response
    assert_equal "The requested refund amount is greater than the available amount. (invalid_parameter)", response.message
  end

  def test_unsuccessful_refund_amount_larger_than_available
    DigitalRiver::ApiClient
      .expects(:post)
      .with("/refunds", anything)
      .returns(unsuccessful_refund_amount_larger_than_available_response)

    options = { order_id: '123456780012', currency: 'USD' }
    assert response = @gateway.refund(10.00, nil, options)
    assert_failure response
    assert_equal "The requested refund amount is greater than the available amount. (invalid_parameter)", response.message
  end

  def test_successful_unstore
    DigitalRiver::ApiClient
      .expects(:delete)
      .with("/customers/123/sources/456", anything)
      .returns(successful_unstore_response)

    assert response = @gateway.unstore('456', { customer_vault_token: '123' })
    assert_success response
  end

  def test_unsuccessful_unstore
    DigitalRiver::ApiClient
      .expects(:delete)
      .with("/customers/123/sources/456", anything)
      .returns(unsuccessful_unstore_response)

    assert response = @gateway.unstore('456', { customer_vault_token: '123' })
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def unsuccessful_unstore_response
    stub(
      success?: false,
      parsed_response: {
        type: "conflict",
        errors: [
          {
            code: "not_found",
            parameter: "sourceId",
            message: "Source 'ea9e87a7-9f81-4448-82e3-d3028ea953c4' has not been attached to the customer."
          }
        ]
      }
    )
  end

  def successful_unstore_response
    stub(
      success?: true,
      parsed_response: {}
    )
  end

  def succcessful_customer_response
    stub(
      success?: true,
      parsed_response: {
        id: "123",
        created_time: "2021-04-26T11:49:58Z",
        email: "test@example.com",
        shipping:
          {
            address: {
              line1: "Evergreen Avenue",
              city: "Bloomfield",
              postal_code: "43040",
              state: "OH",
              country: "US"
            },
            name: "John Doe",
            phone: "1234",
            organization: "Doe's"
          },
        ive_mode: false,
        enabled: true,
        request_to_be_forgotten: false,
        locale: "en_US",
        type: "individual"
      }
    )
  end

  def unsucccessful_customer_response
    stub(
      success?: false,
      parsed_response: {
        type: "bad_request",
        errors: [
          {
            code: "missing_parameter",
            parameter: "shipping.address.country",
            message: "A parameter is missing."
          }
        ]
      }
    )
  end

  def successful_attach_source_response
    stub(
      success?: true,
      parsed_response: {
        id: "456",
        customer_id:  "123",
        type: "creditCard",
        reusable: false,
        owner: {
          first_name: "William",
          last_name: "Brown",
          email: "testing@example.com",
          address: {
            line1: "10380 Bren Road West",
            city: "Minnetonka",
            state: "MN",
            country: "US",
            postal_code: "55343"
          }
        },
        state: "chargeable",
        created_time: "2021-04-26T11:50:38.983Z",
        updated_time: "2021-04-26T11:50:38.983Z",
        flow: "standard",
        credit_card: {
          brand: "Visa",
          expiration_month: 7,
          expiration_year: 2027,
          last_four_digits: "1111",
          payment_identifier: "00700"
        }
      }
    )
  end

  def unsuccessful_customer_find_response
    stub(
      success?: false,
      parsed_response: {
        type: "not_found",
        errors: [
          {
            code: "not_found",
            parameter: "id",
            message: "Customer '123' not found."
          }
        ]
      }
    )
  end

  def source_already_attached_response
    stub(
      success?: false,
      parsed_response: {
        type: "conflict",
        errors: [
          {
            code: "invalid_parameter",
            parameter: "sourceId",
            message: "Source '456' is attached to another customer. A source cannot be attached to more than one customer."
          }
        ]
      }
    )
  end

  def successful_charge_find_response
    stub(
      success?: true,
      parsed_response: {
        id: "456",
        created_time: "2021-04-26T12:57:18Z",
        currency: "USD",
        amount: 249.99,
        state: "processing",
        order_id: "188312420336",
        captured: true,
        captures: [
          {
            id: "789",
            created_time: "2021-04-26T12:57:24Z",
            amount: 249.99,
            state: "pending"
          }
        ],
        refunded: false,
        source_id: "source",
        payment_session_id: "f7820f7c-f75f-4e42-8d83-20895fd5610b",
        type: "merchant_initiated",
        live_mode: false
      }
    )
  end

  def successful_fulfillment_create_response
    stub(
      success?: true,
      parsed_response: {
        id: "fulfillment",
        created_time: "2021-04-26T12:54:47Z",
        items: [
          {
            quantity: 1,
            cancel_quantity: 0,
            sku_id: "sku_14ce5d3f-b931-4fbc-8f87-88b82888f670",
            item_id: "109797320336"
          }
        ],
        order_id: "188311480336",
        live_mode: false
      }
    )
  end

  def unsuccessful_fulfillment_create_response
    stub(
      success?: false,
      parsed_response: {
          type: "bad_request",
          errors: [
            {
              code: "missing_parameter",
              parameter: "orderId",
              message: "A parameter is missing."
            }
          ]
      }
    )
  end

  def successful_order_exists_response
    stub(
      success?: true,
      parsed_response: {
        id: "123",
        customer_id: "123",
        currency: "USD",
        email: "test@example.com",
        ship_to:  {
          address: {
            line1: "Evergreen Avenue",
            city: "Bloomfield",
            postal_code: "43040",
            state: "OH",
            country: "US"
          },
          name: "John Doe",
          phone: "1234",
          email: "test@example.com",
          organization: "Doe's"
        },
        bill_to:  {
          address: {
            line1: "10380 Bren Road West",
            city: "Minnetonka",
            postal_code: "55343",
            state: "MN",
            country: "US"
          },
          name: "William Brown",
          phone: "1234",
          email: "testing@example.com",
          organization: "Doe's"
        },
        total_amount: 249.99,
        subtotal: 249.99,
        total_fees: 0.0,
        total_tax: 0.0,
        total_importer_tax: 0.0,
        total_duty: 0.0,
        total_discount: 0.0,
        total_shipping: 0.0,
        items:  [
          {
            id: "109798190336",
            sku_id: "sku_14ce5d3f-b931-4fbc-8f87-88b82888f670",
            amount: 249.99,
            quantity: 1,
            state: "created",
            state_transitions: {
              created: "2021-04-26T12:48:18Z"
            },
            tax: {
              rate: 0.0,
              amount: 0.0
            },
            importer_tax: {
              amount: 0.0
            },
            duties: {
              amount: 0.0
            },
            available_to_refund_amount: 0.0,
            fees: {
              amount: 0.0, tax_amount: 0.0
            }
          }
        ],
        updated_time: "2021-04-26T12:48:18Z",
        locale: "en_US",
        customer_type: "individual",
        charge_type: "merchant_initiated",
        selling_entity: {
          id: "DR_INC-ENTITY",
          name: "Digital River Inc."
        },
        live_mode: false,
        state: "accepted",
        state_transitions: {
          accepted: "2021-04-26T12:48:21Z"
        },
        fraud_state: "passed",
        fraud_state_transitions: {
          passed: "2021-04-26T12:48:21Z"
        },
        request_to_be_forgotten: false,
        captured_amount: 0.0,
        cancelled_amount: 0.0,
        available_to_refund_amount: 0.0,
        checkout_id: "20677c47-57cb-4447-b49d-6cb2fa038f37",
        payment: {
          session: {
            id: "75eb52fa-9f0a-4488-bd48-aa800df0fe7e"
          },
          charges:  [
            {
              id: "456",
              created_time: "2021-04-26T12:48:21Z",
              currency: "USD",
              amount: 249.99,
              state: "capturable",
              captured: false,
              refunded: false,
              source_id: "source",
              type: "merchant_initiated"
            }
          ]
        },
        sources:  [
          {
            id: "source",
            type: "creditCard",
            amount: 249.99,
            owner:{
              first_name: "William",
              last_name: "Brown",
              email: "testing@example.com",
              address:  {
                line1: "10380 Bren Road West",
                city: "Minnetonka",
                postal_code: "55343",
                state: "MN",
                country: "US"
              }
            },
            credit_card: {
              brand: "Visa",
              expiration_month: 7,
              expiration_year: 2027,
              last_four_digits: "1111"
            }
          }
        ]
      }
    )
  end

  def unsuccessful_order_not_exists_response
    stub(
      success?: false,
      parsed_response: {
        type: "not_found",
        errors: [
          {
            code: "not_found",
            parameter: "id",
            message: "Order '123' not found."
          }
        ]
      }
    )
  end

  def order_in_pending_state_response
    stub(
      success?: true,
      parsed_response: {
        id: "123",
        customer_id: "123",
        currency: "USD",
        email: "test@example.com",
        ship_to:  {
          address: {
            line1: "Evergreen Avenue",
            city: "Bloomfield",
            postal_code: "43040",
            state: "OH",
            country: "US"
          },
          name: "John Doe",
          phone: "1234",
          email: "test@example.com",
          organization: "Doe's"
        },
        bill_to:  {
          address: {
            line1: "10380 Bren Road West",
            city: "Minnetonka",
            postal_code: "55343",
            state: "MN",
            country: "US"
          },
          name: "William Brown",
          phone: "1234",
          email: "testing@example.com",
          organization: "Doe's"
        },
        total_amount: 249.99,
        subtotal: 249.99,
        total_fees: 0.0,
        total_tax: 0.0,
        total_importer_tax: 0.0,
        total_duty: 0.0,
        total_discount: 0.0,
        total_shipping: 0.0,
        items:  [
          {
            id: "109798190336",
            sku_id: "sku_14ce5d3f-b931-4fbc-8f87-88b82888f670",
            amount: 249.99,
            quantity: 1,
            state: "created",
            state_transitions: {
              created: "2021-04-26T12:48:18Z"
            },
            tax: {
              rate: 0.0,
              amount: 0.0
            },
            importer_tax: {
              amount: 0.0
            },
            duties: {
              amount: 0.0
            },
            available_to_refund_amount: 0.0,
            fees: {
              amount: 0.0, tax_amount: 0.0
            }
          }
        ],
        updated_time: "2021-04-26T12:48:18Z",
        locale: "en_US",
        customer_type: "individual",
        charge_type: "merchant_initiated",
        selling_entity: {
          id: "DR_INC-ENTITY",
          name: "Digital River Inc."
        },
        live_mode: false,
        state: "in_review",
        state_transitions: {
          accepted: "2021-04-26T12:48:21Z"
        },
        fraud_state: "passed",
        fraud_state_transitions: {
          passed: "2021-04-26T12:48:21Z"
        },
        request_to_be_forgotten: false,
        captured_amount: 0.0,
        cancelled_amount: 0.0,
        available_to_refund_amount: 0.0,
        checkout_id: "20677c47-57cb-4447-b49d-6cb2fa038f37",
        payment: {
          session: {
            id: "75eb52fa-9f0a-4488-bd48-aa800df0fe7e"
          },
          charges:  [
            {
              id: "456",
              created_time: "2021-04-26T12:48:21Z",
              currency: "USD",
              amount: 249.99,
              state: "capturable",
              captured: false,
              refunded: false,
              source_id: "source",
              type: "merchant_initiated"
            }
          ]
        },
        sources:  [
          {
            id: "source",
            type: "creditCard",
            amount: 249.99,
            owner:{
              first_name: "William",
              last_name: "Brown",
              email: "testing@example.com",
              address:  {
                line1: "10380 Bren Road West",
                city: "Minnetonka",
                postal_code: "55343",
                state: "MN",
                country: "US"
              }
            },
            credit_card: {
              brand: "Visa",
              expiration_month: 7,
              expiration_year: 2027,
              last_four_digits: "1111"
            }
          }
        ]
      }
    )
  end

  def successful_full_refund_response
    stub(
      success?: true,
      parsed_response: {
        id: "re_123",
        currency: "USD",
        amount: 0.999e1,
        refunded_amount: 0.0,
        state: "pending",
      }
    )
  end

  def successful_partial_refund_response
    stub(
      success?: true,
      parsed_response: {
        id: "re_456",
        currency: "USD",
        amount: 0.199e1,
        refunded_amount: 0.0,
        state: "pending",
      }
    )
  end

  def unsuccessful_refund_order_doesnt_exist_response
    stub(
      success?: false,
      parsed_response: {
        type: "bad_request",
        errors: [
          {
            code: "invalid_parameter",
            parameter: "order",
            message: "Requisition not found."
          }
        ]
      }
    )
  end

  def unsuccessful_refund_order_in_fulfilled_state_response
    stub(
      success?: false,
      parsed_response: {
        type: "bad_request",
        errors: [
          {
            code: "invalid_parameter",
            parameter: "amountRequested",
            message: "The requested refund amount is greater than the available amount."
          }
        ]
      }
    )
  end

  def unsuccessful_refund_amount_larger_than_available_response
    stub(
      success?: false,
      parsed_response: {
        type: "bad_request",
        errors: [
          {
            code: "invalid_parameter",
            parameter: "amountRequested",
            message: "The requested refund amount is greater than the available amount."
          }
        ]
      }
    )
  end

  def pre_scrubbed
    %q{
      opening connection to api.digitalriver.com:443...
      opened
      starting SSL for api.digitalriver.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
      <- "POST /customers HTTP/1.1\r\nAuthorization: Bearer sk_test_a3bd3f2ba5db4e2db94dd6b02b4dec33\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.digitalriver.com\r\nContent-Length: 202\r\n\r\n"
      <- "{\"email\":\"holdpass@fraud.com\",\"shipping\":{\"name\":\"Jane Doe\",\"organization\":null,\"phone\":\"123456789\",\"address\":{\"line1\":\"Test\",\"line2\":\"\",\"city\":\"Test\",\"state\":\"AL\",\"postalCode\":\"12345\",\"country\":\"US\"}}}"
      -> "HTTP/1.1 201 \r\n"
      -> "access-control-allow-credentials: true\r\n"
    }
  end

  def post_scrubbed
    %q{
      opening connection to api.digitalriver.com:443...
      opened
      starting SSL for api.digitalriver.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
      <- "POST /customers HTTP/1.1\r\nAuthorization: Bearer [FILTERED]\r\nContent-Type: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.digitalriver.com\r\nContent-Length: 202\r\n\r\n"
      <- "{\"email\":\"holdpass@fraud.com\",\"shipping\":{\"name\":\"Jane Doe\",\"organization\":null,\"phone\":\"123456789\",\"address\":{\"line1\":\"Test\",\"line2\":\"\",\"city\":\"Test\",\"state\":\"AL\",\"postalCode\":\"12345\",\"country\":\"US\"}}}"
      -> "HTTP/1.1 201 \r\n"
      -> "access-control-allow-credentials: true\r\n"
    }
  end
end
