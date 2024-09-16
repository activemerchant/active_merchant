require 'test_helper'

class DecidirTest < Test::Unit::TestCase
  include CommStub
  include ActiveMerchant::Billing::CreditCardFormatting

  def setup
    @gateway_for_purchase = DecidirGateway.new(api_key: 'api_key')
    @gateway_for_auth = DecidirGateway.new(api_key: 'api_key', preauth_mode: true)
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
    @fraud_detection = {
      send_to_cs: false,
      channel: 'Web',
      dispatch_method: 'Store Pick Up',
      csmdds: [
        {
          code: 17,
          description: 'Campo MDD17'
        }
      ],
      device_unique_id: '111'
    }
    @sub_payments = [
      {
        site_id: '04052018',
        installments: 1,
        amount: 1500
      },
      {
        site_id: '04052018',
        installments: 1,
        amount: 1500
      }
    ]

    @network_token = network_tokenization_credit_card(
      '4012001037141112',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: '000203016912340000000FA08400317500000000',
      verification_value: '123'
    )
  end

  def test_supported_card_types
    assert_equal DecidirGateway.supported_cardtypes, %i[visa master american_express diners_club naranja cabal tuya patagonia_365]
  end

  def test_successful_purchase
    @gateway_for_purchase.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 7719132, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_purchase_with_options
    options = {
      ip: '127.0.0.1',
      email: 'joe@example.com',
      card_holder_door_number: '1234',
      card_holder_birthday: '01011980',
      card_holder_identification_type: 'dni',
      card_holder_identification_number: '123456',
      establishment_name: 'Heavenly Buffaloes',
      installments: 12,
      site_id: '99999999'
    }

    response = stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, @credit_card, @options.merge(options))
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /"card_holder_door_number":1234/
      assert data =~ /"card_holder_birthday":"01011980"/
      assert data =~ /"type":"dni"/
      assert data =~ /"number":"123456"/
      assert data =~ /"establishment_name":"Heavenly Buffaloes"/
      assert data =~ /"site_id":"99999999"/
    end.respond_with(successful_purchase_response)

    assert_equal 7719132, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_purchase_with_aggregate_data
    options = {
      aggregate_data: {
        indicator: 1,
        identification_number: '308103480',
        bill_to_pay: 'test1',
        bill_to_refund: 'test2',
        merchant_name: 'Heavenly Buffaloes',
        street: 'Sesame',
        number: '123',
        postal_code: '22001',
        category: 'yum',
        channel: '005',
        geographic_code: 'C1234',
        city: 'Ciudad de Buenos Aires',
        merchant_id: 'dec_agg',
        province: 'Buenos Aires',
        country: 'Argentina',
        merchant_email: 'merchant@mail.com',
        merchant_phone: '2678433111'
      }
    }

    response = stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, @credit_card, @options.merge(options))
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /"aggregate_data":{"indicator":1/
      assert data =~ /"identification_number":"308103480"/
      assert data =~ /"bill_to_pay":"test1"/
      assert data =~ /"bill_to_refund":"test2"/
      assert data =~ /"merchant_name":"Heavenly Buffaloes"/
      assert data =~ /"street":"Sesame"/
      assert data =~ /"number":"123"/
      assert data =~ /"postal_code":"22001"/
      assert data =~ /"category":"yum"/
      assert data =~ /"channel":"005"/
      assert data =~ /"geographic_code":"C1234"/
      assert data =~ /"city":"Ciudad de Buenos Aires"/
      assert data =~ /"merchant_id":"dec_agg"/
      assert data =~ /"province":"Buenos Aires"/
      assert data =~ /"country":"Argentina"/
      assert data =~ /"merchant_email":"merchant@mail.com"/
      assert data =~ /"merchant_phone":"2678433111"/
    end.respond_with(successful_purchase_response)

    assert_equal 7719132, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_purchase_with_fraud_detection
    options = @options.merge(fraud_detection: @fraud_detection)

    response = stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_equal(@fraud_detection, JSON.parse(data, symbolize_names: true)[:fraud_detection])
      assert_match(/device_unique_identifier/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_sub_payments
    options = @options.merge(sub_payments: @sub_payments)
    options[:installments] = 4
    options[:payment_type] = 'distributed'

    response = stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_equal(@sub_payments, JSON.parse(data, symbolize_names: true)[:sub_payments])
      assert_match(/#{options[:installments]}/, data)
      assert_match(/#{options[:payment_type]}/, data)
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_customer_object
    options = @options.merge(customer_id: 'John', customer_email: 'decidir@decidir.com')

    response = stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert data =~ /"email":"decidir@decidir.com"/
      assert data =~ /"id":"John"/
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    @gateway_for_purchase.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'TARJETA INVALIDA | invalid_number', response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_failed_purchase_with_invalid_field
    @gateway_for_purchase.expects(:ssl_request).returns(failed_purchase_with_invalid_field_response)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options.merge(installments: -1))
    assert_failure response
    assert_equal 'invalid_param: installments', response.message
    assert_match 'invalid_request_error', response.error_code
  end

  def test_failed_purchase_with_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_auth.purchase(@amount, @credit_card, @options)
    end
  end

  def test_failed_purchase_error_response
    @gateway_for_purchase.expects(:ssl_request).returns(unique_purchase_error_response)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'invalid_request_error | invalid_param | payment_type', response.error_code
  end

  def test_failed_purchase_error_response_with_error_code
    @gateway_for_purchase.expects(:ssl_request).returns(error_response_with_error_code)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match '14, invalid_number', response.error_code
  end

  def test_failed_purchase_with_unexpected_error_code
    @gateway_for_purchase.expects(:ssl_request).returns(failed_purchase_response_with_unexpected_error)

    response = @gateway_for_purchase.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal ' | processing_error', response.message
    assert_match Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_authorize
    @gateway_for_auth.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway_for_auth.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 7720214, response.authorization
    assert_equal 'pre_approved', response.message
    assert response.test?
  end

  def test_failed_authorize
    @gateway_for_auth.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway_for_auth.authorize(@amount, @credit_card, @options)
    assert_failure response

    assert_equal 7719358, response.authorization
    assert_equal 'TARJETA INVALIDA | invalid_number', response.message
    assert response.test?
  end

  def test_failed_authorize_without_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_purchase.authorize(@amount, @credit_card, @options)
    end
  end

  def test_successful_capture
    @gateway_for_auth.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway_for_auth.capture(@amount, 7720214)
    assert_success response

    assert_equal 7720214, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_partial_capture
    @gateway_for_auth.expects(:ssl_request).returns(failed_partial_capture_response)

    response = @gateway_for_auth.capture(@amount, '')
    assert_failure response

    assert_nil response.authorization
    assert_equal 'amount: Amount out of ranges: 100 - 100', response.message
    assert_equal 'invalid_request_error', response.error_code
    assert response.test?
  end

  def test_failed_capture
    @gateway_for_auth.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway_for_auth.capture(@amount, '')
    assert_failure response

    assert_equal '', response.authorization
    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_failed_capture_without_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_purchase.capture(@amount, @credit_card, @options)
    end
  end

  def test_successful_refund
    @gateway_for_purchase.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway_for_purchase.refund(@amount, 81931, @options)
    assert_success response

    assert_equal 81931, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_partial_refund
    @gateway_for_purchase.expects(:ssl_request).returns(partial_refund_response)

    response = @gateway_for_purchase.refund(@amount - 1, 81932, @options)
    assert_success response

    assert_equal 81932, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_refund
    @gateway_for_purchase.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway_for_purchase.refund(@amount, '')
    assert_failure response

    assert_equal '', response.authorization
    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_successful_void
    @gateway_for_auth.expects(:ssl_request).returns(successful_void_response)

    response = @gateway_for_auth.void(@amount, '')
    assert_success response

    assert_equal 82814, response.authorization
    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_failed_void
    @gateway_for_auth.expects(:ssl_request).returns(failed_void_response)

    response = @gateway_for_auth.void('')
    assert_failure response

    assert_equal '', response.authorization
    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_successful_verify
    @gateway_for_auth.expects(:ssl_request).at_most(3).returns(successful_void_response)

    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_success response

    assert_equal 'approved', response.message
    assert response.test?
  end

  def test_successful_verify_with_failed_void
    @gateway_for_auth.expects(:ssl_request).at_most(3).returns(failed_void_response)

    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_failure response

    assert_equal 'not_found_error', response.message
    assert response.test?
  end

  def test_successful_verify_with_failed_void_unique_error_message
    @gateway_for_auth.expects(:ssl_request).at_most(3).returns(unique_void_error_response)

    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_failure response

    assert_equal 'invalid_status_error - status: refunded', response.message
    assert response.test?
  end

  def test_failed_verify
    @gateway_for_auth.expects(:ssl_request).at_most(2).returns(failed_authorize_response)

    response = @gateway_for_auth.verify(@credit_card, @options)
    assert_failure response

    assert_equal 'TARJETA INVALIDA | invalid_number', response.message
    assert response.test?
  end

  def test_failed_verify_for_without_preauth_mode
    assert_raise(ArgumentError) do
      @gateway_for_purchase.verify(@amount, @credit_card, @options)
    end
  end

  def test_successful_inquire_with_authorization
    @gateway_for_purchase.expects(:ssl_request).returns(successful_inquire_response)
    response = @gateway_for_purchase.inquire('818423490')
    assert_success response

    assert_equal 544453, response.authorization
    assert_equal 'rejected', response.message
    assert response.test?
  end

  def test_network_token_payment_method
    options = {
      card_holder_name: 'Tesest payway',
      card_holder_door_number: 1234,
      card_holder_birthday: '200988',
      card_holder_identification_type: 'DNI',
      card_holder_identification_number: '44444444',
      last_4: @credit_card.last_digits
    }

    response = stub_comms(@gateway_for_auth, :ssl_request) do
      @gateway_for_auth.authorize(100, @network_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"cryptogram\":\"#{@network_token.payment_cryptogram}\"/, data)
      assert_match(/"security_code\":\"#{@network_token.verification_value}\"/, data)
      assert_match(/"expiration_month\":\"#{format(@network_token.month, :two_digits)}\"/, data)
      assert_match(/"expiration_year\":\"#{format(@network_token.year, :two_digits)}\"/, data)
    end.respond_with(successful_network_token_response)

    assert_success response
    assert_equal 49120515, response.authorization
  end

  def test_network_token_payment_method_without_cvv
    options = {
      card_holder_name: 'Tesest payway',
      card_holder_door_number: 1234,
      card_holder_birthday: '200988',
      card_holder_identification_type: 'DNI',
      card_holder_identification_number: '44444444',
      last_4: @credit_card.last_digits
    }
    @network_token.verification_value = nil
    response = stub_comms(@gateway_for_auth, :ssl_request) do
      @gateway_for_auth.authorize(100, @network_token, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"cryptogram\":\"#{@network_token.payment_cryptogram}\"/, data)
      assert_not_match(/"security_code\":\"#{@network_token.verification_value}\"/, data)
    end.respond_with(successful_network_token_response)

    assert_success response
    assert_equal 49120515, response.authorization
  end

  def test_scrub
    assert @gateway_for_purchase.supports_scrubbing?
    assert_equal @gateway_for_purchase.scrub(pre_scrubbed), post_scrubbed
  end

  def test_transcript_scrubbing_network_token
    assert_equal @gateway_for_purchase.scrub(pre_scrubbed_network_token), post_scrubbed_network_token
  end

  def test_payment_method_id_with_visa
    post = {}
    @gateway_for_purchase.send(:add_auth_purchase_params, post, @amount, @credit_card, @options)
    assert_equal 1, post[:payment_method_id]
  end

  def test_payment_method_id_with_mastercard
    post = {}
    @gateway_for_purchase.send(:add_auth_purchase_params, post, @amount, credit_card('5299910010000015'), @options)
    assert_equal 104, post[:payment_method_id]
  end

  def test_payment_method_id_with_amex
    post = {}
    @gateway_for_purchase.send(:add_auth_purchase_params, post, @amount, credit_card('373953192351004'), @options)
    assert_equal 65, post[:payment_method_id]
  end

  def test_payment_method_id_with_diners
    post = {}
    @gateway_for_purchase.send(:add_auth_purchase_params, post, @amount, credit_card('36463664750005'), @options)
    assert_equal 8, post[:payment_method_id]
  end

  def test_payment_method_id_with_cabal
    post = {}
    credit_card = credit_card('5896570000000008')
    @gateway_for_purchase.send(:add_auth_purchase_params, post, @amount, credit_card, @options)
    assert_equal 63, post[:payment_method_id]
  end

  def test_payment_method_id_with_naranja
    post = {}
    credit_card = credit_card('5895627823453005')
    @gateway_for_purchase.send(:add_auth_purchase_params, post, @amount, credit_card, @options)
    assert_equal 24, post[:payment_method_id]
  end

  def test_payment_method_id_with_visa_debit
    visa_debit_card = credit_card('4517721004856075')
    debit_options = @options.merge(debit: true)

    stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, visa_debit_card, debit_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"payment_method_id":31/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_payment_method_id_with_mastercard_debit
    # currently lacking a valid MasterCard debit card number, so using the MasterCard credit card number
    mastercard = credit_card('5299910010000015')
    debit_options = @options.merge(debit: true)

    stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, mastercard, debit_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"payment_method_id":105/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_payment_method_id_with_maestro_debit
    # currently lacking a valid Maestro debit card number, so using a generated test card number
    maestro_card = credit_card('6759649826438453')
    debit_options = @options.merge(debit: true)

    stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, maestro_card, debit_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"payment_method_id":106/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_payment_method_id_with_cabal_debit
    # currently lacking a valid Cabal debit card number, so using the Cabal credit card number
    cabal_card = credit_card('5896570000000008')
    debit_options = @options.merge(debit: true)

    stub_comms(@gateway_for_purchase, :ssl_request) do
      @gateway_for_purchase.purchase(@amount, cabal_card, debit_options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"payment_method_id":108/, data)
    end.respond_with(successful_purchase_response)
  end

  private

  def pre_scrubbed
    %q(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established
      <- "POST /api/v2/payments HTTP/1.1\r\nContent-Type: application/json\r\nApikey: 5df6b5764c3f4822aecdc82d56f26b9d\r\nCache-Control: no-cache\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: developers.decidir.com\r\nContent-Length: 414\r\n\r\n"
      <- "{\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"bin\":\"450799\",\"payment_type\":\"single\",\"installments\":1,\"description\":\"Store Purchase\",\"sub_payments\":[],\"amount\":100,\"currency\":\"ARS\",\"card_data\":{\"card_number\":\"4507990000004905\",\"card_expiration_month\":\"09\",\"card_expiration_year\":\"20\",\"security_code\":\"123\",\"card_holder_name\":\"Longbob Longsen\",\"card_holder_identification\":{}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Mon, 24 Jun 2019 18:38:42 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 659\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Kong-Upstream-Latency: 159\r\n"
      -> "X-Kong-Proxy-Latency: 0\r\n"
      -> "Via: kong/0.8.3\r\n"
      -> "\r\n"
      reading 659 bytes...
      -> "{\"id\":7721017,\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"card_brand\":\"Visa\",\"amount\":100,\"currency\":\"ars\",\"status\":\"approved\",\"status_details\":{\"ticket\":\"7297\",\"card_authorization_code\":\"153842\",\"address_validation_code\":\"VTE0011\",\"error\":null},\"date\":\"2019-06-24T15:38Z\",\"customer\":null,\"bin\":\"450799\",\"installments\":1,\"first_installment_expiration_date\":null,\"payment_type\":\"single\",\"sub_payments\":[],\"site_id\":\"99999999\",\"fraud_detection\":{\"status\":null},\"aggregate_data\":null,\"establishment_name\":\"Heavenly Buffaloes\",\"spv\":null,\"confirmed\":null,\"pan\":\"345425f15b2c7c4584e0044357b6394d7e\",\"customer_token\":null,\"card_data\":\"/tokens/7721017\"}"
      read 659 bytes
      Conn close
    )
  end

  def post_scrubbed
    %q(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established
      <- "POST /api/v2/payments HTTP/1.1\r\nContent-Type: application/json\r\nApikey: [FILTERED]\r\nCache-Control: no-cache\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: developers.decidir.com\r\nContent-Length: 414\r\n\r\n"
      <- "{\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"bin\":\"450799\",\"payment_type\":\"single\",\"installments\":1,\"description\":\"Store Purchase\",\"sub_payments\":[],\"amount\":100,\"currency\":\"ARS\",\"card_data\":{\"card_number\":\"[FILTERED]\",\"card_expiration_month\":\"09\",\"card_expiration_year\":\"20\",\"security_code\":\"[FILTERED]\",\"card_holder_name\":\"Longbob Longsen\",\"card_holder_identification\":{}}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Mon, 24 Jun 2019 18:38:42 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 659\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "X-Kong-Upstream-Latency: 159\r\n"
      -> "X-Kong-Proxy-Latency: 0\r\n"
      -> "Via: kong/0.8.3\r\n"
      -> "\r\n"
      reading 659 bytes...
      -> "{\"id\":7721017,\"site_transaction_id\":\"d5972b68-87d5-46fd-8d3d-b2512902b9af\",\"payment_method_id\":1,\"card_brand\":\"Visa\",\"amount\":100,\"currency\":\"ars\",\"status\":\"approved\",\"status_details\":{\"ticket\":\"7297\",\"card_authorization_code\":\"153842\",\"address_validation_code\":\"VTE0011\",\"error\":null},\"date\":\"2019-06-24T15:38Z\",\"customer\":null,\"bin\":\"450799\",\"installments\":1,\"first_installment_expiration_date\":null,\"payment_type\":\"single\",\"sub_payments\":[],\"site_id\":\"99999999\",\"fraud_detection\":{\"status\":null},\"aggregate_data\":null,\"establishment_name\":\"Heavenly Buffaloes\",\"spv\":null,\"confirmed\":null,\"pan\":\"345425f15b2c7c4584e0044357b6394d7e\",\"customer_token\":null,\"card_data\":\"/tokens/7721017\"}"
      read 659 bytes
      Conn close
    )
  end

  def pre_scrubbed_network_token
    %(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /api/v2/payments HTTP/1.1\\r\\nContent-Type: application/json\\r\\nApikey: 5df6b5764c3f4822aecdc82d56f26b9d\\r\\nCache-Control: no-cache\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: developers.decidir.com\\r\\nContent-Length: 505\\r\\n\\r\\n\"
      <- "{\\\"payment_method_id\\\":1,\\\"site_transaction_id\\\":\\\"59239287-c211-4d72-97b0-70fd701126a6\\\",\\\"bin\\\":\\\"401200\\\",\\\"payment_type\\\":\\\"single\\\",\\\"installments\\\":1,\\\"description\\\":\\\"Store Purchase\\\",\\\"amount\\\":100,\\\"currency\\\":\\\"ARS\\\",\\\"card_data\\\":{\\\"card_holder_identification\\\":{},\\\"card_holder_name\\\":\\\"Tesest payway\\\",\\\"last_four_digits\\\":null},\\\"is_tokenized_payment\\\":true,\\\"fraud_detection\\\":{\\\"sent_to_cs\\\":false},\\\"token_card_data\\\":{\\\"expiration_month\\\":\\\"09\\\",\\\"expiration_year\\\":\\\"25\\\",\\\"token\\\":\\\"4012001037141112\\\",\\\"eci\\\":\\\"05\\\",\\\"cryptogram\\\":\\\"/wBBBBBCd4HzpGYAmbmgguoBBBB=\\\"},\\\"sub_payments\\\":[]}\"
      -> "HTTP/1.1 402 Payment Required\\r\\n\"
      -> "Content-Type: application/json; charset=utf-8\\r\\n\"
      -> "Content-Length: 826\\r\\n\"
      -> "Connection: close\\r\\n\"
      -> "date: Wed, 21 Aug 2024 16:35:34 GMT\\r\\n\"
      -> "ETag: W/\\\"33a-JHilnlQgDvDXNEdqUzzsVialMcw\\\"\\r\\n\"
      -> "vary: Origin\\r\\n\"
      -> "Access-Control-Allow-Origin: *\\r\\n\"
      -> "Access-Control-Expose-Headers: Accept,Accept-Version,Content-Length,Content-MD5,Content-Type,Date,X-Auth-Token,Access-Control-Allow-Origin,apikey,Set-Cookie,x-consumer-username\\r\\n\"
      -> "X-Kong-Upstream-Latency: 325\\r\\n\"
      -> "X-Kong-Proxy-Latency: 1\\r\\n\"
      -> "Via: kong/2.0.5\\r\\n\"
      -> "Strict-Transport-Security: max-age=16070400; includeSubDomains\\r\\n\"
      -> "Set-Cookie: TS017a11a6=012e46d8ee27033640500a291b59a9176ef91d5ef14fa722c67ee9909e85848e261382cc63bbfa0cb5d092944db41533293bbb0e26; Path=/; Domain=.developers.decidir.com\\r\\n\"
      -> "\\r\\n\"\nreading 826 bytes...
      -> "{\\\"id\\\":1945684101,\\\"site_transaction_id\\\":\\\"59239287-c211-4d72-97b0-70fd701126a6\\\",\\\"payment_method_id\\\":1,\\\"card_brand\\\":\\\"Visa\\\",\\\"amount\\\":100,\\\"currency\\\":\\\"ars\\\",\\\"status\\\":\\\"rejected\\\",\\\"status_details\\\":{\\\"ticket\\\":\\\"4922\\\",\\\"card_authorization_code\\\":\\\"\\\",\\\"address_validation_code\\\":\\\"VTE2222\\\",\\\"error\\\":{\\\"type\\\":\\\"insufficient_amount\\\",\\\"reason\\\":{\\\"id\\\":13,\\\"description\\\":\\\"MONTO INVALIDO\\\",\\\"additional_description\\\":\\\"\\\"}}},\\\"date\\\":\\\"2024-08-21T13:35Z\\\",\\\"payment_mode\\\":null,\\\"customer\\\":null,\\\"bin\\\":\\\"401200\\\",\\\"installments\\\":1,\\\"first_installment_expiration_date\\\":null,\\\"payment_type\\\":\\\"single\\\",\\\"sub_payments\\\":[],\\\"site_id\\\":\\\"99999999\\\",\\\"fraud_detection\\\":null,\\\"aggregate_data\\\":null,\\\"establishment_name\\\":null,\\\"spv\\\":null,\\\"confirmed\\\":null,\\\"pan\\\":null,\\\"customer_token\\\":null,\\\"card_data\\\":\\\"/tokens/1945684101\\\",\\\"token\\\":\\\"4a08b19a-fbe2-45b2-8ef6-f3f12d4aa6ed\\\",\\\"authenticated_token\\\":false}\"
      read 826 bytes
      Conn close
    )
  end

  def post_scrubbed_network_token
    %(
      opening connection to developers.decidir.com:443...
      opened
      starting SSL for developers.decidir.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /api/v2/payments HTTP/1.1\\r\\nContent-Type: application/json\\r\\nApikey: [FILTERED]\\r\\nCache-Control: no-cache\\r\\nConnection: close\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nAccept: */*\\r\\nUser-Agent: Ruby\\r\\nHost: developers.decidir.com\\r\\nContent-Length: 505\\r\\n\\r\\n\"
      <- "{\\\"payment_method_id\\\":1,\\\"site_transaction_id\\\":\\\"59239287-c211-4d72-97b0-70fd701126a6\\\",\\\"bin\\\":\\\"401200\\\",\\\"payment_type\\\":\\\"single\\\",\\\"installments\\\":1,\\\"description\\\":\\\"Store Purchase\\\",\\\"amount\\\":100,\\\"currency\\\":\\\"ARS\\\",\\\"card_data\\\":{\\\"card_holder_identification\\\":{},\\\"card_holder_name\\\":\\\"Tesest payway\\\",\\\"last_four_digits\\\":null},\\\"is_tokenized_payment\\\":true,\\\"fraud_detection\\\":{\\\"sent_to_cs\\\":false},\\\"token_card_data\\\":{\\\"expiration_month\\\":\\\"09\\\",\\\"expiration_year\\\":\\\"25\\\",\\\"token\\\":\\\"[FILTERED]\\\",\\\"eci\\\":\\\"05\\\",\\\"cryptogram\\\":\\\"/[FILTERED]=\\\"},\\\"sub_payments\\\":[]}\"
      -> "HTTP/1.1 402 Payment Required\\r\\n\"
      -> "Content-Type: application/json; charset=utf-8\\r\\n\"
      -> "Content-Length: 826\\r\\n\"
      -> "Connection: close\\r\\n\"
      -> "date: Wed, 21 Aug 2024 16:35:34 GMT\\r\\n\"
      -> "ETag: W/\\\"33a-JHilnlQgDvDXNEdqUzzsVialMcw\\\"\\r\\n\"
      -> "vary: Origin\\r\\n\"
      -> "Access-Control-Allow-Origin: *\\r\\n\"
      -> "Access-Control-Expose-Headers: Accept,Accept-Version,Content-Length,Content-MD5,Content-Type,Date,X-Auth-Token,Access-Control-Allow-Origin,apikey,Set-Cookie,x-consumer-username\\r\\n\"
      -> "X-Kong-Upstream-Latency: 325\\r\\n\"
      -> "X-Kong-Proxy-Latency: 1\\r\\n\"
      -> "Via: kong/2.0.5\\r\\n\"
      -> "Strict-Transport-Security: max-age=16070400; includeSubDomains\\r\\n\"
      -> "Set-Cookie: TS017a11a6=012e46d8ee27033640500a291b59a9176ef91d5ef14fa722c67ee9909e85848e261382cc63bbfa0cb5d092944db41533293bbb0e26; Path=/; Domain=.developers.decidir.com\\r\\n\"
      -> "\\r\\n\"\nreading 826 bytes...
      -> "{\\\"id\\\":1945684101,\\\"site_transaction_id\\\":\\\"59239287-c211-4d72-97b0-70fd701126a6\\\",\\\"payment_method_id\\\":1,\\\"card_brand\\\":\\\"Visa\\\",\\\"amount\\\":100,\\\"currency\\\":\\\"ars\\\",\\\"status\\\":\\\"rejected\\\",\\\"status_details\\\":{\\\"ticket\\\":\\\"4922\\\",\\\"card_authorization_code\\\":\\\"\\\",\\\"address_validation_code\\\":\\\"VTE2222\\\",\\\"error\\\":{\\\"type\\\":\\\"insufficient_amount\\\",\\\"reason\\\":{\\\"id\\\":13,\\\"description\\\":\\\"MONTO INVALIDO\\\",\\\"additional_description\\\":\\\"\\\"}}},\\\"date\\\":\\\"2024-08-21T13:35Z\\\",\\\"payment_mode\\\":null,\\\"customer\\\":null,\\\"bin\\\":\\\"401200\\\",\\\"installments\\\":1,\\\"first_installment_expiration_date\\\":null,\\\"payment_type\\\":\\\"single\\\",\\\"sub_payments\\\":[],\\\"site_id\\\":\\\"99999999\\\",\\\"fraud_detection\\\":null,\\\"aggregate_data\\\":null,\\\"establishment_name\\\":null,\\\"spv\\\":null,\\\"confirmed\\\":null,\\\"pan\\\":null,\\\"customer_token\\\":null,\\\"card_data\\\":\\\"/tokens/1945684101\\\",\\\"token\\\":\\\"4a08b19a-fbe2-45b2-8ef6-f3f12d4aa6ed\\\",\\\"authenticated_token\\\":false}\"
      read 826 bytes
      Conn close
    )
  end

  def successful_purchase_response
    %(
      {"id":7719132,"site_transaction_id":"ebcb2db7-7aab-4f33-a7d1-6617a5749fce","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"approved","status_details":{"ticket":"7156","card_authorization_code":"174838","address_validation_code":"VTE0011","error":null},"date":"2019-06-21T17:48Z","customer":null,"bin":"450799","installments":1,"establishment_name":"Heavenly Buffaloes","first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999999","fraud_detection":{"status":null},"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"345425f15b2c7c4584e0044357b6394d7e","customer_token":null,"card_data":"/tokens/7719132"}
    )
  end

  def failed_purchase_response
    %(
      {"id":7719351,"site_transaction_id":"73e3ed66-37b1-4c97-8f69-f9cb96422383","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"rejected","status_details":{"ticket":"7162","card_authorization_code":"","address_validation_code":null,"error":{"type":"invalid_number","reason":{"id":14,"description":"TARJETA INVALIDA","additional_description":""}}},"date":"2019-06-21T17:57Z","customer":null,"bin":"400030","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999999","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"11b076fbc8fa6a55783b2f5d03f6938d8a","customer_token":null,"card_data":"/tokens/7719351"}
    )
  end

  def failed_purchase_with_invalid_field_response
    %(
      {\"error_type\":\"invalid_request_error\",\"validation_errors\":[{\"code\":\"invalid_param\",\"param\":\"installments\"}]}    )
  end

  def failed_purchase_response_with_unexpected_error
    %(
      {"id":7719351,"site_transaction_id":"73e3ed66-37b1-4c97-8f69-f9cb96422383","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"rejected","status_details":{"ticket":"7162","card_authorization_code":"","address_validation_code":null,"error":{"type":"processing_error","reason":{"id":-1,"description":"","additional_description":""}}},"date":"2019-06-21T17:57Z","customer":null,"bin":"400030","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999999","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"11b076fbc8fa6a55783b2f5d03f6938d8a","customer_token":null,"card_data":"/tokens/7719351"}
    )
  end

  def successful_authorize_response
    %(
      {"id":7720214,"site_transaction_id":"0fcedc95-4fbc-4299-80dc-f77e9dd7f525","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"pre_approved","status_details":{"ticket":"8187","card_authorization_code":"180548","address_validation_code":"VTE0011","error":null},"date":"2019-06-21T18:05Z","customer":null,"bin":"450799","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999997","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"345425f15b2c7c4584e0044357b6394d7e","customer_token":null,"card_data":"/tokens/7720214"}
    )
  end

  def failed_authorize_response
    %(
      {"id":7719358,"site_transaction_id":"ff1c12c1-fb6d-4c1a-bc20-2e77d4322c61","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"rejected","status_details":{"ticket":"8189","card_authorization_code":"","address_validation_code":null,"error":{"type":"invalid_number","reason":{"id":14,"description":"TARJETA INVALIDA","additional_description":""}}},"date":"2019-06-21T18:07Z","customer":null,"bin":"400030","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999997","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":null,"pan":"11b076fbc8fa6a55783b2f5d03f6938d8a","customer_token":null,"card_data":"/tokens/7719358"}
    )
  end

  def successful_network_token_response
    %(
      {"id": 49120515,
      "site_transaction_id": "Tx1673372774",
      "payment_method_id": 1,
      "card_brand": "Visa",
      "amount": 1200,
      "currency": "ars",
      "status": "approved",
      "status_details": {
          "ticket": "88",
          "card_authorization_code": "B45857",
          "address_validation_code": "VTE2222",
          "error": null
      },
      "date": "2023-01-10T14:46Z",
      "customer": null,
      "bin": "450799",
      "installments": 1,
      "first_installment_expiration_date": null,
      "payment_type": "single",
      "sub_payments": [],
      "site_id": "09001000",
      "fraud_detection": null,
      "aggregate_data": {
          "indicator": "1",
          "identification_number": "30598910045",
          "bill_to_pay": "Payway_Test",
          "bill_to_refund": "Payway_Test",
          "merchant_name": "PAYWAY",
          "street": "Lavarden",
          "number": "247",
          "postal_code": "C1437FBE",
          "category": "05044",
          "channel": "005",
          "geographic_code": "C1437",
          "city": "Buenos Aires",
          "merchant_id": "id_Aggregator",
          "province": "Buenos Aires",
          "country": "Argentina",
          "merchant_email": "qa@test.com",
          "merchant_phone": "+541135211111"
      },
      "establishment_name": null,
      "spv":null,
      "confirmed":null,
      "bread":null,
      "customer_token":null,
      "card_data":"/tokens/49120515",
      "token":"b7b6ca89-ed81-44e0-9d1f-3b3cf443cd74"}
    )
  end

  def successful_capture_response
    %(
      {"id":7720214,"site_transaction_id":"0fcedc95-4fbc-4299-80dc-f77e9dd7f525","payment_method_id":1,"card_brand":"Visa","amount":100,"currency":"ars","status":"approved","status_details":{"ticket":"8187","card_authorization_code":"180548","address_validation_code":"VTE0011","error":null},"date":"2019-06-21T18:05Z","customer":null,"bin":"450799","installments":1,"first_installment_expiration_date":null,"payment_type":"single","sub_payments":[],"site_id":"99999997","fraud_detection":null,"aggregate_data":null,"establishment_name":null,"spv":null,"confirmed":{"id":78436,"origin_amount":100,"date":"2019-06-21T03:00Z"},"pan":"345425f15b2c7c4584e0044357b6394d7e","customer_token":null,"card_data":"/tokens/7720214"}
    )
  end

  def failed_partial_capture_response
    %(
      {"error_type":"invalid_request_error","validation_errors":[{"code":"amount","param":"Amount out of ranges: 100 - 100"}]}
    )
  end

  def failed_capture_response
    %(
      {"error_type":"not_found_error","entity_name":"","id":""}
    )
  end

  def successful_refund_response
    %(
      {"id":81931,"amount":100,"sub_payments":null,"error":null,"status":"approved"}
    )
  end

  def partial_refund_response
    %(
      {"id":81932,"amount":99,"sub_payments":null,"error":null,"status":"approved"}
    )
  end

  def failed_refund_response
    %(
      {"error_type":"not_found_error","entity_name":"","id":""}
    )
  end

  def successful_void_response
    %(
      {"id":82814,"amount":100,"sub_payments":null,"error":null,"status":"approved"}
    )
  end

  def failed_void_response
    %(
      {"error_type":"not_found_error","entity_name":"","id":""}
    )
  end

  def successful_inquire_response
    %(
      { "id": 544453,"site_transaction_id": "52139443","token": "ef4504fc-21f1-4608-bb75-3f73aa9b9ede","user_id": null,"card_brand": "visa","bin": "483621","amount": 10,"currency": "ars","installments": 1,"description": "","payment_type": "single","sub_payments": [],"status": "rejected","status_details": null,"date": "2016-12-15T15:12Z","merchant_id": null,"fraud_detection": {}}
    )
  end

  def unique_purchase_error_response
    %{
      {\"error\":{\"error_type\":\"invalid_request_error\",\"validation_errors\":[{\"code\":\"invalid_param\",\"param\":\"payment_type\"}]}}
    }
  end

  def unique_void_error_response
    %{
      {\"error_type\":\"invalid_status_error\",\"validation_errors\":{\"status\":\"refunded\"}}
    }
  end

  def error_response_with_error_code
    %{
      {\"error\":{\"type\":\"invalid_number\",\"reason\":{\"id\":14,\"description\":\"TARJETA INVALIDA\",\"additional_description\":\"\"}}}
    }
  end
end
