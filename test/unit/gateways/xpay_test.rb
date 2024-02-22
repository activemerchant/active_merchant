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

  def test_check_request_headers
    stub_comms(@gateway, :ssl_post) do
      @gateway.preauth(@amount, @credit_card, @options)
    end.check_request do |_endpoint, _data, headers|
      assert_equal headers['Content-Type'], 'application/json'
      assert_equal headers['X-Api-Key'], 'some api key'
    end.respond_with(successful_preauth_response)
  end

  def test_check_authorize_endpoint
    stub_comms(@gateway, :ssl_post) do
      @gateway.preauth(@amount, @credit_card, @options)
    end.check_request do |endpoint, _data|
      assert_match(/orders\/3steps\/init/, endpoint)
    end.respond_with(successful_purchase_response)
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

  def successful_purchase_response
    <<-RESPONSE
    {"operation":{"orderId":"FBvDOotJJy","operationId":"184228069966633339","channel":null,"operationType":"AUTHORIZATION","operationResult":"PENDING","operationTime":"2023-11-29 21:09:51.828","paymentMethod":"CARD","paymentCircuit":"VISA","paymentInstrumentInfo":"***4549","paymentEndToEndId":"184228069966633339","cancelledOperationId":null,"operationAmount":"100","operationCurrency":"EUR","customerInfo":{"cardHolderName":"Jim Smith","cardHolderEmail":null,"billingAddress":{"name":"Jim Smith","street":"456 My Street","additionalInfo":"Apt 1","city":"Ottawa","postCode":"K1C2N6","province":null,"country":"CA"},"shippingAddress":null,"mobilePhoneCountryCode":null,"mobilePhone":null,"homePhone":null,"workPhone":null,"cardHolderAcctInfo":null,"merchantRiskIndicator":null},"warnings":[],"paymentLinkId":null,"additionalData":{"maskedPan":"434994******4549","cardId":"952fd84b4562026c9f35345599e1f043d893df720b914619b55d682e7435e13d","cardExpiryDate":"202605"}},"threeDSEnrollmentStatus":"ENROLLED","threeDSAuthRequest":"notneeded","threeDSAuthUrl":"https://stg-ta.nexigroup.com/monetaweb/phoenixstos"}
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
