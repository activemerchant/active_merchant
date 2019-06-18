require 'test_helper'

class PaydockTest < Test::Unit::TestCase
  def setup
    @gateway = PaydockGateway.new(login: 'login', password: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_includes response.authorization, 'h=5d08379bef7c2f6cb93d6775'

    # Check PaydockGateway#AUTHORIZATION_MAP for auth references
    coded_response = {
      'e': 'activemerchant@paydock.com',
      'f': 'Longbob',
      'g': '5ccad9177a0295264d275a19',
      'h': '5d08379bef7c2f6cb93d6775',
      'l': 'Longsen',
      'x': 'ch_EqORMS6flGUo8lDEXWjk_g'
    }.to_param

    assert_equal response.authorization, coded_response

    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api-sandbox.paydock.com:443...
      opened
      starting SSL for api-sandbox.paydock.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/json\r\nX-Accepts: application/json\r\nUser-Agent: ActiveMerchant/1.78.0\r\nX-Client-Ip: \r\nX-User-Secret-Key: b10ed24a2e3a1c7afdcd0ef11342f97ccbffeb63\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api-sandbox.paydock.com\r\nContent-Length: 336\r\n\r\n"
      <- "{\"amount\":\"56.00\",\"currency\":\"AUD\",\"description\":\"Store Purchase\",\"customer\":{\"email\":\"activemerchant@paydock.com\",\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"payment_source\":{\"card_name\":\"Longbob Longsen\",\"card_number\":\"4200000000000000\",\"card_ccv\":\"123\",\"expire_month\":9,\"expire_year\":2020,\"gateway_id\":\"5ccad9177a0295264d275a19\"}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx/1.14.1\r\n"
      -> "Date: Tue, 18 Jun 2019 06:27:13 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 969\r\n"
      -> "Connection: close\r\n"
      -> "Vary: X-HTTP-Method-Override\r\n"
      -> "X-Powered-By: PayDock <paydock.com>\r\n"
      -> "ETag: W/\"3c9-lkldh/ZM1dWYpqFn6pGVZg\"\r\n"
      -> "Strict-Transport-Security: max-age=15768000\r\n"
      -> "\r\n"
      reading 969 bytes...
      -> "{\"status\":201,\"error\":null,\"resource\":{\"type\":\"charge\",\"data\":{\"external_id\":\"ch_8FoZyQNBhtlBHXVyOo689g\",\"_id\":\"5d088440d229113e59ea4165\",\"created_at\":\"2019-06-18T06:27:12.802Z\",\"updated_at\":\"2019-06-18T06:27:13.292Z\",\"company_id\":\"5ccad678f0f03c7a14242404\",\"user_id\":\"5ccad678f0f03c7a14242403\",\"amount\":56,\"currency\":\"AUD\",\"description\":\"Store Purchase\",\"__v\":1,\"transactions\":[{\"created_at\":\"2019-06-18T06:27:12.798Z\",\"amount\":56,\"currency\":\"AUD\",\"_id\":\"5d088440d229113e59ea4166\",\"_source_ip_address\":\"112.141.28.74\",\"status\":\"complete\",\"type\":\"sale\"}],\"one_off\":true,\"archived\":false,\"customer\":{\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"email\":\"activemerchant@paydock.com\",\"payment_source\":{\"card_name\":\"Longbob Longsen\",\"card_number_last4\":\"0000\",\"expire_month\":9,\"expire_year\":2020,\"gateway_id\":\"5ccad9177a0295264d275a19\",\"card_scheme\":\"visa\",\"gateway_name\":\"Pin\",\"gateway_type\":\"Pin\"}},\"capture\":true,\"status\":\"complete\",\"items\":[],\"transfer\":{\"items\":[]}}}}"
      read 969 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api-sandbox.paydock.com:443...
      opened
      starting SSL for api-sandbox.paydock.com:443...
      SSL established
      <- "POST /v1/charges HTTP/1.1\r\nContent-Type: application/json\r\nX-Accepts: application/json\r\nUser-Agent: ActiveMerchant/1.78.0\r\nX-Client-Ip: \r\nX-User-Secret-Key: [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: api-sandbox.paydock.com\r\nContent-Length: 336\r\n\r\n"
      <- "{\"amount\":\"56.00\",\"currency\":\"AUD\",\"description\":\"Store Purchase\",\"customer\":{\"email\":\"activemerchant@paydock.com\",\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"payment_source\":{\"card_name\":\"Longbob Longsen\",\"card_number\":\"[FILTERED]\",\"card_ccv\":\"[FILTERED]\",\"expire_month\":9,\"expire_year\":2020,\"gateway_id\":\"[FILTERED]\"}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx/1.14.1\r\n"
      -> "Date: Tue, 18 Jun 2019 06:27:13 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 969\r\n"
      -> "Connection: close\r\n"
      -> "Vary: X-HTTP-Method-Override\r\n"
      -> "X-Powered-By: PayDock <paydock.com>\r\n"
      -> "ETag: W/\"3c9-lkldh/ZM1dWYpqFn6pGVZg\"\r\n"
      -> "Strict-Transport-Security: max-age=15768000\r\n"
      -> "\r\n"
      reading 969 bytes...
      -> "{\"status\":201,\"error\":null,\"resource\":{\"type\":\"charge\",\"data\":{\"external_id\":\"ch_8FoZyQNBhtlBHXVyOo689g\",\"_id\":\"5d088440d229113e59ea4165\",\"created_at\":\"2019-06-18T06:27:12.802Z\",\"updated_at\":\"2019-06-18T06:27:13.292Z\",\"company_id\":\"5ccad678f0f03c7a14242404\",\"user_id\":\"5ccad678f0f03c7a14242403\",\"amount\":56,\"currency\":\"AUD\",\"description\":\"Store Purchase\",\"__v\":1,\"transactions\":[{\"created_at\":\"2019-06-18T06:27:12.798Z\",\"amount\":56,\"currency\":\"AUD\",\"_id\":\"5d088440d229113e59ea4166\",\"_source_ip_address\":\"112.141.28.74\",\"status\":\"complete\",\"type\":\"sale\"}],\"one_off\":true,\"archived\":false,\"customer\":{\"first_name\":\"Longbob\",\"last_name\":\"Longsen\",\"email\":\"activemerchant@paydock.com\",\"payment_source\":{\"card_name\":\"Longbob Longsen\",\"card_number_last4\":\"0000\",\"expire_month\":9,\"expire_year\":2020,\"gateway_id\":\"[FILTERED]\",\"card_scheme\":\"visa\",\"gateway_name\":\"Pin\",\"gateway_type\":\"Pin\"}},\"capture\":true,\"status\":\"complete\",\"items\":[],\"transfer\":{\"items\":[]}}}}"
      read 969 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-eos
    {
      "status":201,
      "error":null,
      "resource": {
        "type":"charge",
        "data":{
          "external_id":"ch_EqORMS6flGUo8lDEXWjk_g",
          "_id":"5d08379bef7c2f6cb93d6775",
          "created_at":"2019-06-18T01:00:11.224Z",
          "updated_at":"2019-06-18T01:00:12.110Z",
          "company_id":"5ccad678f0f03c7a14242404",
          "user_id":"5ccad678f0f03c7a14242403",
          "amount":56,
          "currency":"AUD",
          "description":"Store Purchase",
          "__v":1,
          "transactions":[
            {
              "created_at":"2019-06-18T01:00:11.223Z",
              "amount":56,
              "currency":"AUD",
              "_id":"5d08379bef7c2f6cb93d6776",
              "_source_ip_address":"112.141.28.74",
              "status":"complete",
              "type":"sale"
            }
          ],
          "one_off":true,
          "archived":false,
          "customer":{
            "first_name":"Longbob",
            "last_name":"Longsen",
            "email":"activemerchant@paydock.com",
            "payment_source":{
              "card_name":"Longbob Longsen",
              "card_number_last4":"0000",
              "expire_month":9,
              "expire_year":2020,
              "gateway_id":"5ccad9177a0295264d275a19",
              "card_scheme":"mastercard",
              "gateway_name":"Pin",
              "gateway_type":"Pin"
            }
          },
          "capture":true,
          "status":"complete",
          "items":[],
          "transfer":{ "items":[] }
        }
      }
    }
    eos
  end

  def failed_purchase_response
    <<-eos
      {
        "status":400,
        "error":{
          "message":"Credit Card Invalid or Expired",
          "details":[
            {
              "gateway_specific_code":"card_declined",
              "gateway_specific_description":"The card was declined",
              "param_name":"card_number",
              "description":"Credit Card Invalid or Expired"
            }
          ]
        },
        "resource":{
          "type":"charge",
          "data":{
            "_id":"5d0844a4ef7c2f6cb93d67c7",
            "created_at":"2019-06-18T01:55:48.290Z",
            "updated_at":"2019-06-18T01:55:48.815Z",
            "company_id":"5ccad678f0f03c7a14242404",
            "user_id":"5ccad678f0f03c7a14242403",
            "amount":42,
            "currency":"AUD",
            "description":"Store Purchase",
            "__v":1,
            "transactions":[
              {
                "created_at":"2019-06-18T01:55:48.288Z",
                "amount":42,
                "currency":"AUD",
                "_id":"5d0844a4ef7c2f6cb93d67c8",
                "_source_ip_address":"112.141.28.74",
                "service_logs":[
                  {
                    "req":{
                      "body":{
                        "amount":4200,
                        "currency":"AUD",
                        "description":"Store Purchase",
                        "email":"activemerchant@paydock.com",
                        "ip_address":"127.0.0.1",
                        "card":{
                          "number":"************0001",
                          "expiry_month":"09",
                          "expiry_year":2020,
                          "cvc":"***",
                          "name":"************"
                        }
                      }
                    },
                    "response_body":{
                      "error":"card_declined",
                      "error_description":"The card was declined",
                      "charge_token":"ch_H5eGpP3G30v9vy-JEvnmuA",
                      "code":"card_declined"
                    },
                    "created_at":"2019-06-18T01:55:48.788Z",
                    "_id":"5d0844a4ef7c2f6cb93d67c9"
                  }
                ],
                "status":"failed",
                "type":"sale"
              }
            ],
            "one_off":true,
            "archived":false,
            "customer":{
              "first_name":"Longbob",
              "last_name":"Longsen",
              "email":"activemerchant@paydock.com",
              "payment_source":{
                "card_name":"Longbob Longsen",
                "card_number_last4":"0001",
                "expire_month":9,
                "expire_year":2020,
                "gateway_id":"5ccad9177a0295264d275a19",
                "card_scheme":"mastercard",
                "gateway_name":"Pin",
                "gateway_type":"Pin"
              }
            },
            "capture":true,
            "status":"failed",
            "items":[],
            "transfer":{"items":[]}
          }
        }
      }
    eos
  end
end
