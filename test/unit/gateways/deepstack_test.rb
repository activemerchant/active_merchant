require 'test_helper'

class DeepstackTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    @gateway = DeepstackGateway.new(fixtures(:deepstack))
    @credit_card = credit_card
    @amount = 100

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
      number: '4111111111111111',
      verification_value: '999',
      month: '01',
      year: '2029',
      first_name: 'Bob',
      last_name: 'Bobby'
    )

    address = {
      address1: '123 Some st',
      address2: '',
      first_name: 'Bob',
      last_name: 'Bobberson',
      city: 'Some City',
      state: 'CA',
      zip: '12345',
      country: 'USA',
      email: 'test@test.com'
    }

    shipping_address = {
      address1: '321 Some st',
      address2: '#9',
      first_name: 'Jane',
      last_name: 'Doe',
      city: 'Other City',
      state: 'CA',
      zip: '12345',
      country: 'USA',
      phone: '1231231234',
      email: 'test@test.com'
    }

    @options = {
      order_id: '1',
      billing_address: address,
      shipping_address: shipping_address,
      description: 'Store Purchase'
    }
  end

  def test_successful_token
    @gateway.expects(:ssl_post).returns(successful_token_response)
    response = @gateway.get_token(@credit_card, @options)
    assert_success response
  end

  def test_failed_token
    @gateway.expects(:ssl_post).returns(failed_token_response)
    response = @gateway.get_token(@credit_card, @options)
    assert_failure response
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'ch_IoSx345fOU6SP67MRXgqWw', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'ch_vfndMRFdEUac0SnBNAAT6g', response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_failure response
    assert_not_equal 'Approved', response.message
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response

    @gateway.expects(:ssl_post).returns(successful_capture_response)
    response = @gateway.capture(@amount, response.authorization)
    assert_success response
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)
    response = @gateway.capture(@amount, '')

    assert_failure response
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response

    @gateway.expects(:ssl_post).returns(successful_refund_response)
    response = @gateway.refund(@amount, response.authorization)
    assert_success response
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)
    response = @gateway.refund(@amount, '')

    assert_failure response
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_authorize_response)
    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response

    @gateway.expects(:ssl_post).returns(successful_void_response)
    response = @gateway.void(@amount, response.authorization)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    response = @gateway.void(@amount, '')

    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response)
    response = @gateway.verify(@credit_card, @options)

    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_authorize_response)
    response = @gateway.verify(@credit_card, @options)

    assert_failure response
    assert_match %r{Invalid Request: Card number is invalid.}, response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    '
    opening connection to api.sandbox.deepstack.io:443...
    opened
    starting SSL for api.sandbox.deepstack.io:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
    I, [2023-07-25T08:47:29.985581 #86287]  INFO -- : [ActiveMerchant::Billing::DeepstackGateway] connection_ssl_version=TLSv1.2 connection_ssl_cipher=ECDHE-RSA-AES128-GCM-SHA256
    D, [2023-07-25T08:47:29.985687 #86287] DEBUG -- : {"source":{"type":"credit_card","credit_card":{"account_number":"4111111111111111","cvv":"999","expiration":"0129","customer_id":""},"billing_contact":{"first_name":"Bob","last_name":"Bobberson","phone":"1231231234","address":{"line_1":"123 Some st","line_2":"","city":"Some City","state":"CA","postal_code":"12345","country_code":"USA"}}},"transaction":{"amount":100,"cof_type":"UNSCHEDULED_CARDHOLDER","capture":false,"currency_code":"USD","avs":true,"save_payment_instrument":false},"meta":{"shipping_info":{"first_name":"Jane","last_name":"Doe","phone":"1231231234","email":"test@test.com","address":{"line_1":"321 Some st","line_2":"#9","city":"Other City","state":"CA","postal_code":"12345","country_code":"USA"}},"client_transaction_id":"1","client_transaction_description":"Store Purchase"}}
    <- "POST /api/v1/payments/charge HTTP/1.1\r\nContent-Type: application/json\r\nAccept: text/plain\r\nHmac: YWZhMjVkZWEtNThlMy00ZGEwLWE1MWUtYmI2ZGNhOTQ5YzkwfFBPU1R8MjAyMy0wNy0yNVQxNTo0NzoyOC43NzZafDIwMmIwZDJjLTdhZWMtNDk2Yy1hMTBlLWQ3ZDUzYTRhNTAzZHxpQmxXTFNNNFdjSjFkSGdlczJYb2JqWUpMVUlGM2tkeUg2b1RFbWtFRUVFPQ==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: api.sandbox.deepstack.io\r\nContent-Length: 799\r\n\r\n"
    <- "{\"source\":{\"type\":\"credit_card\",\"credit_card\":{\"account_number\":\"4111111111111111\",\"cvv\":\"999\",\"expiration\":\"0129\",\"customer_id\":\"\"},\"billing_contact\":{\"first_name\":\"Bob\",\"last_name\":\"Bobberson\",\"phone\":\"1231231234\",\"address\":{\"line_1\":\"123 Some st\",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"}}},\"transaction\":{\"amount\":100,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"capture\":false,\"currency_code\":\"USD\",\"avs\":true,\"save_payment_instrument\":false},\"meta\":{\"shipping_info\":{\"first_name\":\"Jane\",\"last_name\":\"Doe\",\"phone\":\"1231231234\",\"email\":\"test@test.com\",\"address\":{\"line_1\":\"321 Some st\",\"line_2\":\"#9\",\"city\":\"Other City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"}},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\"}}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Tue, 25 Jul 2023 15:47:30 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Content-Length: 1389\r\n"
    -> "Connection: close\r\n"
    -> "server: Kestrel\r\n"
    -> "apigw-requestid: IoI23jbrPHcESNQ=\r\n"
    -> "api-supported-versions: 1.0\r\n"
    -> "\r\n"
    reading 1389 bytes...
    -> "{\"id\":\"ch_gSuF1hGsU0CpPPAUs1dg-Q\",\"response_code\":\"00\",\"message\":\"Approved\",\"approved\":true,\"auth_code\":\"asdefr\",\"cvv_result\":\"Y\",\"avs_result\":\"Y\",\"source\":{\"id\":\"\",\"credit_card\":{\"account_number\":\"************1111\",\"expiration\":\"0129\",\"cvv\":\"999\",\"brand\":\"Visa\",\"last_four\":\"1111\"},\"type\":\"credit_card\",\"client_customer_id\":null,\"billing_contact\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":null}},\"amount\":100,\"captured\":false,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"currency_code\":\"USD\",\"country_code\":0,\"billing_info\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":null},\"shipping_info\":{\"first_name\":\"Jane\",\"last_name\":\"Doe\",\"address\":{\"line_1\":\"321 Some st\",\"line_2\":\"#9\",\"city\":\"Other City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\",\"client_invoice_id\":null,\"save_payment_instrument\":false,\"kount_score\":null,\"checks\":{\"address_line1_check\":\"pass\",\"address_postal_code_check\":\"pass\",\"cvc_check\":null},\"completed\":\"2023-07-25T15:47:30.183095Z\"}"
    read 1389 bytes
    Conn close
    '
  end

  def post_scrubbed
    '
    opening connection to api.sandbox.deepstack.io:443...
    opened
    starting SSL for api.sandbox.deepstack.io:443...
    SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
    I, [2023-07-25T08:47:29.985581 #86287]  INFO -- : [ActiveMerchant::Billing::DeepstackGateway] connection_ssl_version=TLSv1.2 connection_ssl_cipher=ECDHE-RSA-AES128-GCM-SHA256
    D, [2023-07-25T08:47:29.985687 #86287] DEBUG -- : {"source":{"type":"credit_card","credit_card":{"account_number":"4111111111111111","cvv":"999","expiration":"0129","customer_id":""},"billing_contact":{"first_name":"Bob","last_name":"Bobberson","phone":"1231231234","address":{"line_1":"123 Some st","line_2":"","city":"Some City","state":"CA","postal_code":"12345","country_code":"USA"}}},"transaction":{"amount":100,"cof_type":"UNSCHEDULED_CARDHOLDER","capture":false,"currency_code":"USD","avs":true,"save_payment_instrument":false},"meta":{"shipping_info":{"first_name":"Jane","last_name":"Doe","phone":"1231231234","email":"test@test.com","address":{"line_1":"321 Some st","line_2":"#9","city":"Other City","state":"CA","postal_code":"12345","country_code":"USA"}},"client_transaction_id":"1","client_transaction_description":"Store Purchase"}}
    <- "POST /api/v1/payments/charge HTTP/1.1\r\nContent-Type: application/json\r\nAccept: text/plain\r\nHmac: [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: api.sandbox.deepstack.io\r\nContent-Length: 799\r\n\r\n"
    <- "{\"source\":{\"type\":\"credit_card\",\"credit_card\":{\"account_number\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"expiration\":\"[FILTERED]\",\"customer_id\":\"\"},\"billing_contact\":{\"first_name\":\"Bob\",\"last_name\":\"Bobberson\",\"phone\":\"1231231234\",\"address\":{\"line_1\":\"123 Some st\",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"}}},\"transaction\":{\"amount\":100,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"capture\":false,\"currency_code\":\"USD\",\"avs\":true,\"save_payment_instrument\":false},\"meta\":{\"shipping_info\":{\"first_name\":\"Jane\",\"last_name\":\"Doe\",\"phone\":\"1231231234\",\"email\":\"test@test.com\",\"address\":{\"line_1\":\"321 Some st\",\"line_2\":\"#9\",\"city\":\"Other City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"}},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\"}}"
    -> "HTTP/1.1 200 OK\r\n"
    -> "Date: Tue, 25 Jul 2023 15:47:30 GMT\r\n"
    -> "Content-Type: application/json; charset=utf-8\r\n"
    -> "Content-Length: 1389\r\n"
    -> "Connection: close\r\n"
    -> "server: Kestrel\r\n"
    -> "apigw-requestid: IoI23jbrPHcESNQ=\r\n"
    -> "api-supported-versions: 1.0\r\n"
    -> "\r\n"
    reading 1389 bytes...
    -> "{\"id\":\"ch_gSuF1hGsU0CpPPAUs1dg-Q\",\"response_code\":\"00\",\"message\":\"Approved\",\"approved\":true,\"auth_code\":\"asdefr\",\"cvv_result\":\"Y\",\"avs_result\":\"Y\",\"source\":{\"id\":\"\",\"credit_card\":{\"account_number\":\"[FILTERED]\",\"expiration\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\",\"brand\":\"Visa\",\"last_four\":\"1111\"},\"type\":\"credit_card\",\"client_customer_id\":null,\"billing_contact\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":null}},\"amount\":100,\"captured\":false,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"currency_code\":\"USD\",\"country_code\":0,\"billing_info\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":null},\"shipping_info\":{\"first_name\":\"Jane\",\"last_name\":\"Doe\",\"address\":{\"line_1\":\"321 Some st\",\"line_2\":\"#9\",\"city\":\"Other City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\",\"client_invoice_id\":null,\"save_payment_instrument\":false,\"kount_score\":null,\"checks\":{\"address_line1_check\":\"pass\",\"address_postal_code_check\":\"pass\",\"cvc_check\":null},\"completed\":\"2023-07-25T15:47:30.183095Z\"}"
    read 1389 bytes
    Conn close
    '
  end

  def successful_purchase_response_2
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_deepstack_test.rb \
        -n test_successful_purchase
    )
  end

  def successful_purchase_response
    %({\"id\":\"ch_IoSx345fOU6SP67MRXgqWw\",\"response_code\":\"00\",\"message\":\"Approved\",\"approved\":true,\"auth_code\":\"asdefr\",\"cvv_result\":\"Y\",\"avs_result\":\"Y\",\"source\":{\"id\":\"\",\"credit_card\":{\"account_number\":\"************1111\",\"expiration\":\"0129\",\"cvv\":\"999\",\"brand\":\"Visa\",\"last_four\":\"1111\"},\"type\":\"credit_card\",\"client_customer_id\":null,\"billing_contact\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"}},\"amount\":100,\"captured\":true,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"currency_code\":\"USD\",\"country_code\":0,\"billing_info\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\",\"client_invoice_id\":null,\"save_payment_instrument\":false,\"kount_score\":null,\"checks\":{\"address_line1_check\":\"pass\",\"address_postal_code_check\":\"pass\",\"cvc_check\":null},\"completed\":\"2023-07-14T17:08:33.5004521Z\"})
  end

  def failed_purchase_response
    %({\"id\":\"ch_xbaPjifXN0Gum4vzdup6iA\",\"response_code\":\"03\",\"message\":\"Invalid Request: Card number is invalid.\",\"approved\":false,\"source\":{\"id\":\"\",\"credit_card\":{\"account_number\":\"************0051\",\"expiration\":\"0129\",\"cvv\":\"999\",\"brand\":\"MasterCard\",\"last_four\":\"0051\"},\"type\":\"credit_card\",\"client_customer_id\":null,\"billing_contact\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"}},\"amount\":100,\"captured\":false,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"currency_code\":\"USD\",\"country_code\":0,\"billing_info\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\",\"client_invoice_id\":null,\"save_payment_instrument\":false,\"kount_score\":null,\"checks\":{\"address_line1_check\":null,\"address_postal_code_check\":null,\"cvc_check\":null},\"completed\":\"2023-07-14T17:11:24.972201Z\"})
  end

  def successful_authorize_response
    %({\"id\":\"ch_vfndMRFdEUac0SnBNAAT6g\",\"response_code\":\"00\",\"message\":\"Approved\",\"approved\":true,\"auth_code\":\"asdefr\",\"cvv_result\":\"Y\",\"avs_result\":\"Y\",\"source\":{\"id\":\"\",\"credit_card\":{\"account_number\":\"************1111\",\"expiration\":\"0129\",\"cvv\":\"999\",\"brand\":\"Visa\",\"last_four\":\"1111\"},\"type\":\"credit_card\",\"client_customer_id\":null,\"billing_contact\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"}},\"amount\":100,\"captured\":false,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"currency_code\":\"USD\",\"country_code\":0,\"billing_info\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\",\"client_invoice_id\":null,\"save_payment_instrument\":false,\"kount_score\":null,\"checks\":{\"address_line1_check\":\"pass\",\"address_postal_code_check\":\"pass\",\"cvc_check\":null},\"completed\":\"2023-07-14T17:36:18.4817926Z\"})
  end

  def failed_authorize_response
    %({\"id\":\"ch_CBue2iT3pUibJ7QySysTrA\",\"response_code\":\"03\",\"message\":\"Invalid Request: Card number is invalid.\",\"approved\":false,\"source\":{\"id\":\"\",\"credit_card\":{\"account_number\":\"************0051\",\"expiration\":\"0129\",\"cvv\":\"999\",\"brand\":\"MasterCard\",\"last_four\":\"0051\"},\"type\":\"credit_card\",\"client_customer_id\":null,\"billing_contact\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"}},\"amount\":100,\"captured\":false,\"cof_type\":\"UNSCHEDULED_CARDHOLDER\",\"currency_code\":\"USD\",\"country_code\":0,\"billing_info\":{\"first_name\":\"Bob Bobberson\",\"last_name\":\"\",\"address\":{\"line_1\":\"123 Some st \",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"},\"client_transaction_id\":\"1\",\"client_transaction_description\":\"Store Purchase\",\"client_invoice_id\":null,\"save_payment_instrument\":false,\"kount_score\":null,\"checks\":{\"address_line1_check\":null,\"address_postal_code_check\":null,\"cvc_check\":null},\"completed\":\"2023-07-14T17:42:30.1835831Z\"})
  end

  def successful_capture_response
    %({\"response_code\":\"00\",\"message\":\"Approved\",\"approved\":true,\"auth_code\":\"asdefr\",\"charge_transaction_id\":\"ch_KpmspGEiSUCgavxiE-xPTw\",\"amount\":100,\"recurring\":false,\"completed\":\"2023-07-14T19:58:49.3255779+00:00\"})
  end

  def failed_capture_response
    %({\"response_code\":\"02\",\"message\":\"Current transaction does not exist or is in an invalid state.\",\"approved\":false,\"charge_transaction_id\":\"\",\"amount\":100,\"recurring\":false,\"completed\":\"2023-07-14T21:33:54.2518371Z\"})
  end

  def successful_refund_response
    %({\"response_code\":\"00\",\"message\":\"Approved\",\"approved\":true,\"auth_code\":\"asdefr\",\"charge_transaction_id\":\"ch_w5A8LS3C1kqdtrCJxWeRqQ\",\"amount\":10000,\"completed\":\"2023-07-15T01:01:58.3190631+00:00\"})
  end

  def failed_refund_response
    %({\"type\":\"https://httpstatuses.com/400\",\"title\":\"Invalid Request\",\"status\":400,\"detail\":\"Specified transaction does not exist.\",\"traceId\":\"00-e9b47344b951b400c34ce541a22e96a7-5ece5267ae02ef3d-00\"})
  end

  def successful_void_response
    %({\"response_code\":\"00\",\"message\":\"Approved\",\"approved\":true,\"auth_code\":\"asdefr\",\"charge_transaction_id\":\"ch_w5A8LS3C1kqdtrCJxWeRqQ\",\"amount\":10000,\"completed\":\"2023-07-15T01:01:58.3190631+00:00\"})
  end

  def failed_void_response
    %({\"type\":\"https://httpstatuses.com/400\",\"title\":\"Invalid Request\",\"status\":400,\"detail\":\"Specified transaction does not exist.\",\"traceId\":\"00-e9b47344b951b400c34ce541a22e96a7-5ece5267ae02ef3d-00\"})
  end

  def successful_token_response
    %({\"id\":\"tok_Ub1AHj7x1U6cUF8x8KDKAw\",\"type\":\"credit_card\",\"customer_id\":null,\"brand\":\"Visa\",\"bin\":\"411111\",\"last_four\":\"1111\",\"expiration\":\"0129\",\"billing_contact\":{\"first_name\":\"Bob\",\"last_name\":\"Bobberson\",\"address\":{\"line_1\":\"123 Some st\",\"line_2\":\"\",\"city\":\"Some City\",\"state\":\"CA\",\"postal_code\":\"12345\",\"country_code\":\"USA\"},\"phone\":\"1231231234\",\"email\":\"test@test.com\"},\"is_default\":false})
  end

  def failed_token_response
    %({\"id\":\"Ji-YEeijmUmiFB6mz_iIUA\",\"response_code\":\"400\",\"message\":\"InvalidRequestException: Card number is invalid.\",\"approved\":false,\"completed\":\"2023-07-15T01:10:47.9188024Z\",\"success\":false})
  end
end
