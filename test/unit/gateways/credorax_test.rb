require 'test_helper'

class CredoraxTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CredoraxGateway.new(merchant_id: 'login', cipher_key: 'password')
    @credit_card = credit_card
    @amount = 100

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_no_match(/i8=sample-eci%3Asample-cavv%3Asample-xid/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Transaction not allowed for cardholder", response.message
    assert response.test?
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_equal "8a829449535154bc0153595952a2517a;006597;90f7449d555f7bed0a2c5d780475f0bf;authorize", response.authorization

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/8a829449535154bc0153595952a2517a/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Transaction not allowed for cardholder", response.message
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
    assert_equal "8a829449535154bc0153595952a2517a;006597;90f7449d555f7bed0a2c5d780475f0bf;purchase", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/8a829449535154bc0153595952a2517a/, data)
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
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_equal "8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/8a82944a5351570601535955efeb513c/, data)
    end.respond_with(successful_refund_response)

    assert_success refund
  end

  def test_failed_refund
    response = stub_comms do
      @gateway.refund(nil, "")
    end.respond_with(failed_refund_response)

    assert_failure response
  end

  def test_successful_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(successful_credit_response)

    assert_success response

    assert_equal "8a82944a53515706015359604c135301;;868f8b942fae639d28e27e8933d575d4;credit", response.authorization
    assert response.test?
  end

  def test_failed_credit
    response = stub_comms do
      @gateway.credit(@amount, @credit_card)
    end.respond_with(failed_credit_response)

    assert_failure response
    assert_equal "Transaction not allowed for cardholder", response.message
    assert response.test?
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
    assert_equal "Transaction not allowed for cardholder", response.message
  end

  def test_empty_response_fails
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(empty_purchase_response)

    assert_failure response
    assert_equal "Unable to read error message", response.message
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_adds_3d_secure_fields
    options_with_3ds = @options.merge({eci: "sample-eci", cavv: "sample-cavv", xid: "sample-xid"})

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |endpoint, data, headers|
      assert_match(/i8=sample-eci%3Asample-cavv%3Asample-xid/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase", response.authorization
    assert response.test?
  end

  def test_defaults_3d_secure_cavv_field_to_none_if_not_present
    options_with_3ds = @options.merge({eci: "sample-eci", xid: "sample-xid"})

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, options_with_3ds)
    end.check_request do |endpoint, data, headers|
      assert_match(/i8=sample-eci%3Anone%3Asample-xid/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "8a82944a5351570601535955efeb513c;006596;02617cf5f02ccaed239b6521748298c5;purchase", response.authorization
    assert response.test?
  end

  private

  def successful_purchase_response
    "M=SPREE978&O=1&T=03%2F09%2F2016+03%3A05%3A16&V=413&a1=02617cf5f02ccaed239b6521748298c5&a2=2&a4=100&a9=6&z1=8a82944a5351570601535955efeb513c&z13=606944188282&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006596&z5=0&z6=00&z9=X&K=057e123af2fba5a37b4df76a7cb5cfb6"
  end

  def failed_purchase_response
    "M=SPREE978&O=1&T=03%2F09%2F2016+03%3A05%3A47&V=413&a1=92176aca194ceafdb4a679389b77f207&a2=2&a4=100&a9=6&z1=8a82944a535157060153595668fd5162&z13=606944188283&z15=100&z2=05&z3=Transaction+has+been+declined.&z5=0&z6=57&K=2d44820a5a907ff820f928696e460ce1"
  end

  def successful_authorize_response
    "M=SPREE978&O=2&T=03%2F09%2F2016+03%3A08%3A58&V=413&a1=90f7449d555f7bed0a2c5d780475f0bf&a2=2&a4=100&a9=6&z1=8a829449535154bc0153595952a2517a&z13=606944188284&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006597&z5=0&z6=00&z9=X&K=00effd2c80ab7ecd45b499c0bbea3d20"
  end

  def failed_authorize_response
    "M=SPREE978&O=2&T=03%2F09%2F2016+03%3A10%3A02&V=413&a1=9bd85e23639ffcd5206f8e7fe4e3d365&a2=2&a4=100&a9=6&z1=8a829449535154bc0153595a4bb051ac&z13=606944188285&z15=100&z2=05&z3=Transaction+has+been+declined.&z5=0&z6=57&K=2fe3ee6b975d1e4ba542c1e7549056f6"
  end

  def successful_capture_response
    "M=SPREE978&O=3&T=03%2F09%2F2016+03%3A09%3A03&V=413&a1=2a349969e0ed61fb0db59fc9f32d2fb3&a2=2&a4=100&g2=8a829449535154bc0153595952a2517a&g3=006597&g4=90f7449d555f7bed0a2c5d780475f0bf&z1=8a82944a535157060153595966ba51f9&z13=606944188284&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006597&z5=0&z6=00&K=4ad979199490a8d000302735220edfa6"
  end

  def failed_capture_response
    "M=SPREE978&O=3&T=03%2F09%2F2016+03%3A10%3A33&V=413&a1=eed7c896e1355dc4007c0c8df44d5852&a2=2&a4=100&a5=EUR&b1=-&z1=1A-1&z2=-9&z3=2.+At+least+one+of+input+parameters+is+malformed.%3A+Parameter+%5Bg4%5D+cannot+be+empty.&K=8d1d8f2f9feeb7909aa3e6c428903d57"
  end

  def successful_void_response
    "M=SPREE978&O=4&T=03%2F09%2F2016+03%3A11%3A11&V=413&a1=&a2=2&a4=100&g2=8a82944a535157060153595b484a524d&g3=006598&g4=0d600bf50198059dbe61979f8c28aab2&z1=8a829449535154bc0153595b57c351d2&z13=606944188287&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006598&z5=0&z6=00&K=e643b9e88b35fd69d5421b59c611a6c9"
  end

  def failed_void_response
    "M=SPREE978&O=4&T=03%2F09%2F2016+03%3A11%3A37&V=413&a1=-&a2=2&a4=-&a5=-&b1=-&z1=1A-1&z2=-9&z3=2.+At+least+one+of+input+parameters+is+malformed.%3A+Parameter+%5Bg4%5D+cannot+be+empty.&K=1e6683cd7b1d01712f12ce7bfc9a5ad2"
  end

  def successful_refund_response
    "M=SPREE978&O=5&T=03%2F09%2F2016+03%3A15%3A32&V=413&a1=b449bb41af3eb09fd483e7629eb2266f&a2=2&a4=100&g2=8a82944a535157060153595f3ea352c2&g3=006600&g4=78141b277cfadba072a0bcb90745faef&z1=8a82944a535157060153595f553a52de&z13=606944188288&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006600&z5=0&z6=00&K=bfdfd8b0dcee974c07c3c85cfea753fe"
  end

  def failed_refund_response
    "M=SPREE978&O=5&T=03%2F09%2F2016+03%3A16%3A06&V=413&a1=c2b481deffe0e27bdef1439655260092&a2=2&a4=-&a5=EUR&b1=-&z1=1A-1&z2=-9&z3=2.+At+least+one+of+input+parameters+is+malformed.%3A+Parameter+%5Bg4%5D+cannot+be+empty.&K=c2f6112b40c61859d03684ac8e422766"
  end

  def successful_credit_response
    "M=SPREE978&O=6&T=03%2F09%2F2016+03%3A16%3A35&V=413&a1=868f8b942fae639d28e27e8933d575d4&a2=2&a4=100&z1=8a82944a53515706015359604c135301&z13=606944188289&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z5=0&z6=00&K=51ba24f6ef3aa161f86e53c34c9616ac"
  end

  def failed_credit_response
    "M=SPREE978&O=6&T=03%2F09%2F2016+03%3A16%3A59&V=413&a1=ff28246cfc811b1c686a52d08d075d9c&a2=2&a4=100&z1=8a829449535154bc01535960a962524f&z13=606944188290&z15=100&z2=05&z3=Transaction+has+been+declined.&z5=0&z6=57&K=cf34816d5c25dc007ef3525505c4c610"
  end

  def empty_purchase_response
    %(
    )
  end

  def transcript
    %(
        opening connection to intconsole.credorax.com:443...
        opened
        starting SSL for intconsole.credorax.com:443...
        SSL established
        <- "POST /intenv/service/gateway HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: intconsole.credorax.com\r\nContent-Length: 264\r\n\r\n"
        <- "a4=100&a1=335ebb08c489e6d361108a7eb7d8b92a&a5=EUR&c1=Longbob+Longsen&b2=1&b1=5223450000000007&b5=090&b4=25&b3=12&d1=127.0.0.1&c3=unspecified%40example.com&c5=456+My+StreetApt+1&c7=Ottawa&c10=K1C2N6&c2=+555+555-5555&M=SPREE978&O=1&K=ef26476215cee15664e75d979d33935b"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Date: Wed, 09 Mar 2016 03:03:00 GMT\r\n"
        -> "Content-Type: application/x-www-form-urlencoded\r\n"
        -> "Content-Length: 283\r\n"
        -> "Connection: close\r\n"
        -> "\r\n"
        reading 283 bytes...
        -> "M=SPREE978&O=1&T=03%2F09%2F2016+03%3A03%3A01&V=413&a1=335ebb08c489e6d361108a7eb7d8b92a&a2=2&a4=100&a9=6&z1=8a829449535154bc01535953dd235043&z13=606944188276&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006592&z5=0&z6=00&z9=X&K=4061e16f39915297827af1586635015a"
        read 283 bytes
        Conn close
    )
  end

  def scrubbed_transcript
    %(
        opening connection to intconsole.credorax.com:443...
        opened
        starting SSL for intconsole.credorax.com:443...
        SSL established
        <- "POST /intenv/service/gateway HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: intconsole.credorax.com\r\nContent-Length: 264\r\n\r\n"
        <- "a4=100&a1=335ebb08c489e6d361108a7eb7d8b92a&a5=EUR&c1=Longbob+Longsen&b2=1&b1=[FILTERED]&b5=[FILTERED]&b4=25&b3=12&d1=127.0.0.1&c3=unspecified%40example.com&c5=456+My+StreetApt+1&c7=Ottawa&c10=K1C2N6&c2=+555+555-5555&M=SPREE978&O=1&K=ef26476215cee15664e75d979d33935b"
        -> "HTTP/1.1 200 OK\r\n"
        -> "Date: Wed, 09 Mar 2016 03:03:00 GMT\r\n"
        -> "Content-Type: application/x-www-form-urlencoded\r\n"
        -> "Content-Length: 283\r\n"
        -> "Connection: close\r\n"
        -> "\r\n"
        reading 283 bytes...
        -> "M=SPREE978&O=1&T=03%2F09%2F2016+03%3A03%3A01&V=413&a1=335ebb08c489e6d361108a7eb7d8b92a&a2=2&a4=100&a9=6&z1=8a829449535154bc01535953dd235043&z13=606944188276&z14=U&z15=100&z2=0&z3=Transaction+has+been+executed+successfully.&z4=006592&z5=0&z6=00&z9=X&K=4061e16f39915297827af1586635015a"
        read 283 bytes
        Conn close
    )
  end
end
