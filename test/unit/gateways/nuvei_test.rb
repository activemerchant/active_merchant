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
    @amount = 10000

    @options = {
      email: 'test@gmail.com',
      billing_address: address.merge(name: 'Cure Tester'),
      ip_address: '127.0.0.1',
      order_id: '123456'
    }

    @three_ds_options = {
      execute_threed: true,
      redirect_url: 'http://www.example.com/redirect',
      callback_url: 'http://www.example.com/callback',
      three_ds_2: {
        browser_info:  {
          width: 390,
          height: 400,
          depth: 24,
          timezone: 300,
          user_agent: 'Spreedly Agent',
          java: false,
          javascript: true,
          language: 'en-US',
          browser_size: '05',
          accept_header: 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        }
      }
    }

    @three_d_secure_options = @options.merge({
      three_d_secure: {
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        eci: '05'
      }
    })

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

    @bank_account = check()

    @apple_pay_card = network_tokenization_credit_card(
      '5204 2452 5046 0049',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      month: '12',
      year: Time.new.year,
      source: :apple_pay,
      verification_value: 111,
      eci: '5'
    )

    @google_pay_card = network_tokenization_credit_card(
      '4761209980011439',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '11',
      year: '2022',
      source: :google_pay,
      verification_value: 111,
      eci: '5'
    )
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

  def test_client_unique_id_present_without_order_id
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_not_nil(json_data['clientUniqueId'])
      end
    end
  end

  def test_successful_authorize
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      if /payment/.match?(endpoint)
        assert_match(%r(/payment), endpoint)
        assert_equal('123456', json_data['clientUniqueId'])
        assert_match(/Auth/, json_data['transactionType'])
      end
    end.respond_with(successful_authorize_response)
  end

  def test_valid_money_format
    assert_equal :dollars, NuveiGateway.money_format
  end

  def test_authorize_sends_decimal_amount
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(10000, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal '100.00', json_data['amount']
    end
  end

  def test_authorize_sends_correct_decimal_amount_with_cents
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(10050, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal '100.50', json_data['amount']
    end
  end

  def test_successful_purchase
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_equal 'false', json_data['savePM']
        assert_match('100.00', json_data['amount'])
        assert_equal('123456', json_data['clientUniqueId'])
        assert_match(/#{@credit_card.number}/, json_data['paymentOption']['card']['cardNumber'])
        assert_match(/#{@credit_card.verification_value}/, json_data['paymentOption']['card']['CVV'])
        assert_match(%r(/payment), endpoint)
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_3ds
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(@three_ds_options))
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      payment_option_card = json_data['paymentOption']['card']
      if /(initPayment|payment)/.match?(endpoint)
        assert_equal '100.00', json_data['amount']
        assert_equal @credit_card.number, payment_option_card['cardNumber']
        assert_equal @credit_card.verification_value, payment_option_card['CVV']
      end
      if /payment/.match?(endpoint)
        assert_not_includes payment_option_card['threeD']['v2AdditionalParams'], 'challengePreference'
        three_ds_assertions(payment_option_card)
      end
    end.respond_with(successful_init_payment_response, successful_purchase_response)
  end

  def test_successful_purchase_with_null_three_ds_2
    stub_comms(@gateway, :ssl_request) do
      options = @options.merge(@three_ds_options)
      options[:three_ds_2] = nil
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      payment_option_card = json_data['paymentOption']['card']
      if /(initPayment|payment)/.match?(endpoint)
        assert_equal '100.00', json_data['amount']
        assert_equal @credit_card.number, payment_option_card['cardNumber']
        assert_equal @credit_card.verification_value, payment_option_card['CVV']
      end

      assert_not_includes payment_option_card, 'threeD' if /payment/.match?(endpoint)
    end.respond_with(successful_init_payment_response, successful_purchase_response)
  end

  def test_successful_purchase_with_3ds_forced
    stub_comms(@gateway, :ssl_request) do
      op = @options.dup
      op[:force_3d_secure] = true
      @gateway.purchase(@amount, @credit_card, op.merge(@three_ds_options))
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      payment_option_card = json_data['paymentOption']['card']
      if /payment/.match?(endpoint)
        assert_equal '01', payment_option_card['threeD']['v2AdditionalParams']['challengePreference']
        three_ds_assertions(payment_option_card)
      end
    end.respond_with(successful_init_payment_response, successful_purchase_response)
  end

  def test_successful_purchase_with_3ds_exception
    stub_comms(@gateway, :ssl_request) do
      op = @options.dup
      op[:force_3d_secure] = false
      @gateway.purchase(@amount, @credit_card, op.merge(@three_ds_options))
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      payment_option_card = json_data['paymentOption']['card']
      if /payment/.match?(endpoint)
        assert_equal '02', payment_option_card['threeD']['v2AdditionalParams']['challengePreference']
        three_ds_assertions(payment_option_card)
      end
    end.respond_with(successful_init_payment_response, successful_purchase_response)
  end

  def test_not_enrolled_card_purchase_with_3ds
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(@three_ds_options))
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      payment_option_card = json_data['paymentOption']['card']
      if /(initPayment|payment)/.match?(endpoint)
        assert_equal '100.00', json_data['amount']
        assert_equal @credit_card.number, payment_option_card['cardNumber']
        assert_equal @credit_card.verification_value, payment_option_card['CVV']
      end
      assert_not_includes payment_option_card, 'threeD' if /payment/.match?(endpoint)
    end.respond_with(not_enrolled_3ds_init_payment_response, successful_purchase_response)
    assert_equal response.message, 'APPROVED'
  end

  def test_not_enrolled_card_purchase_with_3ds_and_forced
    op = @options.dup
    op[:force_3d_secure] = true
    response = stub_comms(@gateway, :ssl_request) do
                 @gateway.purchase(@amount, @credit_card, op.merge(@three_ds_options))
               end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      payment_option_card = json_data['paymentOption']['card']
      if /(initPayment|payment)/.match?(endpoint)
        assert_equal '100.00', json_data['amount']
        assert_equal @credit_card.number, payment_option_card['cardNumber']
        assert_equal @credit_card.verification_value, payment_option_card['CVV']
      end
      assert_not_includes payment_option_card, 'threeD' if /payment/.match?(endpoint)
    end.respond_with(not_enrolled_3ds_init_payment_response, successful_purchase_response)
    assert_equal response.message, '3D Secure is required but not supported'
  end

  def test_successful_refund
    stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, '123456', @options)
    end.check_request(skip_response: true) do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      if /refundTransaction/.match?(endpoint)
        assert_match(/123456/, json_data['relatedTransactionId'])
        assert_match('100.00', json_data['amount'])
      end
    end
  end

  def test_successful_partial_approval
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(55, @credit_card, @options.merge(is_partial_approval: true))
    end.check_request(skip_response: true) do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_equal 1, json_data['isPartialApproval']
      end
    end
  end

  def test_successful_unreferenced_refund
    stub_comms(@gateway, :ssl_request) do
      @gateway.credit(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_match(/refund/, endpoint)
      assert_match('100.00', json_data['amount'])
      assert_match(/#{@credit_card.number}/, json_data['paymentOption']['card']['cardNumber'])
    end.respond_with(successful_purchase_response)
  end

  def test_successful_payout
    stub_comms(@gateway, :ssl_request) do
      @gateway.credit(@amount, @credit_card, @options.merge(user_payment_option_id: '12345678', is_payout: true))
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_match(/payout/, endpoint)
      assert_match(/#{@credit_card.number}/, json_data['cardData']['cardNumber'])
    end.respond_with(successful_purchase_response)
  end

  def test_successful_payout_with_google_pay
    stub_comms(@gateway, :ssl_request) do
      @gateway.credit(@amount, @apple_pay_card, @options.merge(user_payment_option_id: '12345678', is_payout: true))
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_match(/payout/, endpoint)
      assert_match('12345678', json_data['userPaymentOption']['userPaymentOptionId'])
    end.respond_with(successful_purchase_response)
  end

  def test_successful_store
    stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      if /payment/.match?(endpoint)
        assert_equal 'true', json_data['savePM']
        assert_match(/#{@credit_card.number}/, json_data['paymentOption']['card']['cardNumber'])
        assert_equal '0.00', json_data['amount']
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_stored_credentials_cardholder_unscheduled
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential: stored_credential(:cardholder, :unscheduled, :initial)))
    end.check_request do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_equal('0', json_data['isRebilling'])
        assert_equal('0', json_data['paymentOption']['card']['storedCredentials']['storedCredentialsMode'])
        assert_match(/ADDCARD/, json_data['authenticationOnlyType'])
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_stored_credentials_merchant_recurring
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(stored_credential: stored_credential(:merchant, :recurring, id: 'abc123')))
    end.check_request do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_equal('1', json_data['isRebilling'])
        assert_equal('1', json_data['paymentOption']['card']['storedCredentials']['storedCredentialsMode'])
        assert_match(/abc123/, json_data['relatedTransactionId'])
        assert_match(/RECURRING/, json_data['authenticationOnlyType'])
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_authorize_bank_account
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(1.25, @bank_account, @options)
    end.check_request(skip_response: true) do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      if /payment/.match?(endpoint)
        assert_equal('apmgw_ACH', json_data['paymentOption']['alternativePaymentMethod']['paymentMethod'])
        assert_match(/#{@bank_account.routing_number}/, json_data['paymentOption']['alternativePaymentMethod']['RoutingNumber'])
        assert_match(/#{@bank_account.account_number}/, json_data['paymentOption']['alternativePaymentMethod']['AccountNumber'])
      end
    end
  end

  def test_successful_verify
    @options.merge!(authentication_only_type: 'ACCOUNTVERIFICATION')
    stub_comms(@gateway, :ssl_request) do
      @gateway.verify(@credit_card, @options)
    end.check_request(skip_response: true) do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_match(/Auth/, json_data['transactionType'])
        assert_match(/ACCOUNTVERIFICATION/, json_data['authenticationOnlyType'])
        assert_equal '0.00', json_data['amount']
      end
    end
  end

  def test_add_3ds_global_params
    stub_comms do
      @gateway.authorize(@amount, @credit_card, @three_d_secure_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_equal 'jJ81HADVRtXfCBATEp01CJUAAAA', JSON.parse(data)['threeD']['cavv']
      assert_equal '97267598-FAE6-48F2-8083-C23433990FBC', JSON.parse(data)['threeD']['dsTransactionId']
      assert_equal '05', JSON.parse(data)['threeD']['eci']
    end.respond_with(successful_authorize_response)
  end

  def test_add_3ds_global_params_with_challenge_preference
    chellange_preference_params = {
      challenge_preference: 'ExemptionRequest',
      exemption_request_reason: 'AccountVerification'
    }

    stub_comms do
      @gateway.purchase(@amount, @credit_card, @three_d_secure_options.merge(chellange_preference_params))
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      assert_equal 'ExemptionRequest', JSON.parse(data)['threeD']['externalMpi']['challenge_preference']
      assert_equal 'AccountVerification', JSON.parse(data)['threeD']['externalMpi']['exemptionRequestReason']
    end
  end

  def test_successful_purchase_with_apple_pay
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @apple_pay_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_equal 'ApplePay', json_data['paymentOption']['card']['externalToken']['externalTokenProvider']
        assert_not_nil json_data['paymentOption']['card']['externalToken']['cryptogram']
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_google_pay
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @google_pay_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_equal 'GooglePay', json_data['paymentOption']['card']['externalToken']['externalTokenProvider']
        assert_not_nil json_data['paymentOption']['card']['externalToken']['cryptogram']
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_account_funding_transactions
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(is_aft: true, aft_recipient_first_name: 'John', aft_recipient_last_name: 'Doe'))
    end.check_request do |_method, endpoint, data, _headers|
      if /payment/.match?(endpoint)
        json_data = JSON.parse(data)
        assert_match('John', json_data['recipientDetails']['firstName'])
        assert_match('Doe', json_data['recipientDetails']['lastName'])
        assert_match(@credit_card.first_name, json_data['billingAddress']['firstName'])
        assert_match(@credit_card.last_name, json_data['billingAddress']['lastName'])
        assert_match(@options[:billing_address][:address1], json_data['billingAddress']['address'])
        assert_match(@options[:billing_address][:city], json_data['billingAddress']['city'])
        assert_match(@options[:billing_address][:state], json_data['billingAddress']['state'])
        assert_match(@options[:billing_address][:country], json_data['billingAddress']['country'])
      end
    end.respond_with(successful_purchase_response)
  end

  def test_successful_authorize_cardholder_name_verification
    @options.merge!(perform_name_verification: true)

    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, endpoint, data, _headers|
      json_data = JSON.parse(data)
      if /payment/.match?(endpoint)
        assert_match(%r(/payment), endpoint)
        assert_match(/Auth/, json_data['transactionType'])
        assert_equal 'true', json_data['cardHolderNameVerification']['performNameVerification']
        assert_equal 'Longbob', @credit_card.first_name
        assert_equal 'Longsen', @credit_card.last_name
      end
    end.respond_with(successful_authorize_response)
  end

  private

  def three_ds_assertions(payment_option_card)
    assert_equal @three_ds_options[:three_ds_2][:browser_info][:depth], payment_option_card['threeD']['browserDetails']['colorDepth']
    assert_equal @three_ds_options[:three_ds_2][:browser_info][:height], payment_option_card['threeD']['browserDetails']['screenHeight']
    assert_equal @three_ds_options[:three_ds_2][:browser_info][:width], payment_option_card['threeD']['browserDetails']['screenWidth']
    assert_equal @three_ds_options[:three_ds_2][:browser_info][:timezone], payment_option_card['threeD']['browserDetails']['timeZone']
    assert_equal @three_ds_options[:three_ds_2][:browser_info][:user_agent], payment_option_card['threeD']['browserDetails']['userAgent']
    assert_equal @three_ds_options[:callback_url], payment_option_card['threeD']['notificationURL']
    assert_equal 'U', payment_option_card['threeD']['methodCompletionInd']
    assert_equal '02', payment_option_card['threeD']['platformType']
  end

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

  def successful_purchase_response
    <<~RESPONSE
      {"internalRequestId":1172848838, "status":"SUCCESS", "errCode":0, "reason":"", "merchantId":"3755516963854600967", "merchantSiteId":"255388", "version":"1.0", "clientRequestId":"a114381a-0f88-46d0-920c-7b5614f29e5b", "sessionToken":"d3424c9c-dd6d-40dc-85da-a2b92107cbe3", "clientUniqueId":"3ba2a81c46d78837ea819d9f3fe644e7", "orderId":"471833818", "paymentOption":{"userPaymentOptionId":"", "card":{"ccCardNumber":"4****1390", "bin":"476134", "last4Digits":"1390", "ccExpMonth":"09", "ccExpYear":"25", "acquirerId":"19", "cvv2Reply":"", "avsCode":"", "cardType":"Debit", "cardBrand":"VISA", "issuerBankName":"INTL HDQTRS-CENTER OWNED", "issuerCountry":"SG", "isPrepaid":"false", "threeD":{}, "processedBrand":"VISA"}, "paymentAccountReference":"f4iK2pnudYKvTALGdcwEzqj9p4"}, "transactionStatus":"APPROVED", "gwErrorCode":0, "gwExtendedErrorCode":0, "issuerDeclineCode":"", "issuerDeclineReason":"", "transactionType":"Sale", "transactionId":"7110000000001990927", "externalTransactionId":"", "authCode":"111711", "customData":"", "fraudDetails":{"finalDecision":"Accept", "score":"0"}, "externalSchemeTransactionId":"", "merchantAdviceCode":""}
    RESPONSE
  end

  def successful_init_payment_response
    <<~RESPONSE
      {
        "internalRequestId":1281786978,
        "status":"SUCCESS",
        "errCode":0,
        "reason":"",
        "merchantId":"SomeMerchantId",
        "merchantSiteId":"2XXXXX8",
        "version":"1.0",
        "clientRequestId":"7XXXXXXXXXXXXXXXXXXXXXXXXf0",
        "sessionToken":"6XXXXXXXXXXXXXXXXXXXXX7",
        "clientUniqueId":"SOMEe5CLIENTXxXxXId",
        "orderId":"489593998",
        "transactionId":"7110000000004854308",
        "transactionType":"InitAuth3D",
        "transactionStatus":"APPROVED",
        "gwErrorCode":0,
        "gwExtendedErrorCode":0,
        "paymentOption":
         {"card":
           {"ccCardNumber":"2****7736",
            "bin":"222100",
            "last4Digits":"7736",
            "ccExpMonth":"09",
            "ccExpYear":"25",
            "acquirerId":"19",
            "threeD":
             {"methodUrl":"https://3dsn.sandbox.safecharge.com/ThreeDSMethod/api/ThreeDSMethod/threeDSMethodURL",
              "version":"2.1.0",
              "v2supported":"true",
              "methodPayload":
               "eyJ0PaYloADRTU2VyPaYloADhbnNJRCI6PaYloAD0OPaYloADNWMtPaYloAD4NjPaYloADjM2PaYloAD1ZSIPaYloADVlRPaYloADb2ROPaYloADjYXRpPaYloADi",
              "directoryServerId":"A000000004",
              "directoryServerPublicKey":
               "rsa:rsaRASKsdkanzsclajs,cbaksjcbaksj,cmxazx",
              "serverTransId":"21374830-445c-4fdf-8619-d7b36a67cd5e"},
            "processedBrand":"MASTERCARD"}},
        "customData":""}
    RESPONSE
  end

  def not_enrolled_3ds_init_payment_response
    <<~RESPONSE
        {
      "internalRequestId":1281786978,
             "status":"SUCCESS",
             "errCode":0,
             "reason":"",
             "merchantId":"SomeMerchantId",
             "merchantSiteId":"2XXXXX8",
             "version":"1.0",
             "clientRequestId":"7XXXXXXXXXXXXXXXXXXXXXXXXf0",
             "sessionToken":"6XXXXXXXXXXXXXXXXXXXXX7",
             "clientUniqueId":"SOMEe5CLIENTXxXxXId",
             "orderId":"489593998",
             "transactionId":"7110000000004854308",
             "transactionType":"InitAuth3D",
             "transactionStatus":"APPROVED",
             "gwErrorCode":0,
             "gwExtendedErrorCode":0,
             "paymentOption":
           {"card":
             {"ccCardNumber":"2****7736",
              "bin":"222100",
              "last4Digits":"7736",
              "ccExpMonth":"09",
              "ccExpYear":"25",
              "acquirerId":"19",
              "threeD":
               {"methodUrl":"",
                "version":"",
                "v2supported":"false",
                "methodPayload":
                 "",
                "directoryServerId":"",
                "directoryServerPublicKey":"",
                "serverTransId":""},
              "processedBrand":"MASTERCARD"}},
          "customData":""}
    RESPONSE
  end

  def successful_3ds_flow_response
    <<~RESPONSE
         {"internalRequestId":1281822938,
      "status":"SUCCESS",
      "errCode":0,
      "reason":"",
      "merchantId":"3755516963854600967",
      "merchantSiteId":"255388",
      "version":"1.0",
      "clientRequestId":"8f8efbef-3346-47f9-9fcb-2fe74de5d13a",
      "sessionToken":"96893d76-93af-483d-93b4-7e03b6c5f397",
      "clientUniqueId":"660c0fa000b47fd2e9b2071923a97537",
      "orderId":"489602168",
      "paymentOption":
       {"userPaymentOptionId":"",
        "card":
         {"ccCardNumber":"2****7736",
          "bin":"222100",
          "last4Digits":"7736",
          "ccExpMonth":"09",
          "ccExpYear":"25",
          "acquirerId":"19",
          "cvv2Reply":"",
          "avsCode":"",
          "cardBrand":"MASTERCARD",
          "issuerBankName":"",
          "isPrepaid":"false",
          "threeD":
           {"threeDFlow":"1",
            "eci":"7",
            "version":"",
            "whiteListStatus":"",
            "cavv":"",
            "acsChallengeMandated":"N",
            "cReq":"",
            "authenticationType":"",
            "cardHolderInfoText":"",
            "sdk":{"acsSignedContent":""},
            "xid":"",
            "result":"",
            "acsTransID":"",
            "dsTransID":"",
            "threeDReasonId":"",
            "isExemptionRequestInAuthentication":"0",
            "challengePreferenceReason":"12",
            "flow":"none",
            "acquirerDecision":"ExemptionRequest",
            "decisionReason":"NoPreference"},
          "processedBrand":"MASTERCARD"}},
      "transactionStatus":"ERROR",
      "gwErrorCode":-1100,
      "gwErrorReason":"sg_transaction must be of type InitAuth3D, Approved and the same merchant",
      "gwExtendedErrorCode":1271,
      "issuerDeclineCode":"",
      "issuerDeclineReason":"",
      "transactionType":"Auth3D",
      "transactionId":"7110000000004856095",
      "externalTransactionId":"",
      "authCode":"",
      "customData":"",
      "externalSchemeTransactionId":"",
      "merchantAdviceCode":""}
    RESPONSE
  end
end
