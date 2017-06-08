require 'test_helper'

class SquareTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SquareGateway.new(:login => 'sandbox-xxx-client_id',
      :password => 'access token', :location_id => 'loc-id-xxx', :test => true)
    @card_nonce_ok = 'fake-card-nonce-ok'
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase Note'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @card_nonce_ok, @options)
    assert_success response

    assert_equal '1ea0c711-fdc5-5e16-7afe-1c76ad788254', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @card_nonce_ok, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    
    response = @gateway.authorize(@amount, @card_nonce_ok, @options)
    assert_success response

    assert_equal '2d604106-cccc-5299-4dc7-d0903cdfcb77', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, @card_nonce_ok, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    
    response = @gateway.capture(@amount, 'txn_id', @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'txn_id', @options)
    assert_failure response
    assert_equal "Location `CBASEO_-cM-R9G8gM73tbqIzKSU` does not have a transaction with ID `missing-txn-id`.", response.params['errors'].first['detail']
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)
    @options.merge!({:tender_id => 'xyz'})

    response = @gateway.refund(@amount, 'txn_id', @options)

    assert_success response
    assert_equal 'APPROVED', response.params['refund']['status']
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    @options.merge!({:tender_id => 'xyz'})

    response = @gateway.refund(@amount, 'txn_id', @options)
    assert_failure response
    assert_equal "Location `CBASEO_-cM-R9G8gM73tbqIzKSU` does not have a transaction tender with ID `abc`.", response.params['errors'].first['detail']
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    
    response = @gateway.void('txn-id', @options)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)
    
    response = @gateway.void('txn-id', @options)
    assert_failure response
    assert_equal "Location `CBASEO_-cM-R9G8gM73tbqIzKSU` does not have a transaction with ID `non-existant-authorization`.", response.params['errors'].first['detail']
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@card_nonce_ok, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@card_nonce_ok, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
  end

  def test_failed_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@card_nonce_ok, @options)
    end.respond_with(failed_authorize_response, failed_void_response)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal post_scrubbed_card_nonce, @gateway.scrub(pre_scrubbed_card_nonce)
  end

  def test_successful_purchase_invalid_json_returned
    @gateway.expects(:ssl_request).returns("{i am not json / invalid format responded}")

    assert response = @gateway.purchase(@amount, @card_nonce_ok, @options)
    assert_failure response
    assert_match(/^Invalid non-parsable json data response from the Square API/, response.message)
  end

  def test_declined_purchase_invalid_json_returned
    err = ActiveMerchant::ResponseError.new(stub(:body => "{i am not json / invalid format responded}"))
    @gateway.expects(:ssl_request).raises(err)

    assert response = @gateway.purchase(@amount, @card_nonce_ok, @options)
    assert_failure response
    assert_match(/^Invalid non-parsable json data response from the Square API/, response.message)
  end


  def test_successful_purchase_with_customer_card_on_file__new_customer_new_card
    s = sequence("request")
    @gateway.expects(:ssl_request).returns(successful_create_customer_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_link_card_to_customer_response).in_sequence(s)
    @gateway.expects(:ssl_request).returns(successful_purchase_for_customer_card_response).in_sequence(s)

    assert response = @gateway.purchase(100, @card_nonce_ok, {
      :customer => {
        :given_name => 'fname', :family_name => 'lname', :company_name => 'abc inc',
        :nickname => 'fred', :phone_number => '444-111-1232', :email => 'a@example.com',
        :description => 'describe me', :reference_id => 'ref-abc01',
        :billing_address => {
          :zip => '94103'
        }, 
        :cardholder_name => 'Alexander Hamilton',
        :address => { :address1 => '456 My Street', :address2 => 'Apt 1', :address3 => 'line 3',
          :city => 'Ottawa', :sublocality => 'county X', :sublocality_2 => 'sublocality 2',
          :sublocality_3 => 'sublocality 3', :state => 'ON',
          :administrative_district_level_2 => 'admin district 2', 
          :administrative_district_level_3 => 'admin district 3', :zip => 'K1C2N6', :country => 'CA'}
      }
    })
    assert_equal 3, response.responses.count
    assert_success first = response.responses[0]
    assert_match /Success/, first.message
    assert_success second = response.responses[1]
    assert_match /Success/, second.message
    assert_success third = response.responses[2]
    assert_match /Success/, third.message
  end


  private

  def pre_scrubbed_card_nonce
    <<-PRE_SCRUBBED
      opening connection to connect.squareup.com:443...
      opened
      starting SSL for connect.squareup.com:443...
      SSL established
      <- "POST /v2/locations/CBASEO_-cM-R9G8gM73tbqIzKSU/transactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer sandbox-sqXXXX-AA-AA__REDACTED_AABBBQ\r\nUser-Agent: Square/v2 ActiveMerchantBindings/1.60.0\r\nX-Square-Client-User-Agent: {\"bindings_version\":\"1.60.0\",\"lang\":\"ruby\",\"lang_version\":\"2.2.2 p95 (2015-04-13)\",\"platform\":\"x86_64-darwin14\",\"publisher\":\"active_merchant\"}\r\nAccept: application/json\r\nAccept-Encoding: \r\nConnection: close\r\nHost: connect.squareup.com\r\nContent-Length: 359\r\n\r\n"
      <- "{\"amount_money\":{\"amount\":100,\"currency\":\"USD\"},\"idempotency_key\":\"2175bae5cb8cc73f196733355af0a5ad\",\"card_nonce\":\"fake-card-nonce-ok\",\"billing_address\":{\"address_line_1\":\"456 My Street\",\"address_line_2\":\"Apt 1\",\"administrative_district_level_1\":\"ON\",\"locality\":\"Ottawa\",\"postal_code\":\"K1C2N6\",\"country\":\"CA\"},\"reference_id\":null,\"note\":\"Store Purchase Note\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Vary: Origin, Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "Date: Thu, 15 Sep 2016 03:48:59 GMT\r\n"
      -> "connection: close\r\n"
      -> "Strict-Transport-Security: max-age=631152000\r\n"
      -> "content-length: 554\r\n"
      -> "\r\n"
      reading 554 bytes...
      -> "{\"transaction\":{\"id\":\"ad8a3669-39df-5bb8-737e-d2d1ec11f0e1\",\"location_id\":\"CBASEO_-cM-R9G8gM73tbqIzKSU\",\"created_at\":\"2016-09-15T03:48:59Z\",\"tenders\":[{\"id\":\"561e4358-ef65-5c2d-60b9-af777cea7447\",\"location_id\":\"CBASEO_-cM-R9G8gM73tbqIzKSU\",\"transaction_id\":\"ad8a3669-39df-5bb8-737e-d2d1ec11f0e1\",\"created_at\":\"2016-09-15T03:48:59Z\",\"note\":\"Store Purchase Note\",\"amount_money\":{\"amount\":100,\"currency\":\"USD\"},\"type\":\"CARD\",\"card_details\":{\"status\":\"CAPTURED\",\"card\":{\"card_brand\":\"JCB\",\"last_4\":\"0650\"},\"entry_method\":\"KEYED\"}}],\"product\":\"EXTERNAL_API\"}}"
      read 554 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed_card_nonce
    <<-POST_SCRUBBED
      opening connection to connect.squareup.com:443...
      opened
      starting SSL for connect.squareup.com:443...
      SSL established
      <- "POST /v2/locations/CBASEO_-cM-R9G8gM73tbqIzKSU/transactions HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nUser-Agent: Square/v2 ActiveMerchantBindings/1.60.0\r\nX-Square-Client-User-Agent: {\"bindings_version\":\"1.60.0\",\"lang\":\"ruby\",\"lang_version\":\"2.2.2 p95 (2015-04-13)\",\"platform\":\"x86_64-darwin14\",\"publisher\":\"active_merchant\"}\r\nAccept: application/json\r\nAccept-Encoding: \r\nConnection: close\r\nHost: connect.squareup.com\r\nContent-Length: 359\r\n\r\n"
      <- "{\"amount_money\":{\"amount\":100,\"currency\":\"USD\"},\"idempotency_key\":\"2175bae5cb8cc73f196733355af0a5ad\",\"card_nonce\":\"[FILTERED]\",\"billing_address\":{\"address_line_1\":\"456 My Street\",\"address_line_2\":\"Apt 1\",\"administrative_district_level_1\":\"ON\",\"locality\":\"Ottawa\",\"postal_code\":\"K1C2N6\",\"country\":\"CA\"},\"reference_id\":null,\"note\":\"Store Purchase Note\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Vary: Origin, Accept-Encoding\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-Xss-Protection: 1; mode=block\r\n"
      -> "Date: Thu, 15 Sep 2016 03:48:59 GMT\r\n"
      -> "connection: close\r\n"
      -> "Strict-Transport-Security: max-age=631152000\r\n"
      -> "content-length: 554\r\n"
      -> "\r\n"
      reading 554 bytes...
      -> "{\"transaction\":{\"id\":\"ad8a3669-39df-5bb8-737e-d2d1ec11f0e1\",\"location_id\":\"CBASEO_-cM-R9G8gM73tbqIzKSU\",\"created_at\":\"2016-09-15T03:48:59Z\",\"tenders\":[{\"id\":\"561e4358-ef65-5c2d-60b9-af777cea7447\",\"location_id\":\"CBASEO_-cM-R9G8gM73tbqIzKSU\",\"transaction_id\":\"ad8a3669-39df-5bb8-737e-d2d1ec11f0e1\",\"created_at\":\"2016-09-15T03:48:59Z\",\"note\":\"Store Purchase Note\",\"amount_money\":{\"amount\":100,\"currency\":\"USD\"},\"type\":\"CARD\",\"card_details\":{\"status\":\"CAPTURED\",\"card\":{\"card_brand\":\"JCB\",\"last_4\":\"0650\"},\"entry_method\":\"KEYED\"}}],\"product\":\"EXTERNAL_API\"}}"
      read 554 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    #   Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
    #   to "true" when running remote tests:

    #   $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
    #     test/remote/gateways/remote_square_test.rb \
    #     -n test_successful_purchase

    #   Also need to add to square.rb#headers method: 'Accept-Encoding' => ''
    #   So that the response is not gzipped.
    <<-RESPONSE
    {
      "transaction": {
        "id": "1ea0c711-fdc5-5e16-7afe-1c76ad788254",
        "location_id": "CBASEO_-cM-R9G8gM73tbqIzKSU",
        "created_at": "2016-09-12T04:30:56Z",
        "tenders": [
          {
            "id": "be45871a-9e1b-513c-5972-46427a96a34b",
            "location_id": "CBASEO_-cM-R9G8gM73tbqIzKSU",
            "transaction_id": "1ea0c711-fdc5-5e16-7afe-1c76ad788254",
            "created_at": "2016-09-12T04:30:56Z",
            "note": "Store Purchase Note",
            "amount_money": {
              "amount": 100,
              "currency": "USD"
            },
            "type": "CARD",
            "card_details": {
              "status": "CAPTURED",
              "card": {
                "card_brand": "MASTERCARD",
                "last_4": "9029"
              },
              "entry_method": "KEYED"
            }
          }
        ],
        "product": "EXTERNAL_API"
      }
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
       {"errors":[{"category":"PAYMENT_METHOD_ERROR","code":"CARD_DECLINED","detail":"Card declined."}]}
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
      {"transaction":{"id":"2d604106-cccc-5299-4dc7-d0903cdfcb77","location_id":"CBASEO_-cM-R9G8gM73tbqIzKSU","created_at":"2016-09-15T04:59:51Z","tenders":[{"id":"38f923c7-4a09-5fb2-4087-05aaecb7dba9","location_id":"CBASEO_-cM-R9G8gM73tbqIzKSU","transaction_id":"2d604106-cccc-5299-4dc7-d0903cdfcb77","created_at":"2016-09-15T04:59:51Z","note":"Store Purchase Note","amount_money":{"amount":100,"currency":"USD"},"type":"CARD","card_details":{"status":"AUTHORIZED","card":{"card_brand":"AMERICAN_EXPRESS","last_4":"6550"},"entry_method":"KEYED"}}],"product":"EXTERNAL_API"}}
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
      {"errors":[{"category":"PAYMENT_METHOD_ERROR","code":"CARD_DECLINED","detail":"Card declined."}]}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {}
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {"errors":[{"category":"INVALID_REQUEST_ERROR","code":"NOT_FOUND","detail":"Location `CBASEO_-cM-R9G8gM73tbqIzKSU` does not have a transaction with ID `missing-txn-id`.","field":"transaction_id"}]}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      {"refund":{"id":"aa71cea0-8f68-5c4d-6ca5-775dafbfedc9","location_id":"CBASEO_-cM-R9G8gM73tbqIzKSU","transaction_id":"b9347714-3224-5002-557a-accbcb1f016e","tender_id":"d6edb74b-9050-5e2f-7eec-8eb66a0aab4a","created_at":"2016-09-15T05:05:02Z","reason":"oops!","amount_money":{"amount":100,"currency":"USD"},"status":"APPROVED"}}
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
      {"errors":[{"category":"INVALID_REQUEST_ERROR","code":"NOT_FOUND","detail":"Location `CBASEO_-cM-R9G8gM73tbqIzKSU` does not have a transaction tender with ID `abc`."}]}
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      {}
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
      {"errors":[{"category":"INVALID_REQUEST_ERROR","code":"NOT_FOUND","detail":"Location `CBASEO_-cM-R9G8gM73tbqIzKSU` does not have a transaction with ID `non-existant-authorization`.","field":"transaction_id"}]}
    RESPONSE
  end

  def successful_create_customer_response
    <<-RESPONSE
      {
        "customer":{
          "id":"CBASEGSKal7z6RLe1BPcnXW60t0",
          "created_at":"2016-09-18T15:34:39.445Z",
          "updated_at":"2016-09-18T15:34:39.445Z",
          "given_name":"fname",
          "family_name":"lname",
          "nickname":"fred",
          "email_address":"a@example.com",
          "address":{
            "address_line_1":"456 My Street",
            "address_line_2":"Apt 1",
            "address_line_3":"line 3",
            "locality":"Ottawa",
            "sublocality":"county X",
            "sublocality_2":"sublocality 2",
            "sublocality_3":"sublocality 3",
            "administrative_district_level_1":"ON",
            "administrative_district_level_2":"admin district 2",
            "administrative_district_level_3":"admin district 3",
            "postal_code":"K1C2N6",
            "country":"CA"
          },
          "phone_number":"444-111-1232",
          "reference_id":"ref-abc01",
          "preferences":{
            "email_unsubscribed":false
          },
          "note":"describe me"
        }
      }
    RESPONSE
  end

  def successful_link_card_to_customer_response
    <<-RESPONSE
      {
        "card":{
          "id":"c9fbd9a7-6cba-5b63-6f65-c9b4c9f37b26",
          "card_brand":"AMERICAN_EXPRESS",
          "last_4":"6550",
          "exp_month":9,
          "exp_year":2018,
          "cardholder_name":"Alexander Hamilton",
          "billing_address":{
            "postal_code":"94103",
            "country":"ZZ"
          }
        }
      }
    RESPONSE
  end

  def successful_purchase_for_customer_card_response
    <<-RESPONSE
      {
        "transaction":{
          "id":"9e2bf3d1-c4ae-5966-7f3e-310a2cb36e75",
          "location_id":"CBASEO_-cM-R9G8gM73tbqIzKSU",
          "created_at":"2016-09-18T15:34:40Z",
          "tenders":[
            {
              "id":"68b51bc0-5142-5646-5573-c57965d3aef3",
              "location_id":"CBASEO_-cM-R9G8gM73tbqIzKSU",
              "transaction_id":"9e2bf3d1-c4ae-5966-7f3e-310a2cb36e75",
              "created_at":"2016-09-18T15:34:40Z",
              "note":"Online Transaction",
              "amount_money":{
                "amount":200,
                "currency":"USD"
              },
              "customer_id":"CBASEGSKal7z6RLe1BPcnXW60t0",
              "type":"CARD",
              "card_details":{
                "status":"CAPTURED",
                "card":{
                  "id":"c9fbd9a7-6cba-5b63-6f65-c9b4c9f37b26",
                  "card_brand":"AMERICAN_EXPRESS",
                  "last_4":"6550",
                  "exp_month":9,
                  "exp_year":2018
                },
                "entry_method":"ON_FILE"
              }
            }
          ],
          "product":"EXTERNAL_API"
        }
      }
    RESPONSE
  end
end
