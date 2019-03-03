require 'test_helper'

class DLocalTest < Test::Unit::TestCase
  def setup
    @gateway = DLocalGateway.new(login: 'login', trans_key: 'password', secret_key: 'shhhhh_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'D-15104-05b0ec0c-5a1e-470a-b342-eb5f20758ef7', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '300', response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '309', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'D-15104-5a914b68-afb8-44f8-a849-8cf09ab6c246', response.authorization
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_failure response
    assert_equal '4000', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570', response.authorization
  end

  def test_pending_refund
    @gateway.expects(:ssl_post).returns(pending_refund_response)

    response = @gateway.refund(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570', response.authorization
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_failure response
    assert_equal '5007', response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_success response

    assert_equal 'D-15104-c147279d-14ab-4537-8ba6-e3e1cde0f8d2', response.authorization
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', @options)
    assert_failure response

    assert_equal '5002', response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).times(2).returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', response.authorization
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_request).times(2).returns(successful_authorize_response, failed_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3', response.authorization
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal '309', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      <- "POST /secure_payments/ HTTP/1.1\r\nContent-Type: application/json\r\nX-Date: 2018-12-04T18:24:21Z\r\nX-Login: aeaf9bbfa1\r\nX-Trans-Key: 9de3769b7e\r\nAuthorization: V2-HMAC-SHA256, Signature: d58d0e87a59af50ff974dfeea176c067354682aa74a8ac115912576d4214a776\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.dlocal.com\r\nContent-Length: 441\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"payer\":{\"name\":\"Longbob Longsen\",\"phone\":\"(555)555-5555\",\"document\":\"42243309114\",\"address\":null},\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"number\":\"4111111111111111\",\"cvv\":\"123\",\"capture\":true},\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\",\"description\":\"200\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: Reblaze Secure Web Gateway\r\n"
      -> "Date: Tue, 04 Dec 2018 18:24:22 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 565\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Via: 1.1 google\r\n"
      -> "Alt-Svc: clear\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 565 bytes...
      -> "{\"id\":\"D-15104-9f5246d5-34e2-4f63-9d29-380ab1567ec9\",\"amount\":1.00,\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"brand\":\"VI\",\"last4\":\"1111\",\"card_id\":\"CV-434cb5d1-aece-4878-8ce2-24f887fc7ff5\"},\"created_date\":\"2018-12-04T18:24:21.000+0000\",\"approved_date\":\"2018-12-04T18:24:22.000+0000\",\"status\":\"PAID\",\"status_detail\":\"The payment was paid\",\"status_code\":\"200\",\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\"}"
    )
  end

  def post_scrubbed
    %q(
      <- "POST /secure_payments/ HTTP/1.1\r\nContent-Type: application/json\r\nX-Date: 2018-12-04T18:24:21Z\r\nX-Login: aeaf9bbfa1\r\nX-Trans-Key: [FILTERED]\r\nAuthorization: V2-HMAC-SHA256, Signature: d58d0e87a59af50ff974dfeea176c067354682aa74a8ac115912576d4214a776\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: sandbox.dlocal.com\r\nContent-Length: 441\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"payer\":{\"name\":\"Longbob Longsen\",\"phone\":\"(555)555-5555\",\"document\":\"42243309114\",\"address\":null},\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"number\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"capture\":true},\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\",\"description\":\"200\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: Reblaze Secure Web Gateway\r\n"
      -> "Date: Tue, 04 Dec 2018 18:24:22 GMT\r\n"
      -> "Content-Type: application/json;charset=utf-8\r\n"
      -> "Content-Length: 565\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "Via: 1.1 google\r\n"
      -> "Alt-Svc: clear\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 565 bytes...
      -> "{\"id\":\"D-15104-9f5246d5-34e2-4f63-9d29-380ab1567ec9\",\"amount\":1.00,\"currency\":\"BRL\",\"payment_method_id\":\"CARD\",\"payment_method_type\":\"CARD\",\"payment_method_flow\":\"DIRECT\",\"country\":\"BR\",\"card\":{\"holder_name\":\"Longbob Longsen\",\"expiration_month\":9,\"expiration_year\":2019,\"brand\":\"VI\",\"last4\":\"1111\",\"card_id\":\"CV-434cb5d1-aece-4878-8ce2-24f887fc7ff5\"},\"created_date\":\"2018-12-04T18:24:21.000+0000\",\"approved_date\":\"2018-12-04T18:24:22.000+0000\",\"status\":\"PAID\",\"status_detail\":\"The payment was paid\",\"status_code\":\"200\",\"order_id\":\"62595c5db10fdf7b5d5bb3a16d130992\"}"
    )
  end

  def successful_purchase_response
    '{"id":"D-15104-05b0ec0c-5a1e-470a-b342-eb5f20758ef7","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-993903e4-0b33-48fd-8d9b-99fd6c3f0d1a"},"created_date":"2018-12-06T20:20:41.000+0000","approved_date":"2018-12-06T20:20:42.000+0000","status":"PAID","status_detail":"The payment was paid","status_code":"200","order_id":"15940ef43d39331bc64f31341f8ccd93"}'
  end

  def failed_purchase_response
    '{"id":"D-15104-c3027e67-21f8-4308-8c94-06c44ffcea67","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-529b0bb1-8b8a-42f4-b5e4-d358ffb2c978"},"created_date":"2018-12-06T20:22:40.000+0000","status":"REJECTED","status_detail":"The payment was rejected.","status_code":"300","order_id":"7aa5cd3200f287fbac51dcee32184260"}'
  end

  def successful_authorize_response
    '{"id":"D-15104-be03e883-3e6b-497d-840e-54c8b6209bc3","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-ecd897ac-5361-45a1-a407-aaab044ce87e"},"created_date":"2018-12-06T20:24:46.000+0000","approved_date":"2018-12-06T20:24:46.000+0000","status":"AUTHORIZED","status_detail":"The payment was authorized","status_code":"600","order_id":"5694b51b79df484578158d7790b4aacf"}'
  end

  def failed_authorize_response
    '{"id":"D-15104-e6ed3df3-1380-46c6-92d4-29f0f567f799","amount":1.00,"currency":"BRL","payment_method_id":"CARD","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","card":{"holder_name":"Longbob Longsen","expiration_month":9,"expiration_year":2019,"brand":"VI","last4":"1111","card_id":"CV-a6326a1d-b706-4e89-9dff-091d73d85b26"},"created_date":"2018-12-06T20:26:57.000+0000","status":"REJECTED","status_detail":"Card expired.","status_code":"309","order_id":"8ecd3101ba7a9a2d6ccb6465d33ff10d"}'
  end

  def successful_capture_response
    '{"id":"D-15104-5a914b68-afb8-44f8-a849-8cf09ab6c246","amount":1.00,"currency":"BRL","payment_method_id":"VI","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","created_date":"2018-12-06T20:26:17.000+0000","approved_date":"2018-12-06T20:26:18.000+0000","status":"PAID","status_detail":"The payment was paid","status_code":"200","order_id":"f8276e468120faf3e7252e33ac5f9a73"}'
  end

  def failed_capture_response
    '{"code":4000,"message":"Payment not found"}'
  end

  def successful_refund_response
    '{"id":"REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570","payment_id":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f","status":"SUCCESS","currency":"BRL","created_date":"2018-12-06T20:28:37.000+0000","amount":1.00,"status_code":200,"status_detail":"The refund was paid","notification_url":"http://example.com","amount_refunded":1.00,"id_payment":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f"}'
  end

  # I can't invoke a pending response and there is no example in docs, so this response is speculative
  def pending_refund_response
    '{"id":"REF-15104-a9cc29e5-1895-4cec-94bd-aa16c3b92570","payment_id":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f","status":"PENDING","currency":"BRL","created_date":"2018-12-06T20:28:37.000+0000","amount":1.00,"status_code":100,"status_detail":"The refund is pending","notification_url":"http://example.com","amount_refunded":1.00,"id_payment":"D-15104-f9e16b85-5fc8-40f0-a4d8-4e73a892594f"}'
  end

  def failed_refund_response
    '{"code":5007,"message":"Amount exceeded"}'
  end

  def successful_void_response
    '{"id":"D-15104-c147279d-14ab-4537-8ba6-e3e1cde0f8d2","amount":1.00,"currency":"BRL","payment_method_id":"VI","payment_method_type":"CARD","payment_method_flow":"DIRECT","country":"BR","created_date":"2018-12-06T20:38:01.000+0000","approved_date":"2018-12-06T20:38:01.000+0000","status":"CANCELLED","status_detail":"The payment was cancelled","status_code":"400","order_id":"46d8978863be935d892cfa3e992f65f3"}'
  end

  def failed_void_response
    '{"code":5002,"message":"Invalid transaction status"}'
  end
end
