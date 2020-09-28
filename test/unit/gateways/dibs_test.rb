require 'test_helper'

class DibsTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = DibsGateway.new(
      merchant_id: "merchantId",
      secret_key: "secretKey"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response

    assert_equal "1066662996", response.authorization
    assert response.test?
  end

  def test_failed_purchase_due_to_failed_capture
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response, failed_capture_response)

    assert_failure response
    assert_equal "DECLINE: 1", response.message
    assert response.test?
  end

  def test_failed_purchase_due_to_failed_auth
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "DECLINE: REJECTED_BY_ACQUIRER", response.message
    assert response.test?
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)
    assert_success response
    assert_equal "1066662996", response.authorization
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "1066662996", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/1066662996/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "DECLINE: REJECTED_BY_ACQUIRER", response.message
    assert response.test?
  end

  def test_failed_capture
    response = stub_comms do
      @gateway.capture(100, "")
    end.respond_with(failed_capture_response)

    assert_failure response
  end

  def test_successful_void
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "1066662996", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/1066662996/, data)
    end.respond_with(successful_void_response)

    assert_success void
  end

  def test_failed_void
    response = stub_comms do
      @gateway.void("5d53a33d960c46d00f5dc061947d998c")
    end.check_request do |endpoint, data, headers|
      assert_match(/5d53a33d960c46d00f5dc061947d998c/, data)
    end.respond_with(failed_void_response)

    assert_failure response
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_authorize_response, successful_capture_response)

    assert_success response
    assert_equal "1066662996", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/1066662996/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "DECLINE: REJECTED_BY_ACQUIRER", response.message
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(successful_store_response)

    assert_success response

    assert_equal "Succeeded", response.message
    assert response.test?
  end

  def test_failed_store
    response = stub_comms do
      @gateway.store(@credit_card)
    end.respond_with(failed_store_response)

    assert_failure response
    assert_equal "DECLINE: REJECTED_BY_ACQUIRER", response.message
    assert response.test?
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.send(:scrub, transcript)
  end

  def test_invalid_json
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(invalid_json_response)

    assert_failure response
    assert_match %r{Invalid JSON response}, response.message
  end

  private

  def successful_authorize_response
    %({\"transactionId\":\"1066662996\",\"status\":\"ACCEPT\",\"acquirer\":\"TEST\"})
  end

  def failed_authorize_response
    %({\"status\":\"DECLINE\",\"declineReason\":\"REJECTED_BY_ACQUIRER\"})
  end

  def successful_capture_response
    %({\"status\":\"ACCEPT\"})
  end

  def failed_capture_response
    %({\"status\":\"DECLINE\",\"declineReason\":\"1\"})
  end

  def successful_void_response
    %({\"status\":\"ACCEPT\"})
  end

  def failed_void_response
    %({\"status\":\"ERROR\",\"declineReason\":\"Validation error at field: transactionId - Parameter length should not be less than 1 characters\"})
  end

  def successful_refund_response
    %({\"status\":\"ACCEPT\"})
  end

  def failed_refund_response
    %({\"status\":\"ERROR\",\"declineReason\":\"Validation error at field: transactionId - Parameter length should not be less than 1 characters\"})
  end

  def successful_store_response
    %({\"ticketId\":\"1070103439\",\"status\":\"ACCEPT\",\"acquirer\":\"TEST\"})
  end

  def failed_store_response
    %({\"status\":\"DECLINE\",\"declineReason\":\"REJECTED_BY_ACQUIRER\"})
  end

  def invalid_json_response
    "{"
  end

  def transcript
    %(
      <- "POST /merchant/v1/JSON/Transaction/AuthorizeCard HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.dibspayment.com\r\nContent-Length: 293\r\n\r\n"
      <- "request={\"amount\":100,\"orderId\":\"a1f3d8c03f1490750812085ea21852f1\",\"currency\":\"840\",\"cardNumber\":\"4711100000000000\",\"cvc\":\"684\",\"expYear\":\"24\",\"expMonth\":\"6\",\"test\":true,\"clientIp\":\"45.37.180.92\",\"merchantId\":\"90196871\",\"MAC\":\"4ffe83a971fc96075a9fbaae1e9bbdcbfdf8842365f381d6151162dd59e3875f\"}"
      <- "POST /merchant/v1/JSON/Transaction/CaptureTransaction HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.dibspayment.com\r\nContent-Length: 148\r\n\r\n"
      <- "request={\"amount\":100,\"transactionId\":\"1066783460\",\"merchantId\":\"90196871\",\"MAC\":\"5bc0307d55a4f146cfb9d97c42e9bb7b8112c93d4cd8349d38aa5f0360a45e08\"}"
    )
  end

  def scrubbed_transcript
    %(
      <- "POST /merchant/v1/JSON/Transaction/AuthorizeCard HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.dibspayment.com\r\nContent-Length: 293\r\n\r\n"
      <- "request={\"amount\":100,\"orderId\":\"a1f3d8c03f1490750812085ea21852f1\",\"currency\":\"840\",\"cardNumber\":\"[FILTERED]\",\"cvc\":\"[FILTERED]\",\"expYear\":\"24\",\"expMonth\":\"6\",\"test\":true,\"clientIp\":\"45.37.180.92\",\"merchantId\":\"90196871\",\"MAC\":\"4ffe83a971fc96075a9fbaae1e9bbdcbfdf8842365f381d6151162dd59e3875f\"}"
      <- "POST /merchant/v1/JSON/Transaction/CaptureTransaction HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: api.dibspayment.com\r\nContent-Length: 148\r\n\r\n"
      <- "request={\"amount\":100,\"transactionId\":\"1066783460\",\"merchantId\":\"90196871\",\"MAC\":\"5bc0307d55a4f146cfb9d97c42e9bb7b8112c93d4cd8349d38aa5f0360a45e08\"}"
    )
  end
end
