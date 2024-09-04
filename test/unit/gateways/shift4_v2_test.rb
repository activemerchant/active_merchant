require 'test_helper'
require_relative 'securion_pay_test'

class Shift4V2Test < SecurionPayTest
  include CommStub

  def setup
    super
    @gateway = Shift4V2Gateway.new(
      secret_key: 'pr_test_random_key'
    )
    @check = check
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/^Invalid response received from the Shift4 V2 API/, response.message)
  end

  def test_amount_gets_upcased_if_needed
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      assert_equal 'USD', CGI.parse(data)['currency'].first
    end.respond_with(successful_purchase_response)
  end

  def test_successful_store_and_unstore
    @gateway.expects(:ssl_post).returns(successful_new_customer_response)

    store = @gateway.store(@credit_card, @options)
    assert_success store
    @gateway.expects(:ssl_request).returns(successful_unstore_response)
    unstore = @gateway.unstore('card_YhkJQlyF6NEc9RexV5dlZqTl', customer_id: 'cust_KDDJGACwxCUYkUb3fI76ERB7')
    assert_success unstore
  end

  def test_successful_unstore
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.unstore('card_YhkJQlyF6NEc9RexV5dlZqTl', customer_id: 'cust_KDDJGACwxCUYkUb3fI76ERB7')
    end.check_request do |_endpoint, data, _headers|
      assert_match(/cards/, data)
    end.respond_with(successful_unstore_response)
    assert response.success?
    assert_equal response.message, 'Transaction approved'
  end

  def test_purchase_with_bank_account
    stub_comms do
      @gateway.purchase(@amount, @check, @options)
    end.check_request(skip_response: true) do |_endpoint, data, _headers|
      request = CGI.parse(data)
      assert_equal request['paymentMethod[type]'].first, 'ach'
      assert_equal request['paymentMethod[billing][name]'].first, 'Jim Smith'
      assert_equal request['paymentMethod[billing][address][country]'].first, 'CA'
      assert_equal request['paymentMethod[ach][account][routingNumber]'].first, '244183602'
      assert_equal request['paymentMethod[ach][account][accountNumber]'].first, '15378535'
      assert_equal request['paymentMethod[ach][account][accountType]'].first, 'personal_checking'
      assert_equal request['paymentMethod[ach][verificationProvider]'].first, 'external'
    end
  end

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

  def successful_unstore_response
    <<-RESPONSE
      {
        "id" : "card_G9xcxTDcjErIijO19SEWskN6"
      }
    RESPONSE
  end
end
