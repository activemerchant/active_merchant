require 'test_helper'

class CardPointeTest < Test::Unit::TestCase
  def setup
    @gateway = CardPointeGateway.new(username: 'login', password: 'password', merchid: 'merchid123')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: generate_unique_id,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal '155949252515', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, '155949252515', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, '155949252515', @options)
    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('155949252515', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('155949252515', @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert response.params['amount'] = '0.00'
  end

  # def test_successful_verify_with_failed_void
  # end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:expired_card], response.error_code
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_store_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal '14231315860667805749', response.params['profileid']
    assert_equal '1', response.params['acctid']
  end

  def test_successful_update
    @gateway.expects(:ssl_post).returns(successful_update_response)

    response = @gateway.update('13752085791902707729/1', @credit_card, @options)
    assert_success response
    assert_equal '13752085791902707729', response.params['profileid']
    assert_equal '1', response.params['acctid']
  end

  def test_successful_unstore
    @gateway.expects(:ssl_request).returns(successful_unstore_response)

    response = @gateway.unstore('13752085791902707729/1', @options)
    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to fts.cardconnect.com:6443...
      opened
      starting SSL for fts.cardconnect.com:6443...
      SSL established
      <- "POST /cardconnect/rest/auth HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic dGVzdGluZzE6UTJDdHlkOTdQISN1NUpZU1A2UlJUdA==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: fts.cardconnect.com:6443\r\nContent-Length: 300\r\n\r\n"
      <- "{\"capture\":\"Y\",\"amount\":\"1.00\",\"currency\":\"USD\",\"orderid\":null,\"expiry\":\"9/2020\",\"account\":\"6011361000006668\",\"cvv2\":\"123\",\"address\":\"456 My Street, Apt 1\",\"city\":\"Ottawa\",\"postal\":\"K1C2N6\",\"region\":\"ON\",\"country\":\"CA\",\"name\":\"Jim Smith\",\"phone\":\"(555)555-5555\",\"email\":null,\"merchid\":\"496480518000\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "X-FRAME-OPTIONS: DENY\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 257\r\n"
      -> "Date: Wed, 12 Jun 2019 21:22:39 GMT\r\n"
      -> "Server: wgbmsuhp/2.0\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: BIGipServerphu-smb-vip_8080=!7Gmh+jy9KEYvg0yp9hqD8o9BIx0YdydZpoV3IvGPN+CMZ0xm9vm5wxgB54FrQz7Le48rm+UaKF6nAn4=; path=/; Httponly; Secure\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "\r\n"
      reading 257 bytes...
      -> "{\"amount\":\"1.00\",\"resptext\":\"Approval\",\"cvvresp\":\"M\",\"respcode\":\"000\",\"batchid\":\"101\",\"avsresp\":\"\",\"merchid\":\"496480518000\",\"token\":\"9605849968916668\",\"authcode\":\"PPS292\",\"respproc\":\"RPCT\",\"retref\":\"163915262559\",\"respstat\":\"A\",\"account\":\"9605849968916668\"}"
      read 257 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to fts.cardconnect.com:6443...
      opened
      starting SSL for fts.cardconnect.com:6443...
      SSL established
      <- "POST /cardconnect/rest/auth HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: fts.cardconnect.com:6443\r\nContent-Length: 300\r\n\r\n"
      <- "{\"capture\":\"Y\",\"amount\":\"1.00\",\"currency\":\"USD\",\"orderid\":null,\"expiry\":\"[FILTERED]",\"account\":\"[FILTERED]",\"cvv2\":\"[FILTERED]",\"address\":\"456 My Street, Apt 1\",\"city\":\"Ottawa\",\"postal\":\"K1C2N6\",\"region\":\"ON\",\"country\":\"CA\",\"name\":\"Jim Smith\",\"phone\":\"(555)555-5555\",\"email\":null,\"merchid\":\"[FILTERED]"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "X-FRAME-OPTIONS: DENY\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 257\r\n"
      -> "Date: Wed, 12 Jun 2019 21:22:39 GMT\r\n"
      -> "Server: wgbmsuhp/2.0\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: BIGipServerphu-smb-vip_8080=!7Gmh+jy9KEYvg0yp9hqD8o9BIx0YdydZpoV3IvGPN+CMZ0xm9vm5wxgB54FrQz7Le48rm+UaKF6nAn4=; path=/; Httponly; Secure\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "\r\n"
      reading 257 bytes...
      -> "{\"amount\":\"1.00\",\"resptext\":\"Approval\",\"cvvresp\":\"M\",\"respcode\":\"000\",\"batchid\":\"101\",\"avsresp\":\"\",\"merchid\":\"[FILTERED]",\"token\":\"9605849968916668\",\"authcode\":\"PPS292\",\"respproc\":\"RPCT\",\"retref\":\"163915262559\",\"respstat\":\"A\",\"account\":\"[FILTERED]"}"
      read 257 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-RESPONSE
    {\"amount\":\"1.00\",\"resptext\":\"Approval\",\"commcard\":\"   \",\"cvvresp\":\"X\",\"respcode\":\"00\",\"batchid\":\"1900942457\",\"avsresp\":\" \",\"entrymode\":\"Keyed\",\"merchid\":\"496160873888\",\"token\":\"9605849968916668\",\"authcode\":\"PPS935\",\"respproc\":\"FNOR\",\"bintype\":\"\",\"retref\":\"155748247575\",\"respstat\":\"A\",\"account\":\"9605849968916668\"}
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
      {\"respproc\":\"RPCT\",\"amount\":\"0.00\",\"resptext\":\"Violation of law\",\"cardproc\":\"RPCT\",\"retref\":\"163978262845\",\"respstat\":\"C\",\"respcode\":\"124\",\"account\":\"9605849968916668\",\"merchid\":\"496480518000\",\"token\":\"9605849968916668\"}
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
      {\"amount\":\"1.00\",\"resptext\":\"Approval\",\"commcard\":\" C \",\"cvvresp\":\"X\",\"respcode\":\"00\",\"avsresp\":\" \",\"entrymode\":\"Keyed\",\"merchid\":\"496160873888\",\"token\":\"9422925921134242\",\"authcode\":\"PPS915\",\"respproc\":\"FNOR\",\"bintype\":\"\",\"retref\":\"155949252515\",\"respstat\":\"A\",\"account\":\"9422925921134242\"}
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
      {\"respproc\":\"RPCT\",\"amount\":\"0.00\",\"resptext\":\"Over daily limit\",\"cardproc\":\"RPCT\",\"retref\":\"163789163024\",\"respstat\":\"C\",\"respcode\":\"554\",\"account\":\"9605849968916668\",\"merchid\":\"496480518000\",\"token\":\"9605849968916668\"}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {\"amount\":\"1.00\",\"resptext\":\"Approval\",\"setlstat\":\"Queued for Capture\",\"commcard\":\" C \",\"respcode\":\"00\",\"batchid\":\"1900942460\",\"merchid\":\"496160873888\",\"token\":\"9422925921134242\",\"authcode\":\"PPS540\",\"respproc\":\"FNOR\",\"retref\":\"155859171266\",\"respstat\":\"A\",\"account\":\"9422925921134242\"}
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {\"respproc\":\"PPS\",\"resptext\":\"Invalid field\",\"retref\":\"\",\"respstat\":\"C\",\"respcode\":\"34\",\"batchid\":\"-1\",\"account\":\"\"}
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      {\"respproc\":\"PPS\",\"amount\":\"1.00\",\"resptext\":\"Approval\",\"retref\":\"155671152780\",\"respstat\":\"A\",\"respcode\":\"00\",\"merchid\":\"496160873888\"}
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
      {\"respproc\":\"PPS\",\"resptext\":\"Txn not found\",\"retref\":\"\",\"respcode\":\"29\",\"respstat\":\"C\"}
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      {\"authcode\":\"REVERS\",\"respproc\":\"FNOR\",\"amount\":\"0.00\",\"resptext\":\"Approval\",\"currency\":\"USD\",\"retref\":\"155061253175\",\"respstat\":\"A\",\"respcode\":\"00\",\"merchid\":\"496160873888\"}
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
      {\"respproc\":\"PPS\",\"amount\":\"0.00\",\"resptext\":\"Invalid field\",\"currency\":\"\",\"retref\":\"\",\"respstat\":\"C\",\"respcode\":\"34\",\"merchid\":\"496480518000\"}
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
      {\"amount\":\"0.00\",\"resptext\":\"Approval\",\"commcard\":\" C \",\"cvvresp\":\"X\",\"respcode\":\"00\",\"avsresp\":\"Z\",\"entrymode\":\"Keyed\",\"merchid\":\"496160873888\",\"token\":\"9422925921134242\",\"authcode\":\"PPS670\",\"respproc\":\"FNOR\",\"bintype\":\"\",\"retref\":\"155098253457\",\"respstat\":\"A\",\"account\":\"9422925921134242\"}
    RESPONSE
  end

  def failed_verify_response
    <<-RESPONSE
      {\"respproc\":\"RPCT\",\"amount\":\"0.00\",\"resptext\":\"Expired card\",\"cardproc\":\"RPCT\",\"retref\":\"163502164906\",\"respstat\":\"C\",\"respcode\":\"101\",\"account\":\"9605849968916668\",\"merchid\":\"496480518000\",\"token\":\"9605849968916668\"}
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
      {\"country\":\"CA\",\"address\":\"456 My Street\",\"resptext\":\"Profile Saved\",\"city\":\"Ottawa\",\"acctid\":\"1\",\"respcode\":\"09\",\"defaultacct\":\"Y\",\"accttype\":\"VISA\",\"token\":\"9422925921134242\",\"respproc\":\"PPS\",\"profileid\":\"14231315860667805749\",\"auoptout\":\"N\",\"postal\":\"K1C2N6\",\"expiry\":\"0920\",\"region\":\"ON\",\"respstat\":\"A\"}
    RESPONSE
  end

  def successful_update_response
    <<-RESPONSE
      {\"country\":\"CA\",\"address\":\"456 My Street\",\"resptext\":\"Profile Saved\",\"city\":\"Ottawa\",\"acctid\":\"1\",\"respcode\":\"09\",\"defaultacct\":\"Y\",\"accttype\":\"VISA\",\"token\":\"9477257372660010\",\"respproc\":\"PPS\",\"profileid\":\"13752085791902707729\",\"auoptout\":\"N\",\"postal\":\"K1C2N6\",\"expiry\":\"0920\",\"region\":\"ON\",\"respstat\":\"A\"}
    RESPONSE
  end

  def successful_unstore_response
    <<-RESPONSE
      {\"respproc\":\"PPS\",\"resptext\":\"Profile Deleted\",\"respstat\":\"A\",\"respcode\":\"08\"}
    RESPONSE
  end
end
