require 'test_helper'

class PaymillTest < Test::Unit::TestCase
  def setup
    @gateway = PaymillGateway.new(:public_key => 'PUBLIC', :private_key => 'PRIVATE')

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response
    assert_equal "tran_c94ba7df2dae8fd55028df41173c;", response.authorization
    assert_equal "Operation successful", response.message
    assert_equal 20000, response.params['data']['response_code']
    assert_equal 'pay_b8e6a28fc5e5e1601cdbefbaeb8a', response.params['data']['payment']['id']
    assert_equal '5100', response.params['data']['payment']['last4']
    assert_nil response.cvv_result["message"]
    assert_nil response.avs_result["message"]
    assert response.test?
  end

  def test_failed_store_card_attempting_purchase
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Account or Bank Details Incorrect', response.message
    assert_equal '000.100.201', response.params['transaction']['processing']['return']['code']
  end

  def test_broken_gateway
    @gateway.expects(:raw_ssl_request).returns(broken_gateway_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "File not found.\n", response.message
  end

  def test_failed_purchase
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Card declined', response.message
    assert_equal 50102, response.params['data']['response_code']
  end

  def test_invalid_login
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, failed_login_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Access Denied', response.message
  end

  def test_empty_server_response
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, MockResponse.failed(''))
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "Unable to parse error response: ''", response.message
  end

  def test_invalid_server_response
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, MockResponse.failed('not-json'))
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal "Unable to parse error response: 'not-json'", response.message
  end

  def test_invalid_login_on_storing_card
    @gateway.stubs(:raw_ssl_request).returns(failed_store_invalid_credentials_response, successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Unable to process the transaction - please check channelId or login data', response.message
  end

  def test_successful_authorize_and_capture
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response
    assert response.test?

    assert_equal "tran_4c612d5293e26d56d986eb89648c;preauth_fdf916cab73b97c4a139", response.authorization
    assert_equal "Operation successful", response.message
    assert_equal '0004', response.params['data']['payment']['last4']
    assert_equal 20000, response.params['data']['response_code']
    assert_nil response.avs_result["message"]
    assert_nil response.cvv_result["message"]

    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
    assert response.test?
    assert_equal 20000, response.params['data']['response_code']
    assert_equal "Operation successful", response.message
  end

  def test_failed_authorize
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card)
    assert_failure response
    assert_equal 'Card declined', response.message
    assert_equal 50102, response.params['data']['response_code']
  end

  def test_successful_authorize_and_void
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_void_response)
    response = @gateway.void(response.authorization)
    assert_success response
    assert response.test?
    assert_equal "Transaction approved.", response.message
  end

  def test_failed_capture
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_authorize_response)
    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(failed_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_failure response
    assert_equal 'Preauthorization has already been used', response.message
  end

  def test_successful_refund
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_refund_response)
    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert response.test?

    assert_equal 'Operation successful', refund.message
    assert_equal 'tran_89c8728e94273510afa99ab64e45', refund.params['data']['transaction']['id']
    assert_equal 'refund_d02807f46181c0919016;', refund.authorization
    assert_equal 20000, refund.params['data']['response_code']
  end

  def test_successful_refund_response_with_string_response_code
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_refund_response_with_string_response_code)
    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert response.test?

    assert_equal 'Operation successful', refund.message
    assert_equal 'tran_89c8728e94273510afa99ab64e45', refund.params['data']['transaction']['id']
    assert_equal 'refund_d02807f46181c0919016;', refund.authorization
    assert_equal 20000, refund.params['data']['response_code']
  end

  def test_failed_refund
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(failed_refund_response)
    assert refund = @gateway.refund(@amount, response.authorization)
    assert_failure refund
    assert_equal 'Amount to high', refund.message
  end

  def test_successful_store
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response)

    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal "tok_4f9a571b39bd8d0b4db5", response.authorization
    assert_equal "Request successfully processed in 'Merchant in Connector Test Mode'", response.message
    assert response.test?
  end

  def test_failed_store_with_invalid_credit_card
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)
    response = @gateway.store(@credit_card)
    assert_failure response
    assert_equal 'Account or Bank Details Incorrect', response.message
    assert_equal '000.100.201', response.params['transaction']['processing']['return']['code']
  end

  def test_successful_purchase_with_token
    @gateway.stubs(:raw_ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, "token")
    assert_success response
    assert_equal "tran_c94ba7df2dae8fd55028df41173c;", response.authorization
    assert_equal "Operation successful", response.message
    assert_equal 20000, response.params['data']['response_code']
    assert_equal 'pay_b8e6a28fc5e5e1601cdbefbaeb8a', response.params['data']['payment']['id']
    assert_equal '5100', response.params['data']['payment']['last4']
    assert_nil response.cvv_result["message"]
    assert_nil response.avs_result["message"]
    assert response.test?
  end

  def test_successful_authorize_with_token
    @gateway.stubs(:raw_ssl_request).returns(successful_authorize_response)

    assert response = @gateway.authorize(@amount, "token")
    assert_success response
    assert response.test?

    assert_equal "tran_4c612d5293e26d56d986eb89648c;preauth_fdf916cab73b97c4a139", response.authorization
    assert_equal "Operation successful", response.message
    assert_equal '0004', response.params['data']['payment']['last4']
    assert_equal 20000, response.params['data']['response_code']
    assert_nil response.avs_result["message"]
    assert_nil response.cvv_result["message"]
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private
  def successful_store_response
    MockResponse.new 200, %[jsonPFunction({"transaction":{"mode":"CONNECTOR_TEST","channel":"57313835619696ac361dc591bc973626","response":"SYNC","payment":{"code":"CC.DB"},"processing":{"code":"CC.DB.90.00","reason":{"code":"00","message":"Successful Processing"},"result":"ACK","return":{"code":"000.100.112","message":"Request successfully processed in 'Merchant in Connector Test Mode'"},"timestamp":"2013-02-12 21:33:43"},"identification":{"shortId":"1998.1832.1612","uniqueId":"tok_4f9a571b39bd8d0b4db5"}}})]
  end

  def failed_store_response
    MockResponse.new 200, %[jsonPFunction({"transaction":{"mode":"CONNECTOR_TEST","channel":"57313835619696ac361dc591bc973626","response":"SYNC","payment":{"code":"CC.DB"},"processing":{"code":"CC.DB.70.40","reason":{"code":"40","message":"Account Validation"},"result":"NOK","return":{"code":"000.100.201","message":"Account or Bank Details Incorrect"},"timestamp":"2013-02-12 21:54:45"}}})]
  end

  def failed_store_invalid_credentials_response
    MockResponse.new 200, %[jsonPFunction({"error":{"message":"Unable to process the transaction - please check channelId or login data"}})]
  end

  def failed_login_response
    MockResponse.new 401, %[{"error":"Access Denied","exception":"InvalidAuthentication"}]
  end

  def successful_purchase_response
    MockResponse.succeeded <<-JSON
      {
        "data":{
          "id":"tran_c94ba7df2dae8fd55028df41173c",
          "amount":"100",
          "origin_amount":100,
          "status":"closed",
          "description":null,
          "livemode":false,
          "refunds":null,
          "currency":"EUR",
          "created_at":1360717856,
          "updated_at":1360717856,
          "response_code":20000,
          "invoices":[

          ],
          "payment":{
            "id":"pay_b8e6a28fc5e5e1601cdbefbaeb8a",
            "type":"creditcard",
            "client":"client_70f0439c7c13fe5c417b",
            "card_type":"mastercard",
            "country":null,
            "expire_month":9,
            "expire_year":2014,
            "card_holder":null,
            "last4":"5100",
            "created_at":1360717855,
            "updated_at":1360717856
          },
          "client":{
            "id":"client_70f0439c7c13fe5c417b",
            "email":null,
            "description":null,
            "created_at":1360717856,
            "updated_at":1360717856,
            "payment":[

            ],
            "subscription":null
          },
          "preauthorization":null
        },
        "mode":"test"
      }
    JSON
  end

  def failed_purchase_response
    MockResponse.failed <<-JSON
      {
        "data":{
            "id":"tran_a432ce3b113cdd65b48e0d05db88",
            "amount":"100",
            "origin_amount":100,
            "status":"failed",
            "description":null,
            "livemode":false,
            "refunds":null,
            "currency":"EUR",
            "created_at":1385054845,
            "updated_at":1385054845,
            "response_code":50102,
            "short_id":null,
            "is_fraud":false,
            "invoices":[

            ],
            "app_id":null,
            "fees":[

            ],
            "payment":{
                "id":"pay_8b75b960574031979a880f98",
                "type":"creditcard",
                "client":"client_a69d8452d530ed20b297",
                "card_type":"mastercard",
                "country":null,
                "expire_month":"5",
                "expire_year":"2020",
                "card_holder":"",
                "last4":"5100",
                "created_at":1385054844,
                "updated_at":1385054845,
                "app_id":null
            },
            "client":{
                "id":"client_a69d8452d530ed20b297",
                "email":null,
                "description":null,
                "created_at":1385054845,
                "updated_at":1385054845,
                "app_id":null,
                "payment":[

                ],
                "subscription":null
            },
            "preauthorization":null
        },
        "mode":"test"
      }
    JSON
  end

  def successful_authorize_response
    MockResponse.succeeded <<-JSON
      {
        "data":{
            "id":"tran_4c612d5293e26d56d986eb89648c",
            "amount":"100",
            "origin_amount":100,
            "status":"preauth",
            "description":null,
            "livemode":false,
            "refunds":null,
            "currency":"EUR",
            "created_at":1385054035,
            "updated_at":1385054035,
            "response_code":20000,
            "short_id":"7357.7357.7357",
            "is_fraud":false,
            "invoices":[

            ],
            "app_id":null,
            "fees":[

            ],
            "payment":{
                "id":"pay_f9ff269434185e0789106758",
                "type":"creditcard",
                "client":"client_d5179e1b6a8f596b19b9",
                "card_type":"mastercard",
                "country":null,
                "expire_month":"9",
                "expire_year":"2014",
                "card_holder":"",
                "last4":"0004",
                "created_at":1385054033,
                "updated_at":1385054035,
                "app_id":null
            },
            "client":{
                "id":"client_d5179e1b6a8f596b19b9",
                "email":null,
                "description":null,
                "created_at":1385054035,
                "updated_at":1385054035,
                "app_id":null,
                "payment":[

                ],
                "subscription":null
            },
            "preauthorization":{
                "id":"preauth_fdf916cab73b97c4a139",
                "amount":"100",
                "currency":"EUR",
                "status":"closed",
                "livemode":false,
                "created_at":1385054035,
                "updated_at":1385054035,
                "app_id":null,
                "payment":{
                    "id":"pay_f9ff269434185e0789106758",
                    "type":"creditcard",
                    "client":"client_d5179e1b6a8f596b19b9",
                    "card_type":"mastercard",
                    "country":null,
                    "expire_month":"9",
                    "expire_year":"2014",
                    "card_holder":"",
                    "last4":"0004",
                    "created_at":1385054033,
                    "updated_at":1385054035,
                    "app_id":null
                },
                "client":{
                    "id":"client_d5179e1b6a8f596b19b9",
                    "email":null,
                    "description":null,
                    "created_at":1385054035,
                    "updated_at":1385054035,
                    "app_id":null,
                    "payment":[

                    ],
                    "subscription":null
                }
            }
        },
        "mode":"test"
      }
    JSON
  end

  # Paymill returns an HTTP Status code of 200 for an auth failure.
  def failed_authorize_response
    MockResponse.succeeded <<-JSON
      {
        "data":{
          "id":"tran_e53189278c7250bfa15c9c580ff2",
          "amount":"100",
          "origin_amount":100,
          "status":"failed",
          "description":null,
          "livemode":false,
          "refunds":null,
          "currency":"EUR",
          "created_at":1385054501,
          "updated_at":1385054501,
          "response_code":50102,
          "short_id":null,
          "is_fraud":false,
          "invoices":[

          ],
          "app_id":null,
          "fees":[

          ],
          "payment":{
            "id":"pay_7bc2d73764f38040df934995",
            "type":"creditcard",
            "client":"client_531e6247ff900e734884",
            "card_type":"mastercard",
            "country":null,
            "expire_month":"5",
            "expire_year":"2020",
            "card_holder":"",
            "last4":"5100",
            "created_at":1385054500,
            "updated_at":1385054501,
            "app_id":null
        },
        "client":{
            "id":"client_531e6247ff900e734884",
            "email":null,
            "description":null,
            "created_at":1385054501,
            "updated_at":1385054501,
            "app_id":null,
            "payment":[

            ],
            "subscription":null
        },
        "preauthorization":{
            "id":"preauth_cfa6a29b4c679efee58b",
            "amount":"100",
            "currency":"EUR",
            "status":"failed",
            "livemode":false,
            "created_at":1385054501,
            "updated_at":1385054501,
            "app_id":null,
            "payment":{
                "id":"pay_7bc2d73764f38040df934995",
                "type":"creditcard",
                "client":"client_531e6247ff900e734884",
                "card_type":"mastercard",
                "country":null,
                "expire_month":"5",
                "expire_year":"2020",
                "card_holder":"",
                "last4":"5100",
                "created_at":1385054500,
                "updated_at":1385054501,
                "app_id":null
            },
            "client":{
                "id":"client_531e6247ff900e734884",
                "email":null,
                "description":null,
                "created_at":1385054501,
                "updated_at":1385054501,
                "app_id":null,
                "payment":[

                ],
                "subscription":null
              }
          }
        },
        "mode":"test"
      }
    JSON
  end

  def successful_capture_response
    MockResponse.succeeded <<-JSON
      {
        "data":{
          "id":"tran_50fb13e10636cf1e59e13018d100",
          "amount":"100",
          "origin_amount":100,
          "status":"closed",
          "description":null,
          "livemode":false,
          "refunds":null,
          "currency":"EUR",
          "created_at":1360787311,
          "updated_at":1360787312,
          "response_code":20000,
          "invoices":[

          ],
          "payment":{
            "id":"pay_58e0662ef367027b2356f263e5aa",
            "type":"creditcard",
            "client":"client_9e4b7b0d61adc9a9e64e",
            "card_type":"mastercard",
            "country":null,
            "expire_month":9,
            "expire_year":2014,
            "card_holder":null,
            "last4":"5100",
            "created_at":1360787310,
            "updated_at":1360787311
          },
          "client":{
            "id":"client_9e4b7b0d61adc9a9e64e",
            "email":null,
            "description":null,
            "created_at":1360787311,
            "updated_at":1360787311,
            "payment":[
              "pay_58e0662ef367027b2356f263e5aa"
            ],
              "subscription":null
          },
          "preauthorization":{
            "id":"preauth_57c0c87ae3d193f66dc8",
            "amount":"100",
            "status":"closed",
            "livemode":false,
            "created_at":1360787311,
            "updated_at":1360787311,
            "payment":{
              "id":"pay_58e0662ef367027b2356f263e5aa",
              "type":"creditcard",
              "client":"client_9e4b7b0d61adc9a9e64e",
              "card_type":"mastercard",
              "country":null,
              "expire_month":9,
              "expire_year":2014,
              "card_holder":null,
              "last4":"5100",
              "created_at":1360787310,
              "updated_at":1360787311
            },
            "client":{
              "id":"client_9e4b7b0d61adc9a9e64e",
              "email":null,
              "description":null,
              "created_at":1360787311,
              "updated_at":1360787311,
              "payment":[
                "pay_58e0662ef367027b2356f263e5aa"
              ],
                "subscription":null
            }
          }
        },
        "mode":"test"
      }
    JSON
  end

  def successful_void_response
    MockResponse.succeeded <<-JSON
      {
          "data":[],
          "mode":"test"
      }
    JSON
  end

  def successful_refund_response
    MockResponse.succeeded <<-JSON
      {
        "data":{
          "id":"refund_d02807f46181c0919016",
          "amount":"100",
          "status":"refunded",
          "description":null,
          "livemode":false,
          "created_at":1360892424,
          "updated_at":1360892424,
          "response_code":20000,
          "transaction":{
            "id":"tran_89c8728e94273510afa99ab64e45",
            "amount":"000",
            "origin_amount":100,
            "status":"refunded",
            "description":null,
            "livemode":false,
            "refunds":null,
            "currency":"EUR",
            "created_at":1360892424,
            "updated_at":1360892424,
            "response_code":20000,
            "invoices":[

            ],
            "payment":{
              "id":"pay_e7f0738e00f3cd57ff00c60f9b72",
              "type":"creditcard",
              "client":"client_17c00b38c5b6fc62c3e6",
              "card_type":"mastercard",
              "country":null,
              "expire_month":9,
              "expire_year":2014,
              "card_holder":null,
              "last4":"5100",
              "created_at":1360892423,
              "updated_at":1360892424
            },
            "client":{
              "id":"client_17c00b38c5b6fc62c3e6",
              "email":null,
              "description":null,
              "created_at":1360892424,
              "updated_at":1360892424,
              "payment":[
                "pay_e7f0738e00f3cd57ff00c60f9b72"
              ],
                "subscription":null
            },
            "preauthorization":null
          }
        },
        "mode":"test"
      }
    JSON
  end

  def successful_refund_response_with_string_response_code
    MockResponse.succeeded <<-JSON
      {
        "data":{
          "id":"refund_d02807f46181c0919016",
          "amount":"100",
          "status":"refunded",
          "description":null,
          "livemode":false,
          "created_at":1360892424,
          "updated_at":1360892424,
          "response_code":20000,
          "transaction":{
            "id":"tran_89c8728e94273510afa99ab64e45",
            "amount":"000",
            "origin_amount":100,
            "status":"refunded",
            "description":null,
            "livemode":false,
            "refunds":null,
            "currency":"EUR",
            "created_at":1360892424,
            "updated_at":1360892424,
            "response_code":"20000",
            "invoices":[

            ],
            "payment":{
              "id":"pay_e7f0738e00f3cd57ff00c60f9b72",
              "type":"creditcard",
              "client":"client_17c00b38c5b6fc62c3e6",
              "card_type":"mastercard",
              "country":null,
              "expire_month":9,
              "expire_year":2014,
              "card_holder":null,
              "last4":"5100",
              "created_at":1360892423,
              "updated_at":1360892424
            },
            "client":{
              "id":"client_17c00b38c5b6fc62c3e6",
              "email":null,
              "description":null,
              "created_at":1360892424,
              "updated_at":1360892424,
              "payment":[
                "pay_e7f0738e00f3cd57ff00c60f9b72"
              ],
                "subscription":null
            },
            "preauthorization":null
          }
        },
        "mode":"test"
      }
    JSON
  end

  def failed_refund_response
    MockResponse.new 412, %[{"error":"Amount to high","exception":"refund_amount_to_high"}]
  end

  def broken_gateway_response
    MockResponse.new(404, "File not found.\n")
  end

  def failed_capture_response
    MockResponse.new 409, %[{"error":"Preauthorization has already been used","exception":"preauthorization_already_used"}]
  end

  def transcript
    "connection_uri=https://test-token.paymill.com?account.number=5500000000000004&account.expiry.month=09&account.expiry.year=2016&account.verification=123"
  end

  def scrubbed_transcript
    "connection_uri=https://test-token.paymill.com?account.number=[FILTERED]&account.expiry.month=09&account.expiry.year=2016&account.verification=[FILTERED]"
  end

end
