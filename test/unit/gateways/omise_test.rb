require 'test_helper'

class OmiseTest < Test::Unit::TestCase
  def setup
    @gateway = OmiseGateway.new(
      public_key: 'pkey_test_abc',
      secret_key: 'skey_test_123',
    )

    @credit_card = credit_card
    @amount = 3333

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @card_token = {
      object: 'token',
      id: 'tokn_test_4zgf1crg50rdb68xlk5'
    };
  end

  def test_supported_countries
    assert_equal @gateway.supported_countries, %w( TH JP )
  end

  def test_supported_cardtypes
    assert_equal @gateway.supported_cardtypes, [:visa, :master, :jcb]
  end

  def test_supports_scrubbing
    assert @gateway.supports_scrubbing?
  end

  def test_scrub
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  def test_gateway_url
     assert_equal 'https://api.omise.co/', OmiseGateway::API_URL
     assert_equal 'https://vault.omise.co/', OmiseGateway::VAULT_URL
  end

  def test_request_headers
    headers = @gateway.send(:headers, { key: 'pkey_test_555' })
    assert_equal 'Basic cGtleV90ZXN0XzU1NTo=', headers['Authorization']
    assert_equal 'application/json;utf-8', headers['Content-Type']
  end

  def test_post_data
    post_data = @gateway.send(:post_data, { card: {number: '4242424242424242'} })
    assert_equal "{\"card\":{\"number\":\"4242424242424242\"}}", post_data
  end

  def test_parse_response
    response = @gateway.send(:parse, successful_purchase_response)
    assert(response.key?('object'), "expect json response has object key")
  end

  def test_successful_response
    response = @gateway.send(:parse, successful_purchase_response)
    success  = @gateway.send(:successful?, response)
    assert(success, "expect success to be true")
  end

  def test_error_response
    response = @gateway.send(:parse, error_response)
    success  = @gateway.send(:successful?, response)
    assert(!success, "expect success to be false")
  end

  def test_error_code_from
    response = @gateway.send(:parse, invalid_security_code_response)
    error_code  = @gateway.send(:error_code_from, response)
    assert_equal 'invalid_security_code', error_code
  end

  def test_standard_error_code_mapping
    invalid_expiration_date = @gateway.send(:parse, invalid_expiration_date_response)
    invalid_expiration_date_code = @gateway.send(:standard_error_code_mapping, invalid_expiration_date)
    assert_equal 'invalid_expiry_date', invalid_expiration_date_code
  end

  def test_invalid_cvc
    invalid_security_code = @gateway.send(:parse, invalid_security_code_response)
    invalid_cvc_code = @gateway.send(:standard_error_code_mapping, invalid_security_code)
    assert_equal 'invalid_cvc', invalid_cvc_code
  end

  def test_card_declined
    card_declined =  @gateway.send(:parse, failed_capture_response)
    card_declined_code = @gateway.send(:standard_error_code_mapping, card_declined)
    assert_equal 'card_declined', card_declined_code
  end

  def test_invalid_number
    invalid_number = @gateway.send(:parse, incorrect_number_response)
    invalid_number_code = @gateway.send(:standard_error_code_mapping, invalid_number)
    assert_equal 'invalid_number', invalid_number_code
  end

  def test_invalid_expiry_date
    expiration_year = @gateway.send(:parse, invalid_expiration_year_response)
    invalid_expiry_date_code = @gateway.send(:standard_error_code_mapping, expiration_year)
    assert_equal 'invalid_expiry_date', invalid_expiry_date_code

    expiration_month = @gateway.send(:parse, invalid_expiration_month_response)
    invalid_expiry_date_code = @gateway.send(:standard_error_code_mapping, expiration_month)
    assert_equal 'invalid_expiry_date', invalid_expiry_date_code
  end

  def test_successful_api_request
    @gateway.expects(:ssl_request).returns(successful_list_charges_response)
    response = @gateway.send(:https_request, :get, 'charges')
    assert(!response.empty?)
  end

  def test_message_from_response
    response = @gateway.send(:parse, error_response)
    assert_equal 'failed fraud check', @gateway.send(:message_from, response)
  end

  def test_authorization_from_response
    response = @gateway.send(:parse, successful_purchase_response)
    assert_equal 'chrg_test_4zgf1d2wbstl173k99v', @gateway.send(:authorization_from, response)
  end

  def test_add_creditcard
    result = {}
    @gateway.send(:add_creditcard, result, @credit_card)
    assert_equal @credit_card.number, result[:card][:number]
    assert_equal @credit_card.verification_value, result[:card][:security_code]
    assert_equal 'Longbob Longsen', result[:card][:name]
  end

  def test_add_customer_without_card
    result = {}
    customer_id = 'cust_test_4zjzcgm8kpdt4xdhdw2'
    @gateway.send(:add_customer, result, {customer_id: customer_id})
    assert_equal 'cust_test_4zjzcgm8kpdt4xdhdw2', result[:customer]
  end

  def test_add_customer_with_card_id
    result = {}
    customer_id   = 'cust_test_4zjzcgm8kpdt4xdhdw2'
    result[:card] = 'card_test_4zguktjcxanu3dw171a'
    @gateway.send(:add_customer, result, {customer_id: customer_id})
    assert_equal customer_id, result[:customer]
  end

  def test_add_amount
    result = {}
    desc = 'Charge for order 3947'
    @gateway.send(:add_amount, result, @amount, {description: desc})
    assert_equal desc, result[:description]
  end

  def test_add_amount_with_correct_currency
    result = {}
    jpy_currency = 'JPY'
    @gateway.send(:add_amount, result, @amount, {currency: jpy_currency})
    assert_equal jpy_currency, result[:currency]
  end

  def test_commit_transaction
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.send(:commit, :post, 'charges', {})
    assert_equal 'chrg_test_4zgf1d2wbstl173k99v', response.authorization
  end

  def test_successful_token_exchange
    @gateway.expects(:ssl_request).returns(successful_token_exchange)
    token = @gateway.send(:get_token, {}, @credit_card)
    assert_equal 'tokn_test_4zgf1crg50rdb68xlk5', token.params['id']
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).twice.returns(successful_token_exchange, successful_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'chrg_test_4zgf1d2wbstl173k99v', response.authorization
    assert response.test?
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).twice.returns(successful_token_exchange, successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'chrg_test_4zmqak4ccnfut5maxp7', response.authorization
    assert response.test?
    assert response.params['authorized']
  end

  def test_successful_store
    @gateway.expects(:ssl_request).twice.returns(successful_token_exchange, successful_store_response)
    response = @gateway.store(@credit_card, @options)
    assert_equal 'cust_test_4zkp720zggu4rubgsqb', response.authorization
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    response = @gateway.send(:capture, @amount, 'chrg_test_4z5goqdwpjebu1gsmqq')
    assert_equal 'chrg_test_4z5goqdwpjebu1gsmqq', response.params['id']
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)
    response = @gateway.send(:capture, @amount, 'chrg_test_4z5goqdwpjebu1gsmqq')
    assert_equal 'Charge is not authorized', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)
    response = @gateway.send(:refund, @amount, 'chrg_test_4z5goqdwpjebu1gsmqq')
    assert_equal 'rfnd_test_4zmbpt1zwdsqtmtffw8', response.params['id']
  end

  def test_successful_partial_refund
    @gateway.expects(:ssl_request).returns(successful_partial_refund_response)
    response = @gateway.send(:refund, 1000, 'chrg_test_4z5goqdwpjebu1gsmqq')
    assert_equal 1000, response.params['amount']
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    response = @gateway.send(:refund, 9999999, 'chrg_test_4z5goqdwpjebu1gsmqq')
    assert_equal "charge can't be refunded", response.message
  end

  private

  def pre_scrubbed
    <<-'PRE_SCRUBED'
      opening connection to vault.omise.co:443...
      opened
      starting SSL for vault.omise.co:443...
      SSL established
      <- "POST /tokens HTTP/1.1\r\nContent-Type: application/json;utf-8\r\nUser-Agent: Omise/v1.0 ActiveMerchantBindings/1.48.0\r\nAuthorization: Basic cGtleV90ZXN0XzR6dDBmc3M4Z3MwejZiNHpsc3E6\r\nAccept-Encoding: utf-8\r\nAccept: */*\r\nConnection: close\r\nHost: vault.omise.co\r\nContent-Length: 129\r\n\r\n"
      <- "{\"card\":{\"number\":\"4242424242424242\",\"name\":\"Longbob Longsen\",\"security_code\":\"123\",\"expiration_month\":9,\"expiration_year\":2016}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Date: Tue, 28 Apr 2015 11:28:04 GMT\r\n"
      -> "Omise-Version: 2015-04-24\r\n"
      -> "Server: nginx\r\n"
      -> "Status: 200 OK\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubdomains\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Request-Id: 6fe70604-c96c-425a-bdc1-2c50049be41b\r\n"
      -> "X-Runtime: 0.083059\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "Content-Length: 680\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 680 bytes...
      -> "{\n  \"object\": \"token\",\n  \"id\": \"tokn_test_4zulil6gzuconeb4mrm\",\n  \"livemode\": false,\n  \"location\": \"https://vault.omise.co/tokens/tokn_test_4zulil6gzuconeb4mrm\",\n  \"used\": false,\n  \"card\": {\n    \"object\": \"card\",\n    \"id\": \"card_test_4zulil6fy04h678xb52\",\n    \"livemode\": false,\n    \"country\": \"us\",\n    \"city\": null,\n    \"postal_code\": null,\n    \"financing\": \"\",\n    \"last_digits\": \"4242\",\n    \"brand\": \"Visa\",\n    \"expiration_month\": 9,\n    \"expiration_year\": 2016,\n    \"fingerprint\": \"MYfx1beqiXkgHgJMoH+LzpyuspoeQZoQDmsI1GDSl/A=\",\n    \"name\": \"Longbob Longsen\",\n    \"security_code_check\": true,\n    \"created\": \"2015-04-28T11:30:28Z\"\n  },\n  \"created\": \"2015-04-28T11:30:28Z\"\n}\n"
      read 680 bytes
      Conn close
    PRE_SCRUBED
  end

  def post_scrubbed
    <<-'POST_SCRUBBED'
      opening connection to vault.omise.co:443...
      opened
      starting SSL for vault.omise.co:443...
      SSL established
      <- "POST /tokens HTTP/1.1\r\nContent-Type: application/json;utf-8\r\nUser-Agent: Omise/v1.0 ActiveMerchantBindings/1.48.0\r\nAuthorization: Basic [FILTERED]\r\nAccept-Encoding: utf-8\r\nAccept: */*\r\nConnection: close\r\nHost: vault.omise.co\r\nContent-Length: 129\r\n\r\n"
      <- "{\"card\":{\"number\":[FILTERED],\"name\":\"Longbob Longsen\",\"security_code\":[FILTERED],\"expiration_month\":9,\"expiration_year\":2016}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache, no-store\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Date: Tue, 28 Apr 2015 11:28:04 GMT\r\n"
      -> "Omise-Version: 2015-04-24\r\n"
      -> "Server: nginx\r\n"
      -> "Status: 200 OK\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubdomains\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Request-Id: 6fe70604-c96c-425a-bdc1-2c50049be41b\r\n"
      -> "X-Runtime: 0.083059\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "Content-Length: 680\r\n"
      -> "Connection: Close\r\n"
      -> "\r\n"
      reading 680 bytes...
      -> "{\n  \"object\": \"token\",\n  \"id\": \"tokn_test_4zulil6gzuconeb4mrm\",\n  \"livemode\": false,\n  \"location\": \"https://vault.omise.co/tokens/tokn_test_4zulil6gzuconeb4mrm\",\n  \"used\": false,\n  \"card\": {\n    \"object\": \"card\",\n    \"id\": \"card_test_4zulil6fy04h678xb52\",\n    \"livemode\": false,\n    \"country\": \"us\",\n    \"city\": null,\n    \"postal_code\": null,\n    \"financing\": \"\",\n    \"last_digits\": \"4242\",\n    \"brand\": \"Visa\",\n    \"expiration_month\": 9,\n    \"expiration_year\": 2016,\n    \"fingerprint\": \"MYfx1beqiXkgHgJMoH+LzpyuspoeQZoQDmsI1GDSl/A=\",\n    \"name\": \"Longbob Longsen\",\n    \"security_code_check\": true,\n    \"created\": \"2015-04-28T11:30:28Z\"\n  },\n  \"created\": \"2015-04-28T11:30:28Z\"\n}\n"
      read 680 bytes
      Conn close
    POST_SCRUBBED
  end

  def error_response
    <<-RESPONSE
    {
      "object": "error",
      "location": "https://docs.omise.co/api/errors#failed-fraud-check",
      "code": "failed_fraud_check",
      "message": "failed fraud check"
    }
    RESPONSE
  end

  def successful_token_exchange
    <<-RESPONSE
    {
      "object": "token",
      "id": "tokn_test_4zgf1crg50rdb68xlk5",
      "livemode": false,
      "location": "https://vault.omise.co/tokens/tokn_test_4zgf1crg50rdb68xlk5",
      "used": false,
      "card": {
        "object": "card",
        "id": "card_test_4zgf1crf975xnz6coa7",
        "livemode": false,
        "country": "us",
        "city": "Bangkok",
        "postal_code": "10320",
        "financing": "",
        "last_digits": "4242",
        "brand": "Visa",
        "expiration_month": 10,
        "expiration_year": 2018,
        "fingerprint": "mKleiBfwp+PoJWB/ipngANuECUmRKjyxROwFW5IO7TM=",
        "name": "Somchai Prasert",
        "security_code_check": true,
        "created": "2015-03-23T05:25:14Z"
      },
      "created": "2015-03-23T05:25:14Z"
    }
    RESPONSE
  end

  def successful_list_charges_response
    <<-RESPONSE
    {
      "object": "list",
      "from": "1970-01-01T00:00:00+00:00",
      "to": "2015-04-01T03:34:11+00:00",
      "offset": 0,
      "limit": 20,
      "total": 1,
      "data": [
        {
          "object": "charge",
          "id": "chrg_test_4zgukttzllzumc25qvd",
          "livemode": false,
          "location": "/charges/chrg_test_4zgukttzllzumc25qvd",
          "amount": 99,
          "currency": "thb",
          "description": "Charge for order 3947",
          "capture": true,
          "authorized": true,
          "paid": true,
          "transaction": "trxn_test_4zguktuecyuo77xgq38",
          "refunded": 0,
          "refunds": {
            "object": "list",
            "from": "1970-01-01T00:00:00+00:00",
            "to": "2015-04-01T03:34:11+00:00",
            "offset": 0,
            "limit": 20,
            "total": 0,
            "data": [

            ],
            "location": "/charges/chrg_test_4zgukttzllzumc25qvd/refunds"
          },
          "failure_code": null,
          "failure_message": null,
          "card": {
            "object": "card",
            "id": "card_test_4zguktjcxanu3dw171a",
            "livemode": false,
            "country": "us",
            "city": "Bangkok",
            "postal_code": "10320",
            "financing": "",
            "last_digits": "4242",
            "brand": "Visa",
            "expiration_month": 2,
            "expiration_year": 2017,
            "fingerprint": "djVaKigLa0g0b12XdGLV8CAdy45FRrOdVsgmv4oze5I=",
            "name": "JOHN DOE",
            "security_code_check": true,
            "created": "2015-03-24T07:54:32Z"
          },
          "customer": null,
          "ip": null,
          "dispute": null,
          "created": "2015-03-24T07:54:33Z"
        }
      ]
    }
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
    {
      "object": "charge",
      "id": "chrg_test_4zgf1d2wbstl173k99v",
      "livemode": false,
      "location": "/charges/chrg_test_4zgf1d2wbstl173k99v",
      "amount": 100000,
      "currency": "thb",
      "description": null,
      "capture": true,
      "authorized": true,
      "paid": true,
      "transaction": "trxn_test_4zgf1d3f7t9k6gk8hn8",
      "refunded": 0,
      "refunds": {
        "object": "list",
        "from": "1970-01-01T00:00:00+00:00",
        "to": "2015-03-23T05:25:15+00:00",
        "offset": 0,
        "limit": 20,
        "total": 0,
        "data": [

        ],
        "location": "/charges/chrg_test_4zgf1d2wbstl173k99v/refunds"
      },
      "failure_code": null,
      "failure_message": null,
      "card": {
        "object": "card",
        "id": "card_test_4zgf1crf975xnz6coa7",
        "livemode": false,
        "location": "/customers/cust_test_4zgf1cv8e71bbwcww1p/cards/card_test_4zgf1crf975xnz6coa7",
        "country": "us",
        "city": "Bangkok",
        "postal_code": "10320",
        "financing": "",
        "last_digits": "4242",
        "brand": "Visa",
        "expiration_month": 10,
        "expiration_year": 2018,
        "fingerprint": "mKleiBfwp+PoJWB/ipngANuECUmRKjyxROwFW5IO7TM=",
        "name": "Somchai Prasert",
        "security_code_check": true,
        "created": "2015-03-23T05:25:14Z"
      },
      "customer": "cust_test_4zgf1cv8e71bbwcww1p",
      "ip": null,
      "dispute": null,
      "created": "2015-03-23T05:25:15Z"
    }
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
    {
      "object": "customer",
      "id": "cust_test_4zkp720zggu4rubgsqb",
      "livemode": false,
      "location": "/customers/cust_test_4zkp720zggu4rubgsqb",
      "default_card": "card_test_4zkp6xeuzurrvacxs2j",
      "email": "john.doe@example.com",
      "description": "John Doe (id: 30)",
      "created": "2015-04-03T04:10:35Z",
      "cards": {
        "object": "list",
        "from": "1970-01-01T00:00:00+00:00",
        "to": "2015-04-03T04:10:35+00:00",
        "offset": 0,
        "limit": 20,
        "total": 1,
        "data": [
          {
            "object": "card",
            "id": "card_test_4zkp6xeuzurrvacxs2j",
            "livemode": false,
            "location": "/customers/cust_test_4zkp720zggu4rubgsqb/cards/card_test_4zkp6xeuzurrvacxs2j",
            "country": "us",
            "city": "Bangkok",
            "postal_code": "10320",
            "financing": "",
            "last_digits": "4242",
            "brand": "Visa",
            "expiration_month": 4,
            "expiration_year": 2017,
            "fingerprint": "djVaKigLa0g0b12XdGLV8CAdy45FRrOdVsgmv4oze5I=",
            "name": "JOHN DOE",
            "security_code_check": false,
            "created": "2015-04-03T04:10:13Z"
          }
        ],
        "location": "/customers/cust_test_4zkp720zggu4rubgsqb/cards"
      }
    }
    RESPONSE
  end

  def successful_charge_response
    <<-RESPONSE
    {
      "object": "charge",
      "id": "chrg_test_4zmqak4ccnfut5maxp7",
      "livemode": false,
      "location": "/charges/chrg_test_4zmqak4ccnfut5maxp7",
      "amount": 100000,
      "currency": "thb",
      "description": null,
      "capture": false,
      "authorized": true,
      "paid": true,
      "transaction": "trxn_test_4zmqf6njyokta57ljs1",
      "refunded": 0,
      "refunds": {
        "object": "list",
        "from": "1970-01-01T00:00:00+00:00",
        "to": "2015-04-08T09:11:39+00:00",
        "offset": 0,
        "limit": 20,
        "total": 0,
        "data": [

        ],
        "location": "/charges/chrg_test_4zmqak4ccnfut5maxp7/refunds"
      },
      "failure_code": null,
      "failure_message": null,
      "card": {
        "object": "card",
        "id": "card_test_4zmqaffhmut87bi075q",
        "livemode": false,
        "country": "us",
        "city": "Bangkok",
        "postal_code": "10320",
        "financing": "",
        "last_digits": "4242",
        "brand": "Visa",
        "expiration_month": 4,
        "expiration_year": 2017,
        "fingerprint": "djVaKigLa0g0b12XdGLV8CAdy45FRrOdVsgmv4oze5I=",
        "name": "JOHN DOE",
        "security_code_check": true,
        "created": "2015-04-08T08:45:40Z"
      },
      "customer": null,
      "ip": null,
      "dispute": null,
      "created": "2015-04-08T08:46:02Z"
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "object": "charge",
      "id": "chrg_test_4zmqak4ccnfut5maxp7",
      "livemode": false,
      "location": "/charges/chrg_test_4zmqak4ccnfut5maxp7",
      "amount": 100000,
      "currency": "thb",
      "description": null,
      "capture": false,
      "authorized": true,
      "paid": false,
      "transaction": null,
      "refunded": 0,
      "refunds": {
        "object": "list",
        "from": "1970-01-01T00:00:00+00:00",
        "to": "2015-04-08T08:46:02+00:00",
        "offset": 0,
        "limit": 20,
        "total": 0,
        "data": [

        ],
        "location": "/charges/chrg_test_4zmqak4ccnfut5maxp7/refunds"
      },
      "failure_code": null,
      "failure_message": null,
      "card": {
        "object": "card",
        "id": "card_test_4zmqaffhmut87bi075q",
        "livemode": false,
        "country": "us",
        "city": "Bangkok",
        "postal_code": "10320",
        "financing": "",
        "last_digits": "4242",
        "brand": "Visa",
        "expiration_month": 4,
        "expiration_year": 2017,
        "fingerprint": "djVaKigLa0g0b12XdGLV8CAdy45FRrOdVsgmv4oze5I=",
        "name": "JOHN DOE",
        "security_code_check": true,
        "created": "2015-04-08T08:45:40Z"
      },
      "customer": null,
      "ip": null,
      "dispute": null,
      "created": "2015-04-08T08:46:02Z"
      }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    { "object": "charge",
      "id": "chrg_test_4z5goqdwpjebu1gsmqq",
      "livemode": false,
      "location": "/charges/chrg_test_4z5goqdwpjebu1gsmqq",
      "amount": 100000,
      "currency": "thb",
      "description": "Charge for order 3947",
      "capture": false,
      "authorized": true,
      "paid": true,
      "transaction": "trxn_test_4z5gp0t3mpfsu28u8jo",
      "refunded": 0,
      "refunds": {
        "object": "list",
        "from": "1970-01-01T00:00:00+00:00",
        "to": "2015-02-23T05:16:54+00:00",
        "offset": 0,
        "limit": 20,
        "total": 0,
        "data": [

        ],
        "location": "/charges/chrg_test_4z5goqdwpjebu1gsmqq/refunds"
      },
      "return_uri": "http://www.example.com/orders/3947/complete",
      "reference": "paym_4z5goqdw6rblbxztm4c",
      "authorize_uri": "https://api.omise.co/payments/paym_4z5goqdw6rblbxztm4c/authorize",
      "failure_code": null,
      "failure_message": null,
      "card": {
        "object": "card",
        "id": "card_test_4z5gogdycbrium283yk",
        "livemode": false,
        "country": "us",
        "city": "Bangkok",
        "postal_code": "10320",
        "financing": "",
        "last_digits": "4242",
        "brand": "Visa",
        "expiration_month": 2,
        "expiration_year": 2017,
        "fingerprint": "umrBpbHRuc8vstbcNEZPbnKkIycR/gvI6ivW9AshKCw=",
        "name": "JOHN DOE",
        "security_code_check": true,
        "created": "2015-02-23T05:15:18Z"
      },
      "customer": null,
      "ip": null,
      "created": "2015-02-23T05:16:05Z"
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    { "object": "refund",
      "id": "rfnd_test_4zmbpt1zwdsqtmtffw8",
      "location": "/charges/chrg_test_4zmbg6gtzz7zhf6rio6/refunds/rfnd_test_4zmbpt1zwdsqtmtffw8",
      "amount": 3333,
      "currency": "thb",
      "charge": "chrg_test_4zmbg6gtzz7zhf6rio6",
      "transaction": "trxn_test_4zmbpt23zmi9acu4qzk",
      "created": "2015-04-07T07:55:21Z"
     }
    RESPONSE
  end

  def successful_partial_refund_response
    <<-RESPONSE
    { "object": "refund",
      "id": "rfnd_test_4zmbpt1zwdsqtmtffw8",
      "location": "/charges/chrg_test_4zmbg6gtzz7zhf6rio6/refunds/rfnd_test_4zmbpt1zwdsqtmtffw8",
      "amount": 1000,
      "currency": "thb",
      "charge": "chrg_test_4zmbg6gtzz7zhf6rio6",
      "transaction": "trxn_test_4zmbpt23zmi9acu4qzk",
      "created": "2015-04-07T07:55:21Z"
     }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    { "object": "error",
      "location": "https://docs.omise.co/api/errors#failed-refund",
      "code": "failed_refund",
      "message": "charge can't be refunded"
    }
    RESPONSE
  end

  def invalid_expiration_month_response
    <<-RESPONSE
    {
      "object": "error",
      "location": "https://docs.omise.co/api/errors#invalid-card",
      "code": "invalid_card",
      "message": "expiration month is not between 1 and 12 and expiration date is invalid"
    }
    RESPONSE
  end

  def invalid_expiration_year_response
    <<-RESPONSE
    {
      "object": "error",
      "location": "https://docs.omise.co/api/errors#invalid-card",
      "code": "invalid_card",
      "message": "expiration year is invalid"
    }
    RESPONSE
  end

  def invalid_expiration_date_response
    <<-RESPONSE
    {
      "object": "error",
      "location": "https://docs.omise.co/api/errors#invalid-card",
      "code": "invalid_card",
      "message": "expiration month is not between 1 and 12 and expiration date is invalid"
    }
    RESPONSE
  end

  def incorrect_number_response
    <<-RESPONSE
    {
      "object": "error",
      "location": "https://docs.omise.co/api/errors#invalid-card",
      "code": "invalid_card",
      "message": "number is invalid and brand not supported (unknown)"
    }
    RESPONSE
  end

  def invalid_security_code_response
    <<-RESPONSE
    {
      "object": "charge",
      "id": "chrg_4zyeviyhhhs7sow8c3k",
      "livemode": true,
      "location": "/charges/chrg_4zyeviyhhhs7sow8c3k",
      "amount": 111,
      "currency": "thb",
      "description": "activemerchant testing",
      "capture": true,
      "authorized": false,
      "paid": false,
      "transaction": null,
      "refunded": 0,
      "refunds": {
        "object": "list",
        "from": "1970-01-01T00:00:00+00:00",
        "to": "2015-05-08T05:37:50+00:00",
        "offset": 0,
        "limit": 20,
        "total": 0,
        "data": [

        ],
        "location": "/charges/chrg_4zyeviyhhhs7sow8c3k/refunds"
      },
      "failure_code": "invalid_security_code",
      "failure_message": "the security code is invalid",
      "card": {
        "object": "card",
        "id": "card_4zyevhammij8qhn2z59",
        "livemode": true,
        "country": "th",
        "city": "Bangkok",
        "postal_code": "11111",
        "financing": "",
        "last_digits": "1111",
        "brand": "Visa",
        "expiration_month": 1,
        "expiration_year": 2021,
        "fingerprint": "7qTrZY+fWNSQ9JTizVeVV7Jph4RBg6qANX3rBMXhpuE=",
        "name": "WARACHET SAMTALEE",
        "security_code_check": false,
        "created": "2015-05-08T05:37:42Z"
      },
      "customer": null,
      "ip": null,
      "dispute": null,
      "created": "2015-05-08T05:37:50Z"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "object": "error",
      "location": "https://docs.omise.co/api/errors#failed-capture",
      "code": "failed_capture",
      "message": "Charge is not authorized"
    }
    RESPONSE
  end

end
