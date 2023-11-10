require 'test_helper'

class PaywayDotComTest < Test::Unit::TestCase
  def setup
    @gateway = PaywayDotComGateway.new(
      login: 'sprerestwsdev',
      password: 'sprerestwsdev1!',
      company_id: '3',
      source_id: '67'
    )
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '5000', response.message[0, 4]
    assert_equal '0987654321', response.params['cardTransaction']['authorizationCode']
    assert_equal '', response.error_code
    assert response.test?
    assert_equal 'Z', response.avs_result['code']
    assert_equal 'M', response.cvv_result['code']
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '5035', response.message[0, 4]
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    auth_only = @gateway.authorize(103, @credit_card, @options)
    assert_success auth_only
    assert_equal '5000', auth_only.message[0, 4]
  end

  def test_successful_authorize_and_capture
    @gateway.expects(:ssl_request).returns(successful_authorize_and_capture_response)

    auth = @gateway.authorize(104, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_request).returns(successful_capture_response)

    assert capture = @gateway.capture(@amount, auth.authorization, @options)
    assert_success capture
    assert_equal '5000', capture.message[0, 4]
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(105, @credit_card, @options)
    assert_failure response
    assert_equal '5035', response.message[0, 4]
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(106, '')
    assert_failure response
    assert_equal '5025', response.message[0, 4]
  end

  def test_successful_credit
    @gateway.expects(:ssl_request).returns(successful_credit_response)

    credit = @gateway.credit(107, @credit_card, @options)
    assert_success credit
    assert_equal '5000', credit.message[0, 4]
  end

  def test_failed_credit
    @gateway.expects(:ssl_request).returns(failed_credit_response)

    response = @gateway.credit(108, @credit_card, @options)
    assert_failure response
    assert_equal '5035', response.message[0, 4]
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_auth_for_void_response)

    auth = @gateway.authorize(109, @credit_card, @options)
    assert_success auth

    @gateway.expects(:ssl_request).returns(successful_void_auth_response)

    assert void = @gateway.void(auth.authorization, @options)
    assert_success void
    assert_equal '5000', void.message[0, 4]
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response
    assert_equal '5025', response.message[0, 4]
  end

  def test_successful_void_of_sale
    @gateway.expects(:ssl_request).returns(successful_sale_for_void_response)

    sale = @gateway.purchase(110, @credit_card, @options)
    assert_success sale

    @gateway.expects(:ssl_request).returns(successful_void_sale_response)

    assert void = @gateway.void(sale.authorization, @options)
    assert_success void
    assert_equal '5000', void.message[0, 4]
  end

  def test_successful_void_of_credit
    @gateway.expects(:ssl_request).returns(successful_credit_for_void_response)

    credit = @gateway.credit(111, @credit_card, @options)
    assert_success credit

    @gateway.expects(:ssl_request).returns(successful_credit_void_response)

    assert void = @gateway.void(credit.authorization, @options)
    assert_success void
    assert_equal '5000', void.message[0, 4]
  end

  def test_invalid_login
    gateway = PaywayDotComGateway.new(login: '', password: '', company_id: '', source_id: '')
    gateway.expects(:ssl_request).returns(failed_invalid_login_response)

    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{5001}, response.message[0, 4]
  end

  def test_missing_source_id
    error = assert_raises(ArgumentError) { PaywayDotComGateway.new(login: '', password: '', company_id: '') }
    assert_equal 'Missing required parameter: source_id', error.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  def test_scrub_failed_purchase
    assert @gateway.supports_scrubbing?
    assert_equal post_scrubbed_failed_purchase, @gateway.scrub(pre_scrubbed_failed_purchase)
  end

  private

  def pre_scrubbed
    %q(
      opening connection to devedgilpayway.net:443...
      opened
      starting SSL for devedgilpayway.net:443...
      SSL established, protocol: TLSv1.2, cipher: AES256-GCM-SHA384
      <- "POST /PaywayWS/Payment/CreditCard HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: devedgilpayway.net\r\nContent-Length: 423\r\n\r\n"
      <- "{\"userName\":\"sprerestwsdev\",\"password\":\"sprerestwsdev1!\",\"companyId\":\"3\",\"accountInputMode\":\"primaryAccountNumber\",\"cardAccount\":{\"accountNumber\":\"4000100011112224\",\"fsv\":\"737\",\"expirationDate\":\"092022\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"address\":\"456 My Street Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"phone\":\"(555)555-5555\"},\"cardTransaction\":{\"amount\":\"100\",\"eciType\":\"1\",\"sourceId\":\"67\"},\"request\":\"sale\"}"
      -> "HTTP/1.1 200 \r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Expose-Headers: Access-Control-Allow-Origin,Access-Control-Allow-Credentials\r\n"
      -> "Content-Encoding: application/json\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 2051\r\n"
      -> "Date: Mon, 22 Mar 2021 19:06:00 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 2051 bytes...
      -> "{\n    \"cardAccount\": {\n        \"accountNotes1\": \"\",\n        \"accountNotes2\": \"\",\n        \"accountNotes3\": \"\",\n        \"accountNumber\": \"400010******2224\",\n        \"account_number_masked\": \"400010******2224\",\n        \"address\": \"456 My Street Apt 1\",\n        \"auLastUpdate\": \"1999-01-01 00:00:00-05\",\n        \"auUpdateType\": 0,\n        \"cardType\": 1,\n        \"city\": \"Ottawa\",\n        \"commercialCardType\": 0,\n        \"divisionId\": 7,\n        \"email\": \"\",\n        \"expirationDate\": \"0922\",\n        \"firstFour\": \"4000\",\n        \"firstName\": \"Jim\",\n        \"fsv\": \"123\",\n        \"inputMode\": 1,\n        \"lastFour\": \"2224\",\n        \"lastName\": \"Smith\",\n        \"lastUsed\": \"1999-01-01 00:00:00-05\",\n        \"middleName\": \"\",\n        \"onlinePaymentCryptogram\": \"\",\n        \"p2peInput\": \"\",\n        \"paywayToken\": 10163736,\n        \"phone\": \"5555555555\",\n        \"state\": \"ON\",\n        \"status\": 2,\n        \"zip\": \"K1C2N6\"\n    },\n    \"cardTransaction\": {\n        \"addressVerificationResults\": \"\",\n        \"amount\": 100,\n        \"authorizationCode\": \"0987654321\",\n        \"authorizedTime\": \"2021-03-22 00:00:00-04\",\n        \"capturedTime\": \"2021-03-22 15:06:00\",\n        \"cbMode\": 2,\n        \"eciType\": 1,\n        \"fraudSecurityResults\": \"\",\n        \"fsvIndicator\": \"\",\n        \"name\": \"6720210322150600930144\",\n        \"pfpstatus\": 3601,\n        \"pfpstatusString\": \"PFP Not Enabled\",\n        \"processorErrorMessage\": \"\",\n        \"processorOrderId\": \"\",\n        \"processorRecurringAdvice\": \"\",\n        \"processorResponseDate\": \"\",\n        \"processorResultCode\": \"\",\n        \"processorSequenceNumber\": 0,\n        \"processorSoftDescriptor\": \"\",\n        \"referenceNumber\": \"123456\",\n        \"resultCode\": 0,\n        \"sessionToken_string\": \"0\",\n        \"settledTime\": \"1999-01-01 00:00\",\n        \"sourceId\": 67,\n        \"status\": 4,\n        \"tax\": 0,\n        \"testResultAVS\": \"\",\n        \"testResultFSV\": \"\",\n        \"transactionNotes1\": \"\",\n        \"transactionNotes2\": \"\",\n        \"transactionNotes3\": \"\"\n    },\n    \"paywayCode\": \"5000\",\n    \"paywayMessage\": \"\"\n}"
      read 2051 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to devedgilpayway.net:443...
      opened
      starting SSL for devedgilpayway.net:443...
      SSL established, protocol: TLSv1.2, cipher: AES256-GCM-SHA384
      <- "POST /PaywayWS/Payment/CreditCard HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: devedgilpayway.net\r\nContent-Length: 423\r\n\r\n"
      <- "{\"userName\":\"sprerestwsdev\",\"password\":\"[FILTERED]\",\"companyId\":\"3\",\"accountInputMode\":\"primaryAccountNumber\",\"cardAccount\":{\"accountNumber\":\"[FILTERED]\",\"fsv\":\"[FILTERED]\",\"expirationDate\":\"092022\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"address\":\"456 My Street Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"phone\":\"(555)555-5555\"},\"cardTransaction\":{\"amount\":\"100\",\"eciType\":\"1\",\"sourceId\":\"67\"},\"request\":\"sale\"}"
      -> "HTTP/1.1 200 \r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Expose-Headers: Access-Control-Allow-Origin,Access-Control-Allow-Credentials\r\n"
      -> "Content-Encoding: application/json\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 2051\r\n"
      -> "Date: Mon, 22 Mar 2021 19:06:00 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 2051 bytes...
      -> "{\n    \"cardAccount\": {\n        \"accountNotes1\": \"\",\n        \"accountNotes2\": \"\",\n        \"accountNotes3\": \"\",\n        \"accountNumber\": \"[FILTERED]\",\n        \"account_number_masked\": \"400010******2224\",\n        \"address\": \"456 My Street Apt 1\",\n        \"auLastUpdate\": \"1999-01-01 00:00:00-05\",\n        \"auUpdateType\": 0,\n        \"cardType\": 1,\n        \"city\": \"Ottawa\",\n        \"commercialCardType\": 0,\n        \"divisionId\": 7,\n        \"email\": \"\",\n        \"expirationDate\": \"0922\",\n        \"firstFour\": \"4000\",\n        \"firstName\": \"Jim\",\n        \"fsv\": \"[FILTERED]\",\n        \"inputMode\": 1,\n        \"lastFour\": \"2224\",\n        \"lastName\": \"Smith\",\n        \"lastUsed\": \"1999-01-01 00:00:00-05\",\n        \"middleName\": \"\",\n        \"onlinePaymentCryptogram\": \"\",\n        \"p2peInput\": \"\",\n        \"paywayToken\": 10163736,\n        \"phone\": \"5555555555\",\n        \"state\": \"ON\",\n        \"status\": 2,\n        \"zip\": \"K1C2N6\"\n    },\n    \"cardTransaction\": {\n        \"addressVerificationResults\": \"\",\n        \"amount\": 100,\n        \"authorizationCode\": \"0987654321\",\n        \"authorizedTime\": \"2021-03-22 00:00:00-04\",\n        \"capturedTime\": \"2021-03-22 15:06:00\",\n        \"cbMode\": 2,\n        \"eciType\": 1,\n        \"fraudSecurityResults\": \"\",\n        \"fsvIndicator\": \"\",\n        \"name\": \"6720210322150600930144\",\n        \"pfpstatus\": 3601,\n        \"pfpstatusString\": \"PFP Not Enabled\",\n        \"processorErrorMessage\": \"\",\n        \"processorOrderId\": \"\",\n        \"processorRecurringAdvice\": \"\",\n        \"processorResponseDate\": \"\",\n        \"processorResultCode\": \"\",\n        \"processorSequenceNumber\": 0,\n        \"processorSoftDescriptor\": \"\",\n        \"referenceNumber\": \"123456\",\n        \"resultCode\": 0,\n        \"sessionToken_string\": \"0\",\n        \"settledTime\": \"1999-01-01 00:00\",\n        \"sourceId\": 67,\n        \"status\": 4,\n        \"tax\": 0,\n        \"testResultAVS\": \"\",\n        \"testResultFSV\": \"\",\n        \"transactionNotes1\": \"\",\n        \"transactionNotes2\": \"\",\n        \"transactionNotes3\": \"\"\n    },\n    \"paywayCode\": \"5000\",\n    \"paywayMessage\": \"\"\n}"
      read 2051 bytes
      Conn close
    )
  end

  def pre_scrubbed_failed_purchase
    %q(
      opening connection to devedgilpayway.net:443...
      opened
      starting SSL for devedgilpayway.net:443...
      SSL established, protocol: TLSv1.2, cipher: AES256-GCM-SHA384
      <- "POST /PaywayWS/Payment/CreditCard HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: devedgilpayway.net\r\nContent-Length: 423\r\n\r\n"
      <- "{\"userName\":\"sprerestwsdev\",\"password\":\"sprerestwsdev1!\",\"companyId\":\"3\",\"accountInputMode\":\"primaryAccountNumber\",\"cardAccount\":{\"accountNumber\":\"4000300011112221\",\"fsv\":\"123\",\"expirationDate\":\"092022\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"address\":\"456 My Street Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"phone\":\"(555)555-5555\"},\"cardTransaction\":{\"amount\":\"102\",\"eciType\":\"1\",\"sourceId\":\"67\"},\"request\":\"sale\"}"
      -> "HTTP/1.1 200 \r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Expose-Headers: Access-Control-Allow-Origin,Access-Control-Allow-Credentials\r\n"
      -> "Content-Encoding: application/json\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 2013\r\n"
      -> "Date: Tue, 23 Mar 2021 15:04:53 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 2013 bytes...
      -> "{\n    \"cardAccount\": {\n        \"accountNotes1\": \"\",\n        \"accountNotes2\": \"\",\n        \"accountNotes3\": \"\",\n        \"accountNumber\": \"400030******2221\",\n        \"account_number_masked\": \"400030******2221\",\n        \"address\": \"456 My Street Apt 1\",\n        \"auLastUpdate\": \"1999-01-01 00:00\",\n        \"auUpdateType\": 0,\n        \"cardType\": 1,\n        \"city\": \"Ottawa\",\n        \"commercialCardType\": 0,\n        \"divisionId\": 7,\n        \"email\": \"\",\n        \"expirationDate\": \"0922\",\n        \"firstFour\": \"4000\",\n        \"firstName\": \"Jim\",\n        \"fsv\": \"123\",\n        \"inputMode\": 1,\n        \"lastFour\": \"2221\",\n        \"lastName\": \"Smith\",\n        \"lastUsed\": \"1999-01-01 00:00\",\n        \"middleName\": \"\",\n        \"onlinePaymentCryptogram\": \"\",\n        \"p2peInput\": \"\",\n        \"paywayToken\": 0,\n        \"phone\": \"5555555555\",\n        \"state\": \"ON\",\n        \"status\": 2,\n        \"zip\": \"K1C2N6\"\n    },\n    \"cardTransaction\": {\n        \"addressVerificationResults\": \"\",\n        \"amount\": 0,\n        \"authorizationCode\": \"\",\n        \"authorizedTime\": \"1999-01-01\",\n        \"capturedTime\": \"1999-01-01\",\n        \"cbMode\": 0,\n        \"eciType\": 0,\n        \"fraudSecurityResults\": \"\",\n        \"fsvIndicator\": \"\",\n        \"name\": \"\",\n        \"pfpstatus\": 3601,\n        \"pfpstatusString\": \"PFP Not Enabled\",\n        \"processorErrorMessage\": \"\",\n        \"processorOrderId\": \"\",\n        \"processorRecurringAdvice\": \"\",\n        \"processorResponseDate\": \"\",\n        \"processorResultCode\": \"\",\n        \"processorSequenceNumber\": 0,\n        \"processorSoftDescriptor\": \"\",\n        \"referenceNumber\": \"\",\n        \"resultCode\": 1,\n        \"sessionToken_string\": \"0\",\n        \"settledTime\": \"1999-01-01 00:00\",\n        \"sourceId\": 0,\n        \"status\": 0,\n        \"tax\": 0,\n        \"testResultAVS\": \"\",\n        \"testResultFSV\": \"\",\n        \"transactionNotes1\": \"\",\n        \"transactionNotes2\": \"\",\n        \"transactionNotes3\": \"\"\n    },\n    \"paywayCode\": \"5035\",\n    \"paywayMessage\": \"Invalid account number: 4000300011112221\"\n}"
      read 2013 bytes
      Conn close
    )
  end

  def post_scrubbed_failed_purchase
    %q(
      opening connection to devedgilpayway.net:443...
      opened
      starting SSL for devedgilpayway.net:443...
      SSL established, protocol: TLSv1.2, cipher: AES256-GCM-SHA384
      <- "POST /PaywayWS/Payment/CreditCard HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nHost: devedgilpayway.net\r\nContent-Length: 423\r\n\r\n"
      <- "{\"userName\":\"sprerestwsdev\",\"password\":\"[FILTERED]\",\"companyId\":\"3\",\"accountInputMode\":\"primaryAccountNumber\",\"cardAccount\":{\"accountNumber\":\"[FILTERED]\",\"fsv\":\"[FILTERED]\",\"expirationDate\":\"092022\",\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"address\":\"456 My Street Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"phone\":\"(555)555-5555\"},\"cardTransaction\":{\"amount\":\"102\",\"eciType\":\"1\",\"sourceId\":\"67\"},\"request\":\"sale\"}"
      -> "HTTP/1.1 200 \r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Expose-Headers: Access-Control-Allow-Origin,Access-Control-Allow-Credentials\r\n"
      -> "Content-Encoding: application/json\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 2013\r\n"
      -> "Date: Tue, 23 Mar 2021 15:04:53 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 2013 bytes...
      -> "{\n    \"cardAccount\": {\n        \"accountNotes1\": \"\",\n        \"accountNotes2\": \"\",\n        \"accountNotes3\": \"\",\n        \"accountNumber\": \"[FILTERED]\",\n        \"account_number_masked\": \"400030******2221\",\n        \"address\": \"456 My Street Apt 1\",\n        \"auLastUpdate\": \"1999-01-01 00:00\",\n        \"auUpdateType\": 0,\n        \"cardType\": 1,\n        \"city\": \"Ottawa\",\n        \"commercialCardType\": 0,\n        \"divisionId\": 7,\n        \"email\": \"\",\n        \"expirationDate\": \"0922\",\n        \"firstFour\": \"4000\",\n        \"firstName\": \"Jim\",\n        \"fsv\": \"[FILTERED]\",\n        \"inputMode\": 1,\n        \"lastFour\": \"2221\",\n        \"lastName\": \"Smith\",\n        \"lastUsed\": \"1999-01-01 00:00\",\n        \"middleName\": \"\",\n        \"onlinePaymentCryptogram\": \"\",\n        \"p2peInput\": \"\",\n        \"paywayToken\": 0,\n        \"phone\": \"5555555555\",\n        \"state\": \"ON\",\n        \"status\": 2,\n        \"zip\": \"K1C2N6\"\n    },\n    \"cardTransaction\": {\n        \"addressVerificationResults\": \"\",\n        \"amount\": 0,\n        \"authorizationCode\": \"\",\n        \"authorizedTime\": \"1999-01-01\",\n        \"capturedTime\": \"1999-01-01\",\n        \"cbMode\": 0,\n        \"eciType\": 0,\n        \"fraudSecurityResults\": \"\",\n        \"fsvIndicator\": \"\",\n        \"name\": \"\",\n        \"pfpstatus\": 3601,\n        \"pfpstatusString\": \"PFP Not Enabled\",\n        \"processorErrorMessage\": \"\",\n        \"processorOrderId\": \"\",\n        \"processorRecurringAdvice\": \"\",\n        \"processorResponseDate\": \"\",\n        \"processorResultCode\": \"\",\n        \"processorSequenceNumber\": 0,\n        \"processorSoftDescriptor\": \"\",\n        \"referenceNumber\": \"\",\n        \"resultCode\": 1,\n        \"sessionToken_string\": \"0\",\n        \"settledTime\": \"1999-01-01 00:00\",\n        \"sourceId\": 0,\n        \"status\": 0,\n        \"tax\": 0,\n        \"testResultAVS\": \"\",\n        \"testResultFSV\": \"\",\n        \"transactionNotes1\": \"\",\n        \"transactionNotes2\": \"\",\n        \"transactionNotes3\": \"\"\n    },\n    \"paywayCode\": \"5035\",\n    \"paywayMessage\": \"Invalid account number: [FILTERED]\"\n}"
      read 2013 bytes
      Conn close
    )
  end

  def successful_purchase_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00:00-05",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00:00-05",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "I4",
        "amount": 100,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-08 00:00:00-05",
        "capturedTime": "2021-02-08 18:17:49",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "M",
        "fsvIndicator": "",
        "name": "6720210208181749349115",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 4,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def failed_purchase_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400030******2221",
        "account_number_masked": "400030******2221",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "123",
        "inputMode": 1,
        "lastFour": "2221",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 0,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 0,
        "authorizationCode": "",
        "authorizedTime": "1999-01-01",
        "capturedTime": "1999-01-01",
        "cbMode": 0,
        "eciType": 0,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "",
        "resultCode": 1,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 0,
        "status": 0,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5035",
      "paywayMessage": "Invalid account number: 4000300011112221"
    }'
  end

  def successful_authorize_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "737",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 0,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 103,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09",
        "capturedTime": "1999-01-01 00:00:00-05",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209084239789167",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 3,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def successful_authorize_and_capture_response
    '{
	    "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "737",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 0,
        "zip": "K1C2N6"
	    },
	    "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 104,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09",
        "capturedTime": "1999-01-01 00:00:00-05",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209085526437200",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 3,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
	    },
	    "paywayCode": "5000",
	    "paywayMessage": ""
	  }'
  end

  def successful_capture_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00:00-05",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00:00-05",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 104,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09 00:00:00-05",
        "capturedTime": "2021-02-09 08:55:26",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209085526437200",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 4,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def failed_authorize_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400030******2221",
        "account_number_masked": "400030******2221",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "123",
        "inputMode": 1,
        "lastFour": "2221",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 0,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 0,
        "authorizationCode": "",
        "authorizedTime": "1999-01-01",
        "capturedTime": "1999-01-01",
        "cbMode": 0,
        "eciType": 0,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "",
        "resultCode": 1,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 0,
        "status": 0,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5035",
      "paywayMessage": "Invalid account number: 4000300011112221"
    }'
  end

  def failed_capture_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "",
        "account_number_masked": "",
        "address": "",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 8,
        "city": "",
        "commercialCardType": 0,
        "divisionId": 0,
        "email": "",
        "expirationDate": "",
        "firstFour": "",
        "firstName": "",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "",
        "lastName": "",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 0,
        "phone": "",
        "state": "",
        "status": 0,
        "zip": ""
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 0,
        "authorizationCode": "",
        "authorizedTime": "1999-01-01",
        "capturedTime": "1999-01-01",
        "cbMode": 0,
        "eciType": 0,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "",
        "resultCode": 1,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 0,
        "status": 0,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5025",
      "paywayMessage": "failed to read transaction with source 0 and name "
    }'
  end

  def successful_credit_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "737",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 0,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 107,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09 13:09:23",
        "capturedTime": "2021-02-09 13:09:23",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209130923241131",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 4,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def failed_credit_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400030******2221",
        "account_number_masked": "400030******2221",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "123",
        "inputMode": 1,
        "lastFour": "2221",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 0,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 0,
        "authorizationCode": "",
        "authorizedTime": "1999-01-01",
        "capturedTime": "1999-01-01",
        "cbMode": 0,
        "eciType": 0,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "",
        "resultCode": 1,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 0,
        "status": 0,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5035",
      "paywayMessage": "Invalid account number: 4000300011112221"
    }'
  end

  def successful_auth_for_void_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "737",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 0,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 108,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09",
        "capturedTime": "1999-01-01 00:00:00-05",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209135306469560",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 3,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def successful_void_auth_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00:00-05",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00:00-05",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 108,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09 00:00:00-05",
        "capturedTime": "1999-01-01 00:00:00-05",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209135306469560",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 6,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def successful_void_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "",
        "account_number_masked": "",
        "address": "",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 8,
        "city": "",
        "commercialCardType": 0,
        "divisionId": 0,
        "email": "",
        "expirationDate": "",
        "firstFour": "",
        "firstName": "",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "",
        "lastName": "",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 0,
        "phone": "",
        "state": "",
        "status": 0,
        "zip": ""
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 0,
        "authorizationCode": "",
        "authorizedTime": "1999-01-01",
        "capturedTime": "1999-01-01",
        "cbMode": 0,
        "eciType": 0,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "",
        "resultCode": 1,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 0,
        "status": 0,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5025",
      "paywayMessage": "failed to read transaction with source 0 and name "
    }'
  end

  def failed_void_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "",
        "account_number_masked": "",
        "address": "",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 8,
        "city": "",
        "commercialCardType": 0,
        "divisionId": 0,
        "email": "",
        "expirationDate": "",
        "firstFour": "",
        "firstName": "",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "",
        "lastName": "",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 0,
        "phone": "",
        "state": "",
        "status": 0,
        "zip": ""
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 0,
        "authorizationCode": "",
        "authorizedTime": "1999-01-01",
        "capturedTime": "1999-01-01",
        "cbMode": 0,
        "eciType": 0,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "",
        "resultCode": 1,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 0,
        "status": 0,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5025",
      "paywayMessage": "failed to read transaction with source 0 and name "
    }'
  end

  def successful_sale_for_void_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00:00-05",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00:00-05",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 109,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09 00:00:00-05",
        "capturedTime": "2021-02-09 13:00:48",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209130047957988",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 4,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def successful_void_sale_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00:00-05",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00:00-05",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 109,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09 00:00:00-05",
        "capturedTime": "2021-02-09 13:00:48-05",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209130047957988",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 6,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def successful_credit_for_void_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "737",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 0,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 110,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09 13:06:33",
        "capturedTime": "2021-02-09 13:06:33",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "6720210209130633236167",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 4,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def successful_credit_void_response
    '{
      "cardAccount": {
        "accountNotes1": "",
        "accountNotes2": "",
        "accountNotes3": "",
        "accountNumber": "400010******2224",
        "account_number_masked": "400010******2224",
        "address": "456 My Street Apt 1",
        "auLastUpdate": "1999-01-01 00:00:00-05",
        "auUpdateType": 0,
        "cardType": 1,
        "city": "Ottawa",
        "commercialCardType": 0,
        "divisionId": 7,
        "email": "",
        "expirationDate": "0922",
        "firstFour": "4000",
        "firstName": "Jim",
        "fsv": "",
        "inputMode": 1,
        "lastFour": "2224",
        "lastName": "Smith",
        "lastUsed": "1999-01-01 00:00:00-05",
        "middleName": "",
        "onlinePaymentCryptogram": "",
        "p2peInput": "",
        "paywayToken": 10163736,
        "phone": "5555555555",
        "state": "ON",
        "status": 2,
        "zip": "K1C2N6"
      },
      "cardTransaction": {
        "addressVerificationResults": "",
        "amount": 110,
        "authorizationCode": "0987654321",
        "authorizedTime": "2021-02-09 14:02:51-05",
        "capturedTime": "2021-02-09 14:02:51-05",
        "cbMode": 2,
        "eciType": 1,
        "fraudSecurityResults": "",
        "fsvIndicator": "",
        "name": "672021020914025188146",
        "pfpstatus": 3601,
        "pfpstatusString": "PFP Not Enabled",
        "processorErrorMessage": "",
        "processorOrderId": "",
        "processorRecurringAdvice": "",
        "processorResponseDate": "",
        "processorResultCode": "",
        "processorSequenceNumber": 0,
        "processorSoftDescriptor": "",
        "referenceNumber": "123456",
        "resultCode": 0,
        "sessionToken_string": "0",
        "settledTime": "1999-01-01 00:00",
        "sourceId": 67,
        "status": 6,
        "tax": 0,
        "testResultAVS": "",
        "testResultFSV": "",
        "transactionNotes1": "",
        "transactionNotes2": "",
        "transactionNotes3": ""
      },
      "paywayCode": "5000",
      "paywayMessage": ""
    }'
  end

  def failed_invalid_login_response
    '{
      "paywayCode": "5001",
      "paywayMessage": "Session timed out or other session error.  Create new session"
    }'
  end
end
