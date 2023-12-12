require 'test_helper'

class HiPayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = HiPayGateway.new(fixtures(:hi_pay))
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: SecureRandom.random_number(1000000000),
      description: 'Short_description',
      email: 'john.smith@test.com'
    }

    @billing_address = address
  end

  def test_tokenize_pm_with_authorize
    @gateway.expects(:ssl_post).
      with(
        'https://stage-secure2-vault.hipay-tpp.com/rest/v2/token/create',
        all_of(
          includes("card_number=#{@credit_card.number}"),
          includes("card_expiry_month=#{@credit_card.month}"),
          includes("card_expiry_year=#{@credit_card.year}"),
          includes("card_holder=#{@credit_card.first_name}+#{@credit_card.last_name}"),
          includes("cvc=#{@credit_card.verification_value}"),
          includes('multi_use=0'),
          includes('generate_request_id=0')
        ),
        anything
      ).
      returns(successful_tokenize_response)
    @gateway.expects(:ssl_post).with('https://stage-secure-gateway.hipay-tpp.com/rest/v1/order', anything, anything).returns(successful_authorize_response)
    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_tokenize_pm_with_store
    @gateway.expects(:ssl_post).
      with(
        'https://stage-secure2-vault.hipay-tpp.com/rest/v2/token/create',
        all_of(
          includes("card_number=#{@credit_card.number}"),
          includes("card_expiry_month=#{@credit_card.month}"),
          includes("card_expiry_year=#{@credit_card.year}"),
          includes("card_holder=#{@credit_card.first_name}+#{@credit_card.last_name}"),
          includes("cvc=#{@credit_card.verification_value}"),
          includes('multi_use=1'),
          includes('generate_request_id=0')
        ),
        anything
      ).
      returns(successful_tokenize_response)
    @gateway.store(@credit_card, @options)
  end

  def test_authorize_with_credit_card
    @gateway.expects(:ssl_post).
      with(
        'https://stage-secure2-vault.hipay-tpp.com/rest/v2/token/create',
        all_of(
          includes("card_number=#{@credit_card.number}"),
          includes("card_expiry_month=#{@credit_card.month}"),
          includes("card_expiry_year=#{@credit_card.year}"),
          includes("card_holder=#{@credit_card.first_name}+#{@credit_card.last_name}"),
          includes("cvc=#{@credit_card.verification_value}"),
          includes('multi_use=0'),
          includes('generate_request_id=0')
        ),
        anything
      ).
      returns(successful_tokenize_response)

    tokenize_response_token = JSON.parse(successful_tokenize_response)['token']

    @gateway.expects(:ssl_post).
      with('https://stage-secure-gateway.hipay-tpp.com/rest/v1/order',
           all_of(
             includes('payment_product=visa'),
             includes('operation=Authorization'),
             regexp_matches(%r{orderid=\d+}),
             includes("description=#{@options[:description]}"),
             includes('currency=EUR'),
             includes('amount=1.00'),
             includes("cardtoken=#{tokenize_response_token}")
           ),
           anything).
      returns(successful_capture_response)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_authorize_with_credit_card_and_billing_address
    @gateway.expects(:ssl_post).returns(successful_tokenize_response)

    tokenize_response_token = JSON.parse(successful_tokenize_response)['token']

    @gateway.expects(:ssl_post).
      with('https://stage-secure-gateway.hipay-tpp.com/rest/v1/order',
           all_of(
             includes('payment_product=visa'),
             includes('operation=Authorization'),
             includes('streetaddress=456+My+Street'),
             includes('streetaddress2=Apt+1'),
             includes('city=Ottawa'),
             includes('recipient_info=Widgets+Inc'),
             includes('state=ON'),
             includes('country=CA'),
             includes('zipcode=K1C2N6'),
             includes('phone=%28555%29555-5555'),
             regexp_matches(%r{orderid=\d+}),
             includes("description=#{@options[:description]}"),
             includes('currency=EUR'),
             includes('amount=1.00'),
             includes("cardtoken=#{tokenize_response_token}")
           ),
           anything).
      returns(successful_capture_response)

    @gateway.authorize(@amount, @credit_card, @options.merge({ billing_address: @billing_address }))
  end

  def test_purchase_with_stored_pm
    stub_comms do
      @gateway.purchase(@amount, 'authorization_value|card_token|card_brand', @options)
    end.check_request do |_endpoint, data, _headers|
      params = data.split('&').map { |param| param.split('=') }.to_h
      assert_equal 'card_brand', params['payment_product']
      assert_equal 'Sale', params['operation']
      assert_equal @options[:order_id].to_s, params['orderid']
      assert_equal @options[:description], params['description']
      assert_equal 'EUR', params['currency']
      assert_equal '1.00', params['amount']
      assert_equal 'card_token', params['cardtoken']
    end.respond_with(successful_capture_response)
  end

  def test_purhcase_with_credit_card; end

  def test_capture
    @gateway.expects(:ssl_post).with('https://stage-secure2-vault.hipay-tpp.com/rest/v2/token/create', anything, anything).returns(successful_tokenize_response)
    @gateway.expects(:ssl_post).with('https://stage-secure-gateway.hipay-tpp.com/rest/v1/order', anything, anything).returns(successful_authorize_response)

    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    transaction_reference, _card_token, _brand = authorize_response.authorization.split('|')
    @gateway.expects(:ssl_post).
      with(
        "https://stage-secure-gateway.hipay-tpp.com/rest/v1/maintenance/transaction/#{transaction_reference}",
        all_of(
          includes('operation=capture'),
          includes('currency=EUR')
        ),
        anything
      ).
      returns(successful_capture_response)
    @gateway.capture(@amount, transaction_reference, @options)
  end

  def test_required_client_id_and_client_secret
    error = assert_raises ArgumentError do
      HiPayGateway.new
    end

    assert_equal 'Missing required parameter: username', error.message
  end

  def test_supported_card_types
    assert_equal HiPayGateway.supported_cardtypes, %i[visa master american_express]
  end

  def test_supported_countries
    assert_equal HiPayGateway.supported_countries, ['FR']
  end

  # def test_support_scrubbing_flag_enabled
  #   assert @gateway.supports_scrubbing?
  # end

  def test_detecting_successfull_response_from_capture
    assert @gateway.send :success_from, 'capture', { 'status' => '118', 'message' => 'Captured' }
  end

  def test_detecting_successfull_response_from_purchase
    assert @gateway.send :success_from, 'order', { 'state' => 'completed' }
  end

  def test_detecting_successfull_response_from_authorize
    assert @gateway.send :success_from, 'order', { 'state' => 'completed' }
  end

  def test_detecting_successfull_response_from_store
    assert @gateway.send :success_from, 'store', { 'token' => 'random_token' }
  end

  def test_get_response_message_from_messages_key
    message = @gateway.send :message_from, 'order', { 'message' => 'hello' }
    assert_equal 'hello', message
  end

  def test_get_response_message_from_message_user
    message = @gateway.send :message_from, 'order', { other_key: 'something_else' }
    assert_nil message
  end

  def test_url_generation_from_action
    action = 'test'
    assert_equal "#{@gateway.test_url}/v1/#{action}", @gateway.send(:url, action)
  end

  def test_request_headers_building
    gateway = HiPayGateway.new(username: 'abc123', password: 'def456')
    headers = gateway.send :request_headers

    assert_equal 'application/json', headers['Accept']
    assert_equal 'application/x-www-form-urlencoded', headers['Content-Type']
    assert_equal 'Basic YWJjMTIzOmRlZjQ1Ng==', headers['Authorization']
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_tokenize_response
    '{"token":"5fc03718289f58d1ce38482faa79aa4c640c44a5d182ad3d849761ed9ea33155","request_id":"0","card_id":"9fd81707-8f41-4a01-b6ed-279954336ada","multi_use":0,"brand":"VISA","pan":"411111xxxxxx1111","card_holder":"John Smith","card_expiry_month":"12","card_expiry_year":"2025","issuer":"JPMORGAN CHASE BANK, N.A.","country":"US","card_type":"CREDIT","forbidden_issuer_country":false}'
  end

  def successful_authorize_response
    '{"state":"completed","reason":"","forwardUrl":"","test":"true","mid":"00001331069","attemptId":"1","authorizationCode":"no_code","transactionReference":"800271033524","dateCreated":"2023-12-05T23:36:43+0000","dateUpdated":"2023-12-05T23:36:48+0000","dateAuthorized":"2023-12-05T23:36:48+0000","status":"116","message":"Authorized","authorizedAmount":"500.00","capturedAmount":"0.00","refundedAmount":"0.00","creditedAmount":"0.00","decimals":"2","currency":"EUR","ipAddress":"0.0.0.0","ipCountry":"","deviceId":"","cdata1":"","cdata2":"","cdata3":"","cdata4":"","cdata5":"","cdata6":"","cdata7":"","cdata8":"","cdata9":"","cdata10":"","avsResult":"","eci":"7","paymentProduct":"visa","paymentMethod":{"token":"5fc03718289f58d1ce38482faa79aa4c640c44a5d182ad3d849761ed9ea33155","cardId":"9fd81707-8f41-4a01-b6ed-279954336ada","brand":"VISA","pan":"411111******1111","cardHolder":"JOHN SMITH","cardExpiryMonth":"12","cardExpiryYear":"2025","issuer":"JPMORGAN CHASE BANK, N.A.","country":"US"},"threeDSecure":{"eci":"","authenticationStatus":"Y","authenticationMessage":"Authentication Successful","authenticationToken":"","xid":""},"fraudScreening":{"scoring":"0","result":"ACCEPTED","review":""},"order":{"id":"Sp_ORDER_272437225","dateCreated":"2023-12-05T23:36:43+0000","attempts":"1","amount":"500.00","shipping":"0.00","tax":"0.00","decimals":"2","currency":"EUR","customerId":"","language":"en_US","email":""},"debitAgreement":{"id":"","status":""}}'
  end

  def successful_capture_response
    '{"operation":"capture","test":"true","mid":"00001331069","authorizationCode":"no_code","transactionReference":"800271033524","dateCreated":"2023-12-05T23:36:43+0000","dateUpdated":"2023-12-05T23:37:21+0000","dateAuthorized":"2023-12-05T23:36:48+0000","status":"118","message":"Captured","authorizedAmount":"500.00","capturedAmount":"500.00","refundedAmount":"0.00","decimals":"2","currency":"EUR"}'
  end

  def pre_scrubbed
    <<~PRE_SCRUBBED
      opening connection to stage-secure2-vault.hipay-tpp.com:443...
      opened
      starting SSL for stage-secure2-vault.hipay-tpp.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /rest/v2/token/create HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nAuthorization: Basic OTQ2NTgzNjUuc3RhZ2Utc2VjdXJlLWdhdGV3YXkuaGlwYXktdHBwLmNvbTpUZXN0X1JoeXBWdktpUDY4VzNLQUJ4eUdoS3Zlcw==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: stage-secure2-vault.hipay-tpp.com\r\nContent-Length: 136\r\n\r\n"
      <- "card_number=4111111111111111&card_expiry_month=12&card_expiry_year=2025&card_holder=John+Smith&cvc=514&multi_use=0&generate_request_id=0"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Tue, 12 Dec 2023 14:49:44 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Vary: Authorization\r\n"
      -> "Cache-Control: max-age=0, must-revalidate, private\r\n"
      -> "Expires: Tue, 12 Dec 2023 14:49:44 GMT\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "Set-Cookie: PHPSESSID=j9bfv7gaml9uslij70e15kvrm6; path=/; HttpOnly\r\n"
      -> "Strict-Transport-Security: max-age=86400\r\n"
      -> "\r\n"
      -> "17c\r\n"
      reading 380 bytes...
      -> "{\"token\":\"0acbbfcbd5bf202a05acc0e9c00f79158a2fe8b60caad2213b09e901b89dc28e\",\"request_id\":\"0\",\"card_id\":\"9fd81707-8f41-4a01-b6ed-279954336ada\",\"multi_use\":0,\"brand\":\"VISA\",\"pan\":\"411111xxxxxx1111\",\"card_holder\":\"John Smith\",\"card_expiry_month\":\"12\",\"card_expiry_year\":\"2025\",\"issuer\":\"JPMORGAN CHASE BANK, N.A.\",\"country\":\"US\",\"card_type\":\"CREDIT\",\"forbidden_issuer_country\":false}"
      reading 2 bytes...
      -> "\r\n"
      0
      \r\nConn close
      opening connection to stage-secure-gateway.hipay-tpp.com:443...
      opened
      starting SSL for stage-secure-gateway.hipay-tpp.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /rest/v1/order HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nAuthorization: Basic OTQ2NTgzNjUuc3RhZ2Utc2VjdXJlLWdhdGV3YXkuaGlwYXktdHBwLmNvbTpUZXN0X1JoeXBWdktpUDY4VzNLQUJ4eUdoS3Zlcw==\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: stage-secure-gateway.hipay-tpp.com\r\nContent-Length: 186\r\n\r\n"
      <- "payment_product=visa&operation=Sale&cardtoken=0acbbfcbd5bf202a05acc0e9c00f79158a2fe8b60caad2213b09e901b89dc28e&order_id=Sp_ORDER_100432071&description=An+authorize&currency=EUR&amount=500"
      -> "HTTP/1.1 200 OK\r\n"
      -> "date: Tue, 12 Dec 2023 14:49:45 GMT\r\n"
      -> "expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
      -> "cache-control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
      -> "pragma: no-cache\r\n"
      -> "access-control-allow-origin: \r\n"
      -> "access-control-allow-headers: \r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "content-length: 1472\r\n"
      -> "content-type: application/json; encoding=UTF-8\r\n"
      -> "connection: close\r\n"
      -> "\r\n"
      reading 1472 bytes...
      -> "{\"state\":\"completed\",\"reason\":\"\",\"forwardUrl\":\"\",\"test\":\"true\",\"mid\":\"00001331069\",\"attemptId\":\"1\",\"authorizationCode\":\"no_code\",\"transactionReference\":\"800272278410\",\"referenceToPay\":\"\",\"dateCreated\":\"2023-12-12T14:49:45+0000\",\"dateUpdated\":\"2023-12-12T14:49:50+0000\",\"dateAuthorized\":\"2023-12-12T14:49:49+0000\",\"status\":\"118\",\"message\":\"Captured\",\"authorizedAmount\":\"500.00\",\"capturedAmount\":\"500.00\",\"refundedAmount\":\"0.00\",\"creditedAmount\":\"0.00\",\"decimals\":\"2\",\"currency\":\"EUR\",\"ipAddress\":\"0.0.0.0\",\"ipCountry\":\"\",\"deviceId\":\"\",\"cdata1\":\"\",\"cdata2\":\"\",\"cdata3\":\"\",\"cdata4\":\"\",\"cdata5\":\"\",\"cdata6\":\"\",\"cdata7\":\"\",\"cdata8\":\"\",\"cdata9\":\"\",\"cdata10\":\"\",\"avsResult\":\"\",\"eci\":\"7\",\"paymentProduct\":\"visa\",\"paymentMethod\":{\"token\":\"0acbbfcbd5bf202a05acc0e9c00f79158a2fe8b60caad2213b09e901b89dc28e\",\"cardId\":\"9fd81707-8f41-4a01-b6ed-279954336ada\",\"brand\":\"VISA\",\"pan\":\"411111******1111\",\"cardHolder\":\"JOHN SMITH\",\"cardExpiryMonth\":\"12\",\"cardExpiryYear\":\"2025\",\"issuer\":\"JPMORGAN CHASE BANK, N.A.\",\"country\":\"US\"},\"threeDSecure\":{\"eci\":\"\",\"authenticationStatus\":\"Y\",\"authenticationMessage\":\"Authentication Successful\",\"authenticationToken\":\"\",\"xid\":\"\"},\"fraudScreening\":{\"scoring\":\"0\",\"result\":\"ACCEPTED\",\"review\":\"\"},\"order\":{\"id\":\"Sp_ORDER_100432071\",\"dateCreated\":\"2023-12-12T14:49:45+0000\",\"attempts\":\"1\",\"amount\":\"500.00\",\"shipping\":\"0.00\",\"tax\":\"0.00\",\"decimals\":\"2\",\"currency\":\"EUR\",\"customerId\":\"\",\"language\":\"en_US\",\"email\":\"\"},\"debitAgreement\":{\"id\":\"\",\"status\":\"\"}}"
      reading 1472 bytes...
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~POST_SCRUBBED
      opening connection to stage-secure2-vault.hipay-tpp.com:443...
      opened
      starting SSL for stage-secure2-vault.hipay-tpp.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /rest/v2/token/create HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nAuthorization: Basic [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: stage-secure2-vault.hipay-tpp.com\r\nContent-Length: 136\r\n\r\n"
      <- "card_number=[FILTERED]&card_expiry_month=12&card_expiry_year=2025&card_holder=John+Smith&cvc=[FILTERED]&multi_use=0&generate_request_id=0"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Server: nginx\r\n"
      -> "Date: Tue, 12 Dec 2023 14:49:44 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Vary: Authorization\r\n"
      -> "Cache-Control: max-age=0, must-revalidate, private\r\n"
      -> "Expires: Tue, 12 Dec 2023 14:49:44 GMT\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "Set-Cookie: PHPSESSID=j9bfv7gaml9uslij70e15kvrm6; path=/; HttpOnly\r\n"
      -> "Strict-Transport-Security: max-age=86400\r\n"
      -> "\r\n"
      -> "17c\r\n"
      reading 380 bytes...
      -> "{\"token\":\"0acbbfcbd5bf202a05acc0e9c00f79158a2fe8b60caad2213b09e901b89dc28e\",\"request_id\":\"0\",\"card_id\":\"9fd81707-8f41-4a01-b6ed-279954336ada\",\"multi_use\":0,\"brand\":\"VISA\",\"pan\":\"411111xxxxxx1111\",\"card_holder\":\"John Smith\",\"card_expiry_month\":\"12\",\"card_expiry_year\":\"2025\",\"issuer\":\"JPMORGAN CHASE BANK, N.A.\",\"country\":\"US\",\"card_type\":\"CREDIT\",\"forbidden_issuer_country\":false}"
      reading 2 bytes...
      -> "\r\n"
      0
      \r\nConn close
      opening connection to stage-secure-gateway.hipay-tpp.com:443...
      opened
      starting SSL for stage-secure-gateway.hipay-tpp.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      <- "POST /rest/v1/order HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nAuthorization: Basic [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: stage-secure-gateway.hipay-tpp.com\r\nContent-Length: 186\r\n\r\n"
      <- "payment_product=visa&operation=Sale&cardtoken=0acbbfcbd5bf202a05acc0e9c00f79158a2fe8b60caad2213b09e901b89dc28e&order_id=Sp_ORDER_100432071&description=An+authorize&currency=EUR&amount=500"
      -> "HTTP/1.1 200 OK\r\n"
      -> "date: Tue, 12 Dec 2023 14:49:45 GMT\r\n"
      -> "expires: Thu, 19 Nov 1981 08:52:00 GMT\r\n"
      -> "cache-control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\r\n"
      -> "pragma: no-cache\r\n"
      -> "access-control-allow-origin: \r\n"
      -> "access-control-allow-headers: \r\n"
      -> "access-control-allow-credentials: true\r\n"
      -> "content-length: 1472\r\n"
      -> "content-type: application/json; encoding=UTF-8\r\n"
      -> "connection: close\r\n"
      -> "\r\n"
      reading 1472 bytes...
      -> "{\"state\":\"completed\",\"reason\":\"\",\"forwardUrl\":\"\",\"test\":\"true\",\"mid\":\"00001331069\",\"attemptId\":\"1\",\"authorizationCode\":\"no_code\",\"transactionReference\":\"800272278410\",\"referenceToPay\":\"\",\"dateCreated\":\"2023-12-12T14:49:45+0000\",\"dateUpdated\":\"2023-12-12T14:49:50+0000\",\"dateAuthorized\":\"2023-12-12T14:49:49+0000\",\"status\":\"118\",\"message\":\"Captured\",\"authorizedAmount\":\"500.00\",\"capturedAmount\":\"500.00\",\"refundedAmount\":\"0.00\",\"creditedAmount\":\"0.00\",\"decimals\":\"2\",\"currency\":\"EUR\",\"ipAddress\":\"0.0.0.0\",\"ipCountry\":\"\",\"deviceId\":\"\",\"cdata1\":\"\",\"cdata2\":\"\",\"cdata3\":\"\",\"cdata4\":\"\",\"cdata5\":\"\",\"cdata6\":\"\",\"cdata7\":\"\",\"cdata8\":\"\",\"cdata9\":\"\",\"cdata10\":\"\",\"avsResult\":\"\",\"eci\":\"7\",\"paymentProduct\":\"visa\",\"paymentMethod\":{\"token\":\"0acbbfcbd5bf202a05acc0e9c00f79158a2fe8b60caad2213b09e901b89dc28e\",\"cardId\":\"9fd81707-8f41-4a01-b6ed-279954336ada\",\"brand\":\"VISA\",\"pan\":\"411111******1111\",\"cardHolder\":\"JOHN SMITH\",\"cardExpiryMonth\":\"12\",\"cardExpiryYear\":\"2025\",\"issuer\":\"JPMORGAN CHASE BANK, N.A.\",\"country\":\"US\"},\"threeDSecure\":{\"eci\":\"\",\"authenticationStatus\":\"Y\",\"authenticationMessage\":\"Authentication Successful\",\"authenticationToken\":\"\",\"xid\":\"\"},\"fraudScreening\":{\"scoring\":\"0\",\"result\":\"ACCEPTED\",\"review\":\"\"},\"order\":{\"id\":\"Sp_ORDER_100432071\",\"dateCreated\":\"2023-12-12T14:49:45+0000\",\"attempts\":\"1\",\"amount\":\"500.00\",\"shipping\":\"0.00\",\"tax\":\"0.00\",\"decimals\":\"2\",\"currency\":\"EUR\",\"customerId\":\"\",\"language\":\"en_US\",\"email\":\"\"},\"debitAgreement\":{\"id\":\"\",\"status\":\"\"}}"
      reading 1472 bytes...
      Conn close
    POST_SCRUBBED
  end
end
