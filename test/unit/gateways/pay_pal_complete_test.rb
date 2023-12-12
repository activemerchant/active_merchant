require 'test_helper'

class PayPalCompleteTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaypalCompleteGateway.new(client_id: 'client_id', secret: 'secret', bn_code: 'bn_code')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    stub_auth
    stub_purchase

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_store
    stub_auth
    stub_card_vaulting

    response = @gateway.store(@credit_card)
    assert_success response
  end

  def test_successful_refund
    stub_auth
    stub_purchase
    stub_refund

    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    refund_response = @gateway.refund(@amount, purchase_response.authorization, @options)
    assert_success refund_response
  end

  def test_successful_void
    stub_auth
    stub_purchase
    stub_refund

    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    refund_response = @gateway.void(purchase_response.authorization, @options)
    assert_success refund_response
  end

  def test_successful_unstore
    stub_auth
    stub_card_vaulting
    stub_card_removal

    store_response = @gateway.store(@credit_card)
    assert_success store_response

    unstore_response = @gateway.unstore(store_response.params['id'])
    assert_success unstore_response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def stubbed_response_for(response, code: 200)
    stub(body: send(response), code: code)
  end

  def stub_auth
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api-m.sandbox.paypal.com/v1/oauth2/token')
    end.returns(stubbed_response_for(:successful_access_token_response))
  end

  def stub_purchase
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api-m.sandbox.paypal.com/v2/checkout/orders')
    end.returns(stubbed_response_for(:successful_create_order_response, code: 201))
  end

  def stub_refund
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api-m.sandbox.paypal.com/v2/payments/captures')
    end.returns(stubbed_response_for(:successful_refund_response, code: 201))
  end

  def stub_card_vaulting
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api-m.sandbox.paypal.com/v3/vault/setup-tokens')
    end.returns(stubbed_response_for(:successful_creation_of_setup_token_response, code: 201))

    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api-m.sandbox.paypal.com/v3/vault/payment-tokens')
    end.returns(stubbed_response_for(:successful_creation_of_payment_token_response, code: 201))
  end

  def stub_card_removal
    @gateway.expects(:raw_ssl_request).with do |http_method, endpoint|
      http_method == :delete && endpoint.to_s.start_with?('https://api-m.sandbox.paypal.com/v3/vault/payment-tokens')
    end.returns(stubbed_response_for(:successful_unstore_response, code: 204))
  end

  def successful_access_token_response
    <<~RESPONSE
      {
        "scope": "https://uri.paypal.com/services/customer/partner-referrals/readwrite",
        "access_token": "A21AALChrbsuhw5fbnUWGgDDPyjIe6aEcipmZ_wFiookWLbXIk0jI3CVl4zFwWJZLXMh9eJlwxdB6MYPRPALkuOiAAgsabIZw",
        "token_type": "Bearer",
        "app_id": "APP-80W284485P519543T",
        "expires_in": 31679,
        "nonce": "2023-12-11T03:37:24ZXY-3HENyUiFIB86oTarqo9iHFtgtyLahtQ6zLjutNYY"
      }
    RESPONSE
  end

  def successful_creation_of_setup_token_response
    <<~RESPONSE
      {
        "id": "9B88192079652840T",
        "customer": {
          "id": "AfUTZQEskD"
        },
        "status": "APPROVED",
        "payment_source": {
          "card": {
            "name": "Mitch Zboncak",
            "last_digits": "1111",
            "brand": "VISA",
            "expiry": "2030-03",
            "billing_address": {
              "address_line_1": "Infinite Loop 1",
              "admin_area_2": "Cupertino",
              "admin_area_1": "CA",
              "postal_code": "95014",
              "country_code": "US"
            }
          }
        },
        "links": [
          {
            "href": "https://api.sandbox.paypal.com/v3/vault/setup-tokens/9B88192079652840T",
            "rel": "self",
            "method": "GET",
            "encType": "application/json"
          },
          {
            "href": "https://api.sandbox.paypal.com/v3/vault/payment-tokens",
            "rel": "confirm",
            "method": "POST",
            "encType": "application/json"
          }
        ]
      }
    RESPONSE
  end

  def successful_creation_of_payment_token_response
    <<~RESPONSE
      {
        "id": "39b83620176362610",
        "customer": {
          "id": "AfUTZQEskD"
        },
        "payment_source": {
          "card": {
            "name": "Mitch Zboncak",
            "last_digits": "1111",
            "brand": "VISA",
            "expiry": "2030-03",
            "billing_address": {
              "address_line_1": "Infinite Loop 1",
              "admin_area_2": "Cupertino",
              "admin_area_1": "CA",
              "postal_code": "95014",
              "country_code": "US"
            }
          }
        },
        "links": [
          {
            "href": "https://api.sandbox.paypal.com/v3/vault/payment-tokens/39b83620176362610",
            "rel": "self",
            "method": "GET",
            "encType": "application/json"
          },
          {
            "href": "https://api.sandbox.paypal.com/v3/vault/payment-tokens/39b83620176362610",
            "rel": "delete",
            "method": "DELETE",
            "encType": "application/json"
          }
        ]
      }
    RESPONSE
  end

  def successful_create_order_response
    <<~RESPONSE
      {
        "id": "8UY678134N833721C",
        "status": "COMPLETED",
        "payment_source": {
          "card": {
            "name": "Lavern Hane",
            "last_digits": "1111",
            "expiry": "2030-03",
            "brand": "VISA",
            "available_networks": ["VISA"],
            "type": "UNKNOWN",
            "bin_details": {}
          }
        },
        "purchase_units": [
          {
            "reference_id": "hal-2023121103493138",
            "payments": {
              "captures": [
                {
                  "id": "1WV2450084401050C",
                  "status": "COMPLETED", "amount":
                    {
                      "currency_code": "USD",
                      "value": "10.00"
                    },
                  "final_capture": true,
                  "disbursement_mode": "INSTANT",
                  "seller_protection": {
                    "status": "NOT_ELIGIBLE"
                  },
                  "seller_receivable_breakdown": {
                    "gross_amount": {
                      "currency_code": "USD",
                      "value": "10.00"
                    },
                    "paypal_fee": {
                      "currency_code": "USD",
                      "value": "0.75"
                    },
                    "net_amount": {
                      "currency_code": "USD",
                      "value": "9.25"
                    }
                  },
                  "links": [
                    {
                      "href": "https://api.sandbox.paypal.com/v2/payments/captures/1WV2450084401050C",
                      "rel": "self",
                      "method": "GET"
                    },
                    {
                      "href": "https://api.sandbox.paypal.com/v2/payments/captures/1WV2450084401050C/refund",
                      "rel": "refund",
                      "method": "POST"
                    },
                    {
                      "href": "https://api.sandbox.paypal.com/v2/checkout/orders/8UY678134N833721C",
                      "rel": "up",
                      "method": "GET"
                    }
                  ],
                  "create_time": "2023-12-11T03:49:36Z",
                  "update_time": "2023-12-11T03:49:36Z",
                  "network_transaction_reference": {
                    "id": "406248795407735",
                    "network": "VISA"
                  },
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
        "links": [
          { "href": "https://api.sandbox.paypal.com/v2/checkout/orders/8UY678134N833721C",
            "rel": "self",
            "method": "GET"
          }
        ]
      }
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
      {
        "id": "5SM047555K845754U",
        "status": "COMPLETED",
        "links": [
          {
            "href": "https://api-m.sandbox.paypal.com/v2/payments/refunds/5SM047555K845754U", "rel": "self", "method": "GET"
          },
          {
            "href":"https://api-m.sandbox.paypal.com/v2/payments/captures/8LD87690VK317734S", "rel": "up", "method": "GET"
          }
        ]
      }
    RESPONSE
  end

  def successful_unstore_response; end

  def pre_scrubbed
    %q(
<- "POST /v1/oauth2/token HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic SWgtS1cwYVpUcVNTOHYtZEdoeGhXTV9sb1RqX0o5FER1JmcFlJcWN4aUllV2FaVUNvV1BhaHg1VVJsS0hiRnkwR1hfbkFLTUhYb3BhVGVmLU93MThwV2FtU0VrOXFGeHRBbG5LcDhrTG1NNlo=\r\nPaypal-Partner-Attribution-Id: Chargify_PPCP\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.sandbox.paypal.com\r\nContent-Length: 29\r\n\r\n"
<- "https://uri.paypal.com/services/subscriptions\",\"access_token\":\"AGNyvK5656xsp6uk9kCVcbFHUkIZK0PThH0WT0Z9CMyL1S8uM-TJBsMVfdfdffdfQ8q4U_pcUMEh4o3454d2eXwcShZDt0PaacbBcULyrA\",\"token_type\":\"Bearer\",\"app_id\":\"APP-80W284485P519543T\",\"expires_in\":32169,\"nonce\":\"2020-06-18T15:04:08Z2yATQnwK96TrAqDsxF3J97kEQFQfbxMKhlCkvR5QiEM\"}""
<- "{\"source\":{\"card\":{\"type\":\"visa\",\"name\":\"J P\",\"number\":\"4111111111111111\",\"security_code\":\"123\",\"expiry\":\"2026-03\"}}}"
    )
  end

  def post_scrubbed
    %q(
<- "POST /v1/oauth2/token HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]=\r\nPaypal-Partner-Attribution-Id: Chargify_PPCP\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.sandbox.paypal.com\r\nContent-Length: 29\r\n\r\n"
<- "https://uri.paypal.com/services/subscriptions\",\"access_token[FILTERED]\",\"token_type\":\"Bearer\",\"app_id\":\"APP-80W284485P519543T\",\"expires_in\":32169,\"nonce\":\"2020-06-18T15:04:08Z2yATQnwK96TrAqDsxF3J97kEQFQfbxMKhlCkvR5QiEM\"}""
<- "{\"source\":{\"card\":{\"type\":\"visa\",\"name\":\"J P\",\"number[FILTERED]\",\"security_code[FILTERED]\",\"expiry\":\"2026-03\"}}}"
    )
  end
end