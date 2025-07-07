require 'test_helper'

class PaysafeTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = PaysafeGateway.new(username: 'username', password: 'password', account_id: 'account_id')
    @credit_card = credit_card
    @mastercard = credit_card('5454545454545454', brand: 'master')
    @amount = 100

    @options = {
      billing_address: address,
      merchant_descriptor: {
        dynamic_descriptor: 'Store Purchase'
      }
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'cddbd29d-4983-4719-983a-c6a862895781', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_mastercard_3ds2
    mc_three_d_secure_2_options = {
      currency: 'EUR',
      three_d_secure: {
        eci: 0,
        cavv: 'AAABBhkXYgAAAAACBxdiENhf7A+=',
        version: '2.1.0',
        ds_transaction_id: 'a3a721f3-b6fa-4cb5-84ea-c7b5c39890a2'
      }
    }
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @mastercard, mc_three_d_secure_2_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"threeDSecureVersion":"2.1.0"/, data)
      assert_match(/"directoryServerTransactionId":"a3a721f3-b6fa-4cb5-84ea-c7b5c39890a2"/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_airline_details
    airline_details = {
      airline_travel_details: {
        passenger_name: 'Joe Smith',
        departure_date: '2021-11-30',
        origin: 'SXF',
        computerized_reservation_system: 'DATS',
        ticket: {
          ticket_number: 9876789,
          is_restricted_ticket: false
        },
        customer_reference_number: 107854099,
        travel_agency: {
          name: 'Sally Travel',
          code: 'AGENTS'
        },
        trip_legs: {
          leg1: {
            flight: {
              carrier_code: 'LH',
              flight_number: '344'
            },
            service_class: 'F',
            is_stop_over_allowed: true,
            departure_date: '2021-11-30'
          },
          leg2: {
            flight: {
              flight_number: '999'
            },
            destination: 'SOF',
            fare_basis: 'VMAY'
          }
        }
      }
    }
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, airline_details)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"airlineTravelDetails"/, data)
      assert_match(/"computerizedReservationSystem":"DATS"/, data)
      assert_match(/"tripLegs":{"leg1":{"flight":{"carrierCode":"LH"/, data)
      assert_match(/"leg2":{"flight":{"flightNumber":"999"/, data)
      assert_match(/"departureDate":"2021-11-30"/, data)
      assert_match(/"travelAgency":{"name":"Sally Travel","code":"AGENTS"}/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials
    stored_credential_options = {
      stored_credential: {
        initial_transaction: true,
        reason_type: 'installment',
        initiator: 'merchant'
      }
    }
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential_options))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(%r{"type":"RECURRING"}, data)
      assert_match(%r{"occurrence":"INITIAL"}, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_external_initial_transaction_id
    stored_credential_options = {
      external_initial_transaction_id: 'abc123',
      stored_credential: {
        initial_transaction: false,
        reason_type: 'unscheduled',
        initiator: 'merchant'
      }
    }
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential_options))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(%r{"type":"TOPUP"}, data)
      assert_match(%r{"occurrence":"SUBSEQUENT"}, data)
      assert_match(%r{"externalInitialTransactionId":"abc123"}, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_funding_transaction
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ funding_transaction: 'SDW_WALLET_TRANSFER' }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(%r("fundingTransaction":{"type":"SDW_WALLET_TRANSFER"}), data)
      assert_match(%r("profile":{.+"merchantCustomerId"), data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '3022', response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '3155d89c-dfff-49a2-9352-b531e69102f7', response.authorization
    assert_equal 'COMPLETED', response.message
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal '3009', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)
    auth = '3155d89c-dfff-49a2-9352-b531e69102f7'

    response = @gateway.capture(@amount, auth)
    assert_success response

    assert_equal '6ee71dc2-00c0-4891-b226-ab741e63f43a', response.authorization
    assert_equal 'PENDING', response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, '')
    assert_failure response

    assert_equal '5023', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)
    auth = 'originaltransactionsauthorization'

    response = @gateway.refund(@amount, auth)
    assert_success response

    assert_equal 'e86fe7c3-9d92-4149-89a9-fd2b3da95b05', response.authorization
    assert_equal 'PENDING', response.message
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)
    auth = 'invalidauthorizationid'

    response = @gateway.refund(@amount, auth)
    assert_failure response

    assert_equal '3407', response.error_code
    assert_equal 'Error(s)- code:3407, message:The settlement referred to by the transaction response ID you provided cannot be found.', response.message
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)
    auth = '3155d89c-dfff-49a2-9352-b531e69102f7'

    response = @gateway.void(auth)
    assert_success response

    assert_equal 'eb4d45ac-35ef-49e8-93d0-58b20a4c470e', response.authorization
    assert_equal 'COMPLETED', response.message
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('')
    assert_failure response

    assert_equal '5023', response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal '493936', response.params['authCode']
  end

  def test_successful_store
    profile_options = {
      phone: '111-222-3456',
      email: 'profile@memail.com',
      date_of_birth: {
        month: 1,
        year: 1979,
        day: 1
      }
    }
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, profile_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"holderName":"Longbob Longsen"/, data)
      assert_match(/"dateOfBirth":{"year":1979,"month":1,"day":1}/, data)
    end.respond_with(successful_store_response)

    assert_success response
  end

  def test_successful_credit
    stub_comms(@gateway, :ssl_request) do
      @gateway.credit(100, @credit_card, @options.merge({ email: 'profile@memail.com', customer_id: SecureRandom.hex(16) }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(%r("profile":{.+"merchantCustomerId"), data)
      assert_match(%r("profile":{.+"email"), data)
      assert_match(%r("profile":{"firstName":"Longbob".+}), data)
      assert_match(%r("profile":{.+"lastName"), data)
      assert_match(%r("merchantDescriptor":{"dynamicDescriptor"), data)
    end.respond_with(successful_credit_response)
  end

  def test_merchant_ref_num_and_order_id
    options = @options.merge({ order_id: '12345678' })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"merchantRefNum":"12345678"/, data)
    end.respond_with(successful_purchase_response)

    assert_success response

    options = @options.merge({ order_id: '12345678', merchant_ref_num: '87654321' })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"merchantRefNum":"87654321"/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_truncate_long_address_fields
    options = {
      billing_address: {
        address1: "This is an extremely long address, it is unreasonably long and we can't allow it.",
        address2: "This is an extremely long address2, it is unreasonably long and we can't allow it.",
        city: 'Lake Chargoggagoggmanchauggagoggchaubunagungamaugg',
        state: 'NC',
        zip: '27701'
      }
    }
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"street":"This is an extremely long address, it is unreasona"/, data)
      assert_match(/"street2":"This is an extremely long address2, it is unreason"/, data)
      assert_match(/"city":"Lake Chargoggagoggmanchauggagoggchaubuna"/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_urls_for_test_and_live_mode
    assert_equal 'https://api.test.paysafe.com/customervault/v1/profiles', @gateway.send(:url, 'profiles')
    assert_equal 'https://api.test.paysafe.com/cardpayments/v1/accounts/account_id/auths', @gateway.send(:url, 'auths')

    @gateway.expects(:test?).returns(false).twice
    assert_equal 'https://api.paysafe.com/customervault/v1/profiles', @gateway.send(:url, 'profiles')
    assert_equal 'https://api.paysafe.com/cardpayments/v1/accounts/account_id/auths', @gateway.send(:url, 'auths')
  end

  def test_api_version
    assert_equal 'v1', @gateway.fetch_version
  end

  private

  def pre_scrubbed
    '
      <- "POST /cardpayments/v1/accounts/1002158490/auths HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic cG1sZS03MTA1MjA6Qi1xYTItMC02MGY1YTg5MS0wLTMwMmMwMjE0NDkwZTdlYjliM2IxOWRlOTRlM2FkNjVhOTcxMGM4MTFmYjc4NzhiZTAyMTQxNzQwM2FiYjgyNmQ1NDg2MDdhZGQ3NTNjNmZhMjE0YjYxYmU5YTdj\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.test.paysafe.com\r\nContent-Length: 443\r\n\r\n"
      <- "{\"amount\":100,\"card\":{\"cardExpiry\":{\"month\":9,\"year\":2022},\"cardNum\":\"4107857757053670\",\"cvv\":\"123\"},\"billingDetails\":{\"street\":\"999 This Way Lane\",\"city\":\"Hereville\",\"state\":\"NC\",\"country\":\"FR\",\"zip\":\"98989\",\"phone\":\"999-9999999\"},\"profile\":{\"firstName\":\"Longbob\",\"lastName\":\"Longsen\"},\"merchantDescriptor\":{\"dynamicDescriptor\":\"Store Purchase\",\"phone\":\"999-8887777\"},\"settleWithAuth\":true,\"merchantRefNum\":\"08498355c7f86bf096dc5f3fe77bd1da\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: envoy\r\n"
      -> "Content-Length: 1324\r\n"
      -> "X-Applicationuid: GUID=f26c8e32-e8a4-435d-a288-703750d8a941\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Envoy-Upstream-Service-Time: 144\r\n"
      -> "Expires: Tue, 10 Aug 2021 16:56:06 GMT\r\n"
      -> "Cache-Control: max-age=0, no-cache, no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Date: Tue, 10 Aug 2021 16:56:06 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: WLSESSIONID=g3Ew_iMEkM_6zDo4AisqhBlyuLi5UbyaVrkLVx3hmj-gOgZeKDl9!-2065395402!6582410; path=/; secure; HttpOnly\r\n"
      -> "\r\n"
      reading 1324 bytes...
      -> "{\"id\":\"f26c8e32-e8a4-435d-a288-703750d8a941\",\"merchantRefNum\":\"08498355c7f86bf096dc5f3fe77bd1da\",\"txnTime\":\"2021-08-10T16:56:06Z\",\"status\":\"COMPLETED\",\"amount\":100,\"settleWithAuth\":true,\"preAuth\":false,\"availableToSettle\":0,\"card\":{\"type\":\"VI\",\"lastDigits\":\"3670\",\"cardExpiry\":{\"month\":9,\"year\":2022}},\"authCode\":\"976920\",\"profile\":{\"firstName\":\"Longbob\",\"lastName\":\"Longsen\"},\"billingDetails\":{\"street\":\"999 This Way Lane\",\"city\":\"Hereville\",\"state\":\"NC\",\"country\":\"FR\",\"zip\":\"98989\",\"phone\":\"999-9999999\"},\"merchantDescriptor\":{\"dynamicDescriptor\":\"Store Purchase\",\"phone\":\"999-8887777\"},\"visaAdditionalAuthData\":{},\"currencyCode\":\"EUR\",\"avsResponse\":\"MATCH\",\"cvvVerification\":\"MATCH\",\"settlements\":[{\"id\":\"f26c8e32-e8a4-435d-a288-703750d8a941\",\"merchantRefNum\":\"08498355c7f86bf096dc5f3fe77bd1da\",\"txnTime\":\"2021-08-10T16:56:06Z\",\"status\":\"PENDING\",\"amount\":100,\"availableToRefund\":100,\"links\":[{\"rel\":\"self\",\"href\":\"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/settlements/f26c8e32-e8a4-435d-a288-703750d8a941\"}]}],\"links\":[{\"rel\":\"settlement\",\"href\":\"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/settlements/f26c8e32-e8a4-435d-a288-703750d8a941\"},{\"rel\":\"self\",\"href\":\"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/auths/f26c8e32-e8a4-435d-a288-703750d8a941\"}]}"
    '
  end

  def post_scrubbed
    '
      <- "POST /cardpayments/v1/accounts/1002158490/auths HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: api.test.paysafe.com\r\nContent-Length: 443\r\n\r\n"
      <- "{\"amount\":100,\"card\":{\"cardExpiry\":{\"month\":9,\"year\":2022},\"cardNum\":\"[FILTERED]\",\"cvv\":\"[FILTERED]\"},\"billingDetails\":{\"street\":\"999 This Way Lane\",\"city\":\"Hereville\",\"state\":\"NC\",\"country\":\"FR\",\"zip\":\"98989\",\"phone\":\"999-9999999\"},\"profile\":{\"firstName\":\"Longbob\",\"lastName\":\"Longsen\"},\"merchantDescriptor\":{\"dynamicDescriptor\":\"Store Purchase\",\"phone\":\"999-8887777\"},\"settleWithAuth\":true,\"merchantRefNum\":\"08498355c7f86bf096dc5f3fe77bd1da\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Server: envoy\r\n"
      -> "Content-Length: 1324\r\n"
      -> "X-Applicationuid: GUID=f26c8e32-e8a4-435d-a288-703750d8a941\r\n"
      -> "Content-Type: application/json\r\n"
      -> "X-Envoy-Upstream-Service-Time: 144\r\n"
      -> "Expires: Tue, 10 Aug 2021 16:56:06 GMT\r\n"
      -> "Cache-Control: max-age=0, no-cache, no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Date: Tue, 10 Aug 2021 16:56:06 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: WLSESSIONID=g3Ew_iMEkM_6zDo4AisqhBlyuLi5UbyaVrkLVx3hmj-gOgZeKDl9!-2065395402!6582410; path=/; secure; HttpOnly\r\n"
      -> "\r\n"
      reading 1324 bytes...
      -> "{\"id\":\"f26c8e32-e8a4-435d-a288-703750d8a941\",\"merchantRefNum\":\"08498355c7f86bf096dc5f3fe77bd1da\",\"txnTime\":\"2021-08-10T16:56:06Z\",\"status\":\"COMPLETED\",\"amount\":100,\"settleWithAuth\":true,\"preAuth\":false,\"availableToSettle\":0,\"card\":{\"type\":\"VI\",\"lastDigits\":\"3670\",\"cardExpiry\":{\"month\":9,\"year\":2022}},\"authCode\":\"976920\",\"profile\":{\"firstName\":\"Longbob\",\"lastName\":\"Longsen\"},\"billingDetails\":{\"street\":\"999 This Way Lane\",\"city\":\"Hereville\",\"state\":\"NC\",\"country\":\"FR\",\"zip\":\"98989\",\"phone\":\"999-9999999\"},\"merchantDescriptor\":{\"dynamicDescriptor\":\"Store Purchase\",\"phone\":\"999-8887777\"},\"visaAdditionalAuthData\":{},\"currencyCode\":\"EUR\",\"avsResponse\":\"MATCH\",\"cvvVerification\":\"MATCH\",\"settlements\":[{\"id\":\"f26c8e32-e8a4-435d-a288-703750d8a941\",\"merchantRefNum\":\"08498355c7f86bf096dc5f3fe77bd1da\",\"txnTime\":\"2021-08-10T16:56:06Z\",\"status\":\"PENDING\",\"amount\":100,\"availableToRefund\":100,\"links\":[{\"rel\":\"self\",\"href\":\"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/settlements/f26c8e32-e8a4-435d-a288-703750d8a941\"}]}],\"links\":[{\"rel\":\"settlement\",\"href\":\"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/settlements/f26c8e32-e8a4-435d-a288-703750d8a941\"},{\"rel\":\"self\",\"href\":\"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/auths/f26c8e32-e8a4-435d-a288-703750d8a941\"}]}"
    '
  end

  def successful_purchase_response
    '{"id":"cddbd29d-4983-4719-983a-c6a862895781","merchantRefNum":"c9b2ad852a1a37c1cc5c39b741be7484","txnTime":"2021-08-10T18:25:40Z","status":"COMPLETED","amount":100,"settleWithAuth":true,"preAuth":false,"availableToSettle":0,"card":{"type":"VI","lastDigits":"3670","cardExpiry":{"month":9,"year":2022}},"authCode":"544454","profile":{"firstName":"Longbob","lastName":"Longsen"},"billingDetails":{"street":"999 This Way Lane","city":"Hereville","state":"NC","country":"FR","zip":"98989","phone":"999-9999999"},"merchantDescriptor":{"dynamicDescriptor":"Store Purchase","phone":"999-8887777"},"visaAdditionalAuthData":{},"currencyCode":"EUR","avsResponse":"MATCH","cvvVerification":"MATCH","settlements":[{"id":"cddbd29d-4983-4719-983a-c6a862895781","merchantRefNum":"c9b2ad852a1a37c1cc5c39b741be7484","txnTime":"2021-08-10T18:25:40Z","status":"PENDING","amount":100,"availableToRefund":100,"links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/settlements/cddbd29d-4983-4719-983a-c6a862895781"}]}],"links":[{"rel":"settlement","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/settlements/cddbd29d-4983-4719-983a-c6a862895781"},{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/auths/cddbd29d-4983-4719-983a-c6a862895781"}]}'
  end

  def failed_purchase_response
    '{"id":"c671d488-3f27-46f1-b0a7-2123e4e68f35","merchantRefNum":"12b616e548d7b866c6a61e6d585a762b","error":{"code":"3022","message":"The card has been declined due to insufficient funds.","links":[{"rel":"errorinfo","href":"https://developer.paysafe.com/en/rest-api/cards/test-and-go-live/card-errors/#ErrorCode3022"}]},"riskReasonCode":[1059],"settleWithAuth":true,"cvvVerification":"MATCH","links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/auths/c671d488-3f27-46f1-b0a7-2123e4e68f35"}]}'
  end

  def successful_authorize_response
    '{"id":"3155d89c-dfff-49a2-9352-b531e69102f7","merchantRefNum":"8b3c5142fdce91299e76a39d89e32bc1","txnTime":"2021-08-10T18:31:26Z","status":"COMPLETED","amount":100,"settleWithAuth":false,"preAuth":false,"availableToSettle":100,"card":{"type":"VI","lastDigits":"3670","cardExpiry":{"month":9,"year":2022}},"authCode":"659078","profile":{"firstName":"Longbob","lastName":"Longsen"},"billingDetails":{"street":"999 This Way Lane","city":"Hereville","state":"NC","country":"FR","zip":"98989","phone":"999-9999999"},"merchantDescriptor":{"dynamicDescriptor":"Store Purchase","phone":"999-8887777"},"visaAdditionalAuthData":{},"currencyCode":"EUR","avsResponse":"MATCH","cvvVerification":"MATCH","links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/auths/3155d89c-dfff-49a2-9352-b531e69102f7"}]}'
  end

  def failed_authorize_response
    '{"id":"bde4a254-7df9-462e-8de1-bfaa205d299a","merchantRefNum":"939b24ab14825b7d365842957dbda683","error":{"code":"3009","message":"Your request has been declined by the issuing bank.","links":[{"rel":"errorinfo","href":"https://developer.paysafe.com/en/rest-api/cards/test-and-go-live/card-errors/#ErrorCode3009"}]},"riskReasonCode":[1100],"settleWithAuth":false,"links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/auths/bde4a254-7df9-462e-8de1-bfaa205d299a"}]}'
  end

  def successful_capture_response
    '{"id":"6ee71dc2-00c0-4891-b226-ab741e63f43a","merchantRefNum":"09bf1e741aa1485ceae9b779e550f929","txnTime":"2021-08-10T18:31:26Z","status":"PENDING","amount":100,"availableToRefund":100,"links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/settlements/6ee71dc2-00c0-4891-b226-ab741e63f43a"}]}'
  end

  def failed_capture_response
    '{"error":{"code":"5023","message":"Request method POST not supported","links":[{"rel":"errorinfo","href":"https://developer.paysafe.com/en/rest-api/cards/test-and-go-live/card-errors/#ErrorCode5023"}]}}'
  end

  def successful_verify_response
    '{"id":"2b48475a-e3e7-47b0-8d84-66a331db9945","merchantRefNum":"fe95dee377466d9a54550c228227c5be","txnTime":"2021-08-18T20:06:55Z","status":"COMPLETED","card":{"type":"VI","lastDigits":"3670","cardExpiry":{"month":9,"year":2022}},"authCode":"493936","profile":{"firstName":"Longbob","lastName":"Longsen"},"billingDetails":{"street":"999 This Way Lane","city":"Hereville","state":"NC","country":"FR","zip":"98989","phone":"999-9999999"},"merchantDescriptor":{"dynamicDescriptor":"Test","phone":"123-1234123"},"visaAdditionalAuthData":{},"currencyCode":"EUR","avsResponse":"NOT_PROCESSED","cvvVerification":"MATCH","links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/verifications/2b48475a-e3e7-47b0-8d84-66a331db9945"}]}'
  end

  def successful_refund_response
    '{"id":"e86fe7c3-9d92-4149-89a9-fd2b3da95b05","merchantRefNum":"b8e04a4ff196b20f8aea42558aec8cbd","txnTime":"2021-08-11T13:40:59Z","status":"PENDING","amount":100,"links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/refunds/e86fe7c3-9d92-4149-89a9-fd2b3da95b05"}]}'
  end

  def failed_refund_response
    '{"id":"0c498606-3690-4b24-a083-0f8a75b8e043","merchantRefNum":"2becb71485cb38c862d2589decce99df","error":{"code":"3407","message":"The settlement referred to by the transaction response ID you provided cannot be found.","links":[{"rel":"errorinfo","href":"https://developer.paysafe.com/en/rest-api/cards/test-and-go-live/card-errors/#ErrorCode3407"}]},"links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/refunds/0c498606-3690-4b24-a083-0f8a75b8e043"}]}'
  end

  def successful_void_response
    '{"id":"eb4d45ac-35ef-49e8-93d0-58b20a4c470e","merchantRefNum":"dbeb1095b191c16715052d4bcc98b42d","txnTime":"2021-08-10T18:35:05Z","status":"COMPLETED","amount":100,"links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002158490/voidauths/eb4d45ac-35ef-49e8-93d0-58b20a4c470e"}]}'
  end

  def failed_void_response
    '{"error":{"code":"5023","message":"Request method POST not supported","links":[{"rel":"errorinfo","href":"https://developer.paysafe.com/en/rest-api/cards/test-and-go-live/card-errors/#ErrorCode5023"}]}}'
  end

  def successful_store_response
    '{"id":"bd4e8c66-b023-4b38-b499-bc6d447d1466","status":"ACTIVE","merchantCustomerId":"965d3aff71fb93343ee48513","locale":"en_US","firstName":"Longbob","lastName":"Longsen","dateOfBirth":{"year":1979,"month":1,"day":1},"paymentToken":"PnCQ1xyGCB4sOEq","phone":"111-222-3456","email":"profile@memail.com","addresses":[],"cards":[{"status":"ACTIVE","id":"77685b40-e953-4999-a161-d13b46a8232a","cardBin":"411111","lastDigits":"1111","cardExpiry":{"year":2022,"month":9},"holderName":"Longbob Longsen","cardType":"VI","cardCategory":"CREDIT","paymentToken":"Ct0RrnyIs4lizeH","defaultCardIndicator":true}]}'
  end

  def successful_credit_response
    '{"id":"b40c327e-92d7-4026-a043-be1f1b03c08a","merchantRefNum":"b0ca10f1ab6b782e6bf8a43e17ff41f8","txnTime":"2024-10-02T19:00:27Z","status":"PENDING","gatewayReconciliationId":"2309329680","amount":100,"card":{"type":"VI", "lastDigits":"0000", "cardExpiry":{"month":9, "year":2025}, "issuingCountry":"US"},"profile":{"firstName":"Longbob", "lastName":"Longsen", "email":"profile@memail.com"},"billingDetails":{"street":"456 My Street","street2":"Apt 1","city":"Ottawa","state":"ON","country":"CA","zip":"K1C2N6","phone":"(555)555-5555"},"currencyCode":"USD","merchantDescriptor":{"dynamicDescriptor":"Store Purchase"},"links":[{"rel":"self","href":"https://api.test.paysafe.com/cardpayments/v1/accounts/1002179730/standalonecredits/b40c327e-92d7-4026-a043-be1f1b03c08a"}]}'
  end
end
