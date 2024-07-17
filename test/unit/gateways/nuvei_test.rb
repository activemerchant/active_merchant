require 'test_helper'

class NuveiTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = NuveiGateway.new(
      merchant_id: 'SOMECREDENTIAL',
      merchant_site_id: 'SOMECREDENTIAL',
      secret_key: 'SOMECREDENTIAL',
      session_token: 'fdda0126-674f-4f8c-ad24-31ac846654ab',
      token_expires: Time.now.utc.to_i + 900
    )
    @credit_card = credit_card
    @amount = 100

    @options = {
      email: 'test@gmail.com',
      billing_address: address.merge(name: 'Cure Tester'),
      ip_address: '127.0.0.1'
    }

    @post = {
      merchantId: 'test_merchant_id',
      merchantSiteId: 'test_merchant_site_id',
      clientRequestId: 'test_client_request_id',
      clientUniqueId: 'test_client_unique_id',
      amount: '100',
      currency: 'US',
      relatedTransactionId: 'test_related_transaction_id',
      timeStamp: 'test_time_stamp'
    }
  end

  def test_calculate_checksum_authenticate
    expected_checksum = Digest::SHA256.hexdigest('test_merchant_idtest_merchant_site_idtest_client_request_idtest_time_stampSOMECREDENTIAL')
    assert_equal expected_checksum, @gateway.send(:calculate_checksum, @post, :authenticate)
  end

  def test_calculate_checksum_capture
    expected_checksum = Digest::SHA256.hexdigest('test_merchant_idtest_merchant_site_idtest_client_request_idtest_client_unique_id100UStest_related_transaction_idtest_time_stampSOMECREDENTIAL')
    assert_equal expected_checksum, @gateway.send(:calculate_checksum, @post, :capture)
  end

  def test_calculate_checksum_other
    expected_checksum = Digest::SHA256.hexdigest('test_merchant_idtest_merchant_site_idtest_client_request_id100UStest_time_stampSOMECREDENTIAL')
    assert_equal expected_checksum, @gateway.send(:calculate_checksum, @post, :other)
  end

  def supported_card_types
    assert_equal %i(visa master american_express discover union_pay), NuveiGateway.supported_cardtypes
  end

  def test_supported_countries
    assert_equal %w(US CA IN NZ GB AU US), NuveiGateway.supported_countries
  end

  def build_request_authenticate_url
    action = :authenticate
    assert_equal @gateway.send(:url, action), "#{@gateway.test_url}/getSessionToken"
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_successful_authorize
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      if /payment/.match?(endpoint)
        assert_match(%r(/payment), endpoint)
        assert_match(/Auth/, json_data['transactionType'])
      end
    end.respond_with(successful_authorize_response)
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to ppp-test.nuvei.com:443...
      opened
      starting SSL for ppp-test.nuvei.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      I, [2024-07-22T12:21:29.506576 #65153]  INFO -- : [ActiveMerchant::Billing::NuveiGateway] connection_ssl_version=TLSv1.3 connection_ssl_cipher=TLS_AES_256_GCM_SHA384
      D, [2024-07-22T12:21:29.506622 #65153] DEBUG -- : {"transactionType":"Auth","merchantId":"3755516963854600967","merchantSiteId":"255388","timeStamp":"20240722172128","clientRequestId":"8fdaf176-67e7-4fee-86f7-efa3bfb2df60","clientUniqueId":"e1c3cb6c583be8f475dff7e25a894f81","amount":"100","currency":"USD","paymentOption":{"card":{"cardNumber":"4761344136141390","cardHolderName":"Cure Tester","expirationMonth":"09","expirationYear":"2025","CVV":"999"}},"billingAddress":{"email":"test@gmail.com","country":"CA","firstName":"Cure","lastName":"Tester","phone":"(555)555-5555"},"deviceDetails":{"ipAddress":"127.0.0.1"},"sessionToken":"fdda0126-674f-4f8c-ad24-31ac846654ab","checksum":"577658357a0b2c33e5f567dc52f40e984e50b6fa0344d55abb7849cca9a79741"}
      <- "POST /ppp/api/v1/payment HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer fdda0126-674f-4f8c-ad24-31ac846654ab\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: ppp-test.nuvei.com\r\nContent-Length: 702\r\n\r\n"
      <- "{\"transactionType\":\"Auth\",\"merchantId\":\"3755516963854600967\",\"merchantSiteId\":\"255388\",\"timeStamp\":\"20240722172128\",\"clientRequestId\":\"8fdaf176-67e7-4fee-86f7-efa3bfb2df60\",\"clientUniqueId\":\"e1c3cb6c583be8f475dff7e25a894f81\",\"amount\":\"100\",\"currency\":\"USD\",\"paymentOption\":{\"card\":{\"cardNumber\":\"4761344136141390\",\"cardHolderName\":\"Cure Tester\",\"expirationMonth\":\"09\",\"expirationYear\":\"2025\",\"CVV\":\"999\"}},\"billingAddress\":{\"email\":\"test@gmail.com\",\"country\":\"CA\",\"firstName\":\"Cure\",\"lastName\":\"Tester\",\"phone\":\"(555)555-5555\"},\"deviceDetails\":{\"ipAddress\":\"127.0.0.1\"},\"sessionToken\":\"fdda0126-674f-4f8c-ad24-31ac846654ab\",\"checksum\":\"577658357a0b2c33e5f567dc52f40e984e50b6fa0344d55abb7849cca9a79741\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Server: nginx\r\n"
      -> "Access-Control-Allow-Headers: content-type, X-PINGOTHER\r\n"
      -> "Access-Control-Allow-Methods: GET, POST\r\n"
      -> "P3P: CP=\"ALL ADM DEV PSAi COM NAV OUR OTR STP IND DEM\"\r\n"
      -> "Content-Length: 1103\r\n"
      -> "Date: Mon, 22 Jul 2024 17:21:31 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: JSESSIONID=b766cc7f4ed4fe63f992477fbe27; Path=/ppp; Secure; HttpOnly; SameSite=None\r\n"
      -> "\r\n"
      reading 1103 bytes...
      -> "{\"internalRequestId\":1170828168,\"status\":\"SUCCESS\",\"errCode\":0,\"reason\":\"\",\"merchantId\":\"3755516963854600967\",\"merchantSiteId\":\"255388\",\"version\":\"1.0\",\"clientRequestId\":\"8fdaf176-67e7-4fee-86f7-efa3bfb2df60\",\"sessionToken\":\"fdda0126-674f-4f8c-ad24-31ac846654ab\",\"clientUniqueId\":\"e1c3cb6c583be8f475dff7e25a894f81\",\"orderId\":\"471268418\",\"paymentOption\":{\"userPaymentOptionId\":\"\",\"card\":{\"ccCardNumber\":\"4****1390\",\"bin\":\"476134\",\"last4Digits\":\"1390\",\"ccExpMonth\":\"09\",\"ccExpYear\":\"25\",\"acquirerId\":\"19\",\"cvv2Reply\":\"\",\"avsCode\":\"\",\"cardType\":\"Debit\",\"cardBrand\":\"VISA\",\"issuerBankName\":\"INTL HDQTRS-CENTER OWNED\",\"issuerCountry\":\"SG\",\"isPrepaid\":\"false\",\"threeD\":{},\"processedBrand\":\"VISA\"},\"paymentAccountReference\":\"f4iK2pnudYKvTALGdcwEzqj9p4\"},\"transactionStatus\":\"APPROVED\",\"gwErrorCode\":0,\"gwExtendedErrorCode\":0,\"issuerDeclineCode\":\"\",\"issuerDeclineReason\":\"\",\"transactionType\":\"Auth\",\"transactionId\":\"7110000000001884667\",\"externalTransactionId\":\"\",\"authCode\":\"111144\",\"customData\":\"\",\"fraudDetails\":{\"finalDecision\":\"Accept\",\"score\":\"0\"},\"externalSchemeTransactionId\":\"\",\"merchantAdviceCode\":\"\"}"
      read 1103 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to ppp-test.nuvei.com:443...
      opened
      starting SSL for ppp-test.nuvei.com:443...
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384
      I, [2024-07-22T12:21:29.506576 #65153]  INFO -- : [ActiveMerchant::Billing::NuveiGateway] connection_ssl_version=TLSv1.3 connection_ssl_cipher=TLS_AES_256_GCM_SHA384
      D, [2024-07-22T12:21:29.506622 #65153] DEBUG -- : {"transactionType":"Auth","merchantId":"[FILTERED]","merchantSiteId":"[FILTERED]","timeStamp":"20240722172128","clientRequestId":"8fdaf176-67e7-4fee-86f7-efa3bfb2df60","clientUniqueId":"e1c3cb6c583be8f475dff7e25a894f81","amount":"100","currency":"USD","paymentOption":{"card":{"cardNumber":"[FILTERED]","cardHolderName":"Cure Tester","expirationMonth":"09","expirationYear":"2025","CVV":"999"}},"billingAddress":{"email":"test@gmail.com","country":"CA","firstName":"Cure","lastName":"Tester","phone":"(555)555-5555"},"deviceDetails":{"ipAddress":"127.0.0.1"},"sessionToken":"fdda0126-674f-4f8c-ad24-31ac846654ab","checksum":"577658357a0b2c33e5f567dc52f40e984e50b6fa0344d55abb7849cca9a79741"}
      <- "POST /ppp/api/v1/payment HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer fdda0126-674f-4f8c-ad24-31ac846654ab\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: ppp-test.nuvei.com\r\nContent-Length: 702\r\n\r\n"
      <- "{\"transactionType\":\"Auth\",\"merchantId\":\"[FILTERED]\",\"merchantSiteId\":\"[FILTERED]\",\"timeStamp\":\"20240722172128\",\"clientRequestId\":\"8fdaf176-67e7-4fee-86f7-efa3bfb2df60\",\"clientUniqueId\":\"e1c3cb6c583be8f475dff7e25a894f81\",\"amount\":\"100\",\"currency\":\"USD\",\"paymentOption\":{\"card\":{\"cardNumber\":\"[FILTERED]\",\"cardHolderName\":\"Cure Tester\",\"expirationMonth\":\"09\",\"expirationYear\":\"2025\",\"CVV\":\"999\"}},\"billingAddress\":{\"email\":\"test@gmail.com\",\"country\":\"CA\",\"firstName\":\"Cure\",\"lastName\":\"Tester\",\"phone\":\"(555)555-5555\"},\"deviceDetails\":{\"ipAddress\":\"127.0.0.1\"},\"sessionToken\":\"fdda0126-674f-4f8c-ad24-31ac846654ab\",\"checksum\":\"577658357a0b2c33e5f567dc52f40e984e50b6fa0344d55abb7849cca9a79741\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Server: nginx\r\n"
      -> "Access-Control-Allow-Headers: content-type, X-PINGOTHER\r\n"
      -> "Access-Control-Allow-Methods: GET, POST\r\n"
      -> "P3P: CP=\"ALL ADM DEV PSAi COM NAV OUR OTR STP IND DEM\"\r\n"
      -> "Content-Length: 1103\r\n"
      -> "Date: Mon, 22 Jul 2024 17:21:31 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: JSESSIONID=b766cc7f4ed4fe63f992477fbe27; Path=/ppp; Secure; HttpOnly; SameSite=None\r\n"
      -> "\r\n"
      reading 1103 bytes...
      -> "{\"internalRequestId\":1170828168,\"status\":\"SUCCESS\",\"errCode\":0,\"reason\":\"\",\"merchantId\":\"[FILTERED]\",\"merchantSiteId\":\"[FILTERED]\",\"version\":\"1.0\",\"clientRequestId\":\"8fdaf176-67e7-4fee-86f7-efa3bfb2df60\",\"sessionToken\":\"fdda0126-674f-4f8c-ad24-31ac846654ab\",\"clientUniqueId\":\"e1c3cb6c583be8f475dff7e25a894f81\",\"orderId\":\"471268418\",\"paymentOption\":{\"userPaymentOptionId\":\"\",\"card\":{\"ccCardNumber\":\"4****1390\",\"bin\":\"476134\",\"last4Digits\":\"1390\",\"ccExpMonth\":\"09\",\"ccExpYear\":\"25\",\"acquirerId\":\"19\",\"cvv2Reply\":\"\",\"avsCode\":\"\",\"cardType\":\"Debit\",\"cardBrand\":\"VISA\",\"issuerBankName\":\"INTL HDQTRS-CENTER OWNED\",\"issuerCountry\":\"SG\",\"isPrepaid\":\"false\",\"threeD\":{},\"processedBrand\":\"VISA\"},\"paymentAccountReference\":\"f4iK2pnudYKvTALGdcwEzqj9p4\"},\"transactionStatus\":\"APPROVED\",\"gwErrorCode\":0,\"gwExtendedErrorCode\":0,\"issuerDeclineCode\":\"\",\"issuerDeclineReason\":\"\",\"transactionType\":\"Auth\",\"transactionId\":\"7110000000001884667\",\"externalTransactionId\":\"\",\"authCode\":\"111144\",\"customData\":\"\",\"fraudDetails\":{\"finalDecision\":\"Accept\",\"score\":\"0\"},\"externalSchemeTransactionId\":\"\",\"merchantAdviceCode\":\"\"}"
      read 1103 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_authorize_response
    <<~RESPONSE
      {"internalRequestId":1171104468,"status":"SUCCESS","errCode":0,"reason":"","merchantId":"3755516963854600967","merchantSiteId":"255388","version":"1.0","clientRequestId":"02ba666c-e3e5-4ec9-ae30-3f8500b18c96","sessionToken":"29226538-82c7-4a3c-b363-cb6829b8c32a","clientUniqueId":"c00ed73a7d682bf478295d57bdae3028","orderId":"471361708","paymentOption":{"userPaymentOptionId":"","card":{"ccCardNumber":"4****1390","bin":"476134","last4Digits":"1390","ccExpMonth":"09","ccExpYear":"25","acquirerId":"19","cvv2Reply":"","avsCode":"","cardType":"Debit","cardBrand":"VISA","issuerBankName":"INTL HDQTRS-CENTER OWNED","issuerCountry":"SG","isPrepaid":"false","threeD":{},"processedBrand":"VISA"},"paymentAccountReference":"f4iK2pnudYKvTALGdcwEzqj9p4"},"transactionStatus":"APPROVED","gwErrorCode":0,"gwExtendedErrorCode":0,"issuerDeclineCode":"","issuerDeclineReason":"","transactionType":"Auth","transactionId":"7110000000001908486","externalTransactionId":"","authCode":"111397","customData":"","fraudDetails":{"finalDecision":"Accept","score":"0"},"externalSchemeTransactionId":"","merchantAdviceCode":""}
    RESPONSE
  end
end
