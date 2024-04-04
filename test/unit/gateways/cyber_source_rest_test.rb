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
    @credit_card = credit_card(
      '4111111111111111',
      verification_value: '987',
      month: 12,
      year: 2031
    )
    @master_card = credit_card('2222420000001113', brand: 'master')

    @visa_network_token = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      source: :network_token
    )

    @mastercard_network_token = network_tokenization_credit_card(
      '5555555555554444',
      brand: 'master',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      source: :network_token
    )
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
    stub_comms do
      @gateway.authorize(1000, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
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
    assert_equal 'host date request-target digest v-c-merchant-id', parsed['headers']
    assert_equal %w[algorithm headers keyid signature], signature.split(', ').map { |v| v.split('=').first }.sort
  end

  def test_should_create_an_http_signature_for_a_get
    signature = @gateway.send :get_http_signature, @resource, nil, 'get', @gmt_time

    parsed = parse_signature(signature)
    assert_equal 'host date request-target v-c-merchant-id', parsed['headers']
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_including_customer_if_customer_id_present
    post = { paymentInformation: {} }

    @gateway.send :add_customer_id, post, {}
    assert_nil post[:paymentInformation][:customer]

    @gateway.send :add_customer_id, post, { customer_id: 10 }
    assert_equal 10, post[:paymentInformation][:customer][:customerId]
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

  def test_authorize_network_token_visa
    stub_comms do
      @gateway.authorize(100, @visa_network_token, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '001', request['paymentInformation']['tokenizedCard']['type']
      assert_equal '3', request['paymentInformation']['tokenizedCard']['transactionType']
      assert_equal 'EHuWW9PiBkWvqE5juRwDzAUFBAk=', request['paymentInformation']['tokenizedCard']['cryptogram']
      assert_nil request['paymentInformation']['tokenizedCard']['requestorId']
      assert_equal '015', request['processingInformation']['paymentSolution']
      assert_equal 'internet', request['processingInformation']['commerceIndicator']
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_network_token_mastercard
    stub_comms do
      @gateway.authorize(100, @mastercard_network_token, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '002', request['paymentInformation']['tokenizedCard']['type']
      assert_equal '3', request['paymentInformation']['tokenizedCard']['transactionType']
      assert_equal 'EHuWW9PiBkWvqE5juRwDzAUFBAk=', request['paymentInformation']['tokenizedCard']['cryptogram']
      assert_nil request['paymentInformation']['tokenizedCard']['requestorId']
      assert_equal '014', request['processingInformation']['paymentSolution']
      assert_equal 'internet', request['processingInformation']['commerceIndicator']
    end.respond_with(successful_purchase_response)
  end

  def test_authorize_apple_pay_visa
    stub_comms do
      @gateway.authorize(100, @apple_pay, @options)
    end.check_request do |_endpoint, data, _headers|
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
    stub_comms do
      @gateway.authorize(100, @google_pay_mc, @options.merge(merchant_id: 'MerchantId'))
    end.check_request do |_endpoint, data, headers|
      request = JSON.parse(data)
      assert_equal 'MerchantId', headers['V-C-Merchant-Id']
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
    stub_comms do
      @gateway.authorize(100, @apple_pay_jcb, @options)
    end.check_request do |_endpoint, data, _headers|
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

  def test_stored_credential_cit_initial
    @options[:stored_credential] = stored_credential(:cardholder, :internet, :initial)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'internet', request['processingInformation']['commerceIndicator']
      assert_equal 'customer', request.dig('processingInformation', 'authorizationOptions', 'initiator', 'type')
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_recurring_cit
    @options[:stored_credential] = stored_credential(:cardholder, :recurring)
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'recurring', request['processingInformation']['commerceIndicator']
      assert_equal 'customer', request.dig('processingInformation', 'authorizationOptions', 'initiator', 'type')
      assert_equal true, request.dig('processingInformation', 'authorizationOptions', 'initiator', 'storedCredentialUsed')
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_stored_credential_recurring_mit_ntid
    @options[:stored_credential] = stored_credential(:merchant, :recurring, ntid: '123456789619999')
    response = stub_comms do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal 'recurring', request['processingInformation']['commerceIndicator']
      assert_equal 'merchant', request.dig('processingInformation', 'authorizationOptions', 'initiator', 'type')
      assert_equal true, request.dig('processingInformation', 'authorizationOptions', 'initiator', 'storedCredentialUsed')
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

  def test_mastercard_purchase_with_3ds2
    @options[:three_d_secure] = {
      version: '2.2.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      ds_transaction_id: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y',
      cavv_algorithm: '2'
    }
    stub_comms do
      @gateway.purchase(100, @master_card, @options)
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['consumerAuthenticationInformation']['ucafAuthenticationData'], '3q2+78r+ur7erb7vyv66vv\/\/\/\/8='
      assert_equal json_data['consumerAuthenticationInformation']['ucafCollectionIndicator'], '2'
      assert_equal json_data['consumerAuthenticationInformation']['cavvAlgorithm'], '2'
      assert_equal json_data['consumerAuthenticationInformation']['paSpecificationVersion'], '2.2.0'
      assert_equal json_data['consumerAuthenticationInformation']['directoryServerTransactionID'], 'ODUzNTYzOTcwODU5NzY3Qw=='
      assert_equal json_data['consumerAuthenticationInformation']['eciRaw'], '05'
      assert_equal json_data['consumerAuthenticationInformation']['xid'], '3q2+78r+ur7erb7vyv66vv\/\/\/\/8='
      assert_equal json_data['consumerAuthenticationInformation']['veresEnrolled'], 'true'
      assert_equal json_data['consumerAuthenticationInformation']['paresStatus'], 'Y'
    end.respond_with(successful_purchase_response)
  end

  def test_visa_purchase_with_3ds2
    @options[:three_d_secure] = {
      version: '2.2.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      ds_transaction_id: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y',
      cavv_algorithm: '2'
    }
    stub_comms do
      @gateway.authorize(100, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      json_data = JSON.parse(data)
      assert_equal json_data['consumerAuthenticationInformation']['cavv'], '3q2+78r+ur7erb7vyv66vv\/\/\/\/8='
      assert_equal json_data['consumerAuthenticationInformation']['cavvAlgorithm'], '2'
      assert_equal json_data['consumerAuthenticationInformation']['paSpecificationVersion'], '2.2.0'
      assert_equal json_data['consumerAuthenticationInformation']['directoryServerTransactionID'], 'ODUzNTYzOTcwODU5NzY3Qw=='
      assert_equal json_data['consumerAuthenticationInformation']['eciRaw'], '05'
      assert_equal json_data['consumerAuthenticationInformation']['xid'], '3q2+78r+ur7erb7vyv66vv\/\/\/\/8='
      assert_equal json_data['consumerAuthenticationInformation']['veresEnrolled'], 'true'
      assert_equal json_data['consumerAuthenticationInformation']['paresStatus'], 'Y'
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

  def test_purchase_with_level_2_data
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge({ purchase_order_number: '13829012412' }))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '13829012412', request['orderInformation']['invoiceDetails']['purchaseOrderNumber']
    end.respond_with(successful_purchase_response)
  end

  def test_purchase_with_level_3_data
    options = {
      purchase_order_number: '6789',
      discount_amount: '150',
      ships_from_postal_code: '90210',
      line_items: [
        {
          productName: 'Product Name',
          kind: 'debit',
          quantity: 10,
          unitPrice: '9.5000',
          totalAmount: '95.00',
          taxAmount: '5.00',
          discountAmount: '0.00',
          productCode: '54321',
          commodityCode: '98765'
        },
        {
          productName: 'Other Product Name',
          kind: 'debit',
          quantity: 1,
          unitPrice: '2.5000',
          totalAmount: '90.00',
          taxAmount: '2.00',
          discountAmount: '1.00',
          productCode: '54322',
          commodityCode: '98766'
        }
      ]
    }
    stub_comms do
      @gateway.authorize(100, @credit_card, @options.merge(options))
    end.check_request do |_endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '3', request['processingInformation']['purchaseLevel']
      assert_equal '150', request['orderInformation']['amountDetails']['discountAmount']
      assert_equal '90210', request['orderInformation']['shipping_details']['shipFromPostalCode']
    end.respond_with(successful_purchase_response)
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

  def pre_scrubbed_nt
    <<-PRE
    <- "POST /pts/v2/payments/ HTTP/1.1\r\nContent-Type: application/json;charset=utf-8\r\nAccept: application/hal+json;charset=utf-8\r\nV-C-Merchant-Id: testrest\r\nDate: Sun, 29 Jan 2023 17:13:30 GMT\r\nHost: apitest.cybersource.com\r\nSignature: keyid=\"08c94330-f618-42a3-b09d-e1e43be5efda\", algorithm=\"HmacSHA256\", headers=\"host date (request-target) digest v-c-merchant-id\", signature=\"DJHeHWceVrsJydd8BCbGowr9dzQ/ry5cGN1FocLakEw=\"\r\nDigest: SHA-256=wuV1cxGzs6KpuUKJmlD7pKV6MZ/5G1wQVoYbf8cRChM=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nContent-Length: 584\r\n\r\n"
    <- "{\"clientReferenceInformation\":{\"code\":\"ba20ae354e25edd1a5ab27158c0a2955\"},\"paymentInformation\":{\"tokenizedCard\":{\"number\":\"4111111111111111\",\"expirationMonth\":9,\"expirationYear\":2025,\"cryptogram\":\"EHuWW9PiBkWvqE5juRwDzAUFBAk=\",\"type\":\"001\",\"transactionType\":\"3\"}},\"orderInformation\":{\"amountDetails\":{\"totalAmount\":\"102.21\",\"currency\":\"USD\"},\"billTo\":{\"firstName\":\"John\",\"lastName\":\"Doe\",\"address1\":\"1 Market St\",\"locality\":\"san francisco\",\"administrativeArea\":\"CA\",\"postalCode\":\"94105\",\"country\":\"US\",\"email\":\"test@cybs.com\",\"phoneNumber\":\"4158880000\"}},\"processingInformation\":{\"commerceIndicator\":\"internet\",\"paymentSolution\":\"015\",\"authorizationOptions\":{}}}"
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
    -> "{\"_links\":{\"authReversal\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/7145981349676498704951/reversals\"},\"self\":{\"method\":\"GET\",\"href\":\"/pts/v2/payments/7145981349676498704951\"},\"capture\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/7145981349676498704951/captures\"}},\"clientReferenceInformation\":{\"code\":\"ba20ae354e25edd1a5ab27158c0a2955\"},\"id\":\"7145981349676498704951\",\"issuerInformation\":{\"responseRaw\":\"0110322000000E10000200000000000001022105012115353420253130383141564D334B5953323833313030303030000159008000223134573031363135303730333830323039344730363400103232415050524F56414C00065649435243200034544B54523031313132313231323132313231544C3030323636504E30303431313131\"},\"orderInformation\":{\"amountDetails\":{\"authorizedAmount\":\"102.21\",\"currency\":\"USD\"}},\"paymentAccountInformation\":{\"card\":{\"type\":\"001\"}},\"paymentInformation\":{\"tokenizedCard\":{\"requestorId\":\"12121212121\",\"assuranceLevel\":\"66\",\"type\":\"001\"},\"card\":{\"suffix\":\"1111\",\"type\":\"001\"}},\"pointOfSaleInformation\":{\"terminalId\":\"01234567\"},\"processorInformation\":{\"merchantNumber\":\"000123456789012\",\"approvalCode\":\"831000\",\"networkTransactionId\":\"016150703802094\",\"transactionId\":\"016150703802094\",\"responseCode\":\"00\",\"avs\":{\"code\":\"Y\",\"codeRaw\":\"Y\"}},\"reconciliationId\":\"1081AVM3KYS2\",\"status\":\"AUTHORIZED\",\"submitTimeUtc\":\"2024-05-01T21:15:35Z\"}"
    PRE
  end

  def post_scrubbed_nt
    <<-POST
    <- "POST /pts/v2/payments/ HTTP/1.1\r\nContent-Type: application/json;charset=utf-8\r\nAccept: application/hal+json;charset=utf-8\r\nV-C-Merchant-Id: testrest\r\nDate: Sun, 29 Jan 2023 17:13:30 GMT\r\nHost: apitest.cybersource.com\r\nSignature: keyid=\"[FILTERED]\", algorithm=\"HmacSHA256\", headers=\"host date (request-target) digest v-c-merchant-id\", signature=\"[FILTERED]\"\r\nDigest: SHA-256=[FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nContent-Length: 584\r\n\r\n"
    <- "{\"clientReferenceInformation\":{\"code\":\"ba20ae354e25edd1a5ab27158c0a2955\"},\"paymentInformation\":{\"tokenizedCard\":{\"number\":\"[FILTERED]\",\"expirationMonth\":9,\"expirationYear\":2025,\"cryptogram\":\"[FILTERED]\",\"type\":\"001\",\"transactionType\":\"3\"}},\"orderInformation\":{\"amountDetails\":{\"totalAmount\":\"102.21\",\"currency\":\"USD\"},\"billTo\":{\"firstName\":\"John\",\"lastName\":\"Doe\",\"address1\":\"1 Market St\",\"locality\":\"san francisco\",\"administrativeArea\":\"CA\",\"postalCode\":\"94105\",\"country\":\"US\",\"email\":\"test@cybs.com\",\"phoneNumber\":\"4158880000\"}},\"processingInformation\":{\"commerceIndicator\":\"internet\",\"paymentSolution\":\"015\",\"authorizationOptions\":{}}}"
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
    -> "{\"_links\":{\"authReversal\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/7145981349676498704951/reversals\"},\"self\":{\"method\":\"GET\",\"href\":\"/pts/v2/payments/7145981349676498704951\"},\"capture\":{\"method\":\"POST\",\"href\":\"/pts/v2/payments/7145981349676498704951/captures\"}},\"clientReferenceInformation\":{\"code\":\"ba20ae354e25edd1a5ab27158c0a2955\"},\"id\":\"7145981349676498704951\",\"issuerInformation\":{\"responseRaw\":\"0110322000000E10000200000000000001022105012115353420253130383141564D334B5953323833313030303030000159008000223134573031363135303730333830323039344730363400103232415050524F56414C00065649435243200034544B54523031313132313231323132313231544C3030323636504E30303431313131\"},\"orderInformation\":{\"amountDetails\":{\"authorizedAmount\":\"102.21\",\"currency\":\"USD\"}},\"paymentAccountInformation\":{\"card\":{\"type\":\"001\"}},\"paymentInformation\":{\"tokenizedCard\":{\"requestorId\":\"12121212121\",\"assuranceLevel\":\"66\",\"type\":\"001\"},\"card\":{\"suffix\":\"1111\",\"type\":\"001\"}},\"pointOfSaleInformation\":{\"terminalId\":\"01234567\"},\"processorInformation\":{\"merchantNumber\":\"000123456789012\",\"approvalCode\":\"831000\",\"networkTransactionId\":\"016150703802094\",\"transactionId\":\"016150703802094\",\"responseCode\":\"00\",\"avs\":{\"code\":\"Y\",\"codeRaw\":\"Y\"}},\"reconciliationId\":\"1081AVM3KYS2\",\"status\":\"AUTHORIZED\",\"submitTimeUtc\":\"2024-05-01T21:15:35Z\"}"
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
end
