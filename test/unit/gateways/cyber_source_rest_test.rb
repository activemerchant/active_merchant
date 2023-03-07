require 'test_helper'

class CyberSourceRestTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = CyberSourceRestGateway.new(
      merchant_id: 'abc123',
      public_key: 'def345',
      private_key: "NYlM1sgultLjvgaraWvDCXykdz1buqOW8yXE3pMlmxQ=\n"
    )
    @bank_account = check(account_number: '4100', routing_number: '121042882')
    @credit_card = credit_card('4111111111111111',
      verification_value: '987',
      month: 12,
      year: 2031)
    @apple_pay = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'AceY+igABPs3jdwNaDg3MAACAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :apple_pay,
      verification_value: 569
    )

    @google_pay_mc = network_tokenization_credit_card(
      '5555555555554444',
      payment_cryptogram: 'AceY+igABPs3jdwNaDg3MAACAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :google_pay,
      verification_value: 569,
      brand: 'master'
    )

    @apple_pay_jcb = network_tokenization_credit_card(
      '3566111111111113',
      payment_cryptogram: 'AceY+igABPs3jdwNaDg3MAACAAA=',
      month: '11',
      year: Time.now.year + 1,
      source: :apple_pay,
      verification_value: 569,
      brand: 'jcb'
    )
    @amount = 100
    @options = {
      order_id: '1',
      description: 'Store Purchase',
      billing_address: {
        name:     'John Doe',
        address1: '1 Market St',
        city:     'san francisco',
        state:    'CA',
        zip:      '94105',
        country:  'US',
        phone:    '4158880000'
      },
      email: 'test@cybs.com'
    }
    @gmt_time = Time.now.httpdate
    @digest = 'SHA-256=gXWufV4Zc7VkN9Wkv9jh/JuAVclqDusx3vkyo3uJFWU='
    @resource = '/pts/v2/payments/'
  end

  def test_required_merchant_id_and_secret
    error = assert_raises(ArgumentError) { CyberSourceRestGateway.new }
    assert_equal 'Missing required parameter: merchant_id', error.message
  end

  def test_supported_card_types
    assert_equal CyberSourceRestGateway.supported_cardtypes, %i[visa master american_express discover diners_club jcb maestro elo union_pay cartes_bancaires mada]
  end

  def test_properly_format_on_zero_decilmal
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(1000, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      card = request['paymentInformation']['card']
      amount_details = request['orderInformation']['amountDetails']

      assert_equal '1', request['clientReferenceInformation']['code']
      assert_equal '2031', card['expirationYear']
      assert_equal '12', card['expirationMonth']
      assert_equal '987', card['securityCode']
      assert_equal '001', card['type']
      assert_equal 'USD', amount_details['currency']
      assert_equal '10.00', amount_details['totalAmount']
    end.respond_with(successful_purchase_response)
  end

  def test_should_create_an_http_signature_for_a_post
    signature = @gateway.send :get_http_signature, @resource, @digest, 'post', @gmt_time

    parsed = parse_signature(signature)

    assert_equal 'def345', parsed['keyid']
    assert_equal 'HmacSHA256', parsed['algorithm']
    assert_equal 'host date (request-target) digest v-c-merchant-id', parsed['headers']
    assert_equal %w[algorithm headers keyid signature], signature.split(', ').map { |v| v.split('=').first }.sort
  end

  def test_should_create_an_http_signature_for_a_get
    signature = @gateway.send :get_http_signature, @resource, nil, 'get', @gmt_time

    parsed = parse_signature(signature)
    assert_equal 'host date (request-target) v-c-merchant-id', parsed['headers']
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_add_ammount_and_currency
    post = { orderInformation: {} }

    @gateway.send :add_amount, post, 10221, {}

    assert_equal '102.21', post.dig(:orderInformation, :amountDetails, :totalAmount)
    assert_equal 'USD', post.dig(:orderInformation, :amountDetails, :currency)
  end

  def test_add_credit_card_data
    post = { paymentInformation: {} }
    @gateway.send :add_credit_card, post, @credit_card

    card = post[:paymentInformation][:card]
    assert_equal @credit_card.number, card[:number]
    assert_equal '2031', card[:expirationYear]
    assert_equal '12', card[:expirationMonth]
    assert_equal '987', card[:securityCode]
    assert_equal '001', card[:type]
  end

  def test_add_ach
    post = { paymentInformation: {} }
    @gateway.send :add_ach, post, @bank_account

    bank = post[:paymentInformation][:bank]
    assert_equal @bank_account.account_number, bank[:account][:number]
    assert_equal @bank_account.routing_number, bank[:routingNumber]
  end

  def test_add_billing_address
    post = { orderInformation: {} }

    @gateway.send :add_address, post, @credit_card, @options[:billing_address], @options, :billTo

    address = post[:orderInformation][:billTo]

    assert_equal 'John', address[:firstName]
    assert_equal 'Doe', address[:lastName]
    assert_equal '1 Market St', address[:address1]
    assert_equal 'san francisco', address[:locality]
    assert_equal 'US', address[:country]
    assert_equal 'test@cybs.com', address[:email]
    assert_equal '4158880000', address[:phoneNumber]
  end

  def test_add_shipping_address
    post = { orderInformation: {} }
    @options[:shipping_address] = @options.delete(:billing_address)

    @gateway.send :add_address, post, @credit_card, @options[:shipping_address], @options, :shipTo

    address = post[:orderInformation][:shipTo]

    assert_equal 'John', address[:firstName]
    assert_equal 'Doe', address[:lastName]
    assert_equal '1 Market St', address[:address1]
    assert_equal 'san francisco', address[:locality]
    assert_equal 'US', address[:country]
    assert_equal 'test@cybs.com', address[:email]
    assert_equal '4158880000', address[:phoneNumber]
  end

  def test_authorize_apple_pay_visa
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, @apple_pay, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '001', request['paymentInformation']['tokenizedCard']['type']
      assert_equal '1', request['paymentInformation']['tokenizedCard']['transactionType']
      assert_equal 'AceY+igABPs3jdwNaDg3MAACAAA=', request['paymentInformation']['tokenizedCard']['cryptogram']
      assert_nil request['paymentInformation']['tokenizedCard']['requestorId']
      assert_equal '001', request['processingInformation']['paymentSolution']
      assert_equal 'internet', request['processingInformation']['commerceIndicator']
      assert_include request['consumerAuthenticationInformation'], 'cavv'
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_google_pay_master_card
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, @google_pay_mc, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '002', request['paymentInformation']['tokenizedCard']['type']
      assert_equal '1', request['paymentInformation']['tokenizedCard']['transactionType']
      assert_nil request['paymentInformation']['tokenizedCard']['requestorId']
      assert_equal '012', request['processingInformation']['paymentSolution']
      assert_equal 'internet', request['processingInformation']['commerceIndicator']
      assert_equal request['consumerAuthenticationInformation']['ucafCollectionIndicator'], '2'
      assert_include request['consumerAuthenticationInformation'], 'ucafAuthenticationData'
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_apple_pay_jcb
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, @apple_pay_jcb, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '007', request['paymentInformation']['tokenizedCard']['type']
      assert_equal '1', request['paymentInformation']['tokenizedCard']['transactionType']
      assert_nil request['paymentInformation']['tokenizedCard']['requestorId']
      assert_equal '001', request['processingInformation']['paymentSolution']
      assert_nil request['processingInformation']['commerceIndicator']
      assert_include request['consumerAuthenticationInformation'], 'cavv'
    end.respond_with(successful_purchase_response)
  end

  def test_url_building
    assert_equal "#{@gateway.class.test_url}/pts/v2/action", @gateway.send(:url, 'action')
  end

  def test_use_customer_id_from_third_party_token_instead_of_options
    payment_method_tpv = 'id|amount|customer_id|payment_instrument_id'
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(100, payment_method_tpv, @options.merge(customer_id: 'other_customer_id'))
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'customer_id', request['paymentInformation']['customer']['id']
      assert_equal 'payment_instrument_id', request['paymentInstrument']['id']
    end.respond_with(successful_purchase_response)
  end

  def test_stored_credential_cit_initial
    @options[:stored_credential] = stored_credential(:cardholder, :internet, :initial)
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'internet', request['processingInformation']['commerceIndicator']
      assert_equal 'customer', request.dig('processingInformation', 'authorizationOptions', 'initiator', 'type')
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_recurring_cit
    @options[:stored_credential] = stored_credential(:cardholder, :recurring)
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'recurring', request['processingInformation']['commerceIndicator']
      assert_equal 'customer', request.dig('processingInformation', 'authorizationOptions', 'initiator', 'type')
      assert_equal true, request.dig('processingInformation', 'authorizationOptions', 'initiator', 'merchantInitiatedTransaction', 'storedCredentialUsed')
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_ntid
    @options[:stored_credential] = stored_credential(:merchant, :recurring, ntid: '123456789619999')
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'recurring', request['processingInformation']['commerceIndicator']
      assert_equal 'merchant', request.dig('processingInformation', 'authorizationOptions', 'initiator', 'type')
      assert_equal true, request.dig('processingInformation', 'authorizationOptions', 'initiator', 'merchantInitiatedTransaction', 'storedCredentialUsed')
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_credit_card_purchase_single_request_ignore_avs
    stub_comms do
      options = @options.merge(ignore_avs: true)
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, request_body, _headers|
      json_body = JSON.parse(request_body)
      assert_equal json_body['processingInformation']['authorizationOptions']['ignoreAvsResult'], 'true'
      assert_nil json_body['processingInformation']['authorizationOptions']['ignoreCvResult']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_credit_card_purchase_single_request_without_ignore_avs
    stub_comms do
      # globally ignored AVS for gateway instance:
      options = @options.merge(ignore_avs: false)
      @gateway.options[:ignore_avs] = true
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_endpoint, request_body, _headers|
      json_body = JSON.parse(request_body)
      assert_nil json_body['processingInformation']['authorizationOptions']['ignoreAvsResult']
      assert_nil json_body['processingInformation']['authorizationOptions']['ignoreCvResult']
    end.respond_with(successful_purchase_response)
  end

  def test_successful_credit_card_purchase_single_request_ignore_ccv
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(ignore_cvv: true))
    end.check_request do |_endpoint, request_body, _headers|
      json_body = JSON.parse(request_body)
      assert_nil json_body['processingInformation']['authorizationOptions']['ignoreAvsResult']
      assert_equal json_body['processingInformation']['authorizationOptions']['ignoreCvResult'], 'true'
    end.respond_with(successful_purchase_response)
  end

  def test_successful_credit_card_purchase_single_request_without_ignore_ccv
    stub_comms do
      @gateway.purchase(@amount, @credit_card, @options.merge(ignore_cvv: false))
    end.check_request do |_endpoint, request_body, _headers|
      json_body = JSON.parse(request_body)
      assert_nil json_body['processingInformation']['authorizationOptions']['ignoreAvsResult']
      assert_nil json_body['processingInformation']['authorizationOptions']['ignoreCvResult']
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_includes_mdd_fields
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['merchantDefinedInformation'][0]['key'], 'mdd_field_2'
      assert_equal json_data['merchantDefinedInformation'][0]['value'], 'CustomValue2'
      assert_equal json_data['merchantDefinedInformation'].count, 2
    end.respond_with(successful_purchase_response)
  end

  def test_capture_includes_mdd_fields
    stub_comms do
      @gateway.capture(100, '1846925324700976124593', order_id: '1', mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['merchantDefinedInformation'][0]['key'], 'mdd_field_2'
      assert_equal json_data['merchantDefinedInformation'][0]['value'], 'CustomValue2'
      assert_equal json_data['merchantDefinedInformation'].count, 2
    end.respond_with(successful_capture_response)
  end

  def test_credit_includes_mdd_fields
    stub_comms do
      @gateway.credit(@amount, @credit_card, mdd_field_2: 'CustomValue2', mdd_field_3: 'CustomValue3')
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['merchantDefinedInformation'][0]['key'], 'mdd_field_2'
      assert_equal json_data['merchantDefinedInformation'][0]['value'], 'CustomValue2'
      assert_equal json_data['merchantDefinedInformation'].count, 2
    end.respond_with(successful_credit_response)
  end

  def test_authorize_includes_reconciliation_id
    stub_comms do
      @gateway.authorize(100, @credit_card, order_id: '1', reconciliation_id: '181537')
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['clientReferenceInformation']['reconciliationId'], '181537'
    end.respond_with(successful_purchase_response)
  end

  def test_bank_account_purchase_includes_sec_code
    stub_comms do
      @gateway.purchase(@amount, @bank_account, order_id: '1', sec_code: 'WEB')
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['processingInformation']['bankTransferOptions']['secCode'], 'WEB'
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_includes_invoice_number
    stub_comms do
      @gateway.purchase(100, @credit_card, invoice_number: '1234567')
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['orderInformation']['invoiceDetails']['invoiceNumber'], '1234567'
    end.respond_with(successful_purchase_response)
  end

  def test_adds_application_id_as_partner_solution_id
    partner_id = 'partner_id'
    CyberSourceRestGateway.application_id = partner_id

    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['clientReferenceInformation']['partner']['solutionId'], partner_id
    end.respond_with(successful_purchase_response)
  ensure
    CyberSourceRestGateway.application_id = nil
  end

  def test_successful_store
    stub_comms(@gateway, :ssl_request) do
      @gateway.store(@credit_card, @options.merge(merchant_customer_id: 'merchant_test'))
    end.check_request do |_method, endpoint, data, _headers|
      request = JSON.parse(data)
      case endpoint
      when /instrumentidentifiers/
        assert_equal request['card']['number'], '4111111111111111'
      when /paymentinstruments/
        assert_equal request['card']['expirationMonth'], '12'
        assert_equal request['card']['expirationYear'],  '2031'
        assert_equal request['card']['type'], 'visa'
        assert_equal request['instrumentIdentifier']['id'], '7010000000016241111'
        assert_includes request, 'billTo'
      when /payment-instruments/
        assert_equal request['card']['expirationMonth'], '12'
        assert_equal request['card']['expirationYear'],  '2031'
        assert_equal request['card']['type'], '001'
        assert_equal request['instrumentIdentifier']['id'], '7010000000016241111'
        assert_includes request, 'billTo'
      when /customers/
        assert_equal request['buyerInformation']['email'], 'test@cybs.com'
        assert_includes request['buyerInformation'], 'merchantCustomerId'
        assert_includes request, 'clientReferenceInformation'
        assert_includes request, 'merchantDefinedInformation'
      end
    end.respond_with(successful_create_customer, successful_create_instrument_identifiers, successful_store_response)
  end

  private

  def parse_signature(signature)
    signature.gsub(/=\"$/, '').delete('"').split(', ').map { |x| x.split('=') }.to_h
  end

  def pre_scrubbed
    <<-PRE
    <- "POST /pts/v2/payments/ HTTP/1.1\r\nContent-Type: application/json;charset=utf-8\r\nAccept: application/hal+json;charset=utf-8\r\nV-C-Merchant-Id: testrest\r\nDate: Sun, 29 Jan 2023 17:13:30 GMT\r\nHost: apitest.cybersource.com\r\nSignature: keyid=\"08c94330-f618-42a3-b09d-e1e43be5efda\", algorithm=\"HmacSHA256\", headers=\"host date (request-target) digest v-c-merchant-id\", signature=\"DJHeHWceVrsJydd8BCbGowr9dzQ/ry5cGN1FocLakEw=\"\r\nDigest: SHA-256=wuV1cxGzs6KpuUKJmlD7pKV6MZ/5G1wQVoYbf8cRChM=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nContent-Length: 584\r\n\r\n"
    <- "{\"clientReferenceInformation\":{\"code\":\"b8779865d140125036016a0f85db907f\"},\"paymentInformation\":{\"card\":{\"number\":\"4111111111111111\",\"expirationMonth\":\"12\",\"expirationYear\":\"2031\",\"securityCode\":\"987\",\"type\":\"001\"}},\"orderInformation\":{\"amountDetails\":{\"totalAmount\":\"102.21\",\"currency\":\"USD\"},\"billTo\":{\"firstName\":\"John\",\"lastName\":\"Doe\",\"address1\":\"1 Market St\",\"locality\":\"san francisco\",\"administrativeArea\":\"CA\",\"postalCode\":\"94105\",\"country\":\"US\",\"email\":\"test@cybs.com\",\"phoneNumber\":\"4158880000\"},\"shipTo\":{\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"email\":\"test@cybs.com\"}}}"
    -> "HTTP/1.1 201 Created\r\n"
    -> "Cache-Control: no-cache, no-store, must-revalidate\r\n"
    -> "Pragma: no-cache\r\n"
    -> "Expires: -1\r\n"
    -> "Strict-Transport-Security: max-age=31536000\r\n"
    -> "Content-Type: application/hal+json\r\n"
    -> "Content-Length: 905\r\n"
    -> "x-response-time: 291ms\r\n"
    -> "X-OPNET-Transaction-Trace: 0b1f2bd7-9545-4939-9478-4b76cf7199b6\r\n"
    -> "Connection: close\r\n"
    -> "v-c-correlation-id: 42969bf5-a77d-4035-9d09-58d4ca070e8c\r\n"
    -> "\r\n"
    reading 905 bytes...
    -> "{\"_links\":{\"authReversal\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/6750124114786780104953/reversals\"},\"self\":{\"method\":\"GET\",\"href\":\"/pts/v2/payments/6750124114786780104953\"},\"capture\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/6750124114786780104953/captures\"}},\"clientReferenceInformation\":{\"code\":\"b8779865d140125036016a0f85db907f\"},\"id\":\"6750124114786780104953\",\"orderInformation\":{\"amountDetails\":{\"authorizedAmount\":\"102.21\",\"currency\":\"USD\"}},\"paymentAccountInformation\":{\"card\":{\"type\":\"001\"}},\"paymentInformation\":{\"tokenizedCard\":{\"type\":\"001\"},\"card\":{\"type\":\"001\"}},\"pointOfSaleInformation\":{\"terminalId\":\"111111\"},\"processorInformation\":{\"approvalCode\":\"888888\",\"networkTransactionId\":\"123456789619999\",\"transactionId\":\"123456789619999\",\"responseCode\":\"100\",\"avs\":{\"code\":\"X\",\"codeRaw\":\"I1\"}},\"reconciliationId\":\"78243988SD9YL291\",\"status\":\"AUTHORIZED\",\"submitTimeUtc\":\"2023-01-29T17:13:31Z\"}"
    PRE
  end

  def post_scrubbed
    <<-POST
    <- "POST /pts/v2/payments/ HTTP/1.1\r\nContent-Type: application/json;charset=utf-8\r\nAccept: application/hal+json;charset=utf-8\r\nV-C-Merchant-Id: testrest\r\nDate: Sun, 29 Jan 2023 17:13:30 GMT\r\nHost: apitest.cybersource.com\r\nSignature: keyid=\"[FILTERED]\", algorithm=\"HmacSHA256\", headers=\"host date (request-target) digest v-c-merchant-id\", signature=\"[FILTERED]\"\r\nDigest: SHA-256=[FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nContent-Length: 584\r\n\r\n"
    <- "{\"clientReferenceInformation\":{\"code\":\"b8779865d140125036016a0f85db907f\"},\"paymentInformation\":{\"card\":{\"number\":\"[FILTERED]\",\"expirationMonth\":\"12\",\"expirationYear\":\"2031\",\"securityCode\":\"[FILTERED]\",\"type\":\"001\"}},\"orderInformation\":{\"amountDetails\":{\"totalAmount\":\"102.21\",\"currency\":\"USD\"},\"billTo\":{\"firstName\":\"John\",\"lastName\":\"Doe\",\"address1\":\"1 Market St\",\"locality\":\"san francisco\",\"administrativeArea\":\"CA\",\"postalCode\":\"94105\",\"country\":\"US\",\"email\":\"test@cybs.com\",\"phoneNumber\":\"4158880000\"},\"shipTo\":{\"firstName\":\"Longbob\",\"lastName\":\"Longsen\",\"email\":\"test@cybs.com\"}}}"
    -> "HTTP/1.1 201 Created\r\n"
    -> "Cache-Control: no-cache, no-store, must-revalidate\r\n"
    -> "Pragma: no-cache\r\n"
    -> "Expires: -1\r\n"
    -> "Strict-Transport-Security: max-age=31536000\r\n"
    -> "Content-Type: application/hal+json\r\n"
    -> "Content-Length: 905\r\n"
    -> "x-response-time: 291ms\r\n"
    -> "X-OPNET-Transaction-Trace: 0b1f2bd7-9545-4939-9478-4b76cf7199b6\r\n"
    -> "Connection: close\r\n"
    -> "v-c-correlation-id: 42969bf5-a77d-4035-9d09-58d4ca070e8c\r\n"
    -> "\r\n"
    reading 905 bytes...
    -> "{\"_links\":{\"authReversal\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/6750124114786780104953/reversals\"},\"self\":{\"method\":\"GET\",\"href\":\"/pts/v2/payments/6750124114786780104953\"},\"capture\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/6750124114786780104953/captures\"}},\"clientReferenceInformation\":{\"code\":\"b8779865d140125036016a0f85db907f\"},\"id\":\"6750124114786780104953\",\"orderInformation\":{\"amountDetails\":{\"authorizedAmount\":\"102.21\",\"currency\":\"USD\"}},\"paymentAccountInformation\":{\"card\":{\"type\":\"001\"}},\"paymentInformation\":{\"tokenizedCard\":{\"type\":\"001\"},\"card\":{\"type\":\"001\"}},\"pointOfSaleInformation\":{\"terminalId\":\"111111\"},\"processorInformation\":{\"approvalCode\":\"888888\",\"networkTransactionId\":\"123456789619999\",\"transactionId\":\"123456789619999\",\"responseCode\":\"100\",\"avs\":{\"code\":\"X\",\"codeRaw\":\"I1\"}},\"reconciliationId\":\"78243988SD9YL291\",\"status\":\"AUTHORIZED\",\"submitTimeUtc\":\"2023-01-29T17:13:31Z\"}"
    POST
  end

  def successful_purchase_response
    <<-RESPONSE
      {
        "_links": {
          "authReversal": {
            "method": "POST",
            "href": "/pts/v2/payments/6750124114786780104953/reversals"
          },
          "self": {
            "method": "GET",
            "href": "/pts/v2/payments/6750124114786780104953"
          },
          "capture": {
            "method": "POST",
            "href": "/pts/v2/payments/6750124114786780104953/captures"
          }
        },
        "clientReferenceInformation": {
          "code": "b8779865d140125036016a0f85db907f"
        },
        "id": "6750124114786780104953",
        "orderInformation": {
          "amountDetails": {
            "authorizedAmount": "102.21",
            "currency": "USD"
          }
        },
        "paymentAccountInformation": {
          "card": {
            "type": "001"
          }
        },
        "paymentInformation": {
          "tokenizedCard": {
            "type": "001"
          },
          "card": {
            "type": "001"
          }
        },
        "pointOfSaleInformation": {
          "terminalId": "111111"
        },
        "processorInformation": {
          "approvalCode": "888888",
          "networkTransactiDDDonId": "123456789619999",
          "transactionId": "123456789619999",
          "responseCode": "100",
          "avs": {
            "code": "X",
            "codeRaw": "I1"
          }
        },
        "reconciliationId": "78243988SD9YL291",
        "status": "AUTHORIZED",
        "submitTimeUtc": "2023-01-29T17:13:31Z"
      }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
      "_links": {
        "void": {
          "method": "POST",
          "href": "/pts/v2/captures/6799471903876585704951/voids"
        },
        "self": {
          "method": "GET",
          "href": "/pts/v2/captures/6799471903876585704951"
        }
      },
      "clientReferenceInformation": {
        "code": "TC50171_3"
      },
      "id": "6799471903876585704951",
      "orderInformation": {
        "amountDetails": {
          "totalAmount": "102.21",
          "currency": "USD"
        }
      },
      "reconciliationId": "78243988SD9YL291",
      "status": "PENDING",
      "submitTimeUtc": "2023-03-27T19:59:50Z"
    }
    RESPONSE
  end

  def successful_create_customer
    <<-RESPONSE
    {
      "_links": {
        "self": {
          "href": "/tms/v2/customers/F67E19FBC55DF3AAE053AF598E0A2EA6"
        },
        "paymentInstruments": {
          "href": "/tms/v2/customers/F67E19FBC55DF3AAE053AF598E0A2EA6/payment-instruments"
        },
        "shippingAddresses": {
          "href": "/tms/v2/customers/F67E19FBC55DF3AAE053AF598E0A2EA6/shipping-addresses"
        }
      },
      "id": "F67E19FBC55DF3AAE053AF598E0A2EA6",
      "buyerInformation": {
        "email": "test@cybs.com"
      },
      "clientReferenceInformation": {
        "code": "cd513d9d789f38222d44554a602a0f7c"
      },
      "merchantDefinedInformation": [],
      "metadata": {
        "creator": "testrest"
      }
    }
    RESPONSE
  end

  def successful_credit_response
    <<-RESPONSE
    {
      "_links": {
        "void": {
          "method": "POST",
          "href": "/pts/v2/credits/6799499091686234304951/voids"
        },
        "self": {
          "method": "GET",
          "href": "/pts/v2/credits/6799499091686234304951"
        }
      },
      "clientReferenceInformation": {
        "code": "12345678"
      },
      "creditAmountDetails": {
        "currency": "usd",
        "creditAmount": "200.00"
      },
      "id": "6799499091686234304951",
      "orderInformation": {
        "amountDetails": {
          "currency": "usd"
        }
      },
      "paymentAccountInformation": {
        "card": {
          "type": "001"
        }
      },
      "paymentInformation": {
        "tokenizedCard": {
          "type": "001"
        },
        "card": {
          "type": "001"
        }
      },
      "processorInformation": {
        "approvalCode": "888888",
        "responseCode": "100"
      },
      "reconciliationId": "70391830ZFKZI570",
      "status": "PENDING",
      "submitTimeUtc": "2023-03-27T20:45:09Z"
    }
    RESPONSE
  end

  def successful_create_instrument_identifiers
    <<-RESPONSE
    {
      "_links": {
        "self": {
          "href": "https://apitest.cybersource.com/tms/v1/instrumentidentifiers/7010000000016241111"
        },
        "paymentInstruments": {
          "href": "https://apitest.cybersource.com/tms/v1/instrumentidentifiers/7010000000016241111/paymentinstruments"
        }
      },
      "id": "7010000000016241111",
      "object": "instrumentIdentifier",
      "state": "ACTIVE",
      "card": {
        "number": "411111XXXXXX1111"
      },
      "metadata": {
        "creator": "testrest"
      }
    }
    RESPONSE
  end

  def successful_store_response
    <<-RESPONSE
    {
      "_links": {
        "self": {
          "href": "/tms/v2/customers/F67E19FBC55DF3AAE053AF598E0A2EA6/payment-instruments/F67E1AD76368096DE053AF598E0A21F0"
        },
        "customer": {
          "href": "/tms/v2/customers/F67E19FBC55DF3AAE053AF598E0A2EA6"
        }
      },
      "id": "F67E1AD76368096DE053AF598E0A21F0",
      "default": true,
      "state": "ACTIVE",
      "card": {
        "expirationMonth": "12",
        "expirationYear": "2031",
        "type": "001"
      },
      "billTo": {
        "firstName": "John",
        "lastName": "Doe",
        "address1": "1 Market St",
        "locality": "san francisco",
        "administrativeArea": "CA",
        "postalCode": "94105",
        "country": "US",
        "email": "test@cybs.com",
        "phoneNumber": "4158880000"
      },
      "instrumentIdentifier": {
        "id": "7010000000016241111"
      },
      "metadata": {
        "creator": "testrest"
      },
      "_embedded": {
        "instrumentIdentifier": {
          "_links": {
            "self": {
              "href": "/tms/v1/instrumentidentifiers/7010000000016241111"
            },
            "paymentInstruments": {
              "href": "/tms/v1/instrumentidentifiers/7010000000016241111/paymentinstruments"
            }
          },
          "id": "7010000000016241111",
          "object": "instrumentIdentifier",
          "state": "ACTIVE",
          "card": {
            "number": "411111XXXXXX1111"
          },
          "processingInformation": {
            "authorizationOptions": {
              "initiator": {
                "merchantInitiatedTransaction": {
                  "previousTransactionId": "123456789619999"
                }
              }
            }
          },
          "metadata": {
            "creator": "testrest"
          }
        }
      }
    }
    RESPONSE
  end
end
