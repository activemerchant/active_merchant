require 'test_helper'

class PayPalCommercePlatformTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaypalCommercePlatformGateway.new(client_id: 'client_id', secret: 'secret', bn_code: 'bn_code')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v1/oauth2/token')
    end.returns(stubbed_response_for(:successful_access_token_response))

    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/checkout/orders')
    end.returns(stubbed_response_for(:successful_create_order_response, code: 201))

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
  end

  def test_successful_store
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v1/oauth2/token')
    end.returns(stubbed_response_for(:successful_access_token_response))

    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/vault/payment-tokens')
    end.returns(stubbed_response_for(:successful_create_credit_card_response, code: 201))

    response = @gateway.store(@credit_card)
    assert_success response
  end

  def test_successful_refund
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v1/oauth2/token')
    end.returns(stubbed_response_for(:successful_access_token_response))

    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/checkout/orders')
    end.returns(stubbed_response_for(:successful_create_order_response, code: 201))

    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/payments/captures')
    end.returns(stubbed_response_for(:successful_refund_response, code: 201))

    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    refund_response = @gateway.refund(@amount, purchase_response.authorization, @options)
    assert_success refund_response
  end

  def test_successful_void
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v1/oauth2/token')
    end.returns(stubbed_response_for(:successful_access_token_response))

    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/checkout/orders')
    end.returns(stubbed_response_for(:successful_create_order_response, code: 201))

    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/payments/captures')
    end.returns(stubbed_response_for(:successful_refund_response, code: 201))

    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase_response

    refund_response = @gateway.void(purchase_response.authorization, @options)
    assert_success refund_response
  end

  def test_successful_unstore
    @gateway.expects(:raw_ssl_request).with do |_, endpoint|
      endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v1/oauth2/token')
    end.returns(stubbed_response_for(:successful_access_token_response))

    @gateway.expects(:raw_ssl_request).with do |http_method, endpoint|
      http_method == :post && endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/vault/payment-tokens')
    end.returns(stubbed_response_for(:successful_create_credit_card_response, code: 201))

    @gateway.expects(:raw_ssl_request).with do |http_method, endpoint|
      http_method == :delete && endpoint.to_s.start_with?('https://api.sandbox.paypal.com/v2/vault/payment-tokens')
    end.returns(stubbed_response_for(:successful_unstore_response, code: 204))

    store_response = @gateway.store(@credit_card)
    assert_success store_response

    unstore_response = @gateway.unstore(store_response.params['id'])
    assert_success unstore_response
  end


  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

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

  private

  def stubbed_response_for(response, code: 200)
    stub(body: send(response), code: code)
  end

  def successful_access_token_response
    <<~RESPONSE
      {
        "scope": "https://uri.paypal.com/services/invoicing https://uri.paypal.com/services/vault/payment-tokens/read https://uri.paypal.com/services/disputes/read-buyer https://uri.paypal.com/services/payments/realtimepayment https://uri.paypal.com/services/disputes/update-seller https://uri.paypal.com/services/payments/payment/authcapture openid https://uri.paypal.com/services/disputes/read-seller https://uri.paypal.com/services/payments/refund https://api.paypal.com/v1/vault/credit-card https://api.paypal.com/v1/payments/.* https://uri.paypal.com/payments/payouts https://uri.paypal.com/services/vault/payment-tokens/readwrite https://api.paypal.com/v1/vault/credit-card/.* https://uri.paypal.com/services/subscriptions https://uri.paypal.com/services/applications/webhooks",
        "access_token": "A21AAERQZfTr0oxulliCDhJoSHwguzx-gskBk5IRZdoQUOLA5EciyRRLurSG5KOC79Hh0095GyTTqkgSS2cXBJSj4-4P2qtRg",
        "token_type": "Bearer",
        "app_id": "APP-80W284485P519543T",
        "expires_in": 32400,
        "nonce": "2020-06-18T10:56:46ZKgXVvTUfpOtxEPUdXe6D8quD5E6_JF8ijKpaxWMR2LA"
      }
    RESPONSE
  end

  def successful_create_credit_card_response
    <<~RESPONSE
    {
      "id": "7vg2k7r",
      "status": "CREATED",
      "customer_id": "3",
      "source": {
        "card": {
          "brand": "VISA",
          "last_digits": "1111"
        }
      },
      "links": [
        {
          "href": "https://api.sandbox.paypal.com/v2/vault/payment-tokens/7vg2k7r",
          "rel": "self",
          "method": "GET",
          "encType": "application/json"
        },
        {
          "href": "https://api.sandbox.paypal.com/v2/vault/payment-tokens/7vg2k7r",
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
        "id": "7F474121WN234360L",
        "payment_source": {
          "card": {
            "last_digits": "1111",
            "brand": "VISA",
            "type": "UNKNOWN"
          }
        },
        "purchase_units": [
          {
            "reference_id": "1",
            "payments": {
              "captures": [
                {
                  "id": "2R182482UG340734N",
                  "status": "COMPLETED",
                  "amount": {
                    "currency_code": "USD",
                    "value": "5.01"
                  },
                  "final_capture": true,
                  "disbursement_mode": "INSTANT",
                  "seller_protection": {
                    "status": "NOT_ELIGIBLE"
                  },
                  "seller_receivable_breakdown": {
                    "gross_amount": {
                      "currency_code": "USD",
                      "value": "5.01"
                    },
                    "paypal_fee": {
                      "currency_code": "USD",
                      "value": "0.45"
                    },
                    "platform_fees": [
                      {
                        "amount": {
                          "currency_code": "USD",
                          "value": "1.00"
                        },
                        "payee": {
                          "merchant_id": "CAZB9ABHTGXL4"
                        }
                      }
                    ],
                    "net_amount": {
                      "currency_code": "USD",
                      "value": "3.56"
                    }
                  },
                  "links": [
                    {
                      "href": "https://api.sandbox.paypal.com/v2/payments/captures/2R182482UG340734N",
                      "rel": "self",
                      "method": "GET"
                    },
                    {
                      "href": "https://api.sandbox.paypal.com/v2/payments/captures/2R182482UG340734N/refund",
                      "rel": "refund",
                      "method": "POST"
                    },
                    {
                      "href": "https://api.sandbox.paypal.com/v2/checkout/orders/7F474121WN234360L",
                      "rel": "up",
                      "method": "GET"
                    }
                  ],
                  "create_time": "2020-06-18T13:34:45Z",
                  "update_time": "2020-06-18T13:34:45Z",
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
          {
            "href": "https://api.sandbox.paypal.com/v2/checkout/orders/7F474121WN234360L",
            "rel": "self",
            "method": "GET"
          }
        ],
        "status": "COMPLETED"
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
            "href": "https://api.sandbox.paypal.com/v2/payments/refunds/5SM047555K845754U", "rel": "self", "method": "GET"
          },
          {
            "href":"https://api.sandbox.paypal.com/v2/payments/captures/8LD87690VK317734S", "rel": "up", "method": "GET"
          }
        ]
      }
    RESPONSE
  end

  def successful_unstore_response; end
end
