require 'test_helper'

class Shift4Test < Test::Unit::TestCase
  include CommStub
  def setup
    @gateway = Shift4Gateway.new(client_guid: '123456', auth_token: 'abcder123')
    @credit_card = credit_card('4000100011112224', verification_value: '333', first_name: 'John', last_name: 'Doe')
    @amount = 5
    @options = {}
    @extra_options = {
      clerk_id: '1576',
      notes: 'test notes',
      tax: '2',
      customer_reference: 'D019D09309F2',
      destination_postal_code: '94719',
      product_descriptors: %w(Hamburger Fries Soda Cookie),
      order_id: '123456'
    }
    @customer_address = {
      address1: '123 Street',
      zip: '94901'
    }
  end

  def test_successful_capture
    response = stub_comms do
      @gateway.capture(@amount, '1111g66gw3ryke06', @options)
    end.check_request do |_endpoint, data, headers|
      request = JSON.parse(data)
      assert_nil request['card']['present'], 'N'
      assert_nil request['card']['entryMode']
      assert_nil headers['Invoice']
    end.respond_with(successful_capture_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
    assert_equal response_result(response)['card']['token']['value'].present?, true
  end

  def test_successful_authorize
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.respond_with(successful_authorize_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
    assert_equal response_result(response)['card']['token']['value'].present?, true
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, '1111g66gw3ryke06', @options)
    end.respond_with(successful_purchase_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
    assert_equal response_result(response)['card']['token']['value'].present?, true
  end

  def test_successful_purchase_with_extra_fields
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(@extra_options))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['clerk']['numericId'], @extra_options[:clerk_id]
      assert_equal request['transaction']['notes'], @extra_options[:notes]
      assert_equal request['transaction']['vendorReference'], @extra_options[:order_id]
      assert_equal request['amount']['tax'], @extra_options[:tax].to_f
      assert_equal request['amount']['total'], (@amount / 100.0).to_s
      assert_equal request['transaction']['purchaseCard']['customerReference'], @extra_options[:customer_reference]
      assert_equal request['transaction']['purchaseCard']['destinationPostalCode'], @extra_options[:destination_postal_code]
      assert_equal request['transaction']['purchaseCard']['productDescriptors'], @extra_options[:product_descriptors]
    end.respond_with(successful_purchase_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
  end

  def test_successful_purchase_with_customer_details
    customer = { billing_address: @customer_address, ip: '127.0.0.1', email: 'test@test.com' }
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(customer))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['customer']['addressLine1'], @customer_address[:address1]
      assert_equal request['customer']['postalCode'], @customer_address[:zip]
      assert_equal request['customer']['emailAddress'], customer[:email]
      assert_equal request['customer']['ipAddress'], customer[:ip]
      assert_equal request['customer']['firstName'], @credit_card.first_name
      assert_equal request['customer']['lastName'], @credit_card.last_name
    end.respond_with(successful_purchase_response)

    customer[:billing_address][:zip] = nil
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(customer))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['customer']['postalCode']
    end.respond_with(successful_purchase_response)

    customer[:billing_address][:zip] = ''
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(customer))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['customer']['postalCode']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_stored_credential_framework
    stored_credential_options = {
      initial_transaction: true,
      reason_type: 'recurring'
    }
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_options }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)['transaction']
      assert_equal request['cardOnFile']['usageIndicator'], '01'
      assert_equal request['cardOnFile']['indicator'], '01'
      assert_equal request['cardOnFile']['scheduledIndicator'], '01'
      assert_nil request['cardOnFile']['transactionId']
    end.respond_with(successful_purchase_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'

    stored_credential_options = {
      reason_type: 'recurring',
      network_transaction_id: '123abcdefg'
    }
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ stored_credential: stored_credential_options }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)['transaction']
      assert_equal request['cardOnFile']['usageIndicator'], '02'
      assert_equal request['cardOnFile']['indicator'], '01'
      assert_equal request['cardOnFile']['scheduledIndicator'], '01'
      assert_equal request['cardOnFile']['transactionId'], stored_credential_options[:network_transaction_id]
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_card_on_file_fields
    card_on_file_fields = {
      usage_indicator: '01',
      indicator: '02',
      scheduled_indicator: '01'
    }
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(card_on_file_fields))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)['transaction']
      assert_equal request['cardOnFile']['usageIndicator'], card_on_file_fields[:usage_indicator]
      assert_equal request['cardOnFile']['indicator'], card_on_file_fields[:indicator]
      assert_equal request['cardOnFile']['scheduledIndicator'], card_on_file_fields[:scheduled_indicator]
      assert_nil request['cardOnFile']['transactionId']
    end.respond_with(successful_purchase_response)

    card_on_file_fields = {
      usage_indicator: '02',
      indicator: '01',
      scheduled_indicator: '02',
      transaction_id: 'TXID00001293'
    }
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(card_on_file_fields))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)['transaction']
      assert_equal request['cardOnFile']['usageIndicator'], card_on_file_fields[:usage_indicator]
      assert_equal request['cardOnFile']['indicator'], card_on_file_fields[:indicator]
      assert_equal request['cardOnFile']['scheduledIndicator'], card_on_file_fields[:scheduled_indicator]
      assert_equal request['cardOnFile']['transactionId'], card_on_file_fields[:transaction_id]
    end.respond_with(successful_purchase_response)
  end

  def test_card_on_file_fields_and_stored_credential_framework_combined
    card_on_file_fields = {
      usage_indicator: '02',
      indicator: '02',
      scheduled_indicator: '02'
    }
    stored_credential_options = {
      initial_transaction: true,
      reason_type: 'recurring'
    }
    @options[:stored_credential] = stored_credential_options
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(card_on_file_fields))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)['transaction']
      assert_equal request['cardOnFile']['usageIndicator'], card_on_file_fields[:usage_indicator]
      assert_equal request['cardOnFile']['indicator'], card_on_file_fields[:indicator]
      assert_equal request['cardOnFile']['scheduledIndicator'], card_on_file_fields[:scheduled_indicator]
      assert_nil request['cardOnFile']['transactionId']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_store
    response = stub_comms do
      @gateway.store(@credit_card, @options.merge(@extra_options.except(:tax)))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_nil request['card']['entryMode']
      assert_nil request['clerk']
    end.respond_with(successful_store_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
  end

  def test_successful_refund
    response = stub_comms do
      @gateway.refund(@amount, '1111g66gw3ryke06', @options.merge!(invoice: '4666309473', expiration_date: '1235'))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['card']['present'], 'N'
      assert_equal request['card']['expirationDate'], '1235'
      assert_nil request['card']['entryMode']
      assert_nil request['customer']
    end.respond_with(successful_refund_response)

    assert response.success?
    assert_equal response.message, 'Transaction successful'
  end

  def test_successful_credit
    stub_comms do
      @gateway.refund(@amount, @credit_card, @options.merge!(invoice: '4666309473', expiration_date: '1235'))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['card']['present'], 'N'
      assert_equal request['card']['expirationDate'], @credit_card.expiry_date.expiration.strftime('%m%y')
      assert_nil request['card']['entryMode']
      assert_nil request['customer']
    end.respond_with(successful_refund_response)
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    response = @gateway.void('123')

    assert response.success?
    assert_equal response.message, 'Transaction successful'
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_equal response.message, 'Transaction declined'
    assert_nil response.authorization
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_authorize_with_host_response
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card)
    end.respond_with(failed_authorize_with_host_response)

    assert_failure response
    assert_equal 'CVV value N not accepted.', response.message
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, 'abc', @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(1919, @credit_card, @options)
    assert_failure response
    assert_equal response.error_code, 'D'
    assert_equal response.message, 'Transaction declined'
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('', @options)
    assert_failure response
    assert_nil response.authorization
    assert response.test?
  end

  def test_successful_verify_fields
    card_on_file_fields = {
      usage_indicator: '02',
      indicator: '01',
      scheduled_indicator: '02',
      transaction_id: 'TXID00001293'
    }
    response = stub_comms do
      @gateway.verify(@credit_card, @options.merge(card_on_file_fields))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['transaction']['cardOnFile']['usageIndicator'], card_on_file_fields[:usage_indicator]
      assert_equal request['transaction']['cardOnFile']['indicator'], card_on_file_fields[:indicator]
      assert_equal request['transaction']['cardOnFile']['scheduledIndicator'], card_on_file_fields[:scheduled_indicator]
      assert_equal request['transaction']['cardOnFile']['transactionId'], card_on_file_fields[:transaction_id]
      assert_not_nil request['dateTime']
      assert !request['customer'].nil? && !request['customer'].empty?
      assert_nil request['card']['entryMode']
    end.respond_with(successful_verify_response)

    assert_success response
  end

  def test_successful_verify_with_stored_credential_framework
    stored_credential_options = {
      reason_type: 'recurring',
      network_transaction_id: '123abcdefg'
    }
    stub_comms do
      @gateway.verify(@credit_card, @options.merge({ stored_credential: stored_credential_options }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)['transaction']
      assert_equal request['cardOnFile']['usageIndicator'], '02'
      assert_equal request['cardOnFile']['indicator'], '01'
      assert_equal request['cardOnFile']['scheduledIndicator'], '01'
      assert_equal request['cardOnFile']['transactionId'], stored_credential_options[:network_transaction_id]
    end.respond_with(successful_verify_response)
  end

  def test_card_present_field
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['card']['present'], 'N'
    end.respond_with(successful_purchase_response)

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge({ card_present: 'Y' }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal request['card']['present'], 'Y'
    end.respond_with(successful_purchase_response)
  end

  def test_successful_header_fields
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, _data, headers|
      assert_equal headers['CompanyName'], 'Spreedly'
      assert_equal headers['InterfaceVersion'], '1'
      assert_equal headers['InterfaceName'], 'Spreedly'
    end.respond_with(successful_purchase_response)
  end

  def test_successful_time_zone_offset
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge!(merchant_time_zone: 'EST'))
    end.check_request do |_endpoint, data, _headers|
      assert_equal DateTime.parse(JSON.parse(data)['dateTime']).formatted_offset, Time.now.in_time_zone(@options[:merchant_time_zone]).formatted_offset
    end.respond_with(successful_purchase_response)
  end

  def test_support_scrub
    assert @gateway.supports_scrubbing?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_setup_access_token_should_rise_an_exception_under_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_auth_response)

    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      @gateway.setup_access_token
    end

    assert_match(/Failed with  AuthToken not valid ENGINE22CE/, error.message)
  end

  def test_setup_access_token_should_successfully_extract_the_token_from_response
    @gateway.expects(:ssl_post).returns(sucess_auth_response)

    assert_equal 'abc123', @gateway.setup_access_token
  end

  private

  def response_result(response)
    response.params['result'].first
  end

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to utgapi.shift4test.com:443...
      opened
      starting SSL for utgapi.shift4test.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /api/rest/v1/transactions/authorization HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nCompanyname: Spreedly\r\nAccesstoken: 4902FAD2-E88F-4A8D-98C2-EED2A73DBBE2\r\nInvoice: 1\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: utgapi.shift4test.com\r\nContent-Length: 498\r\n\r\n"
      <- "{\"dateTime\":\"2022-06-09T14:03:36.413505000+14:03\",\"amount\":{\"total\":5.0,\"tax\":1.0},\"clerk\":{\"numericId\":24},\"transaction\":{\"invoice\":\"1\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]}},\"card\":{\"expirationDate\":\"0923\",\"number\":\"4000100011112224\",\"entryMode\":null,\"present\":null,\"securityCode\":{\"indicator\":1,\"value\":\"4444\"}},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"XYZ\",\"lastName\":\"RON\",\"postalCode\":\"89000\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/json; charset=ISO-8859-1\r\n"
      -> "Content-Length: 1074\r\n"
      -> "Date: Thu, 09 Jun 2022 09:03:40 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: deny\r\n"
      -> "Content-Security-Policy: default-src 'none';base-uri 'none';frame-ancestors 'none';object-src 'none';sandbox;\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "Referrer-Policy: no-referrer\r\n"
      -> "X-Powered-By: Electricity\r\n"
      -> "Expires: 0\r\n"
      -> "Cache-Control: private, no-cache, no-store, max-age=0, no-transform\r\n"
      -> "Server: DatasnapHTTPService/2011\r\n"
      -> "\r\n"
      reading 1074 bytes...
      -> ""
      -> "{\"result\":[{\"dateTime\":\"2022-06-09T14:03:36.000-07:00\",\"receiptColumns\":30,\"amount\":{\"tax\":1,\"total\":5},\"card\":{\"type\":\"VS\",\"entryMode\":\"M\",\"number\":\"XXXXXXXXXXXX2224\",\"present\":\"Y\",\"securityCode\":{\"result\":\"N\",\"valid\":\"N\"},\"token\":{\"value\":\"8042728003772224\"}},\"clerk\":{\"numericId\":24},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"XYZ\",\"lastName\":\"RON\",\"postalCode\":\"89000\"},\"device\":{\"capability\":{\"magstripe\":\"Y\",\"manualEntry\":\"Y\"}},\"merchant\":{\"mid\":8504672,\"name\":\"Zippin - Retail\"},\"receipt\":[{\"key\":\"MaskedPAN\",\"printValue\":\"XXXXXXXXXXXX2224\"},{\"key\":\"CardEntryMode\",\"printName\":\"ENTRY METHOD\",\"printValue\":\"KEYED\"},{\"key\":\"SignatureRequired\",\"printValue\":\"N\"}],\"server\":{\"name\":\"UTGAPI05CE\"},\"transaction\":{\"authSource\":\"E\",\"avs\":{\"postalCodeVerified\":\"Y\",\"result\":\"Y\",\"streetVerified\":\"Y\",\"valid\":\"Y\"},\"invoice\":\"0000000001\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]},\"responseCode\":\"D\",\"saleFlag\":\"S\"},\"universalToken\":{\"value\":\"400010-2F1AA405-001AA4-000026B7-1766C44E9E8\"}}]}"
      read 1074 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to utgapi.shift4test.com:443...
      opened
      starting SSL for utgapi.shift4test.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /api/rest/v1/transactions/authorization HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nCompanyname: Spreedly\r\nAccesstoken: 4902FAD2-E88F-4A8D-98C2-EED2A73DBBE2\r\nInvoice: 1\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: utgapi.shift4test.com\r\nContent-Length: 498\r\n\r\n"
      <- "{\"dateTime\":\"2022-06-09T14:03:36.413505000+14:03\",\"amount\":{\"total\":5.0,\"tax\":1.0},\"clerk\":{\"numericId\":24},\"transaction\":{\"invoice\":\"1\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]}},\"card\":{\"expirationDate\":\"[FILTERED]",\"number\":\"[FILTERED]",\"entryMode\":null,\"present\":null,\"securityCode\":{\"indicator\":1,\"value\":\"[FILTERED]\"}},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"[FILTERED]",\"lastName\":\"[FILTERED]",\"postalCode\":\"89000\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Connection: close\r\n"
      -> "Content-Type: text/json; charset=ISO-8859-1\r\n"
      -> "Content-Length: 1074\r\n"
      -> "Date: Thu, 09 Jun 2022 09:03:40 GMT\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Frame-Options: deny\r\n"
      -> "Content-Security-Policy: default-src 'none';base-uri 'none';frame-ancestors 'none';object-src 'none';sandbox;\r\n"
      -> "Strict-Transport-Security: max-age=31536000; includeSubDomains\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "Referrer-Policy: no-referrer\r\n"
      -> "X-Powered-By: Electricity\r\n"
      -> "Expires: 0\r\n"
      -> "Cache-Control: private, no-cache, no-store, max-age=0, no-transform\r\n"
      -> "Server: DatasnapHTTPService/2011\r\n"
      -> "\r\n"
      reading 1074 bytes...
      -> ""
      -> "{\"result\":[{\"dateTime\":\"2022-06-09T14:03:36.000-07:00\",\"receiptColumns\":30,\"amount\":{\"tax\":1,\"total\":5},\"card\":{\"type\":\"VS\",\"entryMode\":\"M\",\"number\":\"[FILTERED]",\"present\":\"Y\",\"securityCode\":{\"result\":\"N\",\"valid\":\"N\"},\"token\":{\"value\":\"8042728003772224\"}},\"clerk\":{\"numericId\":24},\"customer\":{\"addressLine1\":\"89 Main Street\",\"firstName\":\"[FILTERED]",\"lastName\":\"[FILTERED]",\"postalCode\":\"89000\"},\"device\":{\"capability\":{\"magstripe\":\"Y\",\"manualEntry\":\"Y\"}},\"merchant\":{\"mid\":8504672,\"name\":\"Zippin - Retail\"},\"receipt\":[{\"key\":\"MaskedPAN\",\"printValue\":\"XXXXXXXXXXXX2224\"},{\"key\":\"CardEntryMode\",\"printName\":\"ENTRY METHOD\",\"printValue\":\"KEYED\"},{\"key\":\"SignatureRequired\",\"printValue\":\"N\"}],\"server\":{\"name\":\"UTGAPI05CE\"},\"transaction\":{\"authSource\":\"E\",\"avs\":{\"postalCodeVerified\":\"Y\",\"result\":\"Y\",\"streetVerified\":\"Y\",\"valid\":\"Y\"},\"invoice\":\"0000000001\",\"purchaseCard\":{\"customerReference\":\"457\",\"destinationPostalCode\":\"89123\",\"productDescriptors\":[\"Potential\",\"Wrong\"]},\"responseCode\":\"D\",\"saleFlag\":\"S\"},\"universalToken\":{\"value\":\"400010-2F1AA405-001AA4-000026B7-1766C44E9E8\"}}]}"
      read 1074 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<-RESPONSE
      {
          "result": [
              {
                  "dateTime": "2022-02-09T05:11:54.000-08:00",
                  "receiptColumns": 30,
                  "amount": {
                      "total": 5
                  },
                  "card": {
                      "type": "VS",
                      "entryMode": "M",
                      "number": "XXXXXXXXXXXX1111",
                      "present": "N",
                      "securityCode": {
                          "result": "N",
                          "valid": "N"
                      },
                      "token": {
                          "value": "8042714004661111"
                      }
                  },
                  "clerk": {
                      "numericId": 16
                  },
                  "device": {
                      "capability": {
                          "magstripe": "Y",
                          "manualEntry": "Y"
                      }
                  },
                  "merchant": {
                      "mid": 8585812,
                      "name": "RealtimePOS - Retail"
                  },
                  "receipt": [
                      {
                          "key": "MaskedPAN",
                          "printValue": "XXXXXXXXXXXX1111"
                      },
                      {
                          "key": "CardEntryMode",
                          "printName": "ENTRY METHOD",
                          "printValue": "KEYED"
                      },
                      {
                          "key": "SignatureRequired",
                          "printValue": "N"
                      }
                  ],
                  "server": {
                      "name": "UTGAPI12CE"
                  },
                  "transaction": {
                      "authSource": "E",
                      "invoice": "4666309473",
                      "purchaseCard": {
                          "customerReference": "1234567",
                          "destinationPostalCode": "89123",
                          "productDescriptors": [
                              "Test"
                          ]
                      },
                      "responseCode": "A",
                      "saleFlag": "S"
                  },
                  "universalToken": {
                      "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
                  }
              }
          ]
      }
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-06-27T13:06:07.000-07:00",
            "receiptColumns": 30,
            "card": {
              "type": "VS",
              "number": "XXXXXXXXXXXX2224",
              "securityCode": {},
              "token": {
                "value": "22243v5f0vkezpej"
              }
            },
            "merchant": {
              "mid": 8628968
            },
            "server": {
              "name": "UTGAPI11CE"
            },
            "universalToken": {
              "value": "400010-2F1AA405-001AA4-000026B7-1766C44E9E8"
            }
          }
        ]
      }
    RESPONSE
  end

  def successful_authorize_response
    <<-RESPONSE
      {
        "result": [
            {
                "dateTime": "2022-05-02T02:19:38.000-07:00",
                "receiptColumns": 30,
                "amount": {
                    "total": 5
                },
                "card": {
                    "type": "VS",
                    "entryMode": "M",
                    "number": "XXXXXXXXXXXX1111",
                    "present": "N",
                    "securityCode": {},
                    "token": {
                        "value": "8042677003331111"
                    }
                },
                "clerk": {
                    "numericId": 24
                },
                "customer": {
                    "addressLine1": "89 Main Street",
                    "firstName": "XYZ",
                    "lastName": "RON",
                    "postalCode": "89000"
                },
                "device": {
                    "capability": {
                        "magstripe": "Y",
                        "manualEntry": "Y"
                    }
                },
                "merchant": {
                    "mid": 8504672
                },
                "receipt": [
                    {
                        "key": "MaskedPAN",
                        "printValue": "XXXXXXXXXXXX1111"
                    },
                    {
                        "key": "CardEntryMode",
                        "printName": "ENTRY METHOD",
                        "printValue": "KEYED"
                    },
                    {
                        "key": "SignatureRequired",
                        "printValue": "Y"
                    }
                ],
                "server": {
                    "name": "UTGAPI12CE"
                },
                "transaction": {
                    "authorizationCode": "OK168Z",
                    "authSource": "E",
                    "invoice": "3333333309",
                    "purchaseCard": {
                        "customerReference": "457",
                        "destinationPostalCode": "89123",
                        "productDescriptors": [
                            "Potential",
                            "Wrong"
                        ]
                    },
                    "responseCode": "A",
                    "saleFlag": "S"
                },
                "universalToken": {
                    "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
                }
            }
        ]
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
      {
          "result": [
              {
                  "dateTime": "2022-05-08T01:18:22.000-07:00",
                  "receiptColumns": 30,
                  "amount": {
                      "total": 5
                  },
                  "card": {
                      "type": "VS",
                      "entryMode": "M",
                      "number": "XXXXXXXXXXXX1111",
                      "present": "N",
                      "token": {
                          "value": "1111x19h4cryk231"
                      }
                  },
                  "clerk": {
                      "numericId": 24
                  },
                  "device": {
                      "capability": {
                          "magstripe": "Y",
                          "manualEntry": "Y"
                      }
                  },
                  "merchant": {
                      "mid": 8628968
                  },
                  "receipt": [
                      {
                          "key": "MaskedPAN",
                          "printValue": "XXXXXXXXXXXX1111"
                      },
                      {
                          "key": "CardEntryMode",
                          "printName": "ENTRY METHOD",
                          "printValue": "KEYED"
                      },
                      {
                          "key": "SignatureRequired",
                          "printValue": "Y"
                      }
                  ],
                  "server": {
                      "name": "UTGAPI03CE"
                  },
                  "transaction": {
                      "authorizationCode": "OK207Z",
                      "authSource": "E",
                      "invoice": "3333333309",
                      "responseCode": "A",
                      "saleFlag": "S"
                  },
                  "universalToken": {
                      "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
                  }
              }
          ]
      }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-02-09T05:11:54.000-08:00",
            "receiptColumns": 30,
            "amount": {
              "total": 5
            },
            "card": {
              "type": "VS",
              "entryMode": "M",
              "number": "XXXXXXXXXXXX1111",
              "present": "N",
              "securityCode": {
                "result": "N",
                "valid": "N"
              },
              "token": {
                "value": "8042714004661111"
              }
            },
            "clerk": {
              "numericId": 16
            },
            "device": {
              "capability": {
                "magstripe": "Y",
                "manualEntry": "Y"
              }
            },
            "merchant": {
              "mid": 8585812,
              "name": "RealtimePOS - Retail"
            },
            "receipt": [
              {
                "key": "MaskedPAN",
                "printValue": "XXXXXXXXXXXX1111"
              },
              {
                "key": "CardEntryMode",
                "printName": "ENTRY METHOD",
                "printValue": "KEYED"
              },
              {
                "key": "SignatureRequired",
                "printValue": "N"
              }
            ],
            "server": {
              "name": "UTGAPI12CE"
            },
            "transaction": {
              "authSource": "E",
              "invoice": "4666309473",
              "purchaseCard": {
                "customerReference": "1234567",
                "destinationPostalCode": "89123",
                "productDescriptors": [
                  "Test"
                ]
              },
              "responseCode": "A",
              "saleFlag": "S"
            },
            "universalToken": {
              "value": "444433-2D5C1A5C-001624-00001621-16BAAF4ACC6"
            }
          }
        ]
      }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-05-16T14:59:54.000-07:00",
            "receiptColumns": 30,
            "amount": {
              "total": 5
            },
            "card": {
              "type": "VS",
              "entryMode": "M",
              "number": "XXXXXXXXXXXX2224",
              "token": {
                "value": "2224kz7vybyv1gs3"
              }
            },
            "device": {
              "capability": {
                "magstripe": "Y",
                "manualEntry": "Y"
              }
            },
            "merchant": {
              "mid": 8628968
            },
            "receipt": [
              {
                "key": "TransactionResponse",
                "printName": "Response",
                "printValue": "SALE CORRECTION"
              },
              {
                "key": "MaskedPAN",
                "printValue": "XXXXXXXXXXXX2224"
              },
              {
                "key": "CardEntryMode",
                "printName": "ENTRY METHOD",
                "printValue": "KEYED"
              },
              {
                "key": "SignatureRequired",
                "printValue": "N"
              }
            ],
            "server": {
              "name": "UTGAPI07CE"
            },
            "transaction": {
              "authSource": "E",
              "invoice": "0000000001",
              "responseCode": "A",
              "saleFlag": "S"
            }
          }
        ]
      }
    RESPONSE
  end

  def successful_verify_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-09-16T01:40:51.000-07:00",
            "card": {
              "type": "VS",
              "entryMode": "M",
              "number": "XXXXXXXXXXXX2224",
              "present": "N",
              "securityCode": {
                "result": "M",
                "valid": "Y"
              },
              "token": {
                "value": "2224xzsetmjksx13"
              }
            },
            "customer": {
              "firstName": "John",
              "lastName": "Smith"
            },
            "device": {
              "capability": {
                "magstripe": "Y",
                "manualEntry": "Y"
              }
            },
            "merchant": {
              "name": "Spreedly - ECom"
            },
            "server": {
              "name": "UTGAPI12CE"
            },
            "transaction": {
              "authorizationCode": "OK684Z",
              "authSource": "E",
              "responseCode": "A",
              "saleFlag": "S"
            },
            "universalToken": {
              "value": "400010-2F1AA405-001AA4-000026B7-1766C44E9E8"
            }
          }
        ]
      }
    RESPONSE
  end

  def failed_authorize_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "GTV Msg: ERROR{0} 20018: no default category found, UC, Mod10=N TOKEN01CE ENGINE29CE",
                      "primaryCode": 9100,
                      "shortText": "SYSTEM ERROR"
                  },
                  "server": {
                      "name": "UTGAPI12CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def failed_purchase_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime":"2024-01-12T15:11:10.000-08:00",
            "receiptColumns":30,
            "amount": {
              "total":15000000
            },
            "card": {
              "type":"VS",
              "entryMode":"M",
              "number":"XXXXXXXXXXXX2224",
              "present":"N",
              "securityCode": {
                "result":"M",
                "valid":"Y"
              },
              "token": {
                "value":"2224028jbvt7g0ne"
              }
            },
            "clerk": {
              "numericId":1
            },
            "customer": {
              "firstName":"John",
              "lastName":"Smith"
            },
            "device": {
              "capability": {
                "magstripe":"Y",
                "manualEntry":"Y"
              }
            },
            "merchant": {
              "mid":8628968,
              "name":"Spreedly - ECom"
            },
            "receipt": [
              {
                "key":"MaskedPAN",
                "printValue":"XXXXXXXXXXXX2224"
              },
              {
                "key":"CardEntryMode",
                "printName":"ENTRY METHOD",
                "printValue":"KEYED"
              },
              {
                "key":"SignatureRequired",
                "printValue":"N"
              }
            ],
            "server": {
              "name":"UTGAPI11CE"
            },
            "transaction": {
              "authSource":"E",
              "invoice":"0705626580",
              "responseCode":"D",
              "saleFlag":"S"
            },
            "universalToken": {
              "value":"400010-2F1AA405-001AA4-000026B7-1766C44E9E8"
            }
          }
        ]
      }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "INTERNET FAILURE:  Timeout waiting for response across the Internet UTGAPI05CE",
                      "primaryCode": 9961,
                      "shortText": "INTERNET FAILURE"
                  },
                  "server": {
                      "name": "UTGAPI05CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
      {
        "result":
          [
            {
              "dateTime": "2024-01-05T13:38:03.000-08:00",
              "receiptColumns": 30,
              "amount": {
                "total": 19.19
              },
              "card": {
                "type": "VS",
                "entryMode": "M",
                "number": "XXXXXXXXXXXX2224",
                "present": "N",
                "token": {
                  "value": "2224htm77ctttszk"
                }
              },
              "clerk": {
                "numericId": 1
              },
              "device": {
                "capability": {
                  "magstripe": "Y",
                  "manualEntry": "Y"
                }
              },
              "merchant": {
                "name": "Spreedly - ECom"
              },
              "receipt": [
                {
                  "key": "MaskedPAN",
                  "printValue": "XXXXXXXXXXXX2224"
                },
                {
                  "key": "CardEntryMode",
                  "printName": "ENTRY METHOD",
                  "printValue": "KEYED"
                },
                {
                  "key": "SignatureRequired",
                  "printValue": "N"
                }
              ],
              "server":
                {
                  "name": "UTGAPI04CE"
                },
              "transaction":
                {
                  "authSource": "E",
                  "invoice": "0704283292",
                  "responseCode": "D",
                  "saleFlag": "C"
                },
              "universalToken":
                {
                  "value": "400010-2F1AA405-001AA4-000026B7-1766C44E9E8"
                }
            }
          ]
        }
    RESPONSE
  end

  def failed_void_response
    <<-RESPONSE
      {
          "result": [
              {
                  "error": {
                      "longText": "Invoice Not Found 00000000kl 0008628968  ENGINE29CE",
                      "primaryCode": 9815,
                      "shortText": "NO INV"
                  },
                  "server": {
                      "name": "UTGAPI13CE"
                  }
              }
          ]
      }
    RESPONSE
  end

  def successful_access_token_response
    <<-RESPONSE
      {
        "result": [
          {
            "dateTime": "2022-06-22T15:27:51.000-07:00",
            "receiptColumns": 30,
            "credential": {
              "accessToken": "3F6A334E-01E5-4EDB-B4CE-0B1BEFC13518"
            },
            "device": {
              "capability": {
                "magstripe": "Y",
                "manualEntry": "Y"
              }
            },
            "server": {
              "name": "UTGAPI09CE"
            }
          }
        ]
      }
    RESPONSE
  end

  def failed_auth_response
    <<-RESPONSE
      {
        "result": [
          {
            "error": {
              "longText": "AuthToken not valid ENGINE22CE",
              "primaryCode": 9862,
              "secondaryCode": 4,
              "shortText ": "AuthToken"
            },
            "server": {
              "name": "UTGAPI03CE"
            }
          }
        ]
      }
    RESPONSE
  end

  def failed_auth_response_no_message
    <<-RESPONSE
      {
        "result": [
          {
            "error": {
              "secondaryCode": 4,
              "shortText ": "AuthToken"
            },
            "server": {
              "name": "UTGAPI03CE"
            }
          }
        ]
      }
    RESPONSE
  end

  def sucess_auth_response
    <<-RESPONSE
      {
        "result": [
          {
            "credential": {
              "accessToken": "abc123"
            }
          }
        ]
      }
    RESPONSE
  end

  def failed_authorize_with_host_response
    <<-RESPONSE
     {
      "result": [
        {
          "dateTime": "2022-09-16T01:40:51.000-07:00",
          "card": {
            "type": "VS",
            "entryMode": "M",
            "number": "XXXXXXXXXXXX2224",
            "present": "N",
            "securityCode": {
              "result": "M",
              "valid": "Y"
            },
            "token": {
              "value": "2224xzsetmjksx13"
            }
          },
          "customer": {
            "firstName": "John",
            "lastName": "Smith"
          },
          "device": {
            "capability": {
              "magstripe": "Y",
              "manualEntry": "Y"
            }
          },
          "merchant": {
            "name": "Spreedly - ECom"
          },
          "server": {
            "name": "UTGAPI12CE"
          },
          "transaction": {
            "authSource":"E",
            "avs": {
              "postalCodeVerified":"Y",
              "result":"Y",
              "streetVerified":"Y",
              "valid":"Y"
              },
            "cardOnFile": {
              "transactionId":"010512168564062",
              "indicator":"01",
              "scheduledIndicator":"02",
              "usageIndicator":"01"
              },
            "invoice":"0704938459384",
            "hostResponse": {
              "reasonCode":"N7",
              "reasonDescription":"CVV value N not accepted."
              },
            "responseCode":"D",
            "retrievalReference":"400500170391",
            "saleFlag":"S",
            "vendorReference":"2490464558001"
          },
          "universalToken": {
            "value": "400010-2F1AA405-001AA4-000026B7-1766C44E9E8"
          }
        }
      ]
     }
    RESPONSE
  end
end
