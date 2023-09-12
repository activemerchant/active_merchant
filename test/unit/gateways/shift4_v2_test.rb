require 'test_helper'
require_relative 'securion_pay_test'

class Shift4V2Test < SecurionPayTest
  include CommStub

  def setup
    super
    @gateway = Shift4V2Gateway.new(
      secret_key: 'pr_test_random_key'
    )
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/^Invalid response received from the Shift4 V2 API/, response.message)
  end

  def test_ensure_does_not_respond_to_credit; end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.shift4.com:443...
      opened
      starting SSL for api.shift4.com:443...
      SSL established
      <- "POST /charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic cHJfdGVzdF9xWk40VlZJS0N5U2ZDZVhDQm9ITzlEQmU6\r\nUser-Agent: SecurionPay/v1 ActiveMerchantBindings/1.47.0\r\nAccept-Encoding: gzip;q=0,deflate;q=0.6\r\nAccept: */*\r\nConnection: close\r\nHost: api.shift4.com\r\nContent-Length: 214\r\n\r\n"
      <- "amount=2000&currency=usd&card[number]=4242424242424242&card[expMonth]=9&card[expYear]=2016&card[cvc]=123&card[cardholderName]=Longbob+Longsen&description=ActiveMerchant+test+charge&metadata[email]=foo%40example.com"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: cloudflare-nginx\r\n"
      -> "Date: Fri, 12 Jun 2015 21:36:39 GMT\r\n"
      -> "Content-Type: application/json;charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=d5da73266c61acce6307176d45e2672b41434144998; expires=Sat, 11-Jun-16 21:36:38 GMT; path=/; domain=.securionpay.com; HttpOnly\r\n"
      -> "CF-RAY: 1f58b1414ca00af6-WAW\r\n"
      -> "\r\n"
      -> "1f4\r\n"
      reading 500 bytes...
      -> "{\"id\":\"char_TOnen0ZcDMYzECNS4fItK9P4\",\"created\":1434144998,\"objectType\":\"charge\",\"amount\":2000,\"currency\":\"USD\",\"description\":\"ActiveMerchant test charge\",\"card\":{\"id\":\"card_yJ4JNcp6P4sG8UrtZ62VWb5e\",\"created\":1434144998,\"objectType\":\"card\",\"first6\":\"424242\",\"last4\":\"4242\",\"fingerprint\":\"ecAKhFD1dmDAMKD9\",\"expMonth\":\"9\",\"expYear\":\"2016\",\"cardholderName\":\"Longbob Longsen\",\"brand\":\"Visa\",\"type\":\"Credit Card\"},\"captured\":true,\"refunded\":false,\"disputed\":false,\"metadata\":{\"email\":\"foo@example.com\"}}"
      read 500 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api.shift4.com:443...
      opened
      starting SSL for api.shift4.com:443...
      SSL established
      <- "POST /charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: SecurionPay/v1 ActiveMerchantBindings/1.47.0\r\nAccept-Encoding: gzip;q=0,deflate;q=0.6\r\nAccept: */*\r\nConnection: close\r\nHost: api.shift4.com\r\nContent-Length: 214\r\n\r\n"
      <- "amount=2000&currency=usd&card[number]=[FILTERED]&card[expMonth]=[FILTERED]&card[expYear]=[FILTERED]&card[cvc]=[FILTERED]&card[cardholderName]=[FILTERED]&description=ActiveMerchant+test+charge&metadata[email]=foo%40example.com"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: cloudflare-nginx\r\n"
      -> "Date: Fri, 12 Jun 2015 21:36:39 GMT\r\n"
      -> "Content-Type: application/json;charset=UTF-8\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: __cfduid=d5da73266c61acce6307176d45e2672b41434144998; expires=Sat, 11-Jun-16 21:36:38 GMT; path=/; domain=.securionpay.com; HttpOnly\r\n"
      -> "CF-RAY: 1f58b1414ca00af6-WAW\r\n"
      -> "\r\n"
      -> "1f4\r\n"
      reading 500 bytes...
      -> "{\"id\":\"char_TOnen0ZcDMYzECNS4fItK9P4\",\"created\":1434144998,\"objectType\":\"charge\",\"amount\":2000,\"currency\":\"USD\",\"description\":\"ActiveMerchant test charge\",\"card\":{\"id\":\"card_yJ4JNcp6P4sG8UrtZ62VWb5e\",\"created\":1434144998,\"objectType\":\"card\",\"first6\":\"424242\",\"last4\":\"4242\",\"fingerprint\":\"ecAKhFD1dmDAMKD9\",\"expMonth\":\"9\",\"expYear\":\"2016\",\"cardholderName\":\"Longbob Longsen\",\"brand\":\"Visa\",\"type\":\"Credit Card\"},\"captured\":true,\"refunded\":false,\"disputed\":false,\"metadata\":{\"email\":\"foo@example.com\"}}"
      read 500 bytes
      reading 2 bytes...
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    POST_SCRUBBED
  end
end
