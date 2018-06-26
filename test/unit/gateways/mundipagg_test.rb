require 'test_helper'

class MundipaggTest < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = MundipaggGateway.new(api_key: 'my_api_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'ch_90Vjq8TrwfP74XJO', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_holder_document
    @options.merge!(holder_document: 'a1b2c3d4')
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_match(/a1b2c3d4/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert response.test?
  end

  def test_billing_not_sent
    @options.delete(:billing_address)
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      refute data['billing_address']
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'ch_gm5wrlGMI2Fb0x6K', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'ch_gm5wrlGMI2Fb0x6K', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'K1J5B1YFLE')
    assert_success response

    assert_equal 'ch_RbPVPWMH2bcGA50z', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'abc')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('ch_RbPVPWMH2bcGA50z')
    assert_success response

    assert_equal 'ch_RbPVPWMH2bcGA50z', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('abc')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_authorize_response)
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'ch_G9rB74PI3uoDMxAo', response.authorization
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal 'Simulator|Transação de simulação autorizada com sucesso', response.message
  end

  def test_sucessful_store
    @gateway.expects(:ssl_post).times(2).returns(successful_create_customer_response, successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response

    assert_equal 'cus_N70xAX6S65cMnokB|card_51ElNwYSVJFpRe0g', response.authorization
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to api.mundipagg.com:443...
      opened
      starting SSL for api.mundipagg.com:443...
      SSL established
      <- "POST /core/v1/charges/ HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic c2tfdGVzdF9keE1WOE51QnZpajZKNVhuOg==\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.mundipagg.com\r\nContent-Length: 424\r\n\r\n"
      <- "{\"amount\":100,\"currency\":\"USD\",\"customer\":{\"email\":null,\"name\":\"Longbob Longsen\"},\"payment\":{\"payment_method\":\"credit_card\",\"credit_card\":{\"card\":{\"number\":\"4000100011112224\",\"holder_name\":\"Longbob Longsen\",\"exp_month\":9,\"exp_year\":2019,\"cvv\":\"123\",\"billing_address\":{\"street\":\"My Street\",\"number\":\"456\",\"compliment\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\",\"zip_code\":\"K1C2N6\",\"neighborhood\":\"Sesame Street\"}}}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 01 Feb 2018 20:23:19 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 801\r\n"
      -> "Connection: close\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Expires: -1\r\n"
      -> "Set-Cookie: TS01e8e2cd=0118d560cc62281517c87bb3b52c62fba3f9d13acb485adc69cac121833699beb2a66ca4bfe3e2af65dfe2f67542ec36ff8e41db56; Path=/; Domain=.api.mundipagg.com\r\n"
      -> "\r\n"
      reading 801 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\x95T\xCDn\x9C0\x10\xBEW\xEA; \xCEA2,,lnmRU\xD5\xB6I\x9AM\xAA\xAA\x174k\x9B]\xB7`\x13c\xB2\xD9\xA4\xFB4=\xF4A\xF2b\xB5\xCD\xC2\x82H\x95\xE4\x84\x98\xEF\x9B\xF1\xCC7?\x0Fo\xDF8\x8E\xCB\x88{\xEC\xB8x\x9D\xBE\x17\xBF\xD0\x1C>_G??\xDD\x7F\xBF\xF9\x9A\xBBG\x16\xC7\x82P\xC3\xF8\x18$\x97'\xA7\xC1b6\xDF\x03+Pt\x03\xDB\xB4\t\x004\xC1\x81\x8F#\x8FNH\xE6\x85\x10\x11o\x19\xFB\xB1\x87&\xD3I\x12M!\x0E\t\xEC\x1D\xA1\x105W\xDA\xC9G\xA8\xB1\x94\xC0H:6W\nT]\x99\xE8\x86\xD0\xE6SKI9\xDE\x1A\xF3\xF5\xE2\xD4m#l\v\xCAUZP\xB5\x16ME\x92\x12\xA6R\f\x92\xB8\xFDW\xCC\vn\x80\xFC\xC4C\x81\x87\xFC\xAB\x00\x1D\a\x93c\x7F\xF6\xA3\x8D/\xA9.\xEC\xFF\xC4\xA4%\xD6%y\x19\x11\xD7\x95\x12\x05\x95\x9A\xF6`\f\a\xD1\xEB*\xF5O\xCF/6\xE8j\xB3Y\xD0\xF8\xC3\\$\x8D\x8F\xA6p(\xAC\xEE\x9F\x05_-\xC5\xD21\xDF\x8A\xF2\x0E\xA7\x05\xB0\xDC\x10:\v\xA19\xE375\xB5\"f\x90W\xB4E^Z\xD3+\xAA2z\xAE\x05\xA7\xA6=\x0F;c\xD95\xD5\xE6P\xA9TI\xE0\x15`\xC5\x04\x1FUm\xB0\xF4\xAE\xD8\xC2\xE6v\xC3\xC2\xB3\xEB \x96\xF3\xB2\v\xDA\xF3L\xD5\xB6\xA4O\xB6r4}q\xE0\x87\xD3 \x9Eya\x92\x10/DQ\xE6\xC1\x94\xF8\x1E\xC28\xCE\xA2)\xCEhD;\xD7\xD1\xA0\rF\rC\xA9j\xFD`G\xAFj\x8Cie0%\xEBNR\xC6\xB5K\x9E\x9B\xA13\x90\xDF\x05\xC775\x93T\xA6m\xFF*V\xD49(!\xDD\x11\x05\xB2\x8C\xE5\fl\xAD\xED\x9A\x8DY\xAA)1\fga\x18\x8Da^\xD5\x06\x9E\xA0d\x12=\x01C\xAD\xD6]\xF0Y\x10\xC5\xF1lL*t}\xB0\xB2\x94E\x9B\xEE\xEF+\xDB\x89\xC7\xBF\x8F\x7F\x84C\xA8\xD3\xD4\xD1\xFC\xEA\xA0B\xB2{ \xE0`Q8Z!\x1D@\x8C\xE3J\xAA\xA5<\xD4\x86:\x86(\xA9\x84A\x8Fm\x9E\xC0I\xBA\xD7\xBF\xA3\xDA\xAEw3t\xD8\x1DmN\xEF\xE4\xFC'\x8F.\xD4\xEA\x12\xF3\xFB`\x19\xB7N\x9A\x951\xA9\xE7\xB0bw)a+f{\xE4\x86\b!\x1F\xF5HvV3Q\xCB\x1E\b\x82\xB0GYj\x15\xEC\x83\xDFX\x05=\xFBZ\xE4\xA4\xD7\xE5\xFFl\xA9\xD9\xD3\xBB2-\x04WkM\x9B\r\xCD[\n\xE6\xE8%\xEB\x01\x87I4[pK{\xA1\x9E[\xE3\xD9\x8F\x1E\xF9\xB9E\x1E\x90\x97,\xD7\xB7c\x95\x02!\xB2\x99\xF5No\x9B\x92\xA4\xD4\x86\xF9\xB2u\x16\xCD\xCFQ\x0F\xE7u\xB1\xB4\xE7\xCD\r\xA3\xE9\x00\xB9ge\xD7\xFD\xB9\x7F\x12\x9C\raN\xD9j\xBD\x14r-\x9A\x9B\xBD\xA0\x95\xD6\xF3\xA9'0S\xF6\xE2\x9F+\x05\e\x18@F0\xFB\xC0\xF9\xD9\xD0\xC5l\xB9\xB4^'\xEF\x06\x88.\x95\xA6\xFE>\xDF#\xA7+\xEA\xC8\x19&\xD0\xBA\xEC\x0EB\rO\xD2\x9E\xB1\xEBf\xF5\xC5\rzE{\xBAS\xA7;S\n^\xD1\xC16\xB4\xEA\xEA\bm6\xF6\x18\xBF}\xB3\xFB\aD\t\x1C\xBA\xE0\a\x00\x00"
      read 801 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to api.mundipagg.com:443...
      opened
      starting SSL for api.mundipagg.com:443...
      SSL established
      <- "POST /core/v1/charges/ HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]==\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.mundipagg.com\r\nContent-Length: 424\r\n\r\n"
      <- "{\"amount\":100,\"currency\":\"USD\",\"customer\":{\"email\":null,\"name\":\"Longbob Longsen\"},\"payment\":{\"payment_method\":\"credit_card\",\"credit_card\":{\"card\":{\"number\":\"[FILTERED]\",\"holder_name\":\"Longbob Longsen\",\"exp_month\":9,\"exp_year\":2019,\"cvv\":\"[FILTERED]\",\"billing_address\":{\"street\":\"My Street\",\"number\":\"456\",\"compliment\":\"Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\",\"zip_code\":\"K1C2N6\",\"neighborhood\":\"Sesame Street\"}}}}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Date: Thu, 01 Feb 2018 20:23:19 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 801\r\n"
      -> "Connection: close\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Expires: -1\r\n"
      -> "Set-Cookie: TS01e8e2cd=0118d560cc62281517c87bb3b52c62fba3f9d13acb485adc69cac121833699beb2a66ca4bfe3e2af65dfe2f67542ec36ff8e41db56; Path=/; Domain=.api.mundipagg.com\r\n"
      -> "\r\n"
      reading 801 bytes...
      -> "\x1F\x8B\b\x00\x00\x00\x00\x00\x04\x00\x95T\xCDn\x9C0\x10\xBEW\xEA; \xCEA2,,lnmRU\xD5\xB6I\x9AM\xAA\xAA\x174k\x9B]\xB7`\x13c\xB2\xD9\xA4\xFB4=\xF4A\xF2b\xB5\xCD\xC2\x82H\x95\xE4\x84\x98\xEF\x9B\xF1\xCC7?\x0Fo\xDF8\x8E\xCB\x88{\xEC\xB8x\x9D\xBE\x17\xBF\xD0\x1C>_G??\xDD\x7F\xBF\xF9\x9A\xBBG\x16\xC7\x82P\xC3\xF8\x18$\x97'\xA7\xC1b6\xDF\x03+Pt\x03\xDB\xB4\t\x004\xC1\x81\x8F#\x8FNH\xE6\x85\x10\x11o\x19\xFB\xB1\x87&\xD3I\x12M!\x0E\t\xEC\x1D\xA1\x105W\xDA\xC9G\xA8\xB1\x94\xC0H:6W\nT]\x99\xE8\x86\xD0\xE6SKI9\xDE\x1A\xF3\xF5\xE2\xD4m#l\v\xCAUZP\xB5\x16ME\x92\x12\xA6R\f\x92\xB8\xFDW\xCC\vn\x80\xFC\xC4C\x81\x87\xFC\xAB\x00\x1D\a\x93c\x7F\xF6\xA3\x8D/\xA9.\xEC\xFF\xC4\xA4%\xD6%y\x19\x11\xD7\x95\x12\x05\x95\x9A\xF6`\f\a\xD1\xEB*\xF5O\xCF/6\xE8j\xB3Y\xD0\xF8\xC3\\$\x8D\x8F\xA6p(\xAC\xEE\x9F\x05_-\xC5\xD21\xDF\x8A\xF2\x0E\xA7\x05\xB0\xDC\x10:\v\xA19\xE375\xB5\"f\x90W\xB4E^Z\xD3+\xAA2z\xAE\x05\xA7\xA6=\x0F;c\xD95\xD5\xE6P\xA9TI\xE0\x15`\xC5\x04\x1FUm\xB0\xF4\xAE\xD8\xC2\xE6v\xC3\xC2\xB3\xEB \x96\xF3\xB2\v\xDA\xF3L\xD5\xB6\xA4O\xB6r4}q\xE0\x87\xD3 \x9Eya\x92\x10/DQ\xE6\xC1\x94\xF8\x1E\xC28\xCE\xA2)\xCEhD;\xD7\xD1\xA0\rF\rC\xA9j\xFD`G\xAFj\x8Cie0%\xEBNR\xC6\xB5K\x9E\x9B\xA13\x90\xDF\x05\xC775\x93T\xA6m\xFF*V\xD49(!\xDD\x11\x05\xB2\x8C\xE5\fl\xAD\xED\x9A\x8DY\xAA)1\fga\x18\x8Da^\xD5\x06\x9E\xA0d\x12=\x01C\xAD\xD6]\xF0Y\x10\xC5\xF1lL*t}\xB0\xB2\x94E\x9B\xEE\xEF+\xDB\x89\xC7\xBF\x8F\x7F\x84C\xA8\xD3\xD4\xD1\xFC\xEA\xA0B\xB2{ \xE0`Q8Z!\x1D@\x8C\xE3J\xAA\xA5<\xD4\x86:\x86(\xA9\x84A\x8Fm\x9E\xC0I\xBA\xD7\xBF\xA3\xDA\xAEw3t\xD8\x1DmN\xEF\xE4\xFC'\x8F.\xD4\xEA\x12\xF3\xFB`\x19\xB7N\x9A\x951\xA9\xE7\xB0bw)a+f{\xE4\x86\b!\x1F\xF5HvV3Q\xCB\x1E\b\x82\xB0GYj\x15\xEC\x83\xDFX\x05=\xFBZ\xE4\xA4\xD7\xE5\xFFl\xA9\xD9\xD3\xBB2-\x04WkM\x9B\r\xCD[\n\xE6\xE8%\xEB\x01\x87I4[pK{\xA1\x9E[\xE3\xD9\x8F\x1E\xF9\xB9E\x1E\x90\x97,\xD7\xB7c\x95\x02!\xB2\x99\xF5No\x9B\x92\xA4\xD4\x86\xF9\xB2u\x16\xCD\xCFQ\x0F\xE7u\xB1\xB4\xE7\xCD\r\xA3\xE9\x00\xB9ge\xD7\xFD\xB9\x7F\x12\x9C\raN\xD9j\xBD\x14r-\x9A\x9B\xBD\xA0\x95\xD6\xF3\xA9'0S\xF6\xE2\x9F+\x05\e\x18@F0\xFB\xC0\xF9\xD9\xD0\xC5l\xB9\xB4^'\xEF\x06\x88.\x95\xA6\xFE>\xDF#\xA7+\xEA\xC8\x19&\xD0\xBA\xEC\x0EB\rO\xD2\x9E\xB1\xEBf\xF5\xC5\rzE{\xBAS\xA7;S\n^\xD1\xC16\xB4\xEA\xEA\bm6\xF6\x18\xBF}\xB3\xFB\aD\t\x1C\xBA\xE0\a\x00\x00"
      read 801 bytes
      Conn close
    )
  end

  def successful_purchase_response
    %(
      {
        "id": "ch_90Vjq8TrwfP74XJO",
        "code": "ME0KIN4A0O",
        "gateway_id": "162bead8-23a0-4708-b687-078a69a1aa7c",
        "amount": 100,
        "paid_amount": 100,
        "status": "paid",
        "currency": "USD",
        "payment_method": "credit_card",
        "paid_at": "2018-02-01T18:41:05Z",
        "created_at": "2018-02-01T18:41:04Z",
        "updated_at": "2018-02-01T18:41:04Z",
        "customer": {
          "id": "cus_VxJX2NmTqyUnXgL9",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-01T18:41:04Z",
          "updated_at": "2018-02-01T18:41:04Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_JNzjzadcVZHlG8K2",
          "transaction_type": "credit_card",
          "gateway_id": "c579c8fa-53d7-41a8-b4cc-a03c712ebbb7",
          "amount": 100,
          "status": "captured",
          "success": true,
          "installments": 1,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_tid": "198548",
          "acquirer_nsu": "866277",
          "acquirer_auth_code": "713736",
          "acquirer_message": "Simulator|Transação de simulação autorizada com sucesso",
          "acquirer_return_code": "0",
          "operation_type": "auth_and_capture",
          "card": {
            "id": "card_pD02Q6WtOTB7a3kE",
            "first_six_digits": "400010",
            "last_four_digits": "2224",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-01T18:41:04Z",
            "updated_at": "2018-02-01T18:41:04Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-01T18:41:04Z",
          "updated_at": "2018-02-01T18:41:04Z",
          "gateway_response": {
            "code": "201"
          }
        }
      }
    )
  end

  def failed_purchase_response
    %(
      {
        "id": "ch_ykXLG3RfVfNE4dZe",
        "code": "3W80HGVS0R",
        "gateway_id": "79ae6732-1b60-4008-80f5-0d1be8ec41a7",
        "amount": 105200,
        "status": "failed",
        "currency": "USD",
        "payment_method": "credit_card",
        "created_at": "2018-02-01T18:42:44Z",
        "updated_at": "2018-02-01T18:42:45Z",
        "customer": {
          "id": "cus_0JnywlzI3hV6ZNe2",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-01T18:42:44Z",
          "updated_at": "2018-02-01T18:42:44Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_nVx8730IjhOR8PD2",
          "transaction_type": "credit_card",
          "gateway_id": "f3993413-73a0-4e8d-a7bc-eb3ed198c770",
          "amount": 105200,
          "status": "not_authorized",
          "success": false,
          "installments": 1,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_message": "Simulator|Transação de simulada negada por falta de crédito, utilizado para realizar simulação de autorização parcial.",
          "acquirer_return_code": "92",
          "operation_type": "auth_and_capture",
          "card": {
            "id": "card_VrxnWlrsOHOpzMj5",
            "first_six_digits": "400030",
            "last_four_digits": "2220",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-01T18:42:44Z",
            "updated_at": "2018-02-01T18:42:44Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-01T18:42:44Z",
          "updated_at": "2018-02-01T18:42:44Z",
          "gateway_response": {
            "code": "201"
          }
        }
      }
    )
  end

  def successful_authorize_response
    %(
      {
        "id": "ch_gm5wrlGMI2Fb0x6K",
        "code": "K1J5B1YFLE",
        "gateway_id": "3b6c0f72-c4b3-48b2-8eb7-2424321a6c93",
        "amount": 100,
        "status": "pending",
        "currency": "USD",
        "payment_method": "credit_card",
        "created_at": "2018-02-01T16:43:30Z",
        "updated_at": "2018-02-01T16:43:30Z",
        "customer": {
          "id": "cus_bVWYqeTmpu9VYLd9",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-01T16:43:30Z",
          "updated_at": "2018-02-01T16:43:30Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_DWJlEApZI9UL2qR9",
          "transaction_type": "credit_card",
          "gateway_id": "6dae95a7-6b7f-4431-be33-cb3ecf21287a",
          "amount": 100,
          "status": "authorized_pending_capture",
          "success": true,
          "installments": 1,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_tid": "25970",
          "acquirer_nsu": "506128",
          "acquirer_auth_code": "523448",
          "acquirer_message": "Simulator|Transação de simulação autorizada com sucesso",
          "acquirer_return_code": "0",
          "operation_type": "auth_only",
          "card": {
            "id": "card_J26O3K2hvPc2vOQG",
            "first_six_digits": "400010",
            "last_four_digits": "2224",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-01T16:43:30Z",
            "updated_at": "2018-02-01T16:43:30Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-01T16:43:31Z",
          "updated_at": "2018-02-01T16:43:31Z",
          "gateway_response": {
            "code": "201"
          }
        }
      }
    )
  end

  def failed_authorize_response
    %(
      {
        "id": "ch_O4bW13ukwF5XpmLg",
        "code": "2KW1C5VSZO",
        "gateway_id": "9bf24ea7-e913-44bc-92ca-50491ffcd7a1",
        "amount": 105200,
        "status": "failed",
        "currency": "USD",
        "payment_method": "credit_card",
        "created_at": "2018-02-01T18:46:06Z",
        "updated_at": "2018-02-01T18:46:06Z",
        "customer": {
          "id": "cus_7VGAGxqI4OUwZ392",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-01T18:46:06Z",
          "updated_at": "2018-02-01T18:46:06Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_g0JYdDXcDesqd36E",
          "transaction_type": "credit_card",
          "gateway_id": "c0896dd6-0d5c-4e8b-9d92-df5a70e3fb76",
          "amount": 105200,
          "status": "not_authorized",
          "success": false,
          "installments": 1,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_message": "Simulator|Transação de simulada negada por falta de crédito, utilizado para realizar simulação de autorização parcial.",
          "acquirer_return_code": "92",
          "operation_type": "auth_only",
          "card": {
            "id": "card_LR0A1vcVbsmY3wzY",
            "first_six_digits": "400030",
            "last_four_digits": "2220",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-01T18:46:06Z",
            "updated_at": "2018-02-01T18:46:06Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-01T18:46:06Z",
          "updated_at": "2018-02-01T18:46:06Z",
          "gateway_response": {
            "code": "201"
          }
        }
      }
    )
  end

  def successful_capture_response
    %(
      {
        "id": "ch_gm5wrlGMI2Fb0x6K",
        "code": "ch_gm5wrlGMI2Fb0x6K",
        "gateway_id": "3b6c0f72-c4b3-48b2-8eb7-2424321a6c93",
        "amount": 100,
        "paid_amount": 100,
        "status": "paid",
        "currency": "USD",
        "payment_method": "credit_card",
        "paid_at": "2018-02-01T16:43:33Z",
        "created_at": "2018-02-01T16:43:30Z",
        "updated_at": "2018-02-01T16:43:33Z",
        "customer": {
          "id": "cus_bVWYqeTmpu9VYLd9",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-01T16:43:30Z",
          "updated_at": "2018-02-01T16:43:30Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_wL9APd6cws19WNJ7",
          "transaction_type": "credit_card",
          "gateway_id": "6dae95a7-6b7f-4431-be33-cb3ecf21287a",
          "amount": 100,
          "status": "captured",
          "success": true,
          "installments": 1,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_tid": "299257",
          "acquirer_nsu": "894685",
          "acquirer_auth_code": "523448",
          "acquirer_message": "Simulator|Transação de simulação capturada com sucesso",
          "acquirer_return_code": "0",
          "operation_type": "capture",
          "card": {
            "id": "card_J26O3K2hvPc2vOQG",
            "first_six_digits": "400010",
            "last_four_digits": "2224",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-01T16:43:30Z",
            "updated_at": "2018-02-01T16:43:30Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-01T16:43:33Z",
          "updated_at": "2018-02-01T16:43:33Z",
          "gateway_response": {
            "code": "200"
          }
        }
      }
    )
  end

  def failed_capture_response
    '{"message": "Charge not found."}'
  end

  def successful_refund_response
    %(
      {
        "id": "ch_RbPVPWMH2bcGA50z",
        "code": "O5L5A4VCRK",
        "gateway_id": "d77c6a32-e1c8-42d4-bd1b-e92b36f054f9",
        "amount": 100,
        "canceled_amount": 100,
        "status": "canceled",
        "currency": "USD",
        "payment_method": "credit_card",
        "canceled_at": "2018-02-01T16:34:07Z",
        "created_at": "2018-02-01T16:34:07Z",
        "updated_at": "2018-02-01T16:34:07Z",
        "customer": {
          "id": "cus_odYDGxQirlcp693a",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-01T16:34:07Z",
          "updated_at": "2018-02-01T16:34:07Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_m1prZBNTgUmZrGzZ",
          "transaction_type": "credit_card",
          "gateway_id": "23648dca-07dc-4f31-9b24-26aa702dc7e8",
          "amount": 100,
          "status": "voided",
          "success": true,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_tid": "489627",
          "acquirer_nsu": "174061",
          "acquirer_auth_code": "433589",
          "acquirer_return_code": "0",
          "operation_type": "cancel",
          "card": {
            "id": "card_8PaGBMOhXwi9Q24z",
            "first_six_digits": "400010",
            "last_four_digits": "2224",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-01T16:34:07Z",
            "updated_at": "2018-02-01T16:34:07Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-01T16:34:07Z",
          "updated_at": "2018-02-01T16:34:07Z",
          "gateway_response": {
            "code": "200"
          }
        }
      }
    )
  end

  def failed_refund_response
    '{"message": "Charge not found."}'
  end

  def successful_void_response
    %(
      {
        "id": "ch_RbPVPWMH2bcGA50z",
        "code": "O5L5A4VCRK",
        "gateway_id": "d77c6a32-e1c8-42d4-bd1b-e92b36f054f9",
        "amount": 100,
        "canceled_amount": 100,
        "status": "canceled",
        "currency": "USD",
        "payment_method": "credit_card",
        "canceled_at": "2018-02-01T16:34:07Z",
        "created_at": "2018-02-01T16:34:07Z",
        "updated_at": "2018-02-01T16:34:07Z",
        "customer": {
          "id": "cus_odYDGxQirlcp693a",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-01T16:34:07Z",
          "updated_at": "2018-02-01T16:34:07Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_m1prZBNTgUmZrGzZ",
          "transaction_type": "credit_card",
          "gateway_id": "23648dca-07dc-4f31-9b24-26aa702dc7e8",
          "amount": 100,
          "status": "voided",
          "success": true,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_tid": "489627",
          "acquirer_nsu": "174061",
          "acquirer_auth_code": "433589",
          "acquirer_return_code": "0",
          "operation_type": "cancel",
          "card": {
            "id": "card_8PaGBMOhXwi9Q24z",
            "first_six_digits": "400010",
            "last_four_digits": "2224",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-01T16:34:07Z",
            "updated_at": "2018-02-01T16:34:07Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-01T16:34:07Z",
          "updated_at": "2018-02-01T16:34:07Z",
          "gateway_response": {
            "code": "200"
          }
        }
      }
    )
  end

  def failed_void_response
    '{"message": "Charge not found."}'
  end
  
  def successful_verify_response
    %(
      {
        "id": "ch_G9rB74PI3uoDMxAo",
        "code": "8EXXFEBQDK",
        "gateway_id": "4b228be6-6795-416a-9238-204020e7fdd1",
        "amount": 100,
        "canceled_amount": 100,
        "status": "canceled",
        "currency": "USD",
        "payment_method": "credit_card",
        "canceled_at": "2018-02-02T14:25:25Z",
        "created_at": "2018-02-02T14:25:24Z",
        "updated_at": "2018-02-02T14:25:25Z",
        "customer": {
          "id": "cus_V2GXxeOunSYpEvOD",
          "name": "Longbob Longsen",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-02T14:25:24Z",
          "updated_at": "2018-02-02T14:25:24Z",
          "phones": {}
        },
        "last_transaction": {
          "id": "tran_r50yVePSJbuA3dKb",
          "transaction_type": "credit_card",
          "gateway_id": "2d1c155a-e89d-4972-9ee1-a3b3f56d6ff8",
          "amount": 100,
          "status": "voided",
          "success": true,
          "acquirer_name": "simulator",
          "acquirer_affiliation_code": "",
          "acquirer_tid": "711106",
          "acquirer_nsu": "553868",
          "acquirer_auth_code": "271719",
          "acquirer_return_code": "0",
          "operation_type": "cancel",
          "card": {
            "id": "card_7WraOEps6FpRLQob",
            "first_six_digits": "400010",
            "last_four_digits": "2224",
            "brand": "Visa",
            "holder_name": "Longbob Longsen",
            "exp_month": 9,
            "exp_year": 2019,
            "status": "active",
            "created_at": "2018-02-02T14:25:24Z",
            "updated_at": "2018-02-02T14:25:24Z",
            "billing_address": {
              "street": "My Street",
              "number": "456",
              "zip_code": "K1C2N6",
              "neighborhood": "Sesame Street",
              "city": "Ottawa",
              "state": "ON",
              "country": "CA",
              "line_1": "456, My Street, Sesame Street"
            },
            "type": "credit"
          },
          "created_at": "2018-02-02T14:25:25Z",
          "updated_at": "2018-02-02T14:25:25Z",
          "gateway_response": {
            "code": "200"
          }
        }
      }
    )
  end

  def successful_create_customer_response
    %(
      {
        "id": "cus_NRL1bw3HpAHLbWPQ",
        "name": "Sideshow Bob",
        "email": "",
        "delinquent": false,
        "created_at": "2018-02-05T15:03:39Z",
        "updated_at": "2018-02-05T15:03:39Z",
        "phones": {}
      }
    )
  end

  def successful_store_response
    %(
      {
        "id": "card_51ElNwYSVJFpRe0g",
        "first_six_digits": "400010",
        "last_four_digits": "2224",
        "brand": "Visa",
        "holder_name": "Longbob Longsen",
        "exp_month": 9,
        "exp_year": 2019,
        "status": "active",
        "created_at": "2018-02-05T15:45:01Z",
        "updated_at": "2018-02-05T15:45:01Z",
        "billing_address": {
          "street": "My Street",
          "number": "456",
          "zip_code": "K1C2N6",
          "neighborhood": "Sesame Street",
          "city": "Ottawa",
          "state": "ON",
          "country": "CA",
          "line_1": "456, My Street, Sesame Street"
        },
        "customer": {
          "id": "cus_N70xAX6S65cMnokB",
          "name": "Bob Belcher",
          "email": "",
          "delinquent": false,
          "created_at": "2018-02-05T15:45:01Z",
          "updated_at": "2018-02-05T15:45:01Z",
          "phones": {}
        },
        "type": "credit"
      }
    )
  end
end
