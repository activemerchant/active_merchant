require 'test_helper'

class PagarmeTest < Test::Unit::TestCase
  def setup
    #ak_test_e1QGU2gL98MDCHZxHLJ9sofPUFJ7tH
    @gateway = PagarmeGateway.new(username: 'ak_test_47vpijcN54kvjmoniEvvVR6UuuJH4V')

    @credit_card = credit_card('4242424242424242', {
        first_name: 'Richard',
        last_name: 'Deschamps'
    })

    @amount = 1000

    @options = {
        order_id: '1',
        ip: '127.0.0.1',
        customer: 'Richard Deschamps',
        invoice: '1',
        merchant: 'Richard\'s',
        description: 'Store Purchase',
        email: 'suporte@pagar.me',
        billing_address: address(),
        card_hash: "card_ci6y37hc00030a416wrxsmzyi"
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 427312, response.authorization
    assert_equal @amount, response.params["amount"]

    assert_equal @credit_card.name, response.params["card"]["holder_name"]
    assert_equal @credit_card.last_digits, response.params["card"]["last_digits"]
    assert_equal @credit_card.brand, response.params["card"]["brand"]

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'paid', response.params["status"]
    assert_equal 'Transação aprovada', response.message
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code

    assert_equal 'refused', response.params["status"]
    assert_equal 'Transação recusada', response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 429356, response.authorization
    assert_equal @amount, response.params["amount"]

    assert_equal @credit_card.name, response.params["card"]["holder_name"]
    assert_equal @credit_card.last_digits, response.params["card"]["last_digits"]
    assert_equal @credit_card.brand, response.params["card"]["brand"]

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'authorized', response.params["status"]
    assert_equal 'Transação autorizada', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code

    assert_equal 'refused', response.params["status"]
    assert_equal 'Transação recusada', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, 429356, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 429356, response.authorization
    assert_equal @amount, response.params["amount"]

    assert_equal @credit_card.name, response.params["card"]["holder_name"]
    assert_equal @credit_card.last_digits, response.params["card"]["last_digits"]
    assert_equal @credit_card.brand, response.params["card"]["brand"]

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'paid', response.params["status"]
    assert_equal 'Transação aprovada', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, 429356, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code

    assert_equal 'Transação com status \'captured\' não pode ser capturada.', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 429356, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 429356, response.authorization

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'refunded', response.params["status"]
    assert_equal 'Transação estornada', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, 429356, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code

    assert_equal 'Transação já estornada', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void(472218, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 472218, response.authorization

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'refunded', response.params["status"]
    assert_equal 'Transação estornada', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void(472218, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code

    assert_equal 'Transação já estornada', response.message
  end

  def test_successful_verify
    s = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_verify_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_verify_void_response).in_sequence(s)

    response = @gateway.verify(@credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 127, response.params["amount"]

    assert_equal @credit_card.name, response.params["card"]["holder_name"]
    assert_equal @credit_card.last_digits, response.params["card"]["last_digits"]
    assert_equal @credit_card.brand, response.params["card"]["brand"]

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'authorized', response.params["status"]
    assert_equal 'Transação autorizada', response.message

    assert_success response.responses[1]
    assert_equal 'refunded', response.responses[1].params["status"]
    assert_equal 'Transação estornada', response.responses[1].message

    assert response.test?
  end

  def test_successful_verify_with_failed_void
    s = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_verify_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(failed_void_response).in_sequence(s)

    response = @gateway.verify(@credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 127, response.params["amount"]

    assert_equal @credit_card.name, response.params["card"]["holder_name"]
    assert_equal @credit_card.last_digits, response.params["card"]["last_digits"]
    assert_equal @credit_card.brand, response.params["card"]["brand"]

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'authorized', response.params["status"]
    assert_equal 'Transação autorizada', response.message

    assert_failure response.responses[1]
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.responses[1].error_code
    assert_equal 'Transação já estornada', response.responses[1].message
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code

    assert_equal 127, response.params["amount"]
    assert_equal 'refused', response.params["status"]
    assert_equal 'Transação recusada', response.message
  end

  def test_generic_error
    @gateway.expects(:ssl_request).returns(failed_error_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
    assert_equal 'Internal server error.', response.message
  end

  def test_failed_json_body
    @gateway.expects(:ssl_request).returns(failed_json_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code

    assert response.message.start_with?("Resposta inválida")
  end


  def test_successful_recurring
    @gateway.expects(:ssl_request).returns(successful_recurring_response)

    @options = {
        order_id: '1',
        ip: '127.0.0.1',
        customer: {
          document_number: "94123506518",
          id: "70941",
          legal_identifier: "18152564000105",
          name: "nome do cliente",
          email: "eee@email.com",
          born_at: 13121988,
          gender: "M",
          :phone => {
            :ddi => 55,
            :ddd => 11,
            :number => 999887766
          }
        },
        address: {
          street: "rua qualquer",
          complement: "apto",
          number: 13,
          district: "pinheiros",
          city: "sao paulo",
          state: "SP",
          zipcode: "05444040",
          country: "Brasil"
        },
        card_number: "4901720080344448",
        card_holder_name: "Jose da Silva",
        card_expiration_month: "10",
        card_expiration_year: "21",
        card_cvv: "314",
        plan_code: 40408,
        payment_method: 'credit_card',
        invoice: '1',
        merchant: 'Richard\'s',
        description: 'Store Purchase',
        email: 'suporte@pagar.me',
        billing_address: address(),
        card_hash: "card_ci6y37hc00030a416wrxsmzyi"
    }
    response = @gateway.recurring(@amount, @credit_card, @options)

    assert_instance_of Response, response

    assert_equal 'credit_card', response.params["payment_method"]
    assert_equal 'paid', response.params["status"]
    assert_equal 'Transação aprovada', response.message
    assert response.test?
  end
  #
  # def test_get_invoice
  #   @gateway.expects(:ssl_request).returns(success_invoice_response)
  #
  #   response = @gateway.invoice("502012")
  #
  #   assert_instance_of Response, response
  #   #assert_success response
  #
  #   assert_equal 'credit_card', response.params["payment_method"]
  #   assert_equal 'paid', response.params["action"]
  #   assert response.test?
  #
  # end
  #
  #
  # def test_get_invoices
  #
  #   # @gateway.expects(:ssl_post).returns(success_invoice_response)
  #
  #   response = @gateway.invoices('58706')
  #
  #   puts response.params
  # end

  def test_success_find_plan
    @gateway.expects(:ssl_request).returns(success_plan_response)

    response = @gateway.find_plan(13731)

    assert_instance_of Response, response
    #assert_success response

    assert_equal 'Plano Diamond', response.params["name"]
    assert_equal 30, response.params["days"]
    assert response.test?
  end

  def test_failed_find_plan_on_nil_param
    @gateway.expects(:ssl_request).returns(failed_find_plan_response_on_nil_param)

    response = @gateway.find_plan(nil)

    assert_instance_of Response, response
    #assert_success response

    assert_equal 'internal_error', response.params["errors"][0]["type"]
    assert_equal 'Internal server error.', response.params["errors"][0]["message"]
    assert response.test?
  end

  def test_failed_find_plan_on_plan_not_exists
    @gateway.expects(:ssl_request).returns(failed_find_plan_response)

    response = @gateway.find_plan(137352)

    assert_instance_of Response, response
    #assert_success response

    assert_equal 'not_found', response.params["errors"][0]["type"]
    assert_equal 'Plan não encontrado', response.params["errors"][0]["message"]
    assert response.test?
  end

  def test_success_create_plan
    @gateway.expects(:ssl_request).returns(success_plan_response)

    params_plan = {
        name: "Plano Diamond",
        days: "30",
        price: @amount
    }

    response = @gateway.create_plan(params_plan)

    assert_instance_of Response, response
    #assert_success response

    assert_equal 'Plano Diamond', response.params["name"]
    assert_equal 30, response.params["days"]
    assert response.test?
  end

  def test_failed_create_plan
    @gateway.expects(:ssl_request).returns(failed_create_plan_response)

    params_plan = {}

    response = @gateway.create_plan(params_plan)

    assert_instance_of Response, response
    #assert_success response

    assert_equal 'amount', response.params["errors"][0]["parameter_name"]
    assert_equal 'invalid_parameter', response.params["errors"][0]["type"]
    assert_equal 'valor está faltando', response.params["errors"][0]["message"]

    assert_equal 'days', response.params["errors"][1]["parameter_name"]
    assert_equal 'invalid_parameter', response.params["errors"][1]["type"]
    assert_equal 'número de dias está faltando', response.params["errors"][1]["message"]

    assert_equal 'name', response.params["errors"][2]["parameter_name"]
    assert_equal 'invalid_parameter', response.params["errors"][2]["type"]
    assert_equal 'nome está faltando', response.params["errors"][2]["message"]
  end

  def test_success_update_plan
    @gateway.expects(:ssl_request).returns(success_plan_update_response)

    params_plan = {
        name: "Plano Diamond Platinum",
        days: 25,
        plan_code: 13731
    }

    response = @gateway.update_plan(params_plan)

    assert_instance_of Response, response
    #assert_success response

    assert_equal 'Plano Diamond Platinum', response.params["name"]
    assert_equal 25, response.params["days"]
    assert response.test?
  end

  def test_failed_update_plan_plan_not_found
    @gateway.expects(:ssl_request).returns(failed_update_plan_plan_not_found_response)

    params_plan = {
        name: "Plano Diamond Gold",
        days: 25,
        plan_code: 1373222
    }

    response = @gateway.update_plan(params_plan)

    assert_instance_of Response, response
    #assert_success response

    assert_equal 'not_found', response.params["errors"][0]['type']
    assert_equal 'Plan not found.', response.params["errors"][0]['message']
    assert_equal nil, response.params["errors"][0]['parameter_name']
    assert response.test?
  end

  # def test_get_payments
  #
  # #@gateway.expects(:ssl_post).returns(success_invoice_response)
  #
  # response = @gateway.payments("502012")
  #
  #
  # assert_equal response.to_yaml, success_invoice_response
  #
  # end

  # def test_get_payment
  #
  # #@gateway.expects(:ssl_post).returns(success_invoice_response)
  #
  # response = @gateway.payment("502012","29006")
  #
  #
  # assert_equal response.to_yaml, success_invoice_response
  #
  # end


  # def test_update_subscription
  #   params = {
  #       card_expiration_date: "0913",
  #       payment_method: "boleto"
  #   }
  #   @gateway.update(58163, params)
  # end

  # def test_cancel
  #   @gateway.cancel(58163)
  # end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def success_plan_update_response
    <<-SUCCESS_UPDATE_PLAN_RESPONSE
    {
        "object": "plan",
        "id": 13731,
        "amount": 31000,
        "days": 25,
        "name": "Plano Diamond Platinum",
        "trial_days": 7,
        "date_created": "2015-03-03T17:31:47.000Z",
        "payment_methods": [
            "boleto"
        ],
        "color": "gold",
        "charges": null,
        "installments": 1
    }
    SUCCESS_UPDATE_PLAN_RESPONSE
  end

  def success_plan_response
    <<-SUCCESS_PLAN_RESPONSE
    {
        "object": "plan",
        "id": 13731,
        "amount": 31000,
        "days": 30,
        "name": "Plano Diamond",
        "trial_days": 7,
        "date_created": "2015-03-03T17:31:47.000Z",
        "payment_methods": [
            "boleto"
        ],
        "color": "gold",
        "charges": null,
        "installments": 1
    }
    SUCCESS_PLAN_RESPONSE
  end

  def failed_find_plan_response
    <<-FAILED_FIND_PLAN_RESPONSE
    {
       "errors":[
          {
             "type":"not_found",
             "parameter_name":null,
             "message":"Plan não encontrado"
          }
       ],
       "url":"/plans/34234",
       "method":"get"
    }
    FAILED_FIND_PLAN_RESPONSE
  end

  def failed_find_plan_response_on_nil_param
    <<-FAILED_FIND_PLAN_RESPONSE_ON_NIL_PARAM
    {
       "errors":[
          {
             "type":"internal_error",
             "parameter_name":null,
             "message":"Internal server error."
          }
       ],
       "url":"/plans/nil",
       "method":"get"
    }
    FAILED_FIND_PLAN_RESPONSE_ON_NIL_PARAM
  end

  def failed_update_plan_plan_not_found_response
    <<-FAILED_FIND_PLAN_RESPONSE
    {
       "errors":[
          {
             "type":"not_found",
             "parameter_name":null,
             "message":"Plan not found."
          }
       ]
    }
    FAILED_FIND_PLAN_RESPONSE
  end

  def failed_create_plan_response
    <<-FAILED_FIND_PLAN_RESPONSE
    {
       "errors":[
          {
             "parameter_name":"amount",
             "type":"invalid_parameter",
             "message":"valor está faltando"
          },
          {
             "parameter_name":"days",
             "type":"invalid_parameter",
             "message":"número de dias está faltando"
          },
          {
             "parameter_name":"name",
             "type":"invalid_parameter",
             "message":"nome está faltando"
          }
       ],
       "url":"/plans",
       "method":"post"
    }
    FAILED_FIND_PLAN_RESPONSE
  end

  def success_invoice_response
    <<-SUCCESS_INVOICE_RESPONSE
      {
         "id":502012,
         "amount":15151,
         "created_at":"2016-06-01T01:02:51.467Z",
         "action":"paid",
         "object":"transaction",
         "refuse_reason":null,
         "status_reason":"acquirer",
         "acquirer_response_code":"00",
         "acquirer_name":"pagarme",
         "authorization_code":"216288",
         "soft_descriptor":null,
         "tid":502012,
         "nsu":502012,
         "updated_at":"2016-06-01T01:02:51.903Z",
         "installments":1,
         "cost":120,
         "postback_url":null,
         "payment_method":"credit_card",
         "antifraud_score":70.31,
         "boleto_url":null,
         "boleto_barcode":null,
         "boleto_expiration_date":null,
         "referer":"api_key",
         "ip":"189.107.109.252",
         "subscription_id":58223,
         "phone":{
            "ddd":"11",
            "ddi":"55",
            "number":"999887766"
         },
         "address":{
            "object":"address",
            "street":"rua qualquer",
            "complementary":"apto",
            "street_number":"13",
            "neighborhood":"pinheiros",
            "city":"sao paulo",
            "state":"SP",
            "zipcode":"05444040",
            "country":"Brasil",
            "id":33499
         },
         "customer":{
            "object":"customer",
            "document_number":"18152564000105",
            "document_type":"cnpj",
            "name":"nome do cliente",
            "email":"eee@email.com",
            "born_at":null,
            "gender":null,
            "date_created":"2016-05-31T15:30:48.246Z",
            "id":70045
         },
         "card":{
            "object":"card",
            "id":"card_ciovmgj16000e3w6e879dy79m",
            "date_created":"2016-05-31T15:51:43.963Z",
            "date_updated":"2016-05-31T15:51:44.353Z",
            "brand":"visa",
            "holder_name":"Jose da Silva",
            "first_digits":"490172",
            "last_digits":"4448",
            "fingerprint":"l39iC1lfQakA",
            "valid":true
         },
         "metadata":{

         },
         "antifraud_metadata":{

         }
      }
    SUCCESS_INVOICE_RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.pagar.me:443...
      opened
      starting SSL for api.pagar.me:443...
      SSL established
      <- "POST /1/transactions HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic YWtfdGVzdF9sTmxMNHF3Z0RVQ1VoQk1PWElqRnBSSmdXSkpOZjM6eA==\r\nUser-Agent: Pagar.me/1 ActiveMerchant/1.58.0\r\nAccept-Encoding: deflate\r\nAccept: */*\r\nConnection: close\r\nHost: api.pagar.me\r\nContent-Length: 196\r\n\r\n"
      <- "amount=1000&payment_method=credit_card&card_number=4242424242424242&card_holder_name=Richard+Deschamps&card_expiration_date=9%2F2017&card_cvv=123&metadata[description]=ActiveMerchant+Test+Purchase"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-HTTP-Method-Override\r\n"
      -> "Access-Control-Allow-Methods: GET,PUT,POST,DELETE\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Charset: utf-8\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Wed, 23 Mar 2016 08:17:52 GMT\r\n"
      -> "ETag: \"1486888623\"\r\n"
      -> "Server: nginx\r\n"
      -> "X-Powered-By: Express\r\n"
      -> "X-Response-Time: 260ms\r\n"
      -> "Content-Length: 1217\r\n"
      -> "Connection: Close\r\n"
      -> "Set-Cookie: visid_incap_166741=4xzkgPXeQ66jO1Z91iibOjxR8lYAAAAAQUIPAAAAAADBzoQck8nwH8iJzqUkDgR6; expires=Wed, 22 Mar 2017 14:07:58 GMT; path=/; Domain=.pagar.me\r\n"
      -> "Set-Cookie: nlbi_166741=XR6HTRng0zFBQUS2W7H6TQAAAADCwTVJNcjRvaX6/996Dj8I; path=/; Domain=.pagar.me\r\n"
      -> "Set-Cookie: incap_ses_297_166741=4loNMgeLdj0PSeV/BCgfBDxR8lYAAAAAgi6H8uNqma8hraBXzDFdzQ==; path=/; Domain=.pagar.me\r\n"
      -> "X-Iinfo: 6-56899509-56899511 NNNN CT(143 143 0) RT(1458721083333 27) q(0 0 3 -1) r(7 7) U6\r\n"
      -> "X-CDN: Incapsula\r\n"
      -> "\r\n"
      reading 1217 bytes...
      -> "{\"object\":\"transaction\",\"status\":\"paid\",\"refuse_reason\":null,\"status_reason\":\"acquirer\",\"acquirer_response_code\":\"00\",\"acquirer_name\":\"development\",\"authorization_code\":\"606507\",\"soft_descriptor\":null,\"tid\":1458721084304,\"nsu\":1458721084304,\"date_created\":\"2016-03-23T08:18:04.162Z\",\"date_updated\":\"2016-03-23T08:18:04.388Z\",\"amount\":1000,\"authorized_amount\":1000,\"paid_amount\":1000,\"refunded_amount\":0,\"installments\":1,\"id\":428211,\"cost\":65,\"card_holder_name\":\"Richard Deschamps\",\"card_last_digits\":\"4242\",\"card_first_digits\":\"424242\",\"card_brand\":\"visa\",\"postback_url\":null,\"payment_method\":\"credit_card\",\"capture_method\":\"ecommerce\",\"antifraud_score\":null,\"boleto_url\":null,\"boleto_barcode\":null,\"boleto_expiration_date\":null,\"referer\":\"api_key\",\"ip\":\"179.191.82.50\",\"subscription_id\":null,\"phone\":null,\"address\":null,\"customer\":null,\"card\":{\"object\":\"card\",\"id\":\"card_cim4ccq3p00q1ju6e4aw4tdon\",\"date_created\":\"2016-03-23T04:19:38.917Z\",\"date_updated\":\"2016-03-23T04:19:39.160Z\",\"brand\":\"visa\",\"holder_name\":\"Richard Deschamps\",\"first_digits\":\"424242\",\"last_digits\":\"4242\",\"country\":\"US\",\"fingerprint\":\"VpmCgO7Ub/rS\",\"valid\":true},\"metadata\":{\"description\":\"ActiveMerchant Test Purchase\"},\"antifraud_metadata\":{}}"
      read 1217 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api.pagar.me:443...
      opened
      starting SSL for api.pagar.me:443...
      SSL established
      <- "POST /1/transactions HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]==\r\nUser-Agent: Pagar.me/1 ActiveMerchant/1.58.0\r\nAccept-Encoding: deflate\r\nAccept: */*\r\nConnection: close\r\nHost: api.pagar.me\r\nContent-Length: 196\r\n\r\n"
      <- "amount=1000&payment_method=credit_card&card_number=[FILTERED]&card_holder_name=Richard+Deschamps&card_expiration_date=9%2F2017&card_cvv=[FILTERED]&metadata[description]=ActiveMerchant+Test+Purchase"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, X-HTTP-Method-Override\r\n"
      -> "Access-Control-Allow-Methods: GET,PUT,POST,DELETE\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Charset: utf-8\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Wed, 23 Mar 2016 08:17:52 GMT\r\n"
      -> "ETag: \"1486888623\"\r\n"
      -> "Server: nginx\r\n"
      -> "X-Powered-By: Express\r\n"
      -> "X-Response-Time: 260ms\r\n"
      -> "Content-Length: 1217\r\n"
      -> "Connection: Close\r\n"
      -> "Set-Cookie: visid_incap_166741=4xzkgPXeQ66jO1Z91iibOjxR8lYAAAAAQUIPAAAAAADBzoQck8nwH8iJzqUkDgR6; expires=Wed, 22 Mar 2017 14:07:58 GMT; path=/; Domain=.pagar.me\r\n"
      -> "Set-Cookie: nlbi_166741=XR6HTRng0zFBQUS2W7H6TQAAAADCwTVJNcjRvaX6/996Dj8I; path=/; Domain=.pagar.me\r\n"
      -> "Set-Cookie: incap_ses_297_166741=4loNMgeLdj0PSeV/BCgfBDxR8lYAAAAAgi6H8uNqma8hraBXzDFdzQ==; path=/; Domain=.pagar.me\r\n"
      -> "X-Iinfo: 6-56899509-56899511 NNNN CT(143 143 0) RT(1458721083333 27) q(0 0 3 -1) r(7 7) U6\r\n"
      -> "X-CDN: Incapsula\r\n"
      -> "\r\n"
      reading 1217 bytes...
      -> "{\"object\":\"transaction\",\"status\":\"paid\",\"refuse_reason\":null,\"status_reason\":\"acquirer\",\"acquirer_response_code\":\"00\",\"acquirer_name\":\"development\",\"authorization_code\":\"606507\",\"soft_descriptor\":null,\"tid\":1458721084304,\"nsu\":1458721084304,\"date_created\":\"2016-03-23T08:18:04.162Z\",\"date_updated\":\"2016-03-23T08:18:04.388Z\",\"amount\":1000,\"authorized_amount\":1000,\"paid_amount\":1000,\"refunded_amount\":0,\"installments\":1,\"id\":428211,\"cost\":65,\"card_holder_name\":\"Richard Deschamps\",\"card_last_digits\":\"4242\",\"card_first_digits\":\"424242\",\"card_brand\":\"visa\",\"postback_url\":null,\"payment_method\":\"credit_card\",\"capture_method\":\"ecommerce\",\"antifraud_score\":null,\"boleto_url\":null,\"boleto_barcode\":null,\"boleto_expiration_date\":null,\"referer\":\"api_key\",\"ip\":\"179.191.82.50\",\"subscription_id\":null,\"phone\":null,\"address\":null,\"customer\":null,\"card\":{\"object\":\"card\",\"id\":\"card_cim4ccq3p00q1ju6e4aw4tdon\",\"date_created\":\"2016-03-23T04:19:38.917Z\",\"date_updated\":\"2016-03-23T04:19:39.160Z\",\"brand\":\"visa\",\"holder_name\":\"Richard Deschamps\",\"first_digits\":\"424242\",\"last_digits\":\"4242\",\"country\":\"US\",\"fingerprint\":\"VpmCgO7Ub/rS\",\"valid\":true},\"metadata\":{\"description\":\"ActiveMerchant Test Purchase\"},\"antifraud_metadata\":{}}"
      read 1217 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-SUCCESS_RESPONSE
      {
        "acquirer_name": "development",
        "acquirer_response_code": "00",
        "address": null,
        "amount": 1000,
        "antifraud_metadata": {},
        "antifraud_score": null,
        "authorization_code": "799941",
        "authorized_amount": 1000,
        "boleto_barcode": null,
        "boleto_expiration_date": null,
        "boleto_url": null,
        "capture_method": "ecommerce",
        "card": {
          "brand": "visa",
          "country": "US",
          "date_created": "2015-11-06T03:39:13.000Z",
          "date_updated": "2016-03-22T20:40:02.907Z",
          "fingerprint": "W8EBIq2PN+qB",
          "first_digits": "424242",
          "holder_name": "Richard Deschamps",
          "id": "card_cign456uw00rsyp6d5qq0og97",
          "last_digits": "4242",
          "object": "card",
          "valid": true
        },
        "card_brand": "visa",
        "card_first_digits": "424242",
        "card_holder_name": "Richard Deschamps",
        "card_last_digits": "4242",
        "cost": 65,
        "customer": null,
        "date_created": "2016-03-22T20:40:02.917Z",
        "date_updated": "2016-03-22T20:40:03.193Z",
        "id": 427312,
        "installments": 1,
        "ip": "179.191.82.50",
        "metadata": {},
        "nsu": 1458679203081,
        "object": "transaction",
        "paid_amount": 1000,
        "payment_method": "credit_card",
        "phone": null,
        "postback_url": null,
        "referer": "api_key",
        "refunded_amount": 0,
        "refuse_reason": null,
        "soft_descriptor": null,
        "status": "paid",
        "status_reason": "acquirer",
        "subscription_id": null,
        "tid": 1458679203081
      }
    SUCCESS_RESPONSE
  end

  def successful_recurring_response
    <<-SUCCESS_RESPONSE
      {
      "object": "subscription",
      "plan": {
          "object": "plan",
          "id": 12783,
          "amount": 31000,
          "days": 30,
          "name": "Plano Ouro",
          "trial_days": 0,
          "date_created": "2015-03-03T16:56:32.000Z",
          "payment_methods": ["boleto", "credit_card"],
          "color": null,
          "charges": null,
          "installments": 1
      },
      "id": 16892,
      "current_transaction": {
          "object": "transaction",
          "status": "waiting_payment",
          "refuse_reason": null,
          "status_reason": "acquirer",
          "acquirer_response_code": null,
          "acquirer_name": "development",
          "authorization_code": null,
          "soft_descriptor": null,
          "tid": null,
          "nsu": null,
          "date_created": "2015-04-14T20:17:18.000Z",
          "date_updated": "2015-04-14T20:17:19.000Z",
          "amount": 31000,
          "installments": 1,
          "id": 194402,
          "cost": 0,
          "card_holder_name": null,
          "card_last_digits": null,
          "card_first_digits": null,
          "card_brand": null,
          "postback_url": null,
          "payment_method": "boleto",
          "antifraud_score": null,
          "boleto_url": "https://pagar.me",
          "boleto_barcode": "1234 5678",
          "boleto_expiration_date": "2015-04-21T20:17:18.000Z",
          "referer": "api_key",
          "ip": "179.185.132.108",
          "subscription_id": 16892,
          "metadata": {}
      },
      "postback_url": "http://requestb.in/zyn5obzy",
      "payment_method": "credit_card",
      "current_period_start": "2015-04-14T20:17:18.000Z",
      "current_period_end": "2015-05-14T20:17:18.000Z",
      "charges": 2,
      "status": "paid",
      "date_created": "2015-04-14T20:17:19.000Z",
      "phone": null,
      "address": null,
      "customer": {
          "object": "customer",
          "document_number": null,
          "document_type": "cpf",
          "name": null,
          "email": "api@test.com",
          "born_at": null,
          "gender": null,
          "date_created": "2015-03-04T18:40:03.000Z",
          "id": 14437
      },
      "card": null,
      "metadata": null
      }
    SUCCESS_RESPONSE
  end

  def failed_purchase_response
    <<-FAILED_RESPONSE
      {
        "acquirer_name": "development",
        "acquirer_response_code": "88",
        "address": null,
        "amount": 1000,
        "antifraud_metadata": {},
        "antifraud_score": null,
        "authorization_code": null,
        "authorized_amount": 0,
        "boleto_barcode": null,
        "boleto_expiration_date": null,
        "boleto_url": null,
        "capture_method": "ecommerce",
        "card": {
            "brand": "visa",
            "country": "US",
            "date_created": "2015-11-06T03:39:13.000Z",
            "date_updated": "2016-03-22T20:40:02.907Z",
            "fingerprint": "W8EBIq2PN+qB",
            "first_digits": "424242",
            "holder_name": "Richard Deschamps",
            "id": "card_cign456uw00rsyp6d5qq0og97",
            "last_digits": "4242",
            "object": "card",
            "valid": true
        },
        "card_brand": "visa",
        "card_first_digits": "424242",
        "card_holder_name": "Richard Deschamps",
        "card_last_digits": "4242",
        "cost": 0,
        "customer": null,
        "date_created": "2016-03-23T08:44:29.178Z",
        "date_updated": "2016-03-23T08:44:29.716Z",
        "id": 428235,
        "installments": 1,
        "ip": "179.191.82.50",
        "metadata": {},
        "nsu": 1458722669610,
        "object": "transaction",
        "paid_amount": 0,
        "payment_method": "credit_card",
        "phone": null,
        "postback_url": null,
        "referer": "api_key",
        "refunded_amount": 0,
        "refuse_reason": "acquirer",
        "soft_descriptor": null,
        "status": "refused",
        "status_reason": "acquirer",
        "subscription_id": null,
        "tid": 1458722669610
      }
    FAILED_RESPONSE
  end

  def successful_authorize_response
    <<-SUCCESS_RESPONSE
      {
        "acquirer_name": "development",
        "acquirer_response_code": "00",
        "address": null,
        "amount": 1000,
        "antifraud_metadata": {},
        "antifraud_score": null,
        "authorization_code": "231072",
        "authorized_amount": 1000,
        "boleto_barcode": null,
        "boleto_expiration_date": null,
        "boleto_url": null,
        "capture_method": "ecommerce",
        "card": {
            "brand": "visa",
            "country": "US",
            "date_created": "2015-11-06T03:39:13.000Z",
            "date_updated": "2016-03-22T20:40:02.907Z",
            "fingerprint": "W8EBIq2PN+qB",
            "first_digits": "424242",
            "holder_name": "Richard Deschamps",
            "id": "card_cign456uw00rsyp6d5qq0og97",
            "last_digits": "4242",
            "object": "card",
            "valid": true
        },
        "card_brand": "visa",
        "card_first_digits": "424242",
        "card_holder_name": "Richard Deschamps",
        "card_last_digits": "4242",
        "cost": 0,
        "customer": null,
        "date_created": "2016-03-24T18:29:56.523Z",
        "date_updated": "2016-03-24T18:29:56.742Z",
        "id": 429356,
        "installments": 1,
        "ip": "179.191.82.50",
        "metadata": {},
        "nsu": 1458844196661,
        "object": "transaction",
        "paid_amount": 0,
        "payment_method": "credit_card",
        "phone": null,
        "postback_url": null,
        "referer": "api_key",
        "refunded_amount": 0,
        "refuse_reason": null,
        "soft_descriptor": null,
        "status": "authorized",
        "status_reason": "acquirer",
        "subscription_id": null,
        "tid": 1458844196661
      }
    SUCCESS_RESPONSE
  end

  def failed_authorize_response
    <<-FAILED_RESPONSE
      {
        "acquirer_name": "development",
        "acquirer_response_code": "88",
        "address": null,
        "amount": 1000,
        "antifraud_metadata": {},
        "antifraud_score": null,
        "authorization_code": null,
        "authorized_amount": 0,
        "boleto_barcode": null,
        "boleto_expiration_date": null,
        "boleto_url": null,
        "capture_method": "ecommerce",
        "card": {
            "brand": "visa",
            "country": "US",
            "date_created": "2015-11-06T03:39:13.000Z",
            "date_updated": "2016-03-22T20:40:02.907Z",
            "fingerprint": "W8EBIq2PN+qB",
            "first_digits": "424242",
            "holder_name": "Richard Deschamps",
            "id": "card_cign456uw00rsyp6d5qq0og97",
            "last_digits": "4242",
            "object": "card",
            "valid": true
        },
        "card_brand": "visa",
        "card_first_digits": "424242",
        "card_holder_name": "Richard Deschamps",
        "card_last_digits": "4242",
        "cost": 0,
        "customer": null,
        "date_created": "2016-03-24T18:54:03.086Z",
        "date_updated": "2016-03-24T18:54:03.458Z",
        "id": 429402,
        "installments": 1,
        "ip": "179.191.82.50",
        "metadata": {},
        "nsu": 1458845643337,
        "object": "transaction",
        "paid_amount": 0,
        "payment_method": "credit_card",
        "phone": null,
        "postback_url": null,
        "referer": "api_key",
        "refunded_amount": 0,
        "refuse_reason": "acquirer",
        "soft_descriptor": null,
        "status": "refused",
        "status_reason": "acquirer",
        "subscription_id": null,
        "tid": 1458845643337
      }
    FAILED_RESPONSE
  end

  def successful_capture_response
    <<-SUCCESS_RESPONSE
      {
        "acquirer_name": "development",
        "acquirer_response_code": "00",
        "address": null,
        "amount": 1000,
        "antifraud_metadata": {},
        "antifraud_score": null,
        "authorization_code": "231072",
        "authorized_amount": 1000,
        "boleto_barcode": null,
        "boleto_expiration_date": null,
        "boleto_url": null,
        "capture_method": "ecommerce",
        "card": {
            "brand": "visa",
            "country": "US",
            "date_created": "2015-11-06T03:39:13.000Z",
            "date_updated": "2016-03-22T20:40:02.907Z",
            "fingerprint": "W8EBIq2PN+qB",
            "first_digits": "424242",
            "holder_name": "Richard Deschamps",
            "id": "card_cign456uw00rsyp6d5qq0og97",
            "last_digits": "4242",
            "object": "card",
            "valid": true
        },
        "card_brand": "visa",
        "card_first_digits": "424242",
        "card_holder_name": "Richard Deschamps",
        "card_last_digits": "4242",
        "cost": 65,
        "customer": null,
        "date_created": "2016-03-24T18:29:56.523Z",
        "date_updated": "2016-03-24T21:35:14.237Z",
        "id": 429356,
        "installments": 1,
        "ip": "179.191.82.50",
        "metadata": {},
        "nsu": "1458844196661",
        "object": "transaction",
        "paid_amount": 1000,
        "payment_method": "credit_card",
        "phone": null,
        "postback_url": null,
        "referer": "api_key",
        "refunded_amount": 0,
        "refuse_reason": null,
        "soft_descriptor": null,
        "status": "paid",
        "status_reason": "acquirer",
        "subscription_id": null,
        "tid": "1458844196661"
      }
    SUCCESS_RESPONSE
  end

  def failed_capture_response
    <<-FAILED_RESPONSE
    {
      "errors": [
        {
          "message": "Transação com status 'captured' não pode ser capturada.",
          "parameter_name": null,
          "type": "action_forbidden"
        }
      ],
      "method": "post",
      "url": "/transactions/429356/capture"
    }
    FAILED_RESPONSE
  end

  def successful_refund_response
    <<-SUCCESS_RESPONSE
    {
      "acquirer_name": "development",
      "acquirer_response_code": "00",
      "address": null,
      "amount": 1000,
      "antifraud_metadata": {},
      "antifraud_score": null,
      "authorization_code": "231072",
      "authorized_amount": 1000,
      "boleto_barcode": null,
      "boleto_expiration_date": null,
      "boleto_url": null,
      "capture_method": "ecommerce",
      "card": {
        "brand": "visa",
        "country": "US",
        "date_created": "2015-11-06T03:39:13.000Z",
        "date_updated": "2016-03-22T20:40:02.907Z",
        "fingerprint": "W8EBIq2PN+qB",
        "first_digits": "424242",
        "holder_name": "Richard Deschamps",
        "id": "card_cign456uw00rsyp6d5qq0og97",
        "last_digits": "4242",
        "object": "card",
        "valid": true
      },
      "card_brand": "visa",
      "card_first_digits": "424242",
      "card_holder_name": "Richard Deschamps",
      "card_last_digits": "4242",
      "cost": 0,
      "customer": null,
      "date_created": "2016-03-24T18:29:56.523Z",
      "date_updated": "2016-03-29T17:37:20.035Z",
      "id": 429356,
      "installments": 1,
      "ip": "179.191.82.50",
      "metadata": {},
      "nsu": "1458844196661",
      "object": "transaction",
      "paid_amount": 1000,
      "payment_method": "credit_card",
      "phone": null,
      "postback_url": null,
      "referer": "api_key",
      "refunded_amount": 1000,
      "refuse_reason": null,
      "soft_descriptor": null,
      "status": "refunded",
      "status_reason": "acquirer",
      "subscription_id": null,
      "tid": "1458844196661"
    }
    SUCCESS_RESPONSE
  end

  def failed_refund_response
    <<-FAILED_RESPONSE
    {
      "errors": [
        {
          "message": "Transação já estornada",
          "parameter_name": null,
          "type": "action_forbidden"
        }
      ],
      "method": "post",
      "url": "/transactions/429356/refund"
    }
    FAILED_RESPONSE
  end

  def successful_void_response
    <<-SUCCESS_RESPONSE
    {
      "acquirer_name": "pagarme",
      "acquirer_response_code": "00",
      "address": null,
      "amount": 1000,
      "antifraud_metadata": {},
      "antifraud_score": null,
      "authorization_code": "420653",
      "authorized_amount": 1000,
      "boleto_barcode": null,
      "boleto_expiration_date": null,
      "boleto_url": null,
      "capture_method": "ecommerce",
      "card": {
        "brand": "visa",
        "country": "US",
        "date_created": "2016-04-28T19:04:17.522Z",
        "date_updated": "2016-04-28T19:04:17.744Z",
        "fingerprint": "W8EBIq2PN+qB",
        "first_digits": "424242",
        "holder_name": "Richard Deschamps",
        "id": "card_cinknt1td006ffo6dr0jjitj4",
        "last_digits": "4242",
        "object": "card",
        "valid": true
      },
      "card_brand": "visa",
      "card_first_digits": "424242",
      "card_holder_name": "Richard Deschamps",
      "card_last_digits": "4242",
      "cost": 0,
      "customer": null,
      "date_created": "2016-04-28T19:04:17.528Z",
      "date_updated": "2016-04-28T19:07:07.905Z",
      "id": 472218,
      "installments": 1,
      "ip": "179.185.132.108",
      "metadata": {},
      "nsu": 472218,
      "object": "transaction",
      "paid_amount": 0,
      "payment_method": "credit_card",
      "phone": null,
      "postback_url": null,
      "referer": "api_key",
      "refunded_amount": 1000,
      "refuse_reason": null,
      "soft_descriptor": null,
      "status": "refunded",
      "status_reason": "acquirer",
      "subscription_id": null,
      "tid": 472218
    }
    SUCCESS_RESPONSE
  end

  def failed_void_response
    <<-FAILED_RESPONSE
    {
      "errors": [
        {
          "message": "Transação já estornada",
          "parameter_name": null,
          "type": "action_forbidden"
        }
      ],
      "method": "post",
      "url": "/transactions/472218/refund"
    }
    FAILED_RESPONSE
  end

  def successful_verify_response
    <<-SUCCESS_RESPONSE
    {
      "acquirer_name": "pagarme",
      "acquirer_response_code": "00",
      "address": null,
      "amount": 127,
      "antifraud_metadata": {},
      "antifraud_score": null,
      "authorization_code": "713869",
      "authorized_amount": 127,
      "boleto_barcode": null,
      "boleto_expiration_date": null,
      "boleto_url": null,
      "capture_method": "ecommerce",
      "card": {
        "brand": "visa",
        "country": "US",
        "date_created": "2016-05-03T22:15:08.888Z",
        "date_updated": "2016-05-03T22:15:09.140Z",
        "fingerprint": "gulv5VbV4RnS",
        "first_digits": "424242",
        "holder_name": "Richard Deschamps",
        "id": "card_cinrztr2w003sxc6djpqm0toe",
        "last_digits": "4242",
        "object": "card",
        "valid": true
      },
      "card_brand": "visa",
      "card_first_digits": "424242",
      "card_holder_name": "Richard Deschamps",
      "card_last_digits": "4242",
      "cost": 0,
      "customer": null,
      "date_created": "2016-05-03T22:15:18.697Z",
      "date_updated": "2016-05-03T22:15:18.900Z",
      "id": 476135,
      "installments": 1,
      "ip": "179.191.82.50",
      "metadata": {},
      "nsu": 476135,
      "object": "transaction",
      "paid_amount": 0,
      "payment_method": "credit_card",
      "phone": null,
      "postback_url": null,
      "referer": "api_key",
      "refunded_amount": 0,
      "refuse_reason": null,
      "soft_descriptor": null,
      "status": "authorized",
      "status_reason": "antifraud",
      "subscription_id": null,
      "tid": 476135
    }
    SUCCESS_RESPONSE
  end

  def successful_verify_void_response
    <<-SUCCESS_RESPONSE
    {
      "acquirer_name": "pagarme",
      "acquirer_response_code": "00",
      "address": null,
      "amount": 127,
      "antifraud_metadata": {},
      "antifraud_score": null,
      "authorization_code": "713869",
      "authorized_amount": 127,
      "boleto_barcode": null,
      "boleto_expiration_date": null,
      "boleto_url": null,
      "capture_method": "ecommerce",
      "card": {
        "brand": "visa",
        "country": "US",
        "date_created": "2016-05-03T22:15:08.888Z",
        "date_updated": "2016-05-03T22:15:09.140Z",
        "fingerprint": "gulv5VbV4RnS",
        "first_digits": "424242",
        "holder_name": "Richard Deschamps",
        "id": "card_cinrztr2w003sxc6djpqm0toe",
        "last_digits": "4242",
        "object": "card",
        "valid": true
      },
      "card_brand": "visa",
      "card_first_digits": "424242",
      "card_holder_name": "Richard Deschamps",
      "card_last_digits": "4242",
      "cost": 0,
      "customer": null,
      "date_created": "2016-05-03T22:15:18.697Z",
      "date_updated": "2016-05-04T19:48:48.294Z",
      "id": 476135,
      "installments": 1,
      "ip": "179.191.82.50",
      "metadata": {},
      "nsu": 476135,
      "object": "transaction",
      "paid_amount": 0,
      "payment_method": "credit_card",
      "phone": null,
      "postback_url": null,
      "referer": "api_key",
      "refunded_amount": 127,
      "refuse_reason": null,
      "soft_descriptor": null,
      "status": "refunded",
      "status_reason": "acquirer",
      "subscription_id": null,
      "tid": 476135
    }
    SUCCESS_RESPONSE
  end

  def failed_verify_response
    <<-FAILED_RESPONSE
    {
      "acquirer_name": "pagarme",
      "acquirer_response_code": "88",
      "address": null,
      "amount": 127,
      "antifraud_metadata": {},
      "antifraud_score": null,
      "authorization_code": null,
      "authorized_amount": 0,
      "boleto_barcode": null,
      "boleto_expiration_date": null,
      "boleto_url": null,
      "capture_method": "ecommerce",
      "card": {
        "brand": "visa",
        "country": "US",
        "date_created": "2016-05-03T22:15:08.888Z",
        "date_updated": "2016-05-03T22:15:09.140Z",
        "fingerprint": "gulv5VbV4RnS",
        "first_digits": "424242",
        "holder_name": "Richard Deschamps",
        "id": "card_cinrztr2w003sxc6djpqm0toe",
        "last_digits": "4242",
        "object": "card",
        "valid": true
      },
      "card_brand": "visa",
      "card_first_digits": "424242",
      "card_holder_name": "Richard Deschamps",
      "card_last_digits": "4242",
      "cost": 0,
      "customer": null,
      "date_created": "2016-05-03T22:23:26.282Z",
      "date_updated": "2016-05-03T22:23:26.505Z",
      "id": 476143,
      "installments": 1,
      "ip": "179.191.82.50",
      "metadata": {},
      "nsu": 476143,
      "object": "transaction",
      "paid_amount": 0,
      "payment_method": "credit_card",
      "phone": null,
      "postback_url": null,
      "referer": "api_key",
      "refunded_amount": 0,
      "refuse_reason": "acquirer",
      "soft_descriptor": null,
      "status": "refused",
      "status_reason": "acquirer",
      "subscription_id": null,
      "tid": 476143
    }
    FAILED_RESPONSE
  end

  def failed_error_response
    <<-FAILED_RESPONSE
    {
      "errors": [
        {
          "message": "Internal server error.",
          "parameter_name": null,
          "type": "internal_error"
        }
      ],
      "method": "post",
      "url": "/transactions"
    }
    FAILED_RESPONSE
  end

  def failed_json_response
    <<-SUCCESS_RESPONSE
    {
      foo: bar
    }
    SUCCESS_RESPONSE
  end

end
