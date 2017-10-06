require 'test_helper'

class WepayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = WepayGateway.new(
      client_id: 'client_id',
      account_id: 'account_id',
      access_token: 'access_token'
    )

    @credit_card = credit_card
    @amount = 20000

    @options = {
      email: "test@example.com"
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).at_most(3).returns(successful_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal "1181910285|20.00", response.authorization
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).at_most(2).returns(failed_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(successful_capture_response)

    response = @gateway.purchase(@amount, "1422891921", @options)
    assert_success response

    assert_equal "1181910285|20.00", response.authorization
  end

  def test_failed_purchase_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(failed_capture_response)

    response = @gateway.purchase(@amount, "1422891921", @options)
    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "refund_reason parameter is required", response.message
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).at_most(2).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Invalid credit card number", response.message
  end

  def test_successful_authorize_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, "1422891921", @options)
    assert_success response
  end

  def test_failed_authorize_with_token
    @gateway.expects(:ssl_post).at_most(2).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, "1422891921", @options)
    assert_failure response
    assert_equal "Invalid credit card number", response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).at_most(2).returns(successful_capture_response)

    response = @gateway.capture(@amount, "auth|amount", @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).at_most(3).returns(failed_capture_response)

    response = @gateway.capture(@amount, "auth|200.00", @options)
    assert_failure response
    assert_equal "Checkout object must be in state 'Reserved' to capture. Currently it is in state captured", response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void("auth|amount", @options)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void("auth|amount", @options)
    assert_failure response
    assert_equal "this checkout has already been cancelled", response.message
  end

  def test_successful_store_via_create
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal "3322208138", response.authorization
  end

  def test_successful_store_via_transfer
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options.merge(recurring: true))
    assert_success response
    assert_equal "3322208138", response.authorization
  end

  def test_failed_store
    @gateway.expects(:ssl_post).returns(failed_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal "Invalid credit card number", response.message
  end

  def test_invalid_json_response
    @gateway.expects(:ssl_post).returns(invalid_json_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/Invalid JSON response received from WePay/, response.message)
  end

  def test_no_version_by_default
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/Api-Version/, headers.to_s)
    end.respond_with(successful_authorize_response)
  end

  def test_version_override
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(version: '2017-05-31'))
    end.check_request do |endpoint, data, headers|
      assert_match(/"Api-Version\"=>\"2017-05-31\"/, headers.to_s)
    end.respond_with(successful_authorize_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to stage.wepayapi.com:443...
      opened
      starting SSL for stage.wepayapi.com:443...
      SSL established
      <- "POST /v2/credit_card/create HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.65.0\r\nAuthorization: Bearer STAGE_c91882b0bed3584b8aed0f7f515f2f05a1d40924ee6f394ce82d91018cb0f2d3\r\nApi-Version: 2017-02-01\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: stage.wepayapi.com\r\nContent-Length: 272\r\n\r\n"
      <- "{\"client_id\":\"44716\",\"user_name\":\"Longbob Longsen\",\"email\":\"test@example.com\",\"cc_number\":\"5496198584584769\",\"cvv\":\"123\",\"expiration_month\":9,\"expiration_year\":2018,\"address\":{\"address1\":\"456 My Street\",\"city\":\"Ottawa\",\"country\":\"CA\",\"region\":\"ON\",\"postal_code\":\"K1C2N6\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; preload\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Accept-Ranges: bytes\r\n"
      -> "Date: Wed, 26 Apr 2017 18:27:33 GMT\r\n"
      -> "Via: 1.1 varnish\r\n"
      -> "Connection: close\r\n"
      -> "X-Served-By: cache-fra1231-FRA\r\n"
      -> "X-Cache: MISS\r\n"
      -> "X-Cache-Hits: 0\r\n"
      -> "X-Timer: S1493231252.436069,VS0,VE1258\r\n"
      -> "Vary: Authorization\r\n"
      -> "\r\n"
      -> "2b\r\n"
      reading 43 bytes...
      -> "{\"credit_card_id\":2559797807,\"state\":\"new\"}"
      read 43 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to stage.wepayapi.com:443...
      opened
      starting SSL for stage.wepayapi.com:443...
      SSL established
      <- "POST /v2/checkout/create HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.65.0\r\nAuthorization: Bearer STAGE_c91882b0bed3584b8aed0f7f515f2f05a1d40924ee6f394ce82d91018cb0f2d3\r\nApi-Version: 2017-02-01\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: stage.wepayapi.com\r\nContent-Length: 202\r\n\r\n"
      <- "{\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":\"2559797807\",\"auto_capture\":false}},\"account_id\":\"2080478981\",\"amount\":\"20.00\",\"short_description\":\"Purchase\",\"type\":\"goods\",\"currency\":\"USD\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; preload\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Accept-Ranges: bytes\r\n"
      -> "Date: Wed, 26 Apr 2017 18:27:36 GMT\r\n"
      -> "Via: 1.1 varnish\r\n"
      -> "Connection: close\r\n"
      -> "X-Served-By: cache-fra1247-FRA\r\n"
      -> "X-Cache: MISS\r\n"
      -> "X-Cache-Hits: 0\r\n"
      -> "X-Timer: S1493231255.546126,VS0,VE1713\r\n"
      -> "Vary: Authorization\r\n"
      -> "\r\n"
      -> "324\r\n"
      reading 804 bytes...
      -> "{\"checkout_id\":1709862829,\"account_id\":2080478981,\"type\":\"goods\",\"short_description\":\"Purchase\",\"currency\":\"USD\",\"amount\":20,\"state\":\"authorized\",\"soft_descriptor\":\"WPY*Spreedly\",\"create_time\":1493231254,\"gross\":20.88,\"reference_id\":null,\"callback_uri\":null,\"long_description\":null,\"delivery_type\":null,\"fee\":{\"app_fee\":0,\"processing_fee\":0.88,\"fee_payer\":\"payer\"},\"chargeback\":{\"amount_charged_back\":0,\"dispute_uri\":null},\"refund\":{\"amount_refunded\":0,\"refund_reason\":null},\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":2559797807,\"data\":{\"emv_receipt\":null,\"signature_url\":null},\"auto_capture\":false}},\"hosted_checkout\":null,\"payer\":{\"email\":\"test@example.com\",\"name\":\"Longbob Longsen\",\"home_address\":null},\"npo_information\":null,\"payment_error\":null,\"in_review\":false,\"auto_release\":true}"
      read 804 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to stage.wepayapi.com:443...
      opened
      starting SSL for stage.wepayapi.com:443...
      SSL established
      <- "POST /v2/checkout/capture HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.65.0\r\nAuthorization: Bearer STAGE_c91882b0bed3584b8aed0f7f515f2f05a1d40924ee6f394ce82d91018cb0f2d3\r\nApi-Version: 2017-02-01\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: stage.wepayapi.com\r\nContent-Length: 28\r\n\r\n"
      <- "{\"checkout_id\":\"1709862829\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; preload\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Accept-Ranges: bytes\r\n"
      -> "Date: Wed, 26 Apr 2017 18:27:38 GMT\r\n"
      -> "Via: 1.1 varnish\r\n"
      -> "Connection: close\r\n"
      -> "X-Served-By: cache-fra1239-FRA\r\n"
      -> "X-Cache: MISS\r\n"
      -> "X-Cache-Hits: 0\r\n"
      -> "X-Timer: S1493231257.113609,VS0,VE1136\r\n"
      -> "Vary: Authorization\r\n"
      -> "\r\n"
      -> "324\r\n"
      reading 804 bytes...
      -> "{\"checkout_id\":1709862829,\"account_id\":2080478981,\"type\":\"goods\",\"short_description\":\"Purchase\",\"currency\":\"USD\",\"amount\":20,\"state\":\"authorized\",\"soft_descriptor\":\"WPY*Spreedly\",\"create_time\":1493231254,\"gross\":20.88,\"reference_id\":null,\"callback_uri\":null,\"long_description\":null,\"delivery_type\":null,\"fee\":{\"app_fee\":0,\"processing_fee\":0.88,\"fee_payer\":\"payer\"},\"chargeback\":{\"amount_charged_back\":0,\"dispute_uri\":null},\"refund\":{\"amount_refunded\":0,\"refund_reason\":null},\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":2559797807,\"data\":{\"emv_receipt\":null,\"signature_url\":null},\"auto_capture\":false}},\"hosted_checkout\":null,\"payer\":{\"email\":\"test@example.com\",\"name\":\"Longbob Longsen\",\"home_address\":null},\"npo_information\":null,\"payment_error\":null,\"in_review\":false,\"auto_release\":true}"
      read 804 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to stage.wepayapi.com:443...
      opened
      starting SSL for stage.wepayapi.com:443...
      SSL established
      <- "POST /v2/credit_card/create HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.65.0\r\nAuthorization: Bearer [FILTERED]\r\nApi-Version: 2017-02-01\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: stage.wepayapi.com\r\nContent-Length: 272\r\n\r\n"
      <- "{\"client_id\":\"44716\",\"user_name\":\"Longbob Longsen\",\"email\":\"test@example.com\",\"cc_number\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"expiration_month\":9,\"expiration_year\":2018,\"address\":{\"address1\":\"456 My Street\",\"city\":\"Ottawa\",\"country\":\"CA\",\"region\":\"ON\",\"postal_code\":\"K1C2N6\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; preload\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Accept-Ranges: bytes\r\n"
      -> "Date: Wed, 26 Apr 2017 18:27:33 GMT\r\n"
      -> "Via: 1.1 varnish\r\n"
      -> "Connection: close\r\n"
      -> "X-Served-By: cache-fra1231-FRA\r\n"
      -> "X-Cache: MISS\r\n"
      -> "X-Cache-Hits: 0\r\n"
      -> "X-Timer: S1493231252.436069,VS0,VE1258\r\n"
      -> "Vary: Authorization\r\n"
      -> "\r\n"
      -> "2b\r\n"
      reading 43 bytes...
      -> "{\"credit_card_id\":2559797807,\"state\":\"new\"}"
      read 43 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to stage.wepayapi.com:443...
      opened
      starting SSL for stage.wepayapi.com:443...
      SSL established
      <- "POST /v2/checkout/create HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.65.0\r\nAuthorization: Bearer [FILTERED]\r\nApi-Version: 2017-02-01\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: stage.wepayapi.com\r\nContent-Length: 202\r\n\r\n"
      <- "{\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":\"2559797807\",\"auto_capture\":false}},\"account_id\":\"2080478981\",\"amount\":\"20.00\",\"short_description\":\"Purchase\",\"type\":\"goods\",\"currency\":\"USD\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; preload\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Accept-Ranges: bytes\r\n"
      -> "Date: Wed, 26 Apr 2017 18:27:36 GMT\r\n"
      -> "Via: 1.1 varnish\r\n"
      -> "Connection: close\r\n"
      -> "X-Served-By: cache-fra1247-FRA\r\n"
      -> "X-Cache: MISS\r\n"
      -> "X-Cache-Hits: 0\r\n"
      -> "X-Timer: S1493231255.546126,VS0,VE1713\r\n"
      -> "Vary: Authorization\r\n"
      -> "\r\n"
      -> "324\r\n"
      reading 804 bytes...
      -> "{\"checkout_id\":1709862829,\"account_id\":2080478981,\"type\":\"goods\",\"short_description\":\"Purchase\",\"currency\":\"USD\",\"amount\":20,\"state\":\"authorized\",\"soft_descriptor\":\"WPY*Spreedly\",\"create_time\":1493231254,\"gross\":20.88,\"reference_id\":null,\"callback_uri\":null,\"long_description\":null,\"delivery_type\":null,\"fee\":{\"app_fee\":0,\"processing_fee\":0.88,\"fee_payer\":\"payer\"},\"chargeback\":{\"amount_charged_back\":0,\"dispute_uri\":null},\"refund\":{\"amount_refunded\":0,\"refund_reason\":null},\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":2559797807,\"data\":{\"emv_receipt\":null,\"signature_url\":null},\"auto_capture\":false}},\"hosted_checkout\":null,\"payer\":{\"email\":\"test@example.com\",\"name\":\"Longbob Longsen\",\"home_address\":null},\"npo_information\":null,\"payment_error\":null,\"in_review\":false,\"auto_release\":true}"
      read 804 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
      opening connection to stage.wepayapi.com:443...
      opened
      starting SSL for stage.wepayapi.com:443...
      SSL established
      <- "POST /v2/checkout/capture HTTP/1.1\r\nContent-Type: application/json\r\nUser-Agent: ActiveMerchantBindings/1.65.0\r\nAuthorization: Bearer [FILTERED]\r\nApi-Version: 2017-02-01\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: stage.wepayapi.com\r\nContent-Length: 28\r\n\r\n"
      <- "{\"checkout_id\":\"1709862829\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: nginx\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "Strict-Transport-Security: max-age=31536000; preload\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Accept-Ranges: bytes\r\n"
      -> "Date: Wed, 26 Apr 2017 18:27:38 GMT\r\n"
      -> "Via: 1.1 varnish\r\n"
      -> "Connection: close\r\n"
      -> "X-Served-By: cache-fra1239-FRA\r\n"
      -> "X-Cache: MISS\r\n"
      -> "X-Cache-Hits: 0\r\n"
      -> "X-Timer: S1493231257.113609,VS0,VE1136\r\n"
      -> "Vary: Authorization\r\n"
      -> "\r\n"
      -> "324\r\n"
      reading 804 bytes...
      -> "{\"checkout_id\":1709862829,\"account_id\":2080478981,\"type\":\"goods\",\"short_description\":\"Purchase\",\"currency\":\"USD\",\"amount\":20,\"state\":\"authorized\",\"soft_descriptor\":\"WPY*Spreedly\",\"create_time\":1493231254,\"gross\":20.88,\"reference_id\":null,\"callback_uri\":null,\"long_description\":null,\"delivery_type\":null,\"fee\":{\"app_fee\":0,\"processing_fee\":0.88,\"fee_payer\":\"payer\"},\"chargeback\":{\"amount_charged_back\":0,\"dispute_uri\":null},\"refund\":{\"amount_refunded\":0,\"refund_reason\":null},\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":2559797807,\"data\":{\"emv_receipt\":null,\"signature_url\":null},\"auto_capture\":false}},\"hosted_checkout\":null,\"payer\":{\"email\":\"test@example.com\",\"name\":\"Longbob Longsen\",\"home_address\":null},\"npo_information\":null,\"payment_error\":null,\"in_review\":false,\"auto_release\":true}"
      read 804 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    )
  end

  def successful_store_response
    %({"credit_card_id": 3322208138,"state": "new"})
  end

  def failed_store_response
    %({"error": "invalid_request","error_description": "Invalid credit card number","error_code": 1003})
  end

  def successful_refund_response
    %({"checkout_id":1852898602,"state":"refunded"})
  end

  def failed_refund_response
    %({"error":"invalid_request","error_description":"refund_reason parameter is required","error_code":1004})
  end

  def successful_void_response
    %({"checkout_id":225040456,"state":"cancelled"})
  end

  def failed_void_response
    %({"error":"invalid_request","error_description":"this checkout has already been cancelled","error_code":4004})
  end

  def successful_authorize_response
    %({\"checkout_id\":1181910285,\"account_id\":2080478981,\"type\":\"goods\",\"short_description\":\"Purchase\",\"currency\":\"USD\",\"amount\":20,\"state\":\"authorized\",\"soft_descriptor\":\"WPY*Spreedly\",\"create_time\":1481836590,\"gross\":20.88,\"reference_id\":null,\"callback_uri\":null,\"long_description\":null,\"delivery_type\":null,\"fee\":{\"app_fee\":0,\"processing_fee\":0.88,\"fee_payer\":\"payer\"},\"chargeback\":{\"amount_charged_back\":0,\"dispute_uri\":null},\"refund\":{\"amount_refunded\":0,\"refund_reason\":null},\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":1929540809,\"data\":{\"emv_receipt\":null,\"signature_url\":null},\"auto_capture\":false}},\"hosted_checkout\":null,\"payer\":{\"email\":\"test@example.com\",\"name\":\"Longbob Longsen\",\"home_address\":null},\"npo_information\":null,\"payment_error\":null,\"in_review\":false,\"auto_release\":true})
  end

  def failed_authorize_response
    %({\"error\":\"invalid_request\",\"error_description\":\"Invalid credit card number\",\"error_code\":1003})
  end

  def successful_capture_response
    %({\"checkout_id\":1181910285,\"account_id\":2080478981,\"type\":\"goods\",\"short_description\":\"Purchase\",\"currency\":\"USD\",\"amount\":20,\"state\":\"authorized\",\"soft_descriptor\":\"WPY*Spreedly\",\"create_time\":1481836590,\"gross\":20.88,\"reference_id\":null,\"callback_uri\":null,\"long_description\":null,\"delivery_type\":null,\"fee\":{\"app_fee\":0,\"processing_fee\":0.88,\"fee_payer\":\"payer\"},\"chargeback\":{\"amount_charged_back\":0,\"dispute_uri\":null},\"refund\":{\"amount_refunded\":0,\"refund_reason\":null},\"payment_method\":{\"type\":\"credit_card\",\"credit_card\":{\"id\":1929540809,\"data\":{\"emv_receipt\":null,\"signature_url\":null},\"auto_capture\":false}},\"hosted_checkout\":null,\"payer\":{\"email\":\"test@example.com\",\"name\":\"Longbob Longsen\",\"home_address\":null},\"npo_information\":null,\"payment_error\":null,\"in_review\":false,\"auto_release\":true})
  end

  def failed_capture_response
    %({"error":"invalid_request","error_description":"Checkout object must be in state 'Reserved' to capture. Currently it is in state captured","error_code":4004})
  end

  def invalid_json_response
    %({"checkout_id"=1852898602,"state":"captured")
  end

end
