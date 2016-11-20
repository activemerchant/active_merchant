require "test_helper"

class TelrTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = TelrGateway.new(
      merchant_id: "login",
      api_key: "password"
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "029724176180|100|AED", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert_equal "Not authorised", response.message
  end

  def test_successful_authorize_and_capture
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(successful_authorize_response)

    assert_success response
    assert_match(/029894296182/, response.authorization)

    capture = stub_comms do
      @gateway.capture(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/029894296182/, data)
    end.respond_with(successful_capture_response)

    assert_success capture
  end

  def test_failed_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_response)

    assert_failure response
    assert_equal "Not authorised", response.message
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
    assert_equal "029894296182|100|AED", response.authorization

    void = stub_comms do
      @gateway.void(response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/029894296182/, data)
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
    assert_equal "029724176180|100|AED", response.authorization

    refund = stub_comms do
      @gateway.refund(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/029724176180/, data)
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
    assert_equal "Not authorised", response.message
  end

  def test_successful_reference_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response
    assert_match(/029724176180/, response.authorization)

    ref_purchase = stub_comms do
      @gateway.purchase(@amount, response.authorization)
    end.check_request do |endpoint, data, headers|
      assert_match(/029724176180/, data)
    end.respond_with(successful_reference_purchase_response)

    assert_success ref_purchase
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  private

  def successful_purchase_response
    %(
    <remote><auth><status>A</status><code>904492</code><message>Authorised</message><tranref>029724176180</tranref><cvv>Y</cvv><avs>X</avs><trace>4000/4491/5772cdab</trace></auth></remote>
    )
  end

  def failed_purchase_response
    %(
    <remote><auth><status>D</status><code>31</code><message>Not authorised</message><tranref>020220116187</tranref><cvv>X</cvv><avs>X</avs><trace>4000/10194/577bcfae</trace></auth></remote>
    )
  end

  def successful_authorize_response
    %(
    <remote><auth><status>A</status><code>926899</code><message>Authorised</message><tranref>029894296182</tranref><cvv>Y</cvv><avs>X</avs><trace>4000/26898/577531b2</trace></auth></remote>
    )
  end

  def failed_authorize_response
    %(
    <remote><auth><status>D</status><code>31</code><message>Not authorised</message><tranref>020220646187</tranref><cvv>X</cvv><avs>X</avs><trace>4000/10700/577bd1ae</trace></auth></remote>
    )
  end

  def successful_capture_response
    %(
    <remote><auth><status>A</status><code>926914</code><message>Authorised</message><tranref>017235426182</tranref><cvv>Y</cvv><avs>X</avs><trace>4000/26913/577531b6</trace></auth></remote>
    )
  end

  def failed_capture_response
    %(
    <remote><auth><status>E</status><code>22</code><message>Invalid transaction reference</message><tranref>000000000000</tranref><cvv>X</cvv><avs>X</avs><trace>4000/10724/577bd1cc</trace></auth></remote>
    )
  end

  def successful_void_response
    %(
    <remote><auth><status>A</status><code>923928</code><message>Processed</message><tranref>017319276183</tranref><cvv>Y</cvv><avs>X</avs><trace>4001/23927/5776b2e2</trace></auth></remote>
    )
  end

  def failed_void_response
    %(
    <remote><auth><status>E</status><code>05</code><message>Transaction cost or currency not valid</message><tranref>000000000000</tranref><cvv>X</cvv><avs>X</avs><trace>4000/10757/577bd1fb</trace></auth></remote>
    )
  end

  def successful_refund_response
    %(
    <remote><auth><status>A</status><code>927615</code><message>Accepted</message><tranref>029895196182</tranref><cvv>Y</cvv><avs>X</avs><trace>4000/27614/577533d0</trace></auth></remote>
    )
  end

  def failed_refund_response
    %(
    <remote><auth><status>E</status><code>05</code><message>Transaction cost or currency not valid</message><tranref>000000000000</tranref><cvv>X</cvv><avs>X</avs><trace>4000/10779/577bd219</trace></auth></remote>
    )
  end

  def successful_reference_purchase_response
    %(
    <remote><auth><status>A</status><code>930196</code><message>Authorised</message><tranref>017855576193</tranref><cvv>Y</cvv><avs>X</avs><trace>4000/30195/5783aee5</trace></auth></remote>
    )
  end

  def transcript
    %q(
    opening connection to secure.telr.com:443...
    opened
    starting SSL for secure.telr.com:443...
    SSL established
    <- "POST /gateway/remote.xml HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: secure.telr.com\r\nContent-Length: 864\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<remote>\n  <store>16715</store>\n  <key>WZV7W#gbMVw^kSBk</key>\n  <tran>\n    <type>sale</type>\n    <amount>1.00</amount>\n    <currency>USD</currency>\n    <cartid>eb82363979530f39ef983a9edbe99611</cartid>\n    <class>moto</class>\n    <description>Test transaction</description>\n    <test>1</test>\n  </tran>\n  <card>\n    <number>5105105105105100</number>\n    <cvv>123</cvv>\n    <expiry>\n      <month>09</month>\n      <year>17</year>\n    </expiry>\n  </card>\n  <billing>\n    <name>\n      <first>Longbob</first>\n      <last>Longsen</last>\n    </name>\n    <email>email@address.com</email>\n    <ip>107.15.245.37</ip>\n    <address>\n      <country>CA</country>\n      <region>ON</region>\n      <line1>456 My Street</line1>\n      <line2>Apt 1</line2>\n      <city>Ottawa</city>\n      <zip>K1C2N6</zip>\n    </address>\n  </billing>\n</remote>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Tue, 05 Jul 2016 15:39:29 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Expires: -1\r\n"
    -> "Cache-Control: no-cache\r\n"
    -> "CacheControl: no-cache\r\n"
    -> "Pragma: no-cache\r\n"
    -> "Content-Length: 226\r\n"
    -> "Content-Type: text/xml;charset=UTF-8\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 226 bytes...
    -> ""
    -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<remote><auth><status>A</status><code>911424</code><message>Authorised</message><tranref>017562546187</tranref><cvv>Y</cvv><avs>X</avs><trace>4000/11423/577bd4ae</trace></auth></remote>\n\n"
    read 226 bytes
    Conn close
    )
  end

  def scrubbed_transcript
    %q(
    opening connection to secure.telr.com:443...
    opened
    starting SSL for secure.telr.com:443...
    SSL established
    <- "POST /gateway/remote.xml HTTP/1.1\r\nContent-Type: text/xml\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: secure.telr.com\r\nContent-Length: 864\r\n\r\n"
    <- "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<remote>\n  <store>16715</store>\n  <key>[FILTERED]</key>\n  <tran>\n    <type>sale</type>\n    <amount>1.00</amount>\n    <currency>USD</currency>\n    <cartid>eb82363979530f39ef983a9edbe99611</cartid>\n    <class>moto</class>\n    <description>Test transaction</description>\n    <test>1</test>\n  </tran>\n  <card>\n    <number>[FILTERED]</number>\n    <cvv>[FILTERED]</cvv>\n    <expiry>\n      <month>09</month>\n      <year>17</year>\n    </expiry>\n  </card>\n  <billing>\n    <name>\n      <first>Longbob</first>\n      <last>Longsen</last>\n    </name>\n    <email>email@address.com</email>\n    <ip>107.15.245.37</ip>\n    <address>\n      <country>CA</country>\n      <region>ON</region>\n      <line1>456 My Street</line1>\n      <line2>Apt 1</line2>\n      <city>Ottawa</city>\n      <zip>K1C2N6</zip>\n    </address>\n  </billing>\n</remote>\n"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Tue, 05 Jul 2016 15:39:29 GMT\r\n"
    -> "Server: Apache\r\n"
    -> "Expires: -1\r\n"
    -> "Cache-Control: no-cache\r\n"
    -> "CacheControl: no-cache\r\n"
    -> "Pragma: no-cache\r\n"
    -> "Content-Length: 226\r\n"
    -> "Content-Type: text/xml;charset=UTF-8\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 226 bytes...
    -> ""
    -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<remote><auth><status>A</status><code>911424</code><message>Authorised</message><tranref>017562546187</tranref><cvv>[FILTERED]</cvv><avs>X</avs><trace>4000/11423/577bd4ae</trace></auth></remote>\n\n"
    read 226 bytes
    Conn close
    )
  end
end
