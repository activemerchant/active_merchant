require 'test_helper'

class ClearhausTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ClearhausGateway.new(api_key: 'test_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @test_signing_key = "7e51b92e-ca7e-48e3-8a96-7d66cf1f2da2"
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(
      successful_authorize_response
    ).then.returns(
      successful_capture_response
    )

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 40000, response.error_code
    assert_equal ClearhausGateway::ACTION_CODE_MESSAGES[40000], response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).times(1).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization
    assert response.test?
  end

  def test_successful_authorize_with_threed
    stub_comms do
      response = @gateway.authorize(@amount, @credit_card, @options.merge(pares: '123'))
      assert_success response
      assert response.test?
    end.check_request do |endpoint, data, headers|
      expr = { threed_secure: { pares: '123' } }.to_query
      assert_match expr, data
    end.respond_with(successful_authorize_response)
  end

  def test_additional_params
    stub_comms do
      response = @gateway.authorize(@amount, @credit_card, @options.merge(order_id: '123', text_on_statement: 'test'))
      assert_success response
      assert response.test?
    end.check_request do |endpoint, data, headers|
      order_expr = { reference: '123'}.to_query
      tos_expr   = { text_on_statement: 'test'}.to_query

      assert_match order_expr, data
      assert_match tos_expr, data
    end.respond_with(successful_authorize_response)
  end

  def test_successful_authorize_with_card
    stub_comms do
      response = @gateway.authorize(@amount, "4110", @options)
      assert_success response

      assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization
      assert response.test?
    end.check_request do |endpoint, data, headers|
      assert_match %r{/cards/4110/authorizations}, endpoint
    end.respond_with(successful_authorize_response)
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 40000, response.error_code
    assert_equal ClearhausGateway::ACTION_CODE_MESSAGES[40000], response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    auth_response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth_response

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, auth_response.authorization, @options)
    assert_success response

    assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization, "It's acutally the id of the original auth"
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 40000, response.error_code
    assert_equal ClearhausGateway::ACTION_CODE_MESSAGES[40000], response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'f04c0872-47ce-4683-8d8c-e154221bba14', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 40000, response.error_code
    assert_equal ClearhausGateway::ACTION_CODE_MESSAGES[40000], response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@credit_card, @options)
    assert_success response

    assert_equal '77d08c40-cfa9-42e3-993d-795f772b70a4', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void( @credit_card, @options)
    assert_failure response

    assert_equal 40000, response.error_code
    assert_equal ClearhausGateway::ACTION_CODE_MESSAGES[40000], response.message
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(
      successful_authorize_response
    ).then.returns(
      successful_void_response
    )

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(
      successful_authorize_response
    ).then.returns(
      failed_void_response
    )

    response = @gateway.verify(@credit_card, @options)
    assert_success(response)
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).times(1).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)

    assert_equal 40000, response.error_code
    assert_equal ClearhausGateway::ACTION_CODE_MESSAGES[40000], response.message
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response

    assert_equal '58dabba0-e9ea-4133-8c38-bfa1028c1ed2', response.authorization
    assert response.test?
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_failure response
  end

  def test_signing_request
    gateway = ClearhausGateway.new(api_key: 'test_key', signing_key: @test_signing_key, private_key: test_private_key)
    card = credit_card('4111111111111111', month: '06', year: '2018', verification_value: '123')
    options = { currency: 'EUR', ip: '1.1.1.1' }

    stub_comms gateway, :ssl_request do
      response = gateway.authorize(2050, card, options)
      assert_success response

      assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization
      assert response.test?
    end.check_request do |method, endpoint, data, headers|
      assert headers["Signature"]
      assert_match %r{7e51b92e-ca7e-48e3-8a96-7d66cf1f2da2 RS256-hex}, headers["Signature"]
      assert_match %r{02f56ed1f6c60cdefd$}, headers["Signature"]
    end.respond_with(successful_authorize_response)
  end

  def test_cleans_whitespace_from_private_key
    private_key_with_whitespace = "     #{test_private_key}     "
    gateway = ClearhausGateway.new(api_key: 'test_key', signing_key: @test_signing_key, private_key: private_key_with_whitespace)
    card = credit_card('4111111111111111', month: '06', year: '2018', verification_value: '123')
    options = { currency: 'EUR', ip: '1.1.1.1' }

    stub_comms gateway, :ssl_request do
      response = gateway.authorize(2050, card, options)
      assert_success response

      assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization
      assert response.test?
    end.check_request do |method, endpoint, data, headers|
      assert headers["Signature"]
      assert_match %r{7e51b92e-ca7e-48e3-8a96-7d66cf1f2da2 RS256-hex}, headers["Signature"]
      assert_match %r{02f56ed1f6c60cdefd$}, headers["Signature"]
    end.respond_with(successful_authorize_response)
  end

  def test_unsuccessful_signing_request_with_invalid_key
    gateway = ClearhausGateway.new(api_key: "test_key",  signing_key: @test_signing_key, private_key: "foo")

    # stub actual network access, but this shouldn't be reached
    gateway.stubs(:ssl_post).returns(nil)

    card = credit_card("4111111111111111", month: "06", year: "2018", verification_value: "123")
    options = { currency: "EUR", ip: "1.1.1.1" }

    response = gateway.authorize(2050, card, options)
    assert_failure response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
opening connection to gateway.test.clearhaus.com:443...
opened
starting SSL for gateway.test.clearhaus.com:443...
SSL established
<- "POST /authorizations HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic NTI2Y2Y1NjQtMTE5Yy00YmI2LTljZjgtMDAxNWVhYzdlNGY2Og==\r\nUser-Agent: Clearhaus ActiveMerchantBindings/1.54.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.test.clearhaus.com\r\nContent-Length: 128\r\n\r\n"
<- "amount=100&card%5Bcsc%5D=123&card%5Bexpire_month%5D=09&card%5Bexpire_year%5D=2016&card%5Bnumber%5D=4111111111111111&currency=EUR"
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/vnd.clearhaus-gateway.hal+json; version=0.9.0; charset=utf-8\r\n"
-> "Date: Wed, 28 Oct 2015 18:56:11 GMT\r\n"
-> "Server: nginx/1.6.2\r\n"
-> "Status: 201 Created\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Content-Length: 901\r\n"
-> "Connection: Close\r\n"
-> "\r\n"
reading 901 bytes...
-> "{\"id\":\"efb04d12-4bb6-41c0-b030-45ff105641b0\",\"status\":{\"code\":20000},\"processed_at\":\"2015-10-28T18:56:10+00:00\",\"amount\":100,\"currency\":\"EUR\",\"recurring\":false,\"threed_secure\":false,\"_embedded\":{\"card\":{\"id\":\"27127636-0748-4df5-97fe-e58a0c29b618\",\"scheme\":\"visa\",\"last4\":\"1111\",\"_links\":{\"self\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618\"},\"authorizations\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618/authorizations\"},\"credits\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618/credits\"}}}},\"_links\":{\"self\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0\"},\"card\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618\"},\"captures\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/captures\"},\"voids\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/voids\"},\"refunds\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/refunds\"}}}"
read 901 bytes
Conn close
opening connection to gateway.test.clearhaus.com:443...
opened
starting SSL for gateway.test.clearhaus.com:443...
SSL established
<- "POST /authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/captures HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic NTI2Y2Y1NjQtMTE5Yy00YmI2LTljZjgtMDAxNWVhYzdlNGY2Og==\r\nUser-Agent: Clearhaus ActiveMerchantBindings/1.54.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.test.clearhaus.com\r\nContent-Length: 23\r\n\r\n"
<- "amount=100&currency=EUR"
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/vnd.clearhaus-gateway.hal+json; version=0.9.0; charset=utf-8\r\n"
-> "Date: Wed, 28 Oct 2015 18:56:12 GMT\r\n"
-> "Server: nginx/1.6.2\r\n"
-> "Status: 201 Created\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Content-Length: 363\r\n"
-> "Connection: Close\r\n"
-> "\r\n"
reading 363 bytes...
-> "{\"id\":\"802988cf-fb01-4430-963a-735ddc6b87f4\",\"status\":{\"code\":20000},\"processed_at\":\"2015-10-28T18:56:12+00:00\",\"amount\":100,\"_links\":{\"self\":{\"href\":\"/captures/802988cf-fb01-4430-963a-735ddc6b87f4\"},\"authorization\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0\"},\"refunds\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/refunds\"}}}"
read 363 bytes
Conn close
    )
  end

  def post_scrubbed
    %q(
opening connection to gateway.test.clearhaus.com:443...
opened
starting SSL for gateway.test.clearhaus.com:443...
SSL established
<- "POST /authorizations HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Clearhaus ActiveMerchantBindings/1.54.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.test.clearhaus.com\r\nContent-Length: 128\r\n\r\n"
<- "amount=100&card%5Bcsc%5D=[FILTERED]&card%5Bexpire_month%5D=09&card%5Bexpire_year%5D=2016&card%5Bnumber%5D=[FILTERED]&currency=EUR"
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/vnd.clearhaus-gateway.hal+json; version=0.9.0; charset=utf-8\r\n"
-> "Date: Wed, 28 Oct 2015 18:56:11 GMT\r\n"
-> "Server: nginx/1.6.2\r\n"
-> "Status: 201 Created\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Content-Length: 901\r\n"
-> "Connection: Close\r\n"
-> "\r\n"
reading 901 bytes...
-> "{\"id\":\"efb04d12-4bb6-41c0-b030-45ff105641b0\",\"status\":{\"code\":20000},\"processed_at\":\"2015-10-28T18:56:10+00:00\",\"amount\":100,\"currency\":\"EUR\",\"recurring\":false,\"threed_secure\":false,\"_embedded\":{\"card\":{\"id\":\"27127636-0748-4df5-97fe-e58a0c29b618\",\"scheme\":\"visa\",\"last4\":\"1111\",\"_links\":{\"self\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618\"},\"authorizations\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618/authorizations\"},\"credits\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618/credits\"}}}},\"_links\":{\"self\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0\"},\"card\":{\"href\":\"/cards/27127636-0748-4df5-97fe-e58a0c29b618\"},\"captures\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/captures\"},\"voids\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/voids\"},\"refunds\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/refunds\"}}}"
read 901 bytes
Conn close
opening connection to gateway.test.clearhaus.com:443...
opened
starting SSL for gateway.test.clearhaus.com:443...
SSL established
<- "POST /authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/captures HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Clearhaus ActiveMerchantBindings/1.54.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.test.clearhaus.com\r\nContent-Length: 23\r\n\r\n"
<- "amount=100&currency=EUR"
-> "HTTP/1.1 201 Created\r\n"
-> "Content-Type: application/vnd.clearhaus-gateway.hal+json; version=0.9.0; charset=utf-8\r\n"
-> "Date: Wed, 28 Oct 2015 18:56:12 GMT\r\n"
-> "Server: nginx/1.6.2\r\n"
-> "Status: 201 Created\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Content-Length: 363\r\n"
-> "Connection: Close\r\n"
-> "\r\n"
reading 363 bytes...
-> "{\"id\":\"802988cf-fb01-4430-963a-735ddc6b87f4\",\"status\":{\"code\":20000},\"processed_at\":\"2015-10-28T18:56:12+00:00\",\"amount\":100,\"_links\":{\"self\":{\"href\":\"/captures/802988cf-fb01-4430-963a-735ddc6b87f4\"},\"authorization\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0\"},\"refunds\":{\"href\":\"/authorizations/efb04d12-4bb6-41c0-b030-45ff105641b0/refunds\"}}}"
read 363 bytes
Conn close
    )
  end

  def test_private_key
    %Q{-----BEGIN RSA PRIVATE KEY-----\nMIIBOwIBAAJBALYK0zmwuYkH3YWcFNLLddx5cwDxEY7Gi1xITuQqRrU4yD3uSw+J\nWYKknb4Tbndb6iEHY+e6gIGD+49TojnNeIUCAwEAAQJARyuYRRe4kcBHdPL+mSL+\nY0IAGkAlUyKAXYXPghidKD/v/oLrFaZWALGM2clv6UoYYpPnInSgbcud4sTcfeUm\nQQIhAN2JZ2qv0WGcbIopBpwpQ5jDxMGVkmkVVUEWWABGF8+pAiEA0lySxTELZm8b\nGx9UEDRghN+Qv/OuIKFldu1Ba4f8W30CIQCaQFIBtunTTVdF28r+cLzgYW9eWwbW\npEP4TdZ4WlW6AQIhAMDCTUdeUpjxlH/87BXROORozAXocBW8bvJUI486U5ctAiAd\nInviQqJd1KTGRDmWIGrE5YACVmW2JSszD9t5VKxkAA==\n-----END RSA PRIVATE KEY-----}
  end

  def failed_purchase_response
    failed_ch_response
  end

  def successful_authorize_response
    {
      "id"     => "84412a34-fa29-4369-a098-0165a80e8fda",
      "status" => {
          "code" => 20000
      },
      "processed_at" => "2014-07-09T09:53:41+00:00",
      "_links" => {
          "captures" => { "href" => "/authorizations/84412a34-fa29-4369-a098-0165a80e8fda/captures" }
      }
    }.to_json
  end

  def failed_authorize_response
    failed_ch_response
  end

  def successful_capture_response
    {
        "id" => "d8e92a70-3030-4d4d-8ad2-684b230c1bed",
        "status" => {
            "code" => 20000
        },
        "processed_at" => "2014-07-09T11:47:28+00:00",
        "amount" => 1000,
        "_links" => {
            "authorization" => {
                "href" => "/authorizations/84412a34-fa29-4369-a098-0165a80e8fda"
            },
            "refunds" => {
                "href" => "/authorizations/84412a34-fa29-4369-a098-0165a80e8fda/refunds"
            }
        }
    }.to_json
  end

  def failed_capture_response
    failed_ch_response
  end

  def successful_refund_response
    {
      "id" => "f04c0872-47ce-4683-8d8c-e154221bba14",
      "status" => {
          "code" => 20000
      },
      "processed_at" => "2014-07-09T11:57:58+00:00",
      "amount" => 500,
      "_links" => {
          "authorization" => { "href" => "/authorizations/84412a34-fa29-4369-a098-0165a80e8fda" }
      }
    }.to_json
  end

  def failed_refund_response
    failed_ch_response
  end

  def successful_void_response
    {
      "id" => "77d08c40-cfa9-42e3-993d-795f772b70a4",
      "status" => {
        "code" => 20000
      },
      "processed_at" => "2015-08-21T16:44:48+00:00",
      "_links" => {
        "self" => {
          "href" => "/authorizations/77d08c40-cfa9-42e3-993d-795f772b70a4"
        },
        "card" => {
          "href" => "/cards/27127636-0748-4df5-97fe-e58a0c29b618"
        },
        "captures" => {
          "href" => "/authorizations/77d08c40-cfa9-42e3-993d-795f772b70a4/captures"
        },
        "voids" => { "href" => "/authorizations/77d08c40-cfa9-42e3-993d-795f772b70a4/voids"},
        "refunds" => { "href" => "/authorizations/77d08c40-cfa9-42e3-993d-795f772b70a4/refunds"}
      }
    }
  end

  def failed_void_response
    failed_ch_response
  end

  def successful_store_response
    {
      "id" => "58dabba0-e9ea-4133-8c38-bfa1028c1ed2",
      "status" => {
          "code"=> 20000
      },
      "processed_at" => "2014-07-09T12:14:31+00:00",
      "last4" => "0004",
      "scheme" => "mastercard",
      "_links" => {
          "authorizations" => { "href" => "/cards/58dabba0-e9ea-4133-8c38-bfa1028c1ed2/authorizations" },
          "credits"=> { "href" => "/cards/58dabba0-e9ea-4133-8c38-bfa1028c1ed2/credits" }
      }
    }.to_json
  end

  def failed_store_response
    failed_ch_response
  end

  def failed_ch_response
    { "status" => { "code" => 40000, "message" => "General input error" }}.to_json
  end

end
