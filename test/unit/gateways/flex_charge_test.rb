require 'test_helper'

class FlexChargeTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FlexChargeGateway.new(
      app_key: 'SOMECREDENTIAL',
      app_secret: 'SOMECREDENTIAL',
      site_id: 'SOMECREDENTIAL',
      mid: 'SOMECREDENTIAL'
    )
    @credit_card = credit_card
    @amount = 100

    @options = {
      is_declined: true,
      order_id: SecureRandom.uuid,
      idempotency_key: SecureRandom.uuid,
      email: 'test@gmail.com',
      response_code: '100',
      response_code_source: 'nmi',
      avs_result_code: '200',
      cvv_result_code: '111',
      cavv_result_code: '111',
      timezone_utc_offset: '-5',
      billing_address: address.merge(name: 'Cure Tester'),
      shipping_address: address.merge(name: 'Jhon Doe', country: 'US'),
      sense_key: 'abc123',
      extra_data: { hello: 'world' }.to_json
    }

    @cit_options = {
      is_mit: false,
      phone: '+99.2001a/+99.2001b'
    }.merge(@options)

    @mit_options = {
      is_mit: true,
      is_recurring: false,
      mit_expiry_date_utc: (Time.now + 1.day).getutc.iso8601,
      description: 'MyShoesStore'
    }.merge(@options)

    @mit_recurring_options = {
      is_recurring: true,
      subscription_id: SecureRandom.uuid,
      subscription_interval: 'monthly'
    }.merge(@mit_options)

    @three_d_secure_options = {
      three_d_secure: {
        eci: '05',
        cavv: 'AAABCSIIAAAAAAACcwgAEMCoNh=',
        xid: 'MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
        version: '2.1.0',
        ds_transaction_id: 'MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=',
        cavv_algorithm: 'AAABCSIIAAAAAAACcwgAEMCoNh=',
        directory_response_status: 'Y',
        authentication_response_status: 'Y',
        enrolled: 'Y'
      }
    }.merge(@options)
  end

  def test_supported_countries
    assert_equal %w(US), FlexChargeGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master american_express discover], @gateway.supported_cardtypes
  end

  def test_build_request_url_for_purchase
    action = :purchase
    assert_equal @gateway.send(:url, action), "#{@gateway.test_url}evaluate"
  end

  def test_build_request_url_with_id_param
    action = :refund
    id = 123
    assert_equal @gateway.send(:url, action, id), "#{@gateway.test_url}orders/123/refund"
  end

  def test_build_request_url_for_store
    action = :store
    assert_equal @gateway.send(:url, action), "#{@gateway.test_url}tokenize"
  end

  def test_invalid_instance
    error = assert_raises(ArgumentError) { FlexChargeGateway.new }
    assert_equal 'Missing required parameter: app_key', error.message
  end

  def test_successful_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, headers|
      request = JSON.parse(data)
      if /token/.match?(endpoint)
        assert_equal request['AppKey'], @gateway.options[:app_key]
        assert_equal request['AppSecret'], @gateway.options[:app_secret]
      end

      if /evaluate/.match?(endpoint)
        assert_equal headers['Authorization'], "Bearer #{@gateway.options[:access_token]}"
        assert_equal request['siteId'], @gateway.options[:site_id]
        assert_equal request['mid'], @gateway.options[:mid]
        assert_equal request['isDeclined'], @options[:is_declined]
        assert_equal request['orderId'], @options[:order_id]
        assert_equal request['idempotencyKey'], @options[:idempotency_key]
        assert_equal request['senseKey'], 'abc123'
        assert_equal request['Source'], 'Spreedly'
        assert_equal request['ExtraData'], { hello: 'world' }.to_json
        assert_equal request['transaction']['timezoneUtcOffset'], @options[:timezone_utc_offset]
        assert_equal request['transaction']['amount'], @amount
        assert_equal request['transaction']['responseCode'], @options[:response_code]
        assert_equal request['transaction']['responseCodeSource'], @options[:response_code_source]
        assert_equal request['transaction']['avsResultCode'], @options[:avs_result_code]
        assert_equal request['transaction']['cvvResultCode'], @options[:cvv_result_code]
        assert_equal request['transaction']['cavvResultCode'], @options[:cavv_result_code]
        assert_equal request['transactionType'], 'Purchase'
        assert_equal request['payer']['email'], @options[:email]
        assert_equal request['description'], @options[:description]

        assert_equal request['billingInformation']['firstName'], 'Cure'
        assert_equal request['billingInformation']['country'], 'CA'
        assert_equal request['shippingInformation']['firstName'], 'Jhon'
        assert_equal request['shippingInformation']['country'], 'US'
      end
    end.respond_with(successful_access_token_response, successful_purchase_response)

    assert_success response

    assert_equal 'ca7bb327-a750-412d-a9c3-050d72b3f0c5#USD', response.authorization
    assert response.test?
  end

  def test_successful_authorization
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transactionType'], 'Authorization' if /evaluate/.match?(endpoint)
    end.respond_with(successful_access_token_response, successful_purchase_response)
  end

  def test_successful_purchase_three_ds_global
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @three_d_secure_options)
    end.respond_with(successful_access_token_response, successful_purchase_response)
    assert_success response
    assert_equal 'ca7bb327-a750-412d-a9c3-050d72b3f0c5#USD', response.authorization
    assert response.test?
  end

  def test_succeful_request_with_three_ds_global
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @three_d_secure_options)
    end.check_request do |_method, endpoint, data, _headers|
      if /evaluate/.match?(endpoint)
        request = JSON.parse(data)
        assert_equal request['threeDSecure']['EcommerceIndicator'], @three_d_secure_options[:three_d_secure][:eci]
        assert_equal request['threeDSecure']['authenticationValue'], @three_d_secure_options[:three_d_secure][:cavv]
        assert_equal request['threeDSecure']['xid'], @three_d_secure_options[:three_d_secure][:xid]
        assert_equal request['threeDSecure']['threeDsVersion'], @three_d_secure_options[:three_d_secure][:version]
        assert_equal request['threeDSecure']['directoryServerTransactionId'], @three_d_secure_options[:three_d_secure][:ds_transaction_id]
        assert_equal request['threeDSecure']['authenticationValueAlgorithm'], @three_d_secure_options[:three_d_secure][:cavv_algorithm]
        assert_equal request['threeDSecure']['directoryResponseStatus'], @three_d_secure_options[:three_d_secure][:directory_response_status]
        assert_equal request['threeDSecure']['authenticationResponseStatus'], @three_d_secure_options[:three_d_secure][:authentication_response_status]
        assert_equal request['threeDSecure']['enrolled'], @three_d_secure_options[:three_d_secure][:enrolled]
      end
    end.respond_with(successful_access_token_response, successful_purchase_response)
  end

  def test_failed_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_access_token_response, failed_purchase_response)

    assert_failure response
    assert_equal '400', response.error_code
    assert_equal '400', response.message
  end

  def test_purchase_using_card_with_no_number
    credit_card_with_no_number = credit_card
    credit_card_with_no_number.number = nil

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, credit_card_with_no_number, @options)
    end.respond_with(successful_access_token_response, successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_token
    payment = 'bb114473-43fc-46c4-9082-ea3dfb490509'

    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, payment, @options)
    end.respond_with(successful_access_token_response, successful_purchase_response)

    assert_success response
  end

  def test_failed_refund
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, 'reference', @options)
    end.check_request do |_method, endpoint, data, _headers|
      request = JSON.parse(data)

      if /token/.match?(endpoint)
        assert_equal request['AppKey'], @gateway.options[:app_key]
        assert_equal request['AppSecret'], @gateway.options[:app_secret]
      end

      assert_equal request['amountToRefund'], (@amount.to_f / 100).round(2) if /orders\/reference\/refund/.match?(endpoint)
    end.respond_with(successful_access_token_response, failed_refund_response)

    assert_failure response
    assert response.test?
  end

  def test_failed_purchase_idempotency_key
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_access_token_response, missed_idempotency_key_field)

    assert_failure response
    assert_nil response.error_code
    assert_equal '{"IdempotencyKey":["The IdempotencyKey field is required."]}', response.message
  end

  def test_failed_purchase_expiry_date
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_access_token_response, invalid_expiry_date_utc)

    assert_failure response
    assert_nil response.error_code
    assert_equal '{"ExpiryDateUtc":["The field ExpiryDateUtc is invalid."]}', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_address_names_from_address
    names = @gateway.send(:names_from_address, @options[:billing_address], @credit_card)

    assert_equal 'Cure', names.first
    assert_equal 'Tester', names.last
  end

  def test_address_names_from_credit_card
    @options.delete(:billing_address)
    names = @gateway.send(:names_from_address, {}, @credit_card)

    assert_equal 'Longbob', names.first
    assert_equal 'Longsen', names.last
  end

  def test_address_names_when_passing_string_token
    names = @gateway.send(:names_from_address, @options[:billing_address], SecureRandom.uuid)

    assert_equal 'Cure', names.first
    assert_equal 'Tester', names.last
  end

  def test_successful_store
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.respond_with(successful_access_token_response, successful_store_response)

    assert_success response
    assert_equal 'd3e10716-6aac-4eb8-a74d-c1a3027f1d96', response.authorization
  end

  def test_successful_inquire_request
    session_id = 'f8da8dc7-17de-4b5e-858d-4bdc47cd5dbf'
    stub_comms(@gateway, :ssl_request) do
      @gateway.inquire(session_id, {})
    end.check_request do |_method, endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['orderSessionKey'], session_id if /outcome/.match?(endpoint)
    end.respond_with(successful_access_token_response, successful_purchase_response)
  end

  def test_address_when_billing_address_provided
    address = @gateway.send(:address, @options)
    assert_equal 'CA', address[:country]
  end

  def test_address_when_address_is_provided_in_options
    @options.delete(:billing_address)
    @options[:address] = { country: 'US' }
    address = @gateway.send(:address, @options)
    assert_equal 'US', address[:country]
  end

  def test_authorization_from_on_store
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.respond_with(successful_access_token_response, successful_store_response)

    assert_success response
    assert_equal 'd3e10716-6aac-4eb8-a74d-c1a3027f1d96', response.authorization
  end

  def test_authorization_from_on_purchase
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.respond_with(successful_access_token_response, successful_purchase_response)

    assert_success response
    assert_equal 'ca7bb327-a750-412d-a9c3-050d72b3f0c5#USD', response.authorization
  end

  def test_add_base_data_without_idempotency_key
    @options.delete(:idempotency_key)
    post = {}
    @gateway.send(:add_base_data, post, @options)

    assert_equal 5, post[:idempotencyKey].split('-').size
  end

  private

  def pre_scrubbed
    "opening connection to api-sandbox.flex-charge.com:443...
    opened
    starting SSL for api-sandbox.flex-charge.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
    <- \"POST /v1/oauth2/token HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api-sandbox.flex-charge.com\\r\
    Content-Length: 153\\r\
    \\r\
    \"
    <- \"{\\\"AppKey\\\":\\\"2/tprAqlvujvIZonWkLntQMj3CbH7Y9sKLqTTdWu\\\",\\\"AppSecret\\\":\\\"AQAAAAEAACcQAAAAEFb/TYEfAlzWhb6SDXEbS06A49kc/P6Cje6 MDta3o61GGS4tLLk8m/BZuJOyZ7B99g==\\\"}\"
    -> \"HTTP/1.1 200 OK\\r\
    \"
    -> \"Date: Thu, 04 Apr 2024 13:29:08 GMT\\r\
    \"
    -> \"Content-Type: application/json; charset=utf-8\\r\
    \"
    -> \"Content-Length: 902\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"server: Kestrel\\r\
    \"
    -> \"set-cookie: AWSALB=n2vt9daKLxUPgxF+n3g+4uQDgxt1PNVOY/HwVuLZdkf0Ye8XkAFuEVrnu6xh/xf7k2ZYZHqaPthqR36D3JxPJIs7QfNbcfAhvxTlPEVx8t/IyB1Kb/Vinasi3vZD; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/\\r\
    \"
    -> \"set-cookie: AWSALBCORS=n2vt9daKLxUPgxF+n3g+4uQDgxt1PNVOY/HwVuLZdkf0Ye8XkAFuEVrnu6xh/xf7k2ZYZHqaPthqR36D3JxPJIs7QfNbcfAhvxTlPEVx8t/IyB1Kb/Vinasi3vZD; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/; SameSite=None; Secure\\r\
    \"
    -> \"apigw-requestid: Vs-twgfMoAMEaEQ=\\r\
    \"
    -> \"\\r\
    \"
    reading 902 bytes...
    -> \"{\\\"accessToken\\\":\\\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwYmE4NGY2ZS03YTllLTQzZjEtYWU2ZC1jNTA4YjQ2NjQyNGEiLCJ1bmlxdWVfbmFtZSI6IjBiYTg0ZjZlLTdhOWUtNDNmMS1hZTZkLWM1MDhiNDY2NDI0YSIsImp0aSI6IjI2NTQxY2FlLWM3ZjUtNDU0MC04MTUyLTZiNGExNzQ3ZTJmMSIsImlhdCI6IjE3MTIyMzczNDg1NjUiLCJhdWQiOlsicGF5bWVudHMiLCJvcmRlcnMiLCJtZXJjaGFudHMiLCJlbGlnaWJpbGl0eS1zZnRwIiwiZWxpZ2liaWxpdHkiLCJjb250YWN0Il0sImN1c3RvbTptaWQiOiJkOWQwYjVmZC05NDMzLTQ0ZDMtODA1MS02M2ZlZTI4NzY4ZTgiLCJuYmYiOjE3MTIyMzczNDgsImV4cCI6MTcxMjIzNzk0OCwiaXNzIjoiQXBpLUNsaWVudC1TZXJ2aWNlIn0.ZGYzd6NA06o2zP-qEWf6YpyrY-v-Jb-i1SGUOUkgRPo\\\",\\\"refreshToken\\\":\\\"AQAAAAEAACcQAAAAEG5H7emaTnpUcVSWrbwLlPBEEdQ3mTCCHT5YMLBNauXxilaXHwL8oFiI4heg6yA\\\",\\\"expires\\\":1712237948565,\\\"id\\\":\\\"0ba84f6e-7a9e-43f1-ae6d-c508b466424a\\\",\\\"session\\\":null,\\\"daysToEnforceMFA\\\":null,\\\"skipAvailable\\\":null,\\\"success\\\":true,\\\"result\\\":null,\\\"status\\\":null,\\\"statusCode\\\":null,\\\"errors\\\":[],\\\"customProperties\\\":{}}\"
    read 902 bytes
    Conn close
    opening connection to api-sandbox.flex-charge.com:443...
    opened
    starting SSL for api-sandbox.flex-charge.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
    <- \"POST /v1/evaluate HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwYmE4NGY2ZS03YTllLTQzZjEtYWU2ZC1jNTA4YjQ2NjQyNGEiLCJ1bmlxdWVfbmFtZSI6IjBiYTg0ZjZlLTdhOWUtNDNmMS1hZTZkLWM1MDhiNDY2NDI0YSIsImp0aSI6IjI2NTQxY2FlLWM3ZjUtNDU0MC04MTUyLTZiNGExNzQ3ZTJmMSIsImlhdCI6IjE3MTIyMzczNDg1NjUiLCJhdWQiOlsicGF5bWVudHMiLCJvcmRlcnMiLCJtZXJjaGFudHMiLCJlbGlnaWJpbGl0eS1zZnRwIiwiZWxpZ2liaWxpdHkiLCJjb250YWN0Il0sImN1c3RvbTptaWQiOiJkOWQwYjVmZC05NDMzLTQ0ZDMtODA1MS02M2ZlZTI4NzY4ZTgiLCJuYmYiOjE3MTIyMzczNDgsImV4cCI6MTcxMjIzNzk0OCwiaXNzIjoiQXBpLUNsaWVudC1TZXJ2aWNlIn0.ZGYzd6NA06o2zP-qEWf6YpyrY-v-Jb-i1SGUOUkgRPo\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api-sandbox.flex-charge.com\\r\
    Content-Length: 999\\r\
    \\r\
    \"
    <- \"{\\\"siteId\\\":\\\"ffae80fd-2b8e-487a-94c3-87503a0c71bb\\\",\\\"mid\\\":\\\"d9d0b5fd-9433-44d3-8051-63fee28768e8\\\",\\\"isDeclined\\\":true,\\\"orderId\\\":\\\"b53827df-1f19-4dd9-9829-25a108255ba1\\\",\\\"idempotencyKey\\\":\\\"46902e30-ae70-42c5-a0d3-1994133b4f52\\\",\\\"transaction\\\":{\\\"id\\\":\\\"b53827df-1f19-4dd9-9829-25a108255ba1\\\",\\\"dynamicDescriptor\\\":\\\"MyShoesStore\\\",\\\"timezoneUtcOffset\\\":\\\"-5\\\",\\\"amount\\\":100,\\\"currency\\\":\\\"USD\\\",\\\"responseCode\\\":\\\"100\\\",\\\"responseCodeSource\\\":\\\"nmi\\\",\\\"avsResultCode\\\":\\\"200\\\",\\\"cvvResultCode\\\":\\\"111\\\",\\\"cavvResultCode\\\":\\\"111\\\",\\\"cardNotPresent\\\":true},\\\"paymentMethod\\\":{\\\"holderName\\\":\\\"Longbob Longsen\\\",\\\"cardType\\\":\\\"CREDIT\\\",\\\"cardBrand\\\":\\\"VISA\\\",\\\"cardCountry\\\":\\\"CA\\\",\\\"expirationMonth\\\":9,\\\"expirationYear\\\":2025,\\\"cardBinNumber\\\":\\\"411111\\\",\\\"cardLast4Digits\\\":\\\"1111\\\",\\\"cardNumber\\\":\\\"4111111111111111\\\"},\\\"billingInformation\\\":{\\\"firstName\\\":\\\"Cure\\\",\\\"lastName\\\":\\\"Tester\\\",\\\"country\\\":\\\"CA\\\",\\\"phone\\\":\\\"(555)555-5555\\\",\\\"countryCode\\\":\\\"CA\\\",\\\"addressLine1\\\":\\\"456 My Street\\\",\\\"state\\\":\\\"ON\\\",\\\"city\\\":\\\"Ottawa\\\",\\\"zipCode\\\":\\\"K1C2N6\\\"},\\\"payer\\\":{\\\"email\\\":\\\"test@gmail.com\\\",\\\"phone\\\":\\\"+99.2001a/+99.2001b\\\"}}\"
    -> \"HTTP/1.1 200 OK\\r\
    \"
    -> \"Date: Thu, 04 Apr 2024 13:29:11 GMT\\r\
    \"
    -> \"Content-Type: application/json; charset=utf-8\\r\
    \"
    -> \"Content-Length: 230\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"server: Kestrel\\r\
    \"
    -> \"set-cookie: AWSALB=Mw7gQis/D9qOm0eQvpkNsEOvZerr+YBDNyfJyJ2T2BGel3cg8AX9OtpuXXR/UCCgNRf5J9UTY+soHqLEJuxIEdEK5lNPelLtQbO0oKGB12q0gPRI7T5H1ijnf+RF; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/\\r\
    \"
    -> \"set-cookie: AWSALBCORS=Mw7gQis/D9qOm0eQvpkNsEOvZerr+YBDNyfJyJ2T2BGel3cg8AX9OtpuXXR/UCCgNRf5J9UTY+soHqLEJuxIEdEK5lNPelLtQbO0oKGB12q0gPRI7T5H1ijnf+RF; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/; SameSite=None; Secure\\r\
    \"
    -> \"apigw-requestid: Vs-t0g9gIAMES8w=\\r\
    \"
    -> \"\\r\
    \"
    reading 230 bytes...
    -> \"{\\\"orderSessionKey\\\":\\\"e97b1ff1-4449-46da-bc6c-a76d23f16353\\\",\\\"senseKey\\\":null,\\\"orderId\\\":\\\"e97b1ff1-4449-46da-bc6c-a76d23f16353\\\",\\\"success\\\":true,\\\"result\\\":\\\"Success\\\",\\\"status\\\":\\\"CHALLENGE\\\",\\\"statusCode\\\":null,\\\"errors\\\":[],\\\"customProperties\\\":{}}\"
    read 230 bytes
    Conn close
    "
  end

  def post_scrubbed
    "opening connection to api-sandbox.flex-charge.com:443...
    opened
    starting SSL for api-sandbox.flex-charge.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
    <- \"POST /v1/oauth2/token HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api-sandbox.flex-charge.com\\r\
    Content-Length: 153\\r\
    \\r\
    \"
    <- \"{\\\"AppKey\\\":\\\"[FILTERED]\",\\\"AppSecret\\\":\\\"[FILTERED]\"}\"
    -> \"HTTP/1.1 200 OK\\r\
    \"
    -> \"Date: Thu, 04 Apr 2024 13:29:08 GMT\\r\
    \"
    -> \"Content-Type: application/json; charset=utf-8\\r\
    \"
    -> \"Content-Length: 902\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"server: Kestrel\\r\
    \"
    -> \"set-cookie: AWSALB=n2vt9daKLxUPgxF+n3g+4uQDgxt1PNVOY/HwVuLZdkf0Ye8XkAFuEVrnu6xh/xf7k2ZYZHqaPthqR36D3JxPJIs7QfNbcfAhvxTlPEVx8t/IyB1Kb/Vinasi3vZD; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/\\r\
    \"
    -> \"set-cookie: AWSALBCORS=n2vt9daKLxUPgxF+n3g+4uQDgxt1PNVOY/HwVuLZdkf0Ye8XkAFuEVrnu6xh/xf7k2ZYZHqaPthqR36D3JxPJIs7QfNbcfAhvxTlPEVx8t/IyB1Kb/Vinasi3vZD; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/; SameSite=None; Secure\\r\
    \"
    -> \"apigw-requestid: Vs-twgfMoAMEaEQ=\\r\
    \"
    -> \"\\r\
    \"
    reading 902 bytes...
    -> \"{\\\"accessToken\\\":\\\"[FILTERED]\",\\\"refreshToken\\\":\\\"AQAAAAEAACcQAAAAEG5H7emaTnpUcVSWrbwLlPBEEdQ3mTCCHT5YMLBNauXxilaXHwL8oFiI4heg6yA\\\",\\\"expires\\\":1712237948565,\\\"id\\\":\\\"0ba84f6e-7a9e-43f1-ae6d-c508b466424a\\\",\\\"session\\\":null,\\\"daysToEnforceMFA\\\":null,\\\"skipAvailable\\\":null,\\\"success\\\":true,\\\"result\\\":null,\\\"status\\\":null,\\\"statusCode\\\":null,\\\"errors\\\":[],\\\"customProperties\\\":{}}\"
    read 902 bytes
    Conn close
    opening connection to api-sandbox.flex-charge.com:443...
    opened
    starting SSL for api-sandbox.flex-charge.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
    <- \"POST /v1/evaluate HTTP/1.1\\r\
    Content-Type: application/json\\r\
    Authorization: Bearer [FILTERED]\\r\
    Connection: close\\r\
    Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\
    Accept: */*\\r\
    User-Agent: Ruby\\r\
    Host: api-sandbox.flex-charge.com\\r\
    Content-Length: 999\\r\
    \\r\
    \"
    <- \"{\\\"siteId\\\":\\\"[FILTERED]\",\\\"mid\\\":\\\"[FILTERED]\",\\\"isDeclined\\\":true,\\\"orderId\\\":\\\"b53827df-1f19-4dd9-9829-25a108255ba1\\\",\\\"idempotencyKey\\\":\\\"46902e30-ae70-42c5-a0d3-1994133b4f52\\\",\\\"transaction\\\":{\\\"id\\\":\\\"b53827df-1f19-4dd9-9829-25a108255ba1\\\",\\\"dynamicDescriptor\\\":\\\"MyShoesStore\\\",\\\"timezoneUtcOffset\\\":\\\"-5\\\",\\\"amount\\\":100,\\\"currency\\\":\\\"USD\\\",\\\"responseCode\\\":\\\"100\\\",\\\"responseCodeSource\\\":\\\"nmi\\\",\\\"avsResultCode\\\":\\\"200\\\",\\\"cvvResultCode\\\":\\\"111\\\",\\\"cavvResultCode\\\":\\\"111\\\",\\\"cardNotPresent\\\":true},\\\"paymentMethod\\\":{\\\"holderName\\\":\\\"Longbob Longsen\\\",\\\"cardType\\\":\\\"CREDIT\\\",\\\"cardBrand\\\":\\\"VISA\\\",\\\"cardCountry\\\":\\\"CA\\\",\\\"expirationMonth\\\":9,\\\"expirationYear\\\":2025,\\\"cardBinNumber\\\":\\\"411111\\\",\\\"cardLast4Digits\\\":\\\"1111\\\",\\\"cardNumber\\\":\\\"[FILTERED]\"},\\\"billingInformation\\\":{\\\"firstName\\\":\\\"Cure\\\",\\\"lastName\\\":\\\"Tester\\\",\\\"country\\\":\\\"CA\\\",\\\"phone\\\":\\\"(555)555-5555\\\",\\\"countryCode\\\":\\\"CA\\\",\\\"addressLine1\\\":\\\"456 My Street\\\",\\\"state\\\":\\\"ON\\\",\\\"city\\\":\\\"Ottawa\\\",\\\"zipCode\\\":\\\"K1C2N6\\\"},\\\"payer\\\":{\\\"email\\\":\\\"test@gmail.com\\\",\\\"phone\\\":\\\"+99.2001a/+99.2001b\\\"}}\"
    -> \"HTTP/1.1 200 OK\\r\
    \"
    -> \"Date: Thu, 04 Apr 2024 13:29:11 GMT\\r\
    \"
    -> \"Content-Type: application/json; charset=utf-8\\r\
    \"
    -> \"Content-Length: 230\\r\
    \"
    -> \"Connection: close\\r\
    \"
    -> \"server: Kestrel\\r\
    \"
    -> \"set-cookie: AWSALB=Mw7gQis/D9qOm0eQvpkNsEOvZerr+YBDNyfJyJ2T2BGel3cg8AX9OtpuXXR/UCCgNRf5J9UTY+soHqLEJuxIEdEK5lNPelLtQbO0oKGB12q0gPRI7T5H1ijnf+RF; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/\\r\
    \"
    -> \"set-cookie: AWSALBCORS=Mw7gQis/D9qOm0eQvpkNsEOvZerr+YBDNyfJyJ2T2BGel3cg8AX9OtpuXXR/UCCgNRf5J9UTY+soHqLEJuxIEdEK5lNPelLtQbO0oKGB12q0gPRI7T5H1ijnf+RF; Expires=Thu, 11 Apr 2024 13:29:08 GMT; Path=/; SameSite=None; Secure\\r\
    \"
    -> \"apigw-requestid: Vs-t0g9gIAMES8w=\\r\
    \"
    -> \"\\r\
    \"
    reading 230 bytes...
    -> \"{\\\"orderSessionKey\\\":\\\"e97b1ff1-4449-46da-bc6c-a76d23f16353\\\",\\\"senseKey\\\":null,\\\"orderId\\\":\\\"e97b1ff1-4449-46da-bc6c-a76d23f16353\\\",\\\"success\\\":true,\\\"result\\\":\\\"Success\\\",\\\"status\\\":\\\"CHALLENGE\\\",\\\"statusCode\\\":null,\\\"errors\\\":[],\\\"customProperties\\\":{}}\"
    read 230 bytes
    Conn close
    "
  end

  def successful_access_token_response
    <<~RESPONSE
      {
        "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwYmE4NGY2ZS03YTllLTQzZjEtYWU2ZC1jNTA4YjQ2NjQyNGEiLCJ1bmlxdWVfbmFtZSI6IjBiYTg0ZjZlLTdhOWUtNDNmMS1hZTZkLWM1MDhiNDY2NDI0YSIsImp0aSI6ImY5NzdlZDE3LWFlZDItNGIxOC1hMjY1LWY0NzkwNTY0ZDc1NSIsImlhdCI6IjE3MTIwNzE1NDMyNDYiLCJhdWQiOlsicGF5bWVudHMiLCJvcmRlcnMiLCJtZXJjaGFudHMiLCJlbGlnaWJpbGl0eS1zZnRwIiwiZWxpZ2liaWxpdHkiLCJjb250YWN0Il0sImN1c3RvbTptaWQiOiJkOWQwYjVmZC05NDMzLTQ0ZDMtODA1MS02M2ZlZTI4NzY4ZTgiLCJuYmYiOjE3MTIwNzE1NDMsImV4cCI6MTcxMjA3MjE0MywiaXNzIjoiQXBpLUNsaWVudC1TZXJ2aWNlIn0.S9xgOejudB93Gf9Np9S8jtudhbY9zJj_j7n5al_SKZg",
        "refreshToken": "AQAAAAEAACcQAAAAEKd3NvUOrqgJXW8FtE22UbdZzuMWcbq7kSMIGss9OcV2aGzCXMNrOJgAW5Zg",
        "expires": #{(DateTime.now + 10.minutes).strftime('%Q').to_i},
        "id": "0ba84f6e-7a9e-43f1-ae6d-c508b466424a",
        "session": null,
        "daysToEnforceMFA": null,
        "skipAvailable": null,
        "success": true,
        "result": null,
        "status": null,
        "statusCode": null,
        "errors": [],
        "customProperties": {}
      }
    RESPONSE
  end

  def successful_purchase_response
    <<~RESPONSE
      {
        "orderSessionKey": "ca7bb327-a750-412d-a9c3-050d72b3f0c5",
        "senseKey": null,
        "orderId": "ca7bb327-a750-412d-a9c3-050d72b3f0c5",
        "success": true,
        "result": "Success",
        "status": "CHALLENGE",
        "statusCode": null,
        "errors": [],
        "customProperties": {}
      }
    RESPONSE
  end

  def successful_store_response
    <<~RESPONSE
      {
        "transaction": {
          "on_test_gateway": true,
          "created_at": "2024-05-14T13:44:25.3179186Z",
          "updated_at": "2024-05-14T13:44:25.3179187Z",
          "succeeded": true,
          "state": null,
          "token": null,
          "transaction_type": null,
          "order_id": null,
          "ip": null,
          "description": null,
          "email": null,
          "merchant_name_descriptor": null,
          "merchant_location_descriptor": null,
          "gateway_specific_fields": null,
          "gateway_specific_response_fields": null,
          "gateway_transaction_id": null,
          "gateway_latency_ms": null,
          "amount": 0,
          "currency_code": null,
          "retain_on_success": null,
          "payment_method_added": false,
          "message_key": null,
          "message": null,
          "response": null,
          "payment_method": {
            "token": "d3e10716-6aac-4eb8-a74d-c1a3027f1d96",
            "created_at": "2024-05-14T13:44:25.3179205Z",
            "updated_at": "2024-05-14T13:44:25.3179206Z",
            "email": null,
            "data": null,
            "storage_state": null,
            "test": false,
            "metadata": null,
            "last_four_digits": "1111",
            "first_six_digits": "41111111",
            "card_type": null,
            "first_name": "Cure",
            "last_name": "Tester",
            "month": 9,
            "year": 2025,
            "address1": null,
            "address2": null,
            "city": null,
            "state": null,
            "zip": null,
            "country": null,
            "phone_number": null,
            "company": null,
            "full_name": null,
            "payment_method_type": null,
            "errors": null,
            "fingerprint": null,
            "verification_value": null,
            "number": null
          }
        },
        "cardBinInfo": null,
        "success": true,
        "result": null,
        "status": null,
        "statusCode": null,
        "errors": [],
        "customProperties": {},
        "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwYmE4NGY2ZS03YTllLTQzZjEtYWU2ZC1jNTA4YjQ2NjQyNGEiLCJ1bmlxdWVfbmFtZSI6IjBiYTg0ZjZlLTdhOWUtNDNmMS1hZTZkLWM1MDhiNDY2NDI0YSIsImp0aSI6IjczZTVkOGZiLWYxMDMtNGVlYy1iYTAzLTM2MmY1YjA5MmNkMCIsImlhdCI6IjE3MTU2OTQyNjQ3MDMiLCJhdWQiOlsicGF5bWVudHMiLCJvcmRlcnMiLCJtZXJjaGFudHMiLCJlbGlnaWJpbGl0eS1zZnRwIiwiZWxpZ2liaWxpdHkiLCJjb250YWN0Il0sImN1c3RvbTptaWQiOiJkOWQwYjVmZC05NDMzLTQ0ZDMtODA1MS02M2ZlZTI4NzY4ZTgiLCJuYmYiOjE3MTU2OTQyNjQsImV4cCI6MTcxNTY5NDg2NCwiaXNzIjoiQXBpLUNsaWVudC1TZXJ2aWNlIn0.oB9xtWGthG6tcDie8Q3fXPc1fED8pBAlv8yZQuoiEkA",
        "token_expires": 1715694864703
      }
    RESPONSE
  end

  def failed_purchase_response
    <<~RESPONSE
      {
        "status": "400",
        "errors": {
          "OrderId": ["Merchant's orderId is required"],
           "TraceId": ["00-3b4af05c51be4aa7dd77104ac75f252b-004c728c64ca280d-01"],
           "IsDeclined": ["The IsDeclined field is required."],
           "IdempotencyKey": ["The IdempotencyKey field is required."],
           "Transaction.Id": ["The Id field is required."],
           "Transaction.ResponseCode": ["The ResponseCode field is required."],
           "Transaction.AvsResultCode": ["The AvsResultCode field is required."],
           "Transaction.CvvResultCode": ["The CvvResultCode field is required."]
        }
      }
    RESPONSE
  end

  def failed_refund_response
    <<~RESPONSE
      {
        "responseCode": "2001",
        "responseMessage": "Amount to refund (1.00) is greater than maximum refund amount in (0.00))",
        "transactionId": null,
        "success": false,
        "result": null,
        "status": "FAILED",
        "statusCode": null,
        "errors": [
          {
            "item1": "Amount to refund (1.00) is greater than maximum refund amount in (0.00))",
            "item2": "2001",
            "item3": "2001",
            "item4": true
          }
        ],
        "customProperties": {}
      }
    RESPONSE
  end

  def missed_idempotency_key_field
    <<~RESPONSE
      {
        "TraceId": ["00-bf5a1XXXTRACEXXX174b8a-f58XXXIDXXX32-01"],
        "IdempotencyKey": ["The IdempotencyKey field is required."],
        "access_token": "SomeAccessTokenXXXX1ZWE5ZmY0LTM4MjUtNDc0ZC04ZDhhLTk2OGZjM2NlYTA5ZCIsImlhdCI6IjE3MjI1Mjc1ODI1MjIiLCJhdWQiOlsicGF5bWVudHMiLCJvcmRlcnMiLCJtZXJjaGFudHMiLCJlbGlnaWJpbGl0eS1zZnRwIiwiZWxpZ2liaWxpdHkiLCJjb250YWN0Il0sImN1c3RvbTptaWQiOiJkOWQwYjVmZC05NDMzLTQ0ZDMtODA1MS02M2ZlZTI4NzY4ZTgiLCJuYmYiOjE3MjI1Mjc1ODIsImV4cCI6MTcyMjUyODE4MiwiaXNzIjoiQXBpLUNsaWVudC1TZXJ2aWNlIn0.Q7b5CViX4x3Qmna-JmLS2pQD8kWbrI5-GLLT1Ki9t3o",
        "token_expires": 1722528182522
      }
    RESPONSE
  end

  def invalid_expiry_date_utc
    <<~RESPONSE
      {
        "TraceId": ["00-bf5a1XXXTRACEXXX174b8a-f58XXXIDXXX32-01"],
        "ExpiryDateUtc":["The field ExpiryDateUtc is invalid."],
        "access_token": "SomeAccessTokenXXXX1ZWE5ZmY0LTM4MjUtNDc0ZC04ZDhhLTk2OGZjM2NlYTA5ZCIsImlhdCI6IjE3MjI1Mjc1ODI1MjIiLCJhdWQiOlsicGF5bWVudHMiLCJvcmRlcnMiLCJtZXJjaGFudHMiLCJlbGlnaWJpbGl0eS1zZnRwIiwiZWxpZ2liaWxpdHkiLCJjb250YWN0Il0sImN1c3RvbTptaWQiOiJkOWQwYjVmZC05NDMzLTQ0ZDMtODA1MS02M2ZlZTI4NzY4ZTgiLCJuYmYiOjE3MjI1Mjc1ODIsImV4cCI6MTcyMjUyODE4MiwiaXNzIjoiQXBpLUNsaWVudC1TZXJ2aWNlIn0.Q7b5CViX4x3Qmna-JmLS2pQD8kWbrI5-GLLT1Ki9t3o",
        "token_expires": 1722528182522
      }
    RESPONSE
  end
end
