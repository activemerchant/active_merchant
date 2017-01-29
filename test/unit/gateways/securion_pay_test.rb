require 'test_helper'

class SecurionPayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = SecurionPayGateway.new(
      secret_key: 'pr_test_SyMyCpIJosFIAESEsZUd3TgN',
    )

    @credit_card = credit_card
    @declined_card = credit_card('4916018475814056')
    @new_credit_card = credit_card('4012888888881881')
    @amount = 2000
    @refund_amount = 300

    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_store
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway.expects(:ssl_post).returns(successful_new_customer_response)
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_match %r(^cust_\w+$), response.authorization
    assert_equal "customer", response.params["objectType"]
    assert_match %r(^card_\w+$), response.params["cards"][0]["id"]
    assert_equal "card", response.params["cards"][0]["objectType"]

    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    @gateway.expects(:ssl_post).returns(successful_void_response)

    @options[:customer_id] = response.authorization
    response = @gateway.store(@new_credit_card, @options)
    assert_success response
    assert_match %r(^card_\w+$), response.params["card"]["id"]
    assert_equal @options[:customer_id], response.params["card"]["customerId"]

    @gateway.expects(:ssl_request).returns(successful_customer_update_response)

    response = @gateway.customer(@options)
    assert_success response
    assert_equal @options[:customer_id], response.params["id"]
    assert_equal "401288", response.params["cards"][0]["first6"]
    assert_equal "1881", response.params["cards"][0]["last4"]
    assert_equal "424242", response.params["cards"][1]["first6"]
    assert_equal "4242", response.params["cards"][1]["last4"]
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'char_J10t4hOZCHGO2izfJPKLM9W5', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, "tok_xxx")
    end.check_request do |method, endpoint, data, headers|
      assert_match(/card=tok_xxx/, data)
      refute_match(/card\[number\]/, data)
    end.respond_with(successful_purchase_response)

    assert response
    assert_instance_of Response, response
    assert_success response
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/^Invalid response received from the SecurionPay API/, response.message)
  end

  def test_client_data_submitted_with_purchase
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({ description: "test charge", ip: "127.127.127.127", user_agent: "browser XXX", referrer: "http://www.foobar.com", email: "foo@bar.com" })
      @gateway.purchase(@amount,@credit_card,updated_options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/description=test\+charge/, data)
      assert_match(/ip=127\.127\.127\.127/, data)
      assert_match(/user_agent=browser\+XXX/, data)
      assert_match(/referrer=http\%3A\%2F\%2Fwww\.foobar\.com/, data)
      assert_match(/metadata\[email\]=foo\%40bar\.com/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_client_data_submitted_with_purchase_without_email_or_order
    stub_comms(@gateway, :ssl_request) do
      updated_options = @options.merge({ description: "test charge", ip: "127.127.127.127", user_agent: "browser XXX", referrer: "http://www.foobar.com" })
      @gateway.purchase(@amount,@credit_card,updated_options)
    end.check_request do |method, endpoint, data, headers|
      assert_match(/description=test\+charge/, data)
      assert_match(/ip=127\.127\.127\.127/, data)
      assert_match(/user_agent=browser\+XXX/, data)
      assert_match(/referrer=http\%3A\%2F\%2Fwww\.foobar\.com/, data)
      refute data.include?('metadata')
    end.respond_with(successful_purchase_response)
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'char_hWKC9C5wkXuiTLsxdHzncea3', response.authorization
    assert response.test?
  end

  def test_add_address
    post = { card: { } }
    @gateway.send(:add_address, post, @options)
    assert_equal @options[:billing_address][:zip], post[:card][:addressZip]
    assert_equal @options[:billing_address][:state], post[:card][:addressState]
    assert_equal @options[:billing_address][:address1], post[:card][:addressLine1]
    assert_equal @options[:billing_address][:address2], post[:card][:addressLine2]
    assert_equal @options[:billing_address][:country], post[:card][:addressCountry]
    assert_equal @options[:billing_address][:city], post[:card][:addressCity]
  end

  def test_ensure_does_not_respond_to_credit
    assert !@gateway.respond_to?(:credit)
  end

  def test_address_is_included_with_card_data
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert data =~ /card\[addressLine1\]/
    end.respond_with(successful_purchase_response)
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
    assert_nil response.authorization
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    assert_equal 'char_hWKC9C5wkXuiTLsxdHzncea3', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, "char_CqH9rftszMnaMYBrgtVI49LM", @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, "invalid_authorization_token", @options)
    assert_failure response
    assert_match(/^Requested Charge does not exist/, response.message)
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_full_refund
    @gateway.expects(:ssl_request).returns(successful_full_refund_response)

    response = @gateway.refund(@amount, 'char_DQca5ZjbewP2Oe0lIsNe4EXP', @options)
    assert_instance_of Response, response
    assert_success response
    assert response.params["refunded"]
    assert_equal 0, response.params["amount"]
    assert_equal 1, response.params["refunds"].size
    assert_equal @amount, response.params["refunds"].map{|r| r["amount"]}.sum
    assert_equal 'char_DQca5ZjbewP2Oe0lIsNe4EXP', response.authorization
    assert response.test?
  end

  def test_successful_partially_refund
    @gateway.expects(:ssl_request).returns(successful_partially_refund_response)

    response = @gateway.refund(@refund_amount, 'char_oVnJ1j6fZqOvnopBBvlnpEuX', @options)
    assert_instance_of Response, response
    assert_success response
    assert response.params["refunded"]
    assert_equal @amount - @refund_amount, response.params["amount"]
    assert_equal @refund_amount, response.params["refunds"].map{|r| r["amount"]}.sum
    assert_equal 'char_oVnJ1j6fZqOvnopBBvlnpEuX', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@refund_amount + 1, 'char_oVnJ1j6fZqOvnopBBvlnpEuX', @options)
    assert_failure response
    assert_match(/^Wrong Refund data/, response.message)
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_authorize_refund
    @gateway.expects(:ssl_request).returns(failed_authorize_refund_response)

    response = @gateway.refund(@refund_amount, 'invalid_authorization_token', @options)
    assert_failure response
    assert_match(/^Requested Charge does not exist/, response.message)
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('char_yDS2wtcTFZSWOWGaANjpchVb')
    assert_success response
  end

  def test_failed_authorization_void
    @gateway.expects(:ssl_request).returns(failed_authorization_void_response)

    response = @gateway.void('invalid_authorization_token', @options)
    assert_failure response
    assert_equal "Requested Charge does not exist", response.message
    assert_nil response.authorization
  end

  def test_successful_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, successful_void_response)
    assert_success response
  end

  def test_successful_verify_with_failed_void
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_authorize_response, failed_void_response)
    assert_success response
    assert_equal "Transaction approved", response.message
  end

  def test_failed_verify
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@declined_card, @options)
    end.respond_with(failed_authorize_response, successful_void_response)
    assert_failure response
    assert_equal "The card was declined for other reason.", response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
  end

  def test_declined_request
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response

    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert_equal 'char_mApucpvVbCJgo7x09Je4n9gC', response.params['error']['chargeId']
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.securionpay.com:443...
      opened
      starting SSL for api.securionpay.com:443...
      SSL established
      <- "POST /charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic cHJfdGVzdF9xWk40VlZJS0N5U2ZDZVhDQm9ITzlEQmU6\r\nUser-Agent: SecurionPay/v1 ActiveMerchantBindings/1.47.0\r\nAccept-Encoding: gzip;q=0,deflate;q=0.6\r\nAccept: */*\r\nConnection: close\r\nHost: api.securionpay.com\r\nContent-Length: 214\r\n\r\n"
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
      opening connection to api.securionpay.com:443...
      opened
      starting SSL for api.securionpay.com:443...
      SSL established
      <- "POST /charges HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: SecurionPay/v1 ActiveMerchantBindings/1.47.0\r\nAccept-Encoding: gzip;q=0,deflate;q=0.6\r\nAccept: */*\r\nConnection: close\r\nHost: api.securionpay.com\r\nContent-Length: 214\r\n\r\n"
      <- "amount=2000&currency=usd&card[number]=[FILTERED]&card[expMonth]=9&card[expYear]=2016&card[cvc]=[FILTERED]&card[cardholderName]=Longbob+Longsen&description=ActiveMerchant+test+charge&metadata[email]=foo%40example.com"
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

  def successful_purchase_response
    <<-RESPONSE
    {
      "id" : "char_J10t4hOZCHGO2izfJPKLM9W5",
      "created" : 1426583959,
      "objectType" : "charge",
      "amount" : 2000,
      "currency" : "USD",
      "card" : {
        "id" : "card_Pd9TxYGGFYKmqJlugewRotP1",
        "created" : 1426583959,
        "objectType" : "card",
        "first6" : "401200",
        "last4" : "0007",
        "expMonth" : "11",
        "expYear" : "2022",
        "brand" : "Visa",
        "type" : "Credit Card"
      },
      "captured" : true,
      "refunded" : false,
      "disputed" : false
    }
    RESPONSE
  end

  def invalid_json_response
    <<-RESPONSE
    {
       foo : bar
    }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
    {
      "error" : {
        "type" : "card_error",
        "code" : "invalid_number",
        "message" : "The card number is not a valid credit card number."
      }
    }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
    {
      "id" : "char_hWKC9C5wkXuiTLsxdHzncea3",
      "created" : 1426624786,
      "objectType" : "charge",
      "amount" : 2000,
      "currency" : "USD",
      "card" : {
        "id" : "card_vLk7wLtaWAiqsnnYL9xlcf6W",
        "created" : 1426624786,
        "objectType" : "card",
        "first6" : "401200",
        "last4" : "0007",
        "expMonth" : "11",
        "expYear" : "2022",
        "brand" : "Visa",
        "type" : "Credit Card",
        "customerId" : "cust_OWTybrAX3JP4Bbv1xnkpnHEj"
      },
      "captured" : false,
      "refunded" : false,
      "disputed" : false
    }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
    {
      "error" : {
        "type" : "card_error",
        "code" : "card_declined",
        "message" : "The card was declined for other reason.",
        "chargeId" : "char_mApucpvVbCJgo7x09Je4n9gC"
      }
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "id" : "char_CqH9rftszMnaMYBrgtVI49LM",
      "created" : 1426626399,
      "objectType" : "charge",
      "amount" : 2000,
      "currency" : "USD",
      "description" : "ActiveMerchant test charge",
      "card" : {
        "id" : "card_UpPL1PYsy28Mn8QzWe6gR90x",
        "created" : 1426626399,
        "objectType" : "card",
        "first6" : "424242",
        "last4" : "4242",
        "expMonth" : "9",
        "expYear" : "2016",
        "brand" : "Visa",
        "type" : "Credit Card"
      },
      "captured" : true,
      "refunded" : false,
      "disputed" : false,
      "metadata" : {
        "email" : "foo@example.com"
      }
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
      "error" : {
        "type" : "invalid_request",
        "message" : "Requested Charge does not exist"
      }
    }
    RESPONSE
  end

  def successful_full_refund_response
    <<-RESPONSE
    {
      "id" : "char_DQca5ZjbewP2Oe0lIsNe4EXP",
      "created" : 1426673886,
      "objectType" : "charge",
      "amount" : 0,
      "currency" : "USD",
      "description" : "ActiveMerchant test charge",
      "card" : {
        "id" : "card_d62RqD9jGvcyFSmsGaDEpTic",
        "created" : 1426673886,
        "objectType" : "card",
        "first6" : "424242",
        "last4" : "4242",
        "expMonth" : "9",
        "expYear" : "2016",
        "brand" : "Visa",
        "type" : "Credit Card"
      },
      "captured" : true,
      "refunded" : true,
      "refunds" : [ {
        "created" : 1426675529990,
        "amount" : 2000,
        "currency" : "USD"
      } ],
      "disputed" : false,
      "metadata" : {
        "email" : "foo@example.com"
      }
    }
    RESPONSE
  end

  def successful_partially_refund_response
    <<-RESPONSE
    {
      "id" : "char_oVnJ1j6fZqOvnopBBvlnpEuX",
      "created" : 1426673886,
      "objectType" : "charge",
      "amount" : 1700,
      "currency" : "USD",
      "description" : "ActiveMerchant test charge",
      "card" : {
        "id" : "card_psNTJq6c32PcZNGuztJ6mJGu",
        "created" : 1426673886,
        "objectType" : "card",
        "first6" : "424242",
        "last4" : "4242",
        "expMonth" : "9",
        "expYear" : "2016",
        "brand" : "Visa",
        "type" : "Credit Card"
      },
      "captured" : true,
      "refunded" : true,
      "refunds" : [ {
        "created" : 1426680168474,
        "amount" : 300,
        "currency" : "USD"
      } ],
      "disputed" : false,
      "metadata" : {
        "email" : "foo@example.com"
      }
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
      "error" : {
        "type" : "invalid_request",
        "message" : "Wrong Refund data"
      }
    }
    RESPONSE
  end

  def failed_authorize_refund_response
    <<-RESPONSE
    {
      "error" : {
        "type" : "invalid_request",
        "message" : "Requested Charge does not exist"
      }
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
      "id" : "char_yDS2wtcTFZSWOWGaANjpchVb",
      "created" : 1426682831,
      "objectType" : "charge",
      "amount" : 0,
      "currency" : "USD",
      "description" : "ActiveMerchant test charge",
      "card" : {
        "id" : "card_0mMgPMnlw2vaiwez5WkDarqv",
        "created" : 1426682831,
        "objectType" : "card",
        "first6" : "424242",
        "last4" : "4242",
        "expMonth" : "9",
        "expYear" : "2016",
        "brand" : "Visa",
        "type" : "Credit Card",
        "customerId" : "cust_OWTybrAX3JP4Bbv1xnkpnHEj"
      },
      "captured" : true,
      "refunded" : true,
      "refunds" : [ {
        "created" : 1426683310391,
        "amount" : 2000,
        "currency" : "USD"
      } ],
      "disputed" : false,
      "metadata" : {
        "email" : "foo@example.com"
      }
    }
    RESPONSE
  end

  def failed_authorization_void_response
    <<-RESPONSE
    {
      "error" : {
        "type" : "invalid_request",
        "message" : "Requested Charge does not exist"
      }
    }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
    {
      "error" : {
        "type" : "card_error",
        "code" : "card_declined",
        "message" : "The card was declined for other reason.",
        "chargeId" : "char_2OLS47AyzcHSy5ssRx8wdBEq"
      }
    }
    RESPONSE
  end

  def successful_new_customer_response
    <<-RESPONSE
    {
      "id" : "cust_OWTybrAX3JP4Bbv1xnkpnHEj",
      "created" : 1426706773,
      "objectType" : "customer",
      "email" : "r@r.pl",
      "defaultCardId" : "card_e2M5PpMhzGwpdSs6Nopu54Ny",
      "cards" : [ {
        "id" : "card_e2M5PpMhzGwpdSs6Nopu54Ny",
        "created" : 1426706773,
        "objectType" : "card",
        "first6" : "401288",
        "last4" : "1881",
        "expMonth" : "11",
        "expYear" : "2022",
        "cardholderName" : "Tobias Luetke",
        "customerId" : "cust_OWTybrAX3JP4Bbv1xnkpnHEj",
        "brand" : "Visa",
        "type" : "Credit Card"
      } ],
      "metadata" : {
        "chargeId" : "char_hWKC9C5wkXuiTLsxdHzncea3"
      }
    }
    RESPONSE
  end

  def successful_new_card_response
    <<-RESPONSE
    {
      "id" : "cust_QwQdf2Y1fjCFKrchTtSmwpUM",
      "created" : 1426756430,
      "objectType" : "customer",
      "email" : "r@r.pl",
      "defaultCardId" : "card_Yu7rzoGnhD1YWeo0UmtQVPEL",
      "cards" : [ {
        "id" : "card_gF90YA1KO56BSjkyQmCGfjO5",
        "created" : 1426756429,
        "objectType" : "card",
        "first6" : "401288",
        "last4" : "1881",
        "expMonth" : "11",
        "expYear" : "2022",
        "cardholderName" : "Tobias Luetke",
        "customerId" : "cust_QwQdf2Y1fjCFKrchTtSmwpUM",
        "brand" : "Visa",
        "type" : "Credit Card"
      }, {
        "id" : "card_Yu7rzoGnhD1YWeo0UmtQVPEL",
        "created" : 1426759288,
        "objectType" : "card",
        "first6" : "401200",
        "last4" : "0007",
        "expMonth" : "11",
        "expYear" : "2022",
        "cardholderName" : "Tobias Luetke",
        "customerId" : "cust_QwQdf2Y1fjCFKrchTtSmwpUM",
        "brand" : "Visa",
        "type" : "Credit Card"
      } ]
    }
    RESPONSE
  end

  def successful_customer_update_response
    <<-RESPONSE
    {
      "id" : "cust_OWTybrAX3JP4Bbv1xnkpnHEj",
      "created" : 1426756430,
      "objectType" : "customer",
      "email" : "test@email.pl",
      "description" : "Test Description",
      "defaultCardId" : "card_9k3THkOkmz8OQpJejlaZGizB",
      "cards" : [ {
        "id" : "card_9k3THkOkmz8OQpJejlaZGizB",
        "created" : 1426759508,
        "objectType" : "card",
        "first6" : "401288",
        "last4" : "1881",
        "expMonth" : "11",
        "expYear" : "2022",
        "cardholderName" : "Tobias Luetke",
        "customerId" : "cust_OWTybrAX3JP4Bbv1xnkpnHEj",
        "brand" : "Visa",
        "type" : "Credit Card"
      }, {
        "id" : "card_gF90YA1KO56BSjkyQmCGfjO5",
        "created" : 1426756429,
        "objectType" : "card",
        "first6" : "424242",
        "last4" : "4242",
        "expMonth" : "11",
        "expYear" : "2022",
        "cardholderName" : "Tobias Luetke",
        "customerId" : "cust_OWTybrAX3JP4Bbv1xnkpnHEj",
        "brand" : "Visa",
        "type" : "Credit Card"
      } ]
    }
    RESPONSE
  end

  def successful_change_default_card_response
    <<-RESPONSE
    {
      "id" : "cust_QwQdf2Y1fjCFKrchTtSmwpUM",
      "created" : 1426756430,
      "objectType" : "customer",
      "email" : "test@email.pl",
      "description" : "Test Description",
      "defaultCardId" : "card_gF90YA1KO56BSjkyQmCGfjO5",
      "cards" : [ {
        "id" : "card_9k3THkOkmz8OQpJejlaZGizB",
        "created" : 1426759508,
        "objectType" : "card",
        "first6" : "401200",
        "last4" : "0007",
        "expMonth" : "11",
        "expYear" : "2022",
        "cardholderName" : "Tobias Luetke",
        "customerId" : "cust_QwQdf2Y1fjCFKrchTtSmwpUM",
        "brand" : "Visa",
        "type" : "Credit Card"
      }, {
        "id" : "card_gF90YA1KO56BSjkyQmCGfjO5",
        "created" : 1426756429,
        "objectType" : "card",
        "first6" : "401288",
        "last4" : "1881",
        "expMonth" : "11",
        "expYear" : "2022",
        "cardholderName" : "Tobias Luetke",
        "customerId" : "cust_QwQdf2Y1fjCFKrchTtSmwpUM",
        "brand" : "Visa",
        "type" : "Credit Card"
      } ]
    }
    RESPONSE
  end
end
