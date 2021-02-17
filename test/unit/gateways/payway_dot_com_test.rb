require 'test_helper'

class PaywayDotComTest < Test::Unit::TestCase
  def setup
    @gateway = PaywayDotComGateway.new(
      login: 'sprerestwsdev',
      password: 'sprerestwsdev1!',
      company_id: '3'
    )
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      source_id: '67'
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
    @gateway2 = PaywayDotComGateway.new(login: '', password: '', company_id: '')
    @gateway2.expects(:ssl_request).returns(failed_invalid_login_response)

    assert response = @gateway2.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{5001}, response.message[0, 4]
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
    opening connection to devedgilpayway.net:443...
    opened
    starting SSL for devedgilpayway.net:443...
    SSL established, protocol: TLSv1.2, cipher: AES256-GCM-SHA384
    <- "{\"userName\":\"sprerestwsdev\",\"password\":\"sprerestwsdev1!\",\"companyId\":\"3\",\"accountInputMode\":\"primaryAccountNumber\",\"cardAccount\":{\"accountNumber\":\"4000100011112224\",\"fsv\":\"737\",\"expirationDate\":\"092022\",\"email\":null,\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"address\":\"456 My Street Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"phone\":\"(555)555-5555\"},\"cardTransaction\":{\"amount\":\"100\",\"eciType\":\"1\",\"idSource\":\"67\"},\"request\":\"sale\"}"
    -> "HTTP/1.1 200 \r\n"
    -> "Access-Control-Allow-Origin: *\r\n"
    -> "Access-Control-Expose-Headers: Access-Control-Allow-Origin,Access-Control-Allow-Credentials\r\n"
    -> "Content-Encoding: application/json\r\n"
    -> "Content-Type: application/json\r\n"
    -> "Content-Length: 2051\r\n"
    )
  end

  def post_scrubbed
    %q(
    opening connection to devedgilpayway.net:443...
    opened
    starting SSL for devedgilpayway.net:443...
    SSL established, protocol: TLSv1.2, cipher: AES256-GCM-SHA384
    <- "{\"userName\":\"sprerestwsdev\",\"password\":\"[FILTERED]\",\"companyId\":\"3\",\"accountInputMode\":\"primaryAccountNumber\",\"cardAccount\":{\"accountNumber\":\"[FILTERED]\",\"fsv\":\"[FILTERED]\",\"expirationDate\":\"092022\",\"email\":null,\"firstName\":\"Jim\",\"lastName\":\"Smith\",\"address\":\"456 My Street Apt 1\",\"city\":\"Ottawa\",\"state\":\"ON\",\"zip\":\"K1C2N6\",\"phone\":\"(555)555-5555\"},\"cardTransaction\":{\"amount\":\"100\",\"eciType\":\"1\",\"idSource\":\"67\"},\"request\":\"sale\"}"
    -> "HTTP/1.1 200 \r\n"
    -> "Access-Control-Allow-Origin: *\r\n"
    -> "Access-Control-Expose-Headers: Access-Control-Allow-Origin,Access-Control-Allow-Credentials\r\n"
    -> "Content-Encoding: application/json\r\n"
    -> "Content-Type: application/json\r\n"
    -> "Content-Length: 2051\r\n"
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
