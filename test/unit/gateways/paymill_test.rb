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
    assert_equal "Transaction approved", response.message
    assert_equal 20000, response.params['data']['response_code']
    assert_equal 'pay_b8e6a28fc5e5e1601cdbefbaeb8a', response.params['data']['payment']['id']
    assert_equal '5100', response.params['data']['payment']['last4']
    assert_nil response.cvv_result["message"]
    assert_nil response.avs_result["message"]
    assert response.test?
  end

  def test_failed_purchase_with_invalid_credit_card
    @gateway.expects(:raw_ssl_request).returns(failed_store_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Account or Bank Details Incorrect', response.message
    assert_equal '000.100.201', response.params['transaction']['processing']['return']['code']
  end

  def test_invalid_login
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, failed_login_response)
    response = @gateway.purchase(@amount, @credit_card)
    assert_failure response
    assert_equal 'Access Denied', response.message
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

    assert_equal "tran_50fb13e10636cf1e59e13018d100;preauth_57c0c87ae3d193f66dc8", response.authorization
    assert_equal "Transaction approved", response.message
    assert_equal '5100', response.params['data']['payment']['last4']
    assert_equal 10001, response.params['data']['response_code']
    assert_nil response.avs_result["message"]
    assert_nil response.cvv_result["message"]

    @gateway.expects(:raw_ssl_request).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
    assert response.test?
    assert_equal 20000, response.params['data']['response_code']
    assert_equal "Transaction approved", response.message
  end

  def test_successful_authorize_and_void
    @gateway.stubs(:raw_ssl_request).returns(successful_store_response, successful_authorize_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_success response

    @gateway.expects(:raw_ssl_request).returns(successful_void_response)
    response = @gateway.void(response.authorization)
    assert_success response
    assert response.test?
    assert_equal "Transaction approved", response.message
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

    assert_equal 'Transaction approved', refund.message
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
    assert_equal "Transaction approved", response.message
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

    assert_equal "tran_50fb13e10636cf1e59e13018d100;preauth_57c0c87ae3d193f66dc8", response.authorization
    assert_equal "Transaction approved", response.message
    assert_equal '5100', response.params['data']['payment']['last4']
    assert_equal 10001, response.params['data']['response_code']
    assert_nil response.avs_result["message"]
    assert_nil response.cvv_result["message"]
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

  def successful_authorize_response
    MockResponse.succeeded <<-JSON
      { "data":{
        "id":"tran_50fb13e10636cf1e59e13018d100",
        "amount":"100",
        "origin_amount":100,
        "status":"preauth",
        "description":null,
        "livemode":false,
        "refunds":null,
        "currency":"EUR",
        "created_at":1360787311,
        "updated_at":1360787311,
        "response_code":10001,
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

  def failed_refund_response
    MockResponse.new 412, %[{"error":"Amount to high","exception":"refund_amount_to_high"}]
  end

  def failed_capture_response
    MockResponse.new 409, %[{"error":"Preauthorization has already been used","exception":"preauthorization_already_used"}]
  end

  class MockResponse
    attr_reader :code, :body
    def self.succeeded(body)
      MockResponse.new(200, body)
    end

    def self.failed(body)
      MockResponse.new(422, body)
    end

    def initialize(code, body, headers={})
      @code, @body, @headers = code, body, headers
    end

    def [](header)
      @headers[header]
    end
  end
end
