require 'test_helper'

class GlobalCollectTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = GlobalCollectGateway.new(merchant_id: '1234',
                                        api_key_id: '39u4193urng12',
                                        secret_api_key: '109H/288H*50Y18W4/0G8571F245KA=')

    @credit_card = credit_card('4567350000427977')
    @declined_card = credit_card('5424180279791732')
    @accepted_amount = 4005
    @rejected_amount = 2997
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@accepted_amount, @credit_card, @options)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '000000142800000000920000100001', response.authorization

    capture = stub_comms do
      @gateway.capture(@accepted_amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/000000142800000000920000100001/, endpoint)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_successful_purchase_airline_fields
    options = @options.merge(
      airline_data: {
        code: 111,
        name: 'Spreedly Airlines',
        flight_date: '20190810',
        passenger_name: 'Randi Smith',
        flight_legs: [
          { arrival_airport: 'BDL',
            origin_airport: 'RDU',
            date: '20190810',
            carrier_code: 'SA',
            number: 596,
            airline_class: 'ZZ'},
          { arrival_airport: 'RDU',
            origin_airport: 'BDL',
            date: '20190817',
            carrier_code: 'SA',
            number: 597,
            airline_class: 'ZZ'}
        ]
      }
    )
    stub_comms do
      @gateway.purchase(@accepted_amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_equal 111, JSON.parse(data)['order']['additionalInput']['airlineData']['code']
      assert_equal '20190810', JSON.parse(data)['order']['additionalInput']['airlineData']['flightDate']
      assert_equal 2, JSON.parse(data)['order']['additionalInput']['airlineData']['flightLegs'].length
    end.respond_with(successful_authorize_response, successful_capture_response)
  end

  def test_purchase_does_not_run_capture_if_authorize_auto_captured
    response = stub_comms do
      @gateway.purchase(@accepted_amount, @credit_card, @options)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal 'CAPTURE_REQUESTED', response.params['payment']['status']
    assert_equal 1, response.responses.size
  end

  def test_authorize_with_pre_authorization_flag
    response = stub_comms do
      @gateway.authorize(@accepted_amount, @credit_card, @options.merge(pre_authorization: true))
    end.check_request do |endpoint, data, headers|
      assert_match(/PRE_AUTHORIZATION/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_authorize_without_pre_authorization_flag
    response = stub_comms do
      @gateway.authorize(@accepted_amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/FINAL_AUTHORIZATION/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_successful_authorization_with_extra_options
    options = @options.merge(
      {
        customer: '123987',
        email: 'example@example.com',
        order_id: '123',
        ip: '127.0.0.1',
        fraud_fields:
        {
          'website' => 'www.example.com',
          'giftMessage' => 'Happy Day!'
        }
      }
    )

    response = stub_comms do
      @gateway.authorize(@accepted_amount, @credit_card, options)
    end.check_request do |endpoint, data, headers|
      assert_match %r("fraudFields":{"website":"www.example.com","giftMessage":"Happy Day!","customerIpAddress":"127.0.0.1"}), data
      assert_match %r("merchantReference":"123"), data
      assert_match %r("customer":{"personalInformation":{"name":{"firstName":"Longbob","surname":"Longsen"}},"merchantCustomerId":"123987","contactDetails":{"emailAddress":"example@example.com","phoneNumber":"\(555\)555-5555"},"billingAddress":{"street":"456 My Street","additionalInfo":"Apt 1","zip":"K1C2N6","city":"Ottawa","state":"ON","countryCode":"CA"}}}), data
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_truncates_first_name_to_15_chars
    credit_card = credit_card('4567350000427977', { first_name: 'thisisaverylongfirstname' })

    response = stub_comms do
      @gateway.authorize(@accepted_amount, credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/thisisaverylong/, data)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal '000000142800000000920000100001', response.authorization
  end

  def test_handles_blank_names
    credit_card = credit_card('4567350000427977', { first_name: nil, last_name: nil})

    response = stub_comms do
      @gateway.authorize(@accepted_amount, credit_card, @options)
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@rejected_amount, @declined_card, @options)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal 'Not authorised', response.message
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, '', @options)
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(@accepted_amount, @credit_card, @options)
    end.respond_with(successful_capture_response)

    assert_success response
    assert_equal '000000142800000000920000100001', response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/000000142800000000920000100001/, endpoint)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void('5d53a33d960c46d00f5dc061947d998c')
    end.check_request do |endpoint, data, headers|
      assert_match(/5d53a33d960c46d00f5dc061947d998c/, endpoint)
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_verify_response)
    assert_equal '000000142800000000920000100001', response.authorization

    assert_success response
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_verify_response)
    assert_equal 'cee09c50-5d9d-41b8-b740-8c7bf06d2c66', response.authorization

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.authorize(@accepted_amount, @credit_card, @options)
    end.respond_with(successful_authorize_response)

    assert_equal '000000142800000000920000100001', response.authorization

    capture = stub_comms do
      @gateway.capture(@accepted_amount, response.authorization)
    end.respond_with(successful_capture_response)

    refund = stub_comms do
      @gateway.refund(@accepted_amount, capture.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/000000142800000000920000100001/, endpoint)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_refund_passes_currency_code
    stub_comms do
      @gateway.refund(@accepted_amount, '000000142800000000920000100001', {currency: 'COP'})
    end.check_request do |endpoint, data, headers|
      assert_match(/"currencyCode\":\"COP\"/, data)
    end.respond_with(failed_refund_response)
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, '')
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_rejected_refund
    response = stub_comms do
      @gateway.refund(@accepted_amount, '000000142800000000920000100001')
    end.respond_with(rejected_refund_response)

    assert_failure response
    assert_equal '1850', response.error_code
    assert_equal 'Status: REJECTED', response.message
  end

  def test_invalid_raw_response
    response = stub_comms do
      @gateway.purchase(@accepted_amount, @credit_card, @options)
    end.respond_with(invalid_json_response)

    assert_failure response
    assert_match %r{^Invalid response received from the Ingenico ePayments}, response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_scrub_invalid_response
    response = stub_comms do
      @gateway.purchase(@accepted_amount, @credit_card, @options)
    end.respond_with(invalid_json_plus_card_data).message

    assert_equal @gateway.scrub(response), scrubbed_invalid_json_plus
  end

  private

  def pre_scrubbed
    %q(
    opening connection to api-sandbox.globalcollect.com:443...
    opened
    starting SSL for api-sandbox.globalcollect.com:443...
    SSL established
    <- "POST //v1/1428/payments HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: GCS v1HMAC:96f16a41890565d0:Bqv5QtSXi+SdqXUyoBBeXUDlRvi5DzSm49zWuJTLX9s=\r\nDate: Tue, 15 Mar 2016 14:32:13 GMT\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-sandbox.globalcollect.com\r\nContent-Length: 560\r\n\r\n"
    <- "{\"order\":{\"amountOfMoney\":{\"amount\":\"100\",\"currencyCode\":\"USD\"},\"customer\":{\"merchantCustomerId\":null,\"personalInformation\":{\"name\":{\"firstName\":null,\"surname\":null}},\"billingAddress\":{\"street\":\"456 My Street\",\"additionalInfo\":\"Apt 1\",\"zip\":\"K1C2N6\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryCode\":\"CA\"}},\"contactDetails\":{\"emailAddress\":null}},\"cardPaymentMethodSpecificInput\":{\"paymentProductId\":\"1\",\"skipAuthentication\":\"true\",\"skipFraudService\":\"true\",\"card\":{\"cvv\":\"123\",\"cardNumber\":\"4567350000427977\",\"expiryDate\":\"0917\",\"cardholderName\":\"Longbob Longsen\"}}}"
    -> "HTTP/1.1 201 Created\r\n"
    -> "Date: Tue, 15 Mar 2016 18:32:14 GMT\r\n"
    -> "Server: Apache/2.4.16 (Unix) OpenSSL/1.0.1p\r\n"
    -> "Location: https://api-sandbox.globalcollect.com:443/v1/1428/payments/000000142800000000300000100001\r\n"
    -> "X-Powered-By: Servlet/3.0 JSP/2.2\r\n"
    -> "Connection: close\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "Content-Type: application/json\r\n"
    -> "\r\n"
    -> "457\r\n"
    reading 1111 bytes...
    -> "{\n   \"creationOutput\" : {\n      \"additionalReference\" : \"00000014280000000030\",\n      \"externalReference\" : \"000000142800000000300000100001\"\n   },\n   \"payment\" : {\n      \"id\" : \"000000142800000000300000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 100,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0917\"\n            },\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            }\n         }\n      },\n      \"status\" : \"PENDING_APPROVAL\",\n      \"statusOutput\" : {\n         \"isCancellable\" : true,\n         \"statusCode\" : 600,\n         \"statusCodeChangeDateTime\" : \"20160315193214\",\n         \"isAuthorized\" : true\n      }\n   }\n}"
    read 1111 bytes
    reading 2 bytes...
    -> ""
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    opening connection to api-sandbox.globalcollect.com:443...
    opened
    starting SSL for api-sandbox.globalcollect.com:443...
    SSL established
    <- "POST //v1/1428/payments/000000142800000000300000100001/approve HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: GCS v1HMAC:96f16a41890565d0:9GxB1mGvy8b2nXktFhxm9ppJVfcNrTNl7Szp/xiUXNc=\r\nDate: Tue, 15 Mar 2016 14:32:13 GMT\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-sandbox.globalcollect.com\r\nContent-Length: 208\r\n\r\n"
    <- "{\"order\":{\"amountOfMoney\":{\"amount\":\"100\",\"currencyCode\":\"USD\"},\"customer\":{\"merchantCustomerId\":null,\"personalInformation\":{\"name\":{\"firstName\":null,\"surname\":null}}},\"contactDetails\":{\"emailAddress\":null}}}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Tue, 15 Mar 2016 18:32:15 GMT\r\n"
    -> "Server: Apache/2.4.16 (Unix) OpenSSL/1.0.1p\r\n"
    -> "X-Powered-By: Servlet/3.0 JSP/2.2\r\n"
    -> "Connection: close\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "Content-Type: application/json\r\n"
    -> "\r\n"
    -> "3c7\r\n"
    reading 967 bytes...
    -> "{\n   \"payment\" : {\n      \"id\" : \"000000142800000000300000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 100,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0917\"\n            },\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            }\n         }\n      },\n      \"status\" : \"CAPTURE_REQUESTED\",\n      \"statusOutput\" : {\n         \"isCancellable\" : true,\n         \"statusCode\" : 800,\n         \"statusCodeChangeDateTime\" : \"20160315193215\",\n         \"isAuthorized\" : true\n      }\n   }\n}"
    read 967 bytes
    reading 2 bytes...
    -> ""
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    )
  end

  def post_scrubbed
    %q(
    opening connection to api-sandbox.globalcollect.com:443...
    opened
    starting SSL for api-sandbox.globalcollect.com:443...
    SSL established
    <- "POST //v1/1428/payments HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: [FILTERED]\r\nDate: Tue, 15 Mar 2016 14:32:13 GMT\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-sandbox.globalcollect.com\r\nContent-Length: 560\r\n\r\n"
    <- "{\"order\":{\"amountOfMoney\":{\"amount\":\"100\",\"currencyCode\":\"USD\"},\"customer\":{\"merchantCustomerId\":null,\"personalInformation\":{\"name\":{\"firstName\":null,\"surname\":null}},\"billingAddress\":{\"street\":\"456 My Street\",\"additionalInfo\":\"Apt 1\",\"zip\":\"K1C2N6\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryCode\":\"CA\"}},\"contactDetails\":{\"emailAddress\":null}},\"cardPaymentMethodSpecificInput\":{\"paymentProductId\":\"1\",\"skipAuthentication\":\"true\",\"skipFraudService\":\"true\",\"card\":{\"cvv\":\"[FILTERED]\",\"cardNumber\":\"[FILTERED]\",\"expiryDate\":\"0917\",\"cardholderName\":\"Longbob Longsen\"}}}"
    -> "HTTP/1.1 201 Created\r\n"
    -> "Date: Tue, 15 Mar 2016 18:32:14 GMT\r\n"
    -> "Server: Apache/2.4.16 (Unix) OpenSSL/1.0.1p\r\n"
    -> "Location: https://api-sandbox.globalcollect.com:443/v1/1428/payments/000000142800000000300000100001\r\n"
    -> "X-Powered-By: Servlet/3.0 JSP/2.2\r\n"
    -> "Connection: close\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "Content-Type: application/json\r\n"
    -> "\r\n"
    -> "457\r\n"
    reading 1111 bytes...
    -> "{\n   \"creationOutput\" : {\n      \"additionalReference\" : \"00000014280000000030\",\n      \"externalReference\" : \"000000142800000000300000100001\"\n   },\n   \"payment\" : {\n      \"id\" : \"000000142800000000300000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 100,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0917\"\n            },\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            }\n         }\n      },\n      \"status\" : \"PENDING_APPROVAL\",\n      \"statusOutput\" : {\n         \"isCancellable\" : true,\n         \"statusCode\" : 600,\n         \"statusCodeChangeDateTime\" : \"20160315193214\",\n         \"isAuthorized\" : true\n      }\n   }\n}"
    read 1111 bytes
    reading 2 bytes...
    -> ""
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    opening connection to api-sandbox.globalcollect.com:443...
    opened
    starting SSL for api-sandbox.globalcollect.com:443...
    SSL established
    <- "POST //v1/1428/payments/000000142800000000300000100001/approve HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: [FILTERED]\r\nDate: Tue, 15 Mar 2016 14:32:13 GMT\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-sandbox.globalcollect.com\r\nContent-Length: 208\r\n\r\n"
    <- "{\"order\":{\"amountOfMoney\":{\"amount\":\"100\",\"currencyCode\":\"USD\"},\"customer\":{\"merchantCustomerId\":null,\"personalInformation\":{\"name\":{\"firstName\":null,\"surname\":null}}},\"contactDetails\":{\"emailAddress\":null}}}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Tue, 15 Mar 2016 18:32:15 GMT\r\n"
    -> "Server: Apache/2.4.16 (Unix) OpenSSL/1.0.1p\r\n"
    -> "X-Powered-By: Servlet/3.0 JSP/2.2\r\n"
    -> "Connection: close\r\n"
    -> "Transfer-Encoding: chunked\r\n"
    -> "Content-Type: application/json\r\n"
    -> "\r\n"
    -> "3c7\r\n"
    reading 967 bytes...
    -> "{\n   \"payment\" : {\n      \"id\" : \"000000142800000000300000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 100,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0917\"\n            },\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            }\n         }\n      },\n      \"status\" : \"CAPTURE_REQUESTED\",\n      \"statusOutput\" : {\n         \"isCancellable\" : true,\n         \"statusCode\" : 800,\n         \"statusCodeChangeDateTime\" : \"20160315193215\",\n         \"isAuthorized\" : true\n      }\n   }\n}"
    read 967 bytes
    reading 2 bytes...
    -> ""
    -> "\r\n"
    read 2 bytes
    -> "0\r\n"
    -> "\r\n"
    Conn close
    )
  end

  def successful_authorize_response
    "{\n   \"creationOutput\" : {\n      \"additionalReference\" : \"00000014280000000092\",\n      \"externalReference\" : \"000000142800000000920000100001\"\n   },\n   \"payment\" : {\n      \"id\" : \"000000142800000000920000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 4005,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            },\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0920\"\n            }\n         }\n      },\n      \"status\" : \"PENDING_APPROVAL\",\n      \"statusOutput\" : {\n         \"isCancellable\" : true,\n         \"statusCategory\" : \"PENDING_MERCHANT\",\n         \"statusCode\" : 600,\n         \"statusCodeChangeDateTime\" : \"20191203162910\",\n         \"isAuthorized\" : true,\n         \"isRefundable\" : false\n      }\n   }\n}"
  end

  def failed_authorize_response
    %({\n   \"errorId\" : \"460ec7ed-f8be-4bd7-bf09-a4cbe07f774e\",\n   \"errors\" : [ {\n      \"code\" : \"430330\",\n      \"message\" : \"Not authorised\"\n   } ],\n   \"paymentResult\" : {\n      \"creationOutput\" : {\n         \"additionalReference\" : \"00000014280000000064\",\n         \"externalReference\" : \"000000142800000000640000100001\"\n      },\n      \"payment\" : {\n         \"id\" : \"000000142800000000640000100001\",\n         \"paymentOutput\" : {\n            \"amountOfMoney\" : {\n               \"amount\" : 100,\n               \"currencyCode\" : \"USD\"\n            },\n            \"references\" : {\n               \"paymentReference\" : \"0\"\n            },\n            \"paymentMethod\" : \"card\",\n            \"cardPaymentMethodSpecificOutput\" : {\n               \"paymentProductId\" : 1\n            }\n         },\n         \"status\" : \"REJECTED\",\n         \"statusOutput\" : {\n            \"errors\" : [ {\n               \"code\" : \"430330\",\n               \"requestId\" : \"55635\",\n               \"message\" : \"Not authorised\"\n            } ],\n            \"isCancellable\" : false,\n            \"statusCode\" : 100,\n            \"statusCodeChangeDateTime\" : \"20160316154235\",\n            \"isAuthorized\" : false\n         }\n      }\n   }\n})
  end

  def successful_capture_response
    "{\n   \"payment\" : {\n      \"id\" : \"000000142800000000920000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 4005,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            },\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0920\"\n            }\n         }\n      },\n      \"status\" : \"CAPTURE_REQUESTED\",\n      \"statusOutput\" : {\n         \"isCancellable\" : true,\n         \"statusCategory\" : \"PENDING_CONNECT_OR_3RD_PARTY\",\n         \"statusCode\" : 800,\n         \"statusCodeChangeDateTime\" : \"20191203163030\",\n         \"isAuthorized\" : true,\n         \"isRefundable\" : false\n      }\n   }\n}"
  end

  def failed_capture_response
    %({\n   \"errorId\" : \"6a3ffb94-e1ed-41bc-b9fb-4a8759b3fed7\",\n   \"errors\" : [ {\n      \"code\" : \"1002\",\n      \"propertyName\" : \"paymentId\",\n      \"message\" : \"INVALID_PAYMENT_ID\"\n   } ]\n})
  end

  def successful_refund_response
    %({\n   \"id\" : \"000000142800000000920000100001\",\n   \"refundOutput\" : {\n      \"amountOfMoney\" : {\n         \"amount\" : 4005,\n         \"currencyCode\" : \"USD\"\n      },\n      \"references\" : {\n         \"paymentReference\" : \"0\"\n      },\n      \"paymentMethod\" : \"card\",\n      \"cardRefundMethodSpecificOutput\" : {\n      }\n   },\n   \"status\" : \"REFUND_REQUESTED\",\n   \"statusOutput\" : {\n      \"isCancellable\" : true,\n      \"statusCode\" : 800,\n      \"statusCodeChangeDateTime\" : \"20160317215704\"\n   }\n})
  end

  def failed_refund_response
    %({\n   \"errorId\" : \"1bd31e6a-39dd-4214-941a-088a320e0286\",\n   \"errors\" : [ {\n      \"code\" : \"1002\",\n      \"propertyName\" : \"paymentId\",\n      \"message\" : \"INVALID_PAYMENT_ID\"\n   } ]\n})
  end

  def rejected_refund_response
    %({\n   \"id\" : \"00000022184000047564000-100001\",\n   \"refundOutput\" : {\n      \"amountOfMoney\" : {\n         \"amount\" : 627000,\n         \"currencyCode\" : \"COP\"\n      },\n      \"references\" : {\n         \"merchantReference\" : \"17091GTgZmcC\",\n         \"paymentReference\" : \"0\"\n      },\n      \"paymentMethod\" : \"card\",\n      \"cardRefundMethodSpecificOutput\" : {\n      }\n   },\n   \"status\" : \"REJECTED\",\n   \"statusOutput\" : {\n      \"isCancellable\" : false,\n      \"statusCategory\" : \"UNSUCCESSFUL\",\n      \"statusCode\" : 1850,\n      \"statusCodeChangeDateTime\" : \"20170313230631\"\n   }\n})
  end

  def successful_void_response
    %({\n   \"payment\" : {\n      \"id\" : \"000000142800000000920000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 100,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0917\"\n            },\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            }\n         }\n      },\n      \"status\" : \"CANCELLED\",\n      \"statusOutput\" : {\n         \"isCancellable\" : false,\n         \"statusCode\" : 99999,\n         \"statusCodeChangeDateTime\" : \"20160317191526\"\n      }\n   }\n})
  end

  def failed_void_response
    %({\n   \"errorId\" : \"9e38736e-15f3-4d6b-8517-aad3029619b9\",\n   \"errors\" : [ {\n      \"code\" : \"1002\",\n      \"propertyName\" : \"paymentId\",\n      \"message\" : \"INVALID_PAYMENT_ID\"\n   } ]\n})
  end

  def successful_verify_response
    %({\n   \"payment\" : {\n      \"id\" : \"000000142800000000920000100001\",\n      \"paymentOutput\" : {\n         \"amountOfMoney\" : {\n            \"amount\" : 100,\n            \"currencyCode\" : \"USD\"\n         },\n         \"references\" : {\n            \"paymentReference\" : \"0\"\n         },\n         \"paymentMethod\" : \"card\",\n         \"cardPaymentMethodSpecificOutput\" : {\n            \"paymentProductId\" : 1,\n            \"authorisationCode\" : \"OK1131\",\n            \"card\" : {\n               \"cardNumber\" : \"************7977\",\n               \"expiryDate\" : \"0917\"\n            },\n            \"fraudResults\" : {\n               \"fraudServiceResult\" : \"no-advice\",\n               \"avsResult\" : \"0\",\n               \"cvvResult\" : \"0\"\n            }\n         }\n      },\n      \"status\" : \"CANCELLED\",\n      \"statusOutput\" : {\n         \"isCancellable\" : false,\n         \"statusCode\" : 99999,\n         \"statusCodeChangeDateTime\" : \"20160318170240\"\n      }\n   }\n})
  end

  def failed_verify_response
    %({\n   \"errorId\" : \"cee09c50-5d9d-41b8-b740-8c7bf06d2c66\",\n   \"errors\" : [ {\n      \"code\" : \"430330\",\n      \"message\" : \"Not authorised\"\n   } ],\n   \"paymentResult\" : {\n      \"creationOutput\" : {\n         \"additionalReference\" : \"00000014280000000134\",\n         \"externalReference\" : \"000000142800000000920000100001\"\n      },\n      \"payment\" : {\n         \"id\" : \"000000142800000000920000100001\",\n         \"paymentOutput\" : {\n            \"amountOfMoney\" : {\n               \"amount\" : 100,\n               \"currencyCode\" : \"USD\"\n            },\n            \"references\" : {\n               \"paymentReference\" : \"0\"\n            },\n            \"paymentMethod\" : \"card\",\n            \"cardPaymentMethodSpecificOutput\" : {\n               \"paymentProductId\" : 1\n            }\n         },\n         \"status\" : \"REJECTED\",\n         \"statusOutput\" : {\n            \"errors\" : [ {\n               \"code\" : \"430330\",\n               \"requestId\" : \"64357\",\n               \"message\" : \"Not authorised\"\n            } ],\n            \"isCancellable\" : false,\n            \"statusCode\" : 100,\n            \"statusCodeChangeDateTime\" : \"20160318170253\",\n            \"isAuthorized\" : false\n         }\n      }\n   }\n})
  end

  def invalid_json_response
    '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
      <html><head>
        <title>502 Proxy Error</title>
      </head><body>
        <h1>Proxy Error</h1>
        <p>The proxy server received an invalid
            response from an upstream server.<br />
            The proxy server could not handle the request <em><a href="/v1/9040/payments">POST&nbsp;/v1/9040/payments</a></em>.<p>
            Reason: <strong>Error reading from remote server</strong></p></p>
      </body></html>'
  end

  def invalid_json_plus_card_data
    %q(<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
      <html><head>
      <title>502 Proxy Error</title>
      </head></html>
      opening connection to api-sandbox.globalcollect.com:443...
      opened
      starting SSL for api-sandbox.globalcollect.com:443...
      SSL established
      <- "POST //v1/1428/payments HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: GCS v1HMAC:96f16a41890565d0:Bqv5QtSXi+SdqXUyoBBeXUDlRvi5DzSm49zWuJTLX9s=\r\nDate: Tue, 15 Mar 2016 14:32:13 GMT\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api-sandbox.globalcollect.com\r\nContent-Length: 560\r\n\r\n"
      <- "{\"order\":{\"amountOfMoney\":{\"amount\":\"100\",\"currencyCode\":\"USD\"},\"customer\":{\"merchantCustomerId\":null,\"personalInformation\":{\"name\":{\"firstName\":null,\"surname\":null}},\"billingAddress\":{\"street\":\"456 My Street\",\"additionalInfo\":\"Apt 1\",\"zip\":\"K1C2N6\",\"city\":\"Ottawa\",\"state\":\"ON\",\"countryCode\":\"CA\"}},\"contactDetails\":{\"emailAddress\":null}},\"cardPaymentMethodSpecificInput\":{\"paymentProductId\":\"1\",\"skipAuthentication\":\"true\",\"skipFraudService\":\"true\",\"card\":{\"cvv\":\"123\",\"cardNumber\":\"4567350000427977\",\"expiryDate\":\"0917\",\"cardholderName\":\"Longbob Longsen\"}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Tue, 15 Mar 2016 18:32:14 GMT\r\n"
      -> "Server: Apache/2.4.16 (Unix) OpenSSL/1.0.1p\r\n"
      -> "Location: https://api-sandbox.globalcollect.com:443/v1/1428/payments/000000142800000000300000100001\r\n"
      -> "X-Powered-By: Servlet/3.0 JSP/2.2\r\n"
      -> "Connection: close\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Content-Type: application/json\r\n"
      -> "\r\n"
      -> "457\r\n")
  end

  def scrubbed_invalid_json_plus
    'Invalid response received from the Ingenico ePayments (formerly GlobalCollect) API.  Please contact Ingenico ePayments if you continue to receive this message.  (The raw response returned by the API was "<!DOCTYPE HTML PUBLIC \\"-//IETF//DTD HTML 2.0//EN\\">\\n      <html><head>\\n      <title>502 Proxy Error</title>\\n      </head></html>\\n      opening connection to api-sandbox.globalcollect.com:443...\\n      opened\\n      starting SSL for api-sandbox.globalcollect.com:443...\\n      SSL established\\n      <- \\"POST //v1/1428/payments HTTP/1.1\\\\r\\\\nContent-Type: application/json\\\\r\\\\nAuthorization: [FILTERED]\\\\r\\\\nDate: Tue, 15 Mar 2016 14:32:13 GMT\\\\r\\\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\\\r\\\\nAccept: */*\\\\r\\\\nUser-Agent: Ruby\\\\r\\\\nConnection: close\\\\r\\\\nHost: api-sandbox.globalcollect.com\\\\r\\\\nContent-Length: 560\\\\r\\\\n\\\\r\\\\n\\"\\n      <- \\"{\\\\\\"order\\\\\\":{\\\\\\"amountOfMoney\\\\\\":{\\\\\\"amount\\\\\\":\\\\\\"100\\\\\\",\\\\\\"currencyCode\\\\\\":\\\\\\"USD\\\\\\"},\\\\\\"customer\\\\\\":{\\\\\\"merchantCustomerId\\\\\\":null,\\\\\\"personalInformation\\\\\\":{\\\\\\"name\\\\\\":{\\\\\\"firstName\\\\\\":null,\\\\\\"surname\\\\\\":null}},\\\\\\"billingAddress\\\\\\":{\\\\\\"street\\\\\\":\\\\\\"456 My Street\\\\\\",\\\\\\"additionalInfo\\\\\\":\\\\\\"Apt 1\\\\\\",\\\\\\"zip\\\\\\":\\\\\\"K1C2N6\\\\\\",\\\\\\"city\\\\\\":\\\\\\"Ottawa\\\\\\",\\\\\\"state\\\\\\":\\\\\\"ON\\\\\\",\\\\\\"countryCode\\\\\\":\\\\\\"CA\\\\\\"}},\\\\\\"contactDetails\\\\\\":{\\\\\\"emailAddress\\\\\\":null}},\\\\\\"cardPaymentMethodSpecificInput\\\\\\":{\\\\\\"paymentProductId\\\\\\":\\\\\\"1\\\\\\",\\\\\\"skipAuthentication\\\\\\":\\\\\\"true\\\\\\",\\\\\\"skipFraudService\\\\\\":\\\\\\"true\\\\\\",\\\\\\"card\\\\\\":{\\\\\\"cvv\\\\\\":\\\\\\"[FILTERED]\\\\\\",\\\\\\"cardNumber\\\\\\":\\\\\\"[FILTERED]\\\\\\",\\\\\\"expiryDate\\\\\\":\\\\\\"0917\\\\\\",\\\\\\"cardholderName\\\\\\":\\\\\\"Longbob Longsen\\\\\\"}}}\\"\\n      -> \\"HTTP/1.1 201 Created\\\\r\\\\n\\"\\n      -> \\"Date: Tue, 15 Mar 2016 18:32:14 GMT\\\\r\\\\n\\"\\n      -> \\"Server: Apache/2.4.16 (Unix) OpenSSL/1.0.1p\\\\r\\\\n\\"\\n      -> \\"Location: https://api-sandbox.globalcollect.com:443/v1/1428/payments/000000142800000000300000100001\\\\r\\\\n\\"\\n      -> \\"X-Powered-By: Servlet/3.0 JSP/2.2\\\\r\\\\n\\"\\n      -> \\"Connection: close\\\\r\\\\n\\"\\n      -> \\"Transfer-Encoding: chunked\\\\r\\\\n\\"\\n      -> \\"Content-Type: application/json\\\\r\\\\n\\"\\n      -> \\"\\\\r\\\\n\\"\\n      -> \\"457\\\\r\\\\n\\"")'
  end
end
