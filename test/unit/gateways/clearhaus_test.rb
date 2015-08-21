require 'test_helper'

class ClearhausTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = ClearhausGateway.new(api_key: 'test_key', mpi_api_key: 'test_mpi_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
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
      response = @gateway.authorize(@amount, @credit_card, @options.merge(order_id: '123', description: 'test'))
      assert_success response
      assert response.test?    
    end.check_request do |endpoint, data, headers|
      order_expr = { reference: '123'}.to_query
      tos_expr   = { text_on_statement: 'test'}.to_query

      assert_match order_expr, data
      assert_match tos_expr, data
    end.respond_with(successful_authorize_response)
  end

  def test_successful_threed_auth
    options = { order_id: '123', merchant: { id: '321', name: 'Best Merchant Inc', acquirer_bin: '411111', country: 'DK', url: 'http://myshop.com' }}

    stub_comms do
      assert_success response = @gateway.threed_auth(@amount, @credit_card, options)

      assert_instance_of ClearhausGateway::ThreedResponse, response
      assert response.enrolled?
      assert_equal 'enrolled', response.message
      assert response.params.all?{|k, _| ['term_url', 'pareq_value', 'account_id', 'enrolled', 'eci', 'error'].include?(k) }
    end.check_request do |endpoint, data, headers|
      assert_match %r{/enrolled}, endpoint
      assert_match options.slice(:merchant).to_query, data
    end.respond_with(successful_threed_auth_response)
  end

  def test_failed_threed_auth
    @gateway.expects(:ssl_post).returns(failed_threed_auth_response)
    options = { order_id: '123', merchant: { id: '321', name: 'Best Merchant Inc', acquirer_bin: '411111', country: 'DK', url: 'http://myshop.com' }}

    assert_failure response = @gateway.threed_auth(@amount, @credit_card, options)
    assert !response.enrolled?
    assert_equal 'Merchant not participating', response.message
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
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'd8e92a70-3030-4d4d-8ad2-684b230c1bed', response.authorization
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

    assert_equal '77d08c40-cfa9-42e3-993d-795f772b70a4', response.authorization
    assert response.test? 
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(
      successful_authorize_response
    ).then.returns(
      failed_void_response
    )

    response = @gateway.verify(@credit_card, @options)

    assert_equal 40000, response.error_code
    assert_equal ClearhausGateway::ACTION_CODE_MESSAGES[40000], response.message    
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
    gateway = ClearhausGateway.new(api_key: 'test_key', signing_key: test_private_signing_key)
    card = credit_card('4111111111111111', month: '06', year: '2018', verification_value: '123')
    options = { currency: 'EUR', ip: '1.1.1.1' }

    stub_comms gateway, :ssl_request do
      response = gateway.authorize(2050, card, options)
      assert_success response

      assert_equal '84412a34-fa29-4369-a098-0165a80e8fda', response.authorization
      assert response.test?
    end.check_request do |method, endpoint, data, headers|
      assert headers["Signature"]
      assert_match %r{test_key RS256-hex}, headers["Signature"]
      assert_match /02f56ed1f6c60cdefd$/, headers["Signature"]
    end.respond_with(successful_authorize_response)
  end


  private

  def test_private_signing_key
%Q{-----BEGIN RSA PRIVATE KEY-----
MIIBOwIBAAJBALYK0zmwuYkH3YWcFNLLddx5cwDxEY7Gi1xITuQqRrU4yD3uSw+J
WYKknb4Tbndb6iEHY+e6gIGD+49TojnNeIUCAwEAAQJARyuYRRe4kcBHdPL+mSL+
Y0IAGkAlUyKAXYXPghidKD/v/oLrFaZWALGM2clv6UoYYpPnInSgbcud4sTcfeUm
QQIhAN2JZ2qv0WGcbIopBpwpQ5jDxMGVkmkVVUEWWABGF8+pAiEA0lySxTELZm8b
Gx9UEDRghN+Qv/OuIKFldu1Ba4f8W30CIQCaQFIBtunTTVdF28r+cLzgYW9eWwbW
pEP4TdZ4WlW6AQIhAMDCTUdeUpjxlH/87BXROORozAXocBW8bvJUI486U5ctAiAd
InviQqJd1KTGRDmWIGrE5YACVmW2JSszD9t5VKxkAA==
-----END RSA PRIVATE KEY-----
}

  end

  def failed_purchase_response
    failed_ch_response
  end

  def successful_threed_auth_response
    {
      "term_url"    => "https://secure5.arcot.com/acspage/cap?RID=35325&VAA=B",
      "pareq_value" => "test_pareq",
      "account_id"  => "oDbfkZQ1S6OJ4hYCsOPXBAEFBAg=",
      "enrolled"    => "Y",
      "eci"         => "2",
      "error"       => nil
    }.to_json
  end

  def failed_threed_auth_response
    {
      "enrolled" => "N",
      "eci"      => "1",
      "error"    => "Merchant not participating"
    }.to_json    
  end

  def successful_authorize_response
    {
      "id" => "84412a34-fa29-4369-a098-0165a80e8fda",
      "status" => {
          "code" => 20000
      },
      "processed_at" => "2014-07-09T09:53:41+00:00",
      "_links" => {
          "captures" => { "href": "/authorizations/84412a34-fa29-4369-a098-0165a80e8fda/captures" }
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
          "authorization" => { "href": "/authorizations/84412a34-fa29-4369-a098-0165a80e8fda" }
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
        "voids":{"href":"/authorizations/77d08c40-cfa9-42e3-993d-795f772b70a4/voids"},
        "refunds":{"href":"/authorizations/77d08c40-cfa9-42e3-993d-795f772b70a4/refunds"}
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
