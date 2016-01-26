require 'test_helper'

class ForteTest < Test::Unit::TestCase
  def setup
    @gateway = ForteGateway.new(location_id: 'location_id', account_id: 'account_id', api_key: 'api_key', secret: 'secret')
    @credit_card = credit_card
    @check = check
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:handle_resp).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'trn_bb7687a7-3d3a-40c2-8fa9-90727a814249#123456', response.authorization
    assert response.test?
  end

  def test_purchase_passes_options
    options = { order_id: '1' }

    @gateway.expects(:commit).with(anything, has_entries(:order_number => '1'))

    @gateway.purchase(@amount, @credit_card, options)
  end

  def test_failed_purchase
    @gateway.expects(:handle_resp).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID TRN", response.message
  end

  def test_successful_purchase_with_echeck
    @gateway.expects(:handle_resp).returns(successful_echeck_purchase_response)

    response = @gateway.purchase(@amount, @check, @options)
    assert_success response

    assert_equal 'trn_bb7687a7-3d3a-40c2-8fa9-90727a814249#123456', response.authorization
    assert response.test?
  end

  def test_failed_purchase_with_echeck
    @gateway.expects(:handle_resp).returns(failed_echeck_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID CREDIT CARD NUMBER", response.message
  end

  def test_successful_authorize
    @gateway.expects(:handle_resp).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:handle_resp).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "INVALID CREDIT CARD NUMBER", response.message
  end

  def test_successful_capture
    @gateway.expects(:handle_resp).returns(successful_capture_response)

    response = @gateway.capture(@amount, "authcode")
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:handle_resp).returns(failed_capture_response)

    response = @gateway.capture(@amount, "authcode")
    assert_failure response
  end

  def test_successful_credit
    @gateway.expects(:handle_resp).returns(successful_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_credit
    @gateway.expects(:handle_resp).returns(failed_credit_response)

    response = @gateway.credit(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:handle_resp).returns(successful_credit_response)

    response = @gateway.void("authcode")
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:handle_resp).returns(failed_credit_response)

    response = @gateway.void("authcode")
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:handle_resp).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:handle_resp).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:handle_resp).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
<- "POST /api/v2/accounts/act_300111/locations/loc_176008/transactions/ HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic ZjA4N2E5MGYwMGYwYWU1NzA1MGM5MzdlZDM4MTVjOWY6ZDc5M2Q2NDA2NGUzMTEzYTc0ZmE3MjAzNWNmYzNhMWQ=\r\nX-Forte-Auth-Account-Id: act_300111\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.forte.net\r\nContent-Length: 471\r\n\r\n"
<- "{\"authorization_amount\":\"1.00\",\"card\":{\"card_type\":\"visa\",\"name_on_card\":\"Longbob Longsen\",\"account_number\":\"4000100011112224\",\"expire_month\":9,\"expire_year\":2016,\"card_verification_value\":\"123\"},\"billing_address\":{\"first_name\":\"Jim\",\"last_name\":\"Smith\",\"address_line1\":\"456 My Street\",\"address_line2\":\"Apt 1\",\"address_country\":\"CA\",\"address_zip\":\"K1C2N6\",\"address_state\":\"ON\",\"address_city\":\"Ottawa\"},\"action\":\"sale\",\"account_id\":\"act_300111\",\"location_id\":\"loc_176008\"}"
    )
  end

  def post_scrubbed
    %q(
<- "POST /api/v2/accounts/act_300111/locations/loc_176008/transactions/ HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nX-Forte-Auth-Account-Id: act_300111\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: sandbox.forte.net\r\nContent-Length: 471\r\n\r\n"
<- "{\"authorization_amount\":\"1.00\",\"card\":{\"card_type\":\"visa\",\"name_on_card\":\"Longbob Longsen\",\"account_number[FILTERED]\",\"expire_month\":9,\"expire_year\":2016,\"card_verification_value[FILTERED]\"},\"billing_address\":{\"first_name\":\"Jim\",\"last_name\":\"Smith\",\"address_line1\":\"456 My Street\",\"address_line2\":\"Apt 1\",\"address_country\":\"CA\",\"address_zip\":\"K1C2N6\",\"address_state\":\"ON\",\"address_city\":\"Ottawa\"},\"action\":\"sale\",\"account_id\":\"act_300111\",\"location_id\":\"loc_176008\"}"
    )
  end

  def successful_purchase_response
    %q(
      {
        "transaction_id":"trn_bb7687a7-3d3a-40c2-8fa9-90727a814249",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"sale",
        "authorization_amount":1.0,
        "authorization_code":"123456",
        "billing_address":{
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "card": {
          "name_on_card":"Longbob Longsen",
          "masked_account_number":"****2224",
          "expire_month":9,
          "expire_year":2016,
          "card_verification_value":"***",
          "card_type":"visa"
        },
        "response": {
          "authorization_code":"123456",
          "avs_result":"Y",
          "cvv_code":"M",
          "environment":"sandbox",
          "response_type":"A",
          "response_code":"A01",
          "response_desc":"TEST APPROVAL"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_bb7687a7-3d3a-40c2-8fa9-90727a814249",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_bb7687a7-3d3a-40c2-8fa9-90727a814249/settlements"
        }
      }
    )
  end

  def failed_purchase_response
    %q(
      {
        "transaction_id":"trn_e9ea64c4-5c2c-43dd-9138-f2661b59947c",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"sale",
        "authorization_amount":1.0,
        "billing_address": {
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "card": {
          "name_on_card":"Longbob Longsen",
          "masked_account_number":"****1111",
          "expire_month":9,
          "expire_year":2016,
          "card_verification_value":"***",
          "card_type":"visa"
        },
        "response": {
          "environment":"sandbox",
          "response_type":"D",
          "response_code":"U20",
          "response_desc": "INVALID TRN"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_e9ea64c4-5c2c-43dd-9138-f2661b59947c",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_e9ea64c4-5c2c-43dd-9138-f2661b59947c/settlements"
        }
      }
    )
  end

  def successful_echeck_purchase_response
    %q(
      {
        "transaction_id":"trn_bb7687a7-3d3a-40c2-8fa9-90727a814249",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"sale",
        "authorization_amount":1.0,
        "authorization_code":"123456",
        "billing_address":{
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "echeck": {
          "account_holder": "Jim Smith",
          "masked_account_number":"****8535",
          "routing_number":"244183602",
          "account_type":"checking",
          "check_number":"1"
        },
        "echeck": {
          "name_on_card":"Longbob Longsen",
          "masked_account_number":"****2224",
          "expire_month":9,
          "expire_year":2016,
          "card_verification_value":"***",
          "card_type":"visa"
        },
        "response": {
          "authorization_code":"123456",
          "avs_result":"Y",
          "cvv_code":"M",
          "environment":"sandbox",
          "response_type":"A",
          "response_code":"A01",
          "response_desc":"TEST APPROVAL"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_bb7687a7-3d3a-40c2-8fa9-90727a814249",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_bb7687a7-3d3a-40c2-8fa9-90727a814249/settlements"
        }
      }
    )
  end

  def failed_echeck_purchase_response
    %q(
      {
        "transaction_id":"trn_bb7687a7-3d3a-40c2-8fa9-90727a814249",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"sale",
        "authorization_amount":1.0,
        "authorization_code":"123456",
        "billing_address":{
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "echeck": {
          "account_holder": "Jim Smith",
          "masked_account_number":"****8535",
          "routing_number":"244183602",
          "account_type":"checking",
          "check_number":"1"
        },
        "echeck": {
          "name_on_card":"Longbob Longsen",
          "masked_account_number":"****2224",
          "expire_month":9,
          "expire_year":2016,
          "card_verification_value":"***",
          "card_type":"visa"
        },
        "response": {
          "environment":"sandbox",
          "response_type":"D",
          "response_code":"U19",
          "response_desc":"INVALID CREDIT CARD NUMBER"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_bb7687a7-3d3a-40c2-8fa9-90727a814249",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_bb7687a7-3d3a-40c2-8fa9-90727a814249/settlements"
        }
      }
    )
  end

  def successful_authorize_response
    %q(
      {
        "transaction_id":"trn_527fdc8a-d3d0-4680-badc-bfa784c63c13",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"authorize",
        "authorization_amount":1.0,
        "authorization_code":"123456",
        "billing_address": {
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "card": {
          "name_on_card":"Longbob Longsen",
          "masked_account_number":"****2224",
          "expire_month":9,
          "expire_year":2016,
          "card_verification_value":"***",
          "card_type":"visa"
        },
        "response": {
          "authorization_code":"123456",
          "avs_result":"Y",
          "cvv_code":"M",
          "environment":"sandbox",
          "response_type":"A",
          "response_code":"A01",
          "response_desc":"TEST APPROVAL"
        },
        "links":{
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_527fdc8a-d3d0-4680-badc-bfa784c63c13",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_527fdc8a-d3d0-4680-badc-bfa784c63c13/settlements"
        }
      }
    )
  end

  def failed_authorize_response
    %q(
      {
        "transaction_id":"trn_7c045645-98b3-4c8a-88d6-e8d686884564",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"authorize",
        "authorization_amount":19.85,
        "billing_address": {
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "card": {
          "name_on_card":"Longbob Longsen",
          "masked_account_number":"****1111",
          "expire_month":9,
          "expire_year":2016,
          "card_verification_value":"***",
          "card_type":"visa"
        },
        "response":{
          "environment":"sandbox",
          "response_type":"D",
          "response_code":"U20",
          "response_desc":"INVALID CREDIT CARD NUMBER"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_7c045645-98b3-4c8a-88d6-e8d686884564",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_7c045645-98b3-4c8a-88d6-e8d686884564/settlements"
        }
      }
    )
  end

  def successful_capture_response
    %q(
      {
        "transaction_id":"trn_94a04a97-c847-4420-820b-fb153a1f0f64",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "original_transaction_id":"trn_e5e3b23d-3e13-44d4-bce1-4b9aaa466a5d",
        "action":"capture",
        "authorization_code":"13844235",
        "response": {
          "authorization_code":"13844235",
          "environment":"sandbox",
          "response_type":"A",
          "response_code":"A01",
          "response_desc":"APPROVED"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_94a04a97-c847-4420-820b-fb153a1f0f64",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_94a04a97-c847-4420-820b-fb153a1f0f64/settlements"
        }
      }
    )
  end

  def failed_capture_response
    %q(
      {
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"capture",
        "authorization_code":"",
        "response":{
          "environment":"sandbox",
          "response_desc":"The field transaction_id is required."
        }
      }
    )
  end

  def successful_credit_response
    %q(
      {
        "transaction_id":"trn_357b284e-1dde-42ba-b0a5-5f66e08c7d9f",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"disburse",
        "authorization_amount":1.0,
        "authorization_code":"123456",
        "billing_address": {
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "card": {
          "name_on_card":"Longbob Longsen",
          "masked_account_number":"****2224",
          "expire_month":9,
          "expire_year":2016,
          "card_verification_value":"***",
          "card_type":"visa"
        },
        "response": {
          "authorization_code":"123456",
          "avs_result":"Y",
          "cvv_code":"M",
          "environment":"sandbox",
          "response_type":"A",
          "response_code":"A01",
          "response_desc":"TEST APPROVAL"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_357b284e-1dde-42ba-b0a5-5f66e08c7d9f",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_357b284e-1dde-42ba-b0a5-5f66e08c7d9f/settlements"
        }
      }
    )
  end

  def failed_credit_response
    %q(
      {
        "transaction_id":"trn_ce70ce9a-6265-4892-9a83-5825cb869ed5",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"disburse",
        "authorization_amount":1.0,
        "billing_address": {
          "first_name":"Jim",
          "last_name":"Smith"
        },
        "response": {
          "environment":"sandbox",
          "response_type":"E",
          "response_code":"F01",
          "response_desc":"MANDITORY FIELD MISSING:card.card_type,MANDITORY FIELD MISSING:card.account_number,MANDITORY FIELD MISSING:card.expire_year,MANDITORY FIELD MISSING:card.expire_month"
          },
          "links": {
            "self":"https://sandbox.forte.net/API/v2/transactions/trn_ce70ce9a-6265-4892-9a83-5825cb869ed5",
            "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_ce70ce9a-6265-4892-9a83-5825cb869ed5/settlements"
          }
        }
    )
  end

  def successful_void_response
    %q(
      {
        "transaction_id":"trn_6c9d049e-1971-45fb-a4da-a0c35c4ed274",
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"void",
        "authorization_code":"13802096",
        "response": {
          "authorization_code":"13802096",
          "environment":"sandbox",
          "response_type":"A",
          "response_code":"A01",
          "response_desc":"APPROVED"
        },
        "links": {
          "self":"https://sandbox.forte.net/API/v2/transactions/trn_6c9d049e-1971-45fb-a4da-a0c35c4ed274",
          "settlements":"https://sandbox.forte.net/API/v2/transactions/trn_6c9d049e-1971-45fb-a4da-a0c35c4ed274/settlements"
        }
      }
    )
  end

  def failed_void_response
    %q(
      {
        "account_id":"act_300111",
        "location_id":"loc_176008",
        "action":"void",
        "authorization_code":"",
        "response": {
          "environment":"sandbox",
          "response_desc":"The field transaction_id is required."
        }
      }
    )
  end
end
