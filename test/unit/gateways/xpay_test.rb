require 'test_helper'

class XpayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = XpayGateway.new(
      api_key: 'some api key'
    )
    @credit_card = credit_card
    @amount = 100
    @base_url = @gateway.test_url
    @options = {
      order_id: 'ngGFbpHStk',
      order: {
        currency: 'EUR',
        amount: @amount,
        customer_info: {
          card_holder_name: 'Ryan Reynolds',
          card_holder_email: nil,
          billing_address: address
        }
      }
    }
    @server_error = stub(code: 500, message: 'Internal Server Error', body: 'failure')
    @uuid_regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
  end

  def test_supported_countries
    assert_equal %w(AT BE CY EE FI FR DE GR IE IT LV LT LU MT PT SK SI ES BG HR DK NO PL RO RO SE CH HU), XpayGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master maestro american_express jcb], @gateway.supported_cardtypes
  end

  def test_build_request_url_for_purchase
    action = :purchase
    assert_equal @gateway.send(:build_request_url, action), "#{@base_url}orders/3steps/payment"
  end

  def test_build_request_url_with_id_param
    action = :refund
    id = 123
    assert_equal @gateway.send(:build_request_url, action, id), "#{@base_url}operations/123/refunds"
  end

  def test_invalid_instance
    assert_raise ArgumentError do
      XpayGateway.new()
    end
  end

  def test_check_request_headers_for_orders
    stub_comms(@gateway, :ssl_post) do
      @gateway.preauth(@amount, @credit_card, @options)
    end.check_request do |_endpoint, _data, headers|
      assert_equal headers['Content-Type'], 'application/json'
      assert_equal headers['X-Api-Key'], 'some api key'
      assert_true @uuid_regex.match?(headers['Correlation-Id'].to_s.downcase)
    end.respond_with(successful_preauth_response)
  end

  def test_check_request_headers_for_operations
    stub_comms(@gateway, :ssl_post) do
      @gateway.capture(@amount, '5e971065-e36a-430d-92e7-716efe515a6d#123', @options)
    end.check_request do |_endpoint, _data, headers|
      assert_equal headers['Content-Type'], 'application/json'
      assert_equal headers['X-Api-Key'], 'some api key'
      assert_true @uuid_regex.match?(headers['Correlation-Id'].to_s.downcase)
      assert_true @uuid_regex.match?(headers['Idempotency-Key'].to_s.downcase)
    end.respond_with(successful_capture_response)
  end

  def test_check_preauth_endpoint
    stub_comms(@gateway, :ssl_post) do
      @gateway.preauth(@amount, @credit_card, @options)
    end.check_request do |endpoint, _data|
      assert_match(/orders\/3steps\/init/, endpoint)
    end.respond_with(successful_preauth_response)
  end

  def test_check_authorize_endpoint
    @gateway.expects(:ssl_post).times(2).returns(successful_validation_response, successful_authorize_response)
    @options[:correlation_id] = 'bb34f2b1-a4ed-4054-a29f-2b908068a17e'
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'bb34f2b1-a4ed-4054-a29f-2b908068a17e#592398610041040779', response.authorization
    assert_equal 'AUTHORIZED', response.message
    assert response.test?
  end

  def test_check_purchase_endpoint
    @options[:correlation_id] = 'bb34f2b1-a4ed-4054-a29f-2b908068a17e'
    @gateway.expects(:ssl_post).times(2).returns(successful_validation_response, successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal 'bb34f2b1-a4ed-4054-a29f-2b908068a17e#249959437570040779', response.authorization
    assert_equal 'EXECUTED', response.message
    assert response.test?
  end

  def test_internal_server_error
    ActiveMerchant::Connection.any_instance.expects(:request).returns(@server_error)
    response = @gateway.preauth(@amount, @credit_card, @options)
    assert_equal response.error_code, 500
    assert_equal response.message, 'failure'
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def successful_preauth_response
    <<-RESPONSE
      {
        "operation":{
          "orderId":"OpkGYfLLkYAiqzyxUNkvpB1WB4e",
          "operationId":"696995050267340689",
          "channel":null,
          "operationType":"AUTHORIZATION",
          "operationResult":"PENDING",
          "operationTime":"2024-03-08 05:22:36.277",
          "paymentMethod":"CARD",
          "paymentCircuit":"VISA",
          "paymentInstrumentInfo":"***4549",
          "paymentEndToEndId":"696995050267340689",
          "cancelledOperationId":null,
          "operationAmount":"100",
          "operationCurrency":"EUR",
          "customerInfo":{
            "cardHolderName":"Amee Kuhlman",
            "cardHolderEmail":null,
            "billingAddress":null,
            "shippingAddress":null,
            "mobilePhoneCountryCode":null,
            "mobilePhone":null,
            "homePhone":null,
            "workPhone":null,
            "cardHolderAcctInfo":null,
            "merchantRiskIndicator":null
          },
          "warnings":[],
          "paymentLinkId":null,
          "omnichannelId":null,
          "additionalData":{
            "maskedPan":"434994******4549",
            "cardId":"952fd84b4562026c9f35345599e1f043d893df720b914619b55d682e7435e13d", "cardId4":"B8PJeZ8PQ+/eWfkqJeZr1HDc7wFaS9sbxVOYwBRC9Ro=",
            "cardExpiryDate":"202605"
          }
        },
        "threeDSEnrollmentStatus":"ENROLLED",
        "threeDSAuthRequest":"notneeded",
        "threeDSAuthUrl":"https://stg-ta.nexigroup.com/monetaweb/phoenixstos"
      }
    RESPONSE
  end

  def successful_validation_response
    <<-RESPONSE
      {"operation":{"additionalData":{"maskedPan":"434994******4549","cardId":"952fd84b4562026c9f35345599e1f043d893df720b914619b55d682e7435e13d","cardId4":"B8PJeZ8PQ+/eWfkqJeZr1HDc7wFaS9sbxVOYwBRC9Ro=","cardExpiryDate":"202612"},"channelDetail":"SERVER_TO_SERVER","customerInfo":{"cardHolderEmail":"Rosalia_VonRueden@gmail.com","cardHolderName":"Walter Mante"},"operationAmount":"100","operationCurrency":"978","operationId":"592398610041040779","operationResult":"THREEDS_VALIDATED","operationTime":"2024-03-17 03:10:21.152","operationType":"AUTHORIZATION","orderId":"304","paymentCircuit":"VISA","paymentEndToEndId":"592398610041040779","paymentInstrumentInfo":"***4549","paymentMethod":"CARD","warnings":[{"code":"003","description":"Warning - BillingAddress: field country code is not valid, the size must be 3 - BillingAddress has not been considered."},{"code":"007","description":"Warning - BillingAddress: field Province code is not valid, the size must be between 1 and 2 - BillingAddress has not been considered."},{"code":"010","description":"Warning - ShippingAddress: field country code is not valid, the size must be 3 - ShippingAddress has not been considered."},{"code":"014","description":"Warning - ShippingAddress: field Province code is not valid, the size must be between 1 and 2 - ShippingAddress has not been considered."}]},"threeDSAuthResult":{"authenticationValue":"AAcBBVYIEQAAAABkl4B3dQAAAAA=","cavvAlgorithm":"3","eci":"05","merchantAcquirerBin":"434495","xid":"S0JvQiFdWC16MzshPy1nMUVtOy8=","status":"VALIDATED","vendorcode":"","version":"2.2.0"}}
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
      {"operation":{"additionalData":{"maskedPan":"434994******4549","authorizationCode":"123456","cardCountry":"380","cardId":"952fd84b4562026c9f35345599e1f043d893df720b914619b55d682e7435e13d","cardType":"MONETA","authorizationStatus":"000","cardId4":"B8PJeZ8PQ+/eWfkqJeZr1HDc7wFaS9sbxVOYwBRC9Ro=","cardExpiryDate":"202612","rrn":"914280154542","schemaTID":"144"},"channelDetail":"SERVER_TO_SERVER","customerInfo":{"cardHolderEmail":"Rosalia_VonRueden@gmail.com","cardHolderName":"Walter Mante"},"operationAmount":"100","operationCurrency":"978","operationId":"592398610041040779","operationResult":"AUTHORIZED","operationTime":"2024-03-17 03:10:23.106","operationType":"AUTHORIZATION","orderId":"304","paymentCircuit":"VISA","paymentEndToEndId":"592398610041040779","paymentInstrumentInfo":"***4549","paymentMethod":"CARD","warnings":[{"code":"003","description":"Warning - BillingAddress: field country code is not valid, the size must be 3 - BillingAddress has not been considered."},{"code":"007","description":"Warning - BillingAddress: field Province code is not valid, the size must be between 1 and 2 - BillingAddress has not been considered."},{"code":"010","description":"Warning - ShippingAddress: field country code is not valid, the size must be 3 - ShippingAddress has not been considered."},{"code":"014","description":"Warning - ShippingAddress: field Province code is not valid, the size must be between 1 and 2 - ShippingAddress has not been considered."}]}}
    RESPONSE
  end

  def successful_purchase_response
    <<-RESPONSE
      {"operation":{"additionalData":{"maskedPan":"434994******4549","authorizationCode":"123456","cardCountry":"380","cardId":"952fd84b4562026c9f35345599e1f043d893df720b914619b55d682e7435e13d","cardType":"MONETA","authorizationStatus":"000","cardId4":"B8PJeZ8PQ+/eWfkqJeZr1HDc7wFaS9sbxVOYwBRC9Ro=","cardExpiryDate":"202612","rrn":"914280154542","schemaTID":"144"},"channelDetail":"SERVER_TO_SERVER","customerInfo":{"cardHolderEmail":"Rosalia_VonRueden@gmail.com","cardHolderName":"Walter Mante"},"operationAmount":"90000","operationCurrency":"978","operationId":"249959437570040779","operationResult":"EXECUTED","operationTime":"2024-03-17 03:14:50.141","operationType":"AUTHORIZATION","orderId":"333","paymentCircuit":"VISA","paymentEndToEndId":"249959437570040779","paymentInstrumentInfo":"***4549","paymentMethod":"CARD","warnings":[{"code":"003","description":"Warning - BillingAddress: field country code is not valid, the size must be 3 - BillingAddress has not been considered."},{"code":"007","description":"Warning - BillingAddress: field Province code is not valid, the size must be between 1 and 2 - BillingAddress has not been considered."},{"code":"010","description":"Warning - ShippingAddress: field country code is not valid, the size must be 3 - ShippingAddress has not been considered."},{"code":"014","description":"Warning - ShippingAddress: field Province code is not valid, the size must be between 1 and 2 - ShippingAddress has not been considered."}]}}
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {"operationId":"30762d01-931a-4083-b1c4-c829902056aa","operationTime":"2024-03-17 03:11:32.677"}
    RESPONSE
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
    opening connection to stg-ta.nexigroup.com:443...
    opened
    starting SSL for stg-ta.nexigroup.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
    <- "POST /api/phoenix-0.0/psp/api/v1/orders/2steps/init HTTP/1.1\r\nContent-Type: application/json\r\nX-Api-Key: 5d952446-9004-4023-9eae-a527a152846b\r\nCorrelation-Id: ngGFbpHStk\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: stg-ta.nexigroup.com\r\nContent-Length: 268\r\n\r\n"
    <- "{\"order\":{\"orderId\":\"ngGFbpHStk\",\"amount\":\"100\",\"currency\":\"EUR\",\"customerInfo\":{\"cardHolderName\":\"John Smith\"}},\"card\":{\"pan\":\"4349940199004549\",\"expiryDate\":\"0526\",\"cvv\":\"396\"},\"recurrence\":{\"action\":\"NO_RECURRING\"},\"exemptions\":\"NO_PREFERENCE\",\"threeDSAuthData\":{}}"
    -> "HTTP/1.1 200 \r\n"
    -> "cid: 2dd22695-c628-41d3-9c11-cdd6a72a59ec\r\n"
    -> "Content-Type: application/json\r\n"
    -> "Content-Length: 970\r\n"
    -> "Date: Tue, 28 Nov 2023 11:41:45 GMT\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 970 bytes...
    -> "{\"operation\":{\"orderId\":\"ngGFbpHStk\",\"operationId\":\"829023675869933329\",\"channel\":null,\"operationType\":\"AUTHORIZATION\",\"operationResult\":\"PENDING\",\"operationTime\":\"2023-11-28 12:41:46.724\",\"paymentMethod\":\"CARD\",\"paymentCircuit\":\"VISA\",\"paymentInstrumentInfo\":\"***4549\",\"paymentEndToEndId\":\"829023675869933329\",\"cancelledOperationId\":null,\"operationAmount\":\"100\",\"operationCurrency\":\"EUR\",\"customerInfo\":{\"cardHolderName\":\"John Smith\",\"cardHolderEmail\":null,\"billingAddress\":null,\"shippingAddress\":null,\"mobilePhoneCountryCode\":null,\"mobilePhone\":null,\"homePhone\":null,\"workPhone\":null,\"cardHolderAcctInfo\":null,\"merchantRiskIndicator\":null},\"warnings\":[],\"paymentLinkId\":null,\"additionalData\":{\"maskedPan\":\"434994******4549\",\"cardId\":\"952fd84b4562026c9f35345599e1f043d893df720b914619b55d682e7435e13d\",\"cardExpiryDate\":\"202605\"}},\"threeDSEnrollmentStatus\":\"ENROLLED\",\"threeDSAuthRequest\":\"notneeded\",\"threeDSAuthUrl\":\"https://stg-ta.nexigroup.com/monetaweb/phoenixstos\"}"
    read 970 bytes
    Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
    opening connection to stg-ta.nexigroup.com:443...
    opened
    starting SSL for stg-ta.nexigroup.com:443...
    SSL established, protocol: TLSv1.3, cipher: TLS_AES_128_GCM_SHA256
    <- "POST /api/phoenix-0.0/psp/api/v1/orders/2steps/init HTTP/1.1\r\nContent-Type: application/json\r\nX-Api-Key: [FILTERED]\r\nCorrelation-Id: ngGFbpHStk\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: stg-ta.nexigroup.com\r\nContent-Length: 268\r\n\r\n"
    <- "{\"order\":{\"orderId\":\"ngGFbpHStk\",\"amount\":\"100\",\"currency\":\"EUR\",\"customerInfo\":{\"cardHolderName\":\"John Smith\"}},\"card\":{\"pan\":\"[FILTERED]\",\"expiryDate\":\"0526\",\"cvv\":\"[FILTERED]\"},\"recurrence\":{\"action\":\"NO_RECURRING\"},\"exemptions\":\"NO_PREFERENCE\",\"threeDSAuthData\":{}}"
    -> "HTTP/1.1 200 \r\n"
    -> "cid: 2dd22695-c628-41d3-9c11-cdd6a72a59ec\r\n"
    -> "Content-Type: application/json\r\n"
    -> "Content-Length: 970\r\n"
    -> "Date: Tue, 28 Nov 2023 11:41:45 GMT\r\n"
    -> "Connection: close\r\n"
    -> "\r\n"
    reading 970 bytes...
    -> "{\"operation\":{\"orderId\":\"ngGFbpHStk\",\"operationId\":\"829023675869933329\",\"channel\":null,\"operationType\":\"AUTHORIZATION\",\"operationResult\":\"PENDING\",\"operationTime\":\"2023-11-28 12:41:46.724\",\"paymentMethod\":\"CARD\",\"paymentCircuit\":\"VISA\",\"paymentInstrumentInfo\":\"***4549\",\"paymentEndToEndId\":\"829023675869933329\",\"cancelledOperationId\":null,\"operationAmount\":\"100\",\"operationCurrency\":\"EUR\",\"customerInfo\":{\"cardHolderName\":\"John Smith\",\"cardHolderEmail\":null,\"billingAddress\":null,\"shippingAddress\":null,\"mobilePhoneCountryCode\":null,\"mobilePhone\":null,\"homePhone\":null,\"workPhone\":null,\"cardHolderAcctInfo\":null,\"merchantRiskIndicator\":null},\"warnings\":[],\"paymentLinkId\":null,\"additionalData\":{\"maskedPan\":\"434994******4549\",\"cardId\":\"952fd84b4562026c9f35345599e1f043d893df720b914619b55d682e7435e13d\",\"cardExpiryDate\":\"202605\"}},\"threeDSEnrollmentStatus\":\"ENROLLED\",\"threeDSAuthRequest\":\"notneeded\",\"threeDSAuthUrl\":\"https://stg-ta.nexigroup.com/monetaweb/phoenixstos\"}"
    read 970 bytes
    Conn close
    POST_SCRUBBED
  end
end
