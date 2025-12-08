require 'test_helper'

class PinTest < Test::Unit::TestCase
  def setup
    @gateway = PinGateway.new(api_key: 'I_THISISNOTAREALAPIKEY')

    @credit_card = credit_card

    @google_pay_card = NetworkTokenizationCreditCard.new(
      number: '5200828282828210',
      month: '12',
      year: DateTime.now.year + 1,
      first_name: 'Jane',
      last_name: 'Doe',
      eci: '05',
      payment_cryptogram: 'EEFFGGHH',
      source: :google_pay
    )

    @apple_pay_card = NetworkTokenizationCreditCard.new(
      number: '4007000000027',
      month: '09',
      year: DateTime.now.year + 1,
      first_name: 'Longbob',
      last_name: 'Longsen',
      eci: '05',
      payment_cryptogram: 'AABBCCDD',
      source: :apple_pay
    )

    @amount = 100

    @options = {
      email: 'roland@pinpayments.com',
      billing_address: address,
      description: 'Store Purchase',
      ip: '127.0.0.1'
    }

    @three_d_secure = {
      enabled: true,
      fallback_ok: true,
      callback_url: 'https://yoursite.com/authentication_complete'
    }

    @three_d_secure_v1 = {
      version: '1.0.2',
      eci: '05',
      cavv: '1234',
      xid: '1234'
    }

    @three_d_secure_v2 = {
      version: '2.0.0',
      eci: '06',
      cavv: 'jEoEjMykRWFCBEAAAVOBSYAAAA=',
      ds_transaction_id: 'f92a19e2-485f-4d21-81ea-69a7352f611e'
    }
  end

  def test_endpoint
    assert_equal 'https://test-api.pinpayments.com/1', @gateway.test_url
    assert_equal 'https://api.pinpayments.com/1', @gateway.live_url
  end

  def test_required_api_key_on_initialization
    assert_raises ArgumentError do
      PinGateway.new
    end
  end

  def test_default_currency
    assert_equal 'AUD', PinGateway.default_currency
  end

  def test_money_format
    assert_equal :cents, PinGateway.money_format
  end

  def test_url
    assert_equal 'https://test-api.pinpayments.com/1', PinGateway.test_url
  end

  def test_live_url
    assert_equal 'https://api.pinpayments.com/1', PinGateway.live_url
  end

  def test_supported_countries
    assert_equal %w(AU NZ), PinGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master american_express diners_club discover jcb], PinGateway.supported_cardtypes
  end

  def test_display_name
    assert_equal 'Pin Payments', PinGateway.display_name
  end

  def test_setup_purchase_parameters
    @gateway.expects(:add_amount).with(instance_of(Hash), @amount, @options)
    @gateway.expects(:add_customer_data).with(instance_of(Hash), @options)
    @gateway.expects(:add_invoice).with(instance_of(Hash), @options)
    @gateway.expects(:add_payment_method).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)
    @gateway.expects(:add_capture).with(instance_of(Hash), @options)

    @gateway.stubs(:ssl_request).returns(successful_purchase_response)
    assert_success @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_successful_purchase
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/charges', post_data, headers).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'ch_Kw_JxmVqMeSOQU19_krRdw', response.authorization
    assert_equal JSON.parse(successful_purchase_response), response.params
    assert response.test?
  end

  def test_successful_apple_pay_purchase
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/payment_sources', post_data, headers).returns(successful_payment_token_response_with_apple_pay)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/charges', post_data, headers).returns(successful_purchase_response_with_apple_pay)

    assert response = @gateway.purchase(@amount, @apple_pay_card, @options)
    assert_success response
    assert_equal 'ch_KpX2EKVlZlcjjaAu1gJ_Vg', response.authorization
    assert_equal JSON.parse(successful_purchase_response_with_apple_pay), response.params
    assert response.test?
  end

  def test_successful_google_pay_purchase
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/payment_sources', post_data, headers).returns(successful_payment_token_response_with_google_pay)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/charges', post_data, headers).returns(successful_purchase_response_with_google_pay)

    assert response = @gateway.purchase(@amount, @google_pay_card, @options)
    assert_success response
    assert_equal 'ch_4C1Avej4rgK9rBWFnbMMEg', response.authorization
    assert_equal JSON.parse(successful_purchase_response_with_google_pay), response.params
    assert response.test?
  end

  def test_send_platform_adjustment
    options_with_platform_adjustment = {
      platform_adjustment: {
        amount: 30,
        currency: 'AUD'
      }
    }

    post = {}
    @gateway.send(:add_platform_adjustment, post, @options.merge(options_with_platform_adjustment))
    assert_equal 30, post[:platform_adjustment][:amount]
    assert_equal 'AUD', post[:platform_adjustment][:currency]
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'The current resource was deemed invalid.', response.message
    assert response.test?
  end

  def test_unparsable_body_of_successful_response
    @gateway.stubs(:raw_ssl_request).returns(MockResponse.succeeded('This is not [ JSON'))

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/Invalid JSON response received/, response.message)
  end

  def test_unparsable_body_of_failed_response
    @gateway.stubs(:raw_ssl_request).returns(MockResponse.failed('This is not [ JSON'))

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match(/Invalid JSON response received/, response.message)
  end

  def test_successful_store
    @gateway.expects(:ssl_request).returns(successful_customer_store_response)
    assert response = @gateway.store(@credit_card, @options)
    assert_success response
    assert_equal 'card__o8I8GmoXDF0d35LEDZbNQ;cus_05p0n7UFPmcyCNjD8c6HdA', response.authorization
    assert_equal JSON.parse(successful_customer_store_response), response.params
    assert response.test?
  end

  def test_unsuccessful_store
    @gateway.expects(:ssl_request).returns(failed_customer_store_response)

    assert response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal 'The current resource was deemed invalid.', response.message
    assert response.test?
  end

  def test_successful_unstore
    token = 'cus_05p0n7UFPmcyCNjD8c6HdA'
    @gateway.expects(:ssl_request).with(:delete, "https://test-api.pinpayments.com/1/customers/#{token}", instance_of(String), instance_of(Hash)).returns(nil)

    assert response = @gateway.unstore(token)
    assert_success response
    assert_nil response.message
    assert response.test?
  end

  def test_unsuccessful_unstore
    token = 'cus_05p0n7UFPmcyCNjD8c6HdA'
    @gateway.expects(:ssl_request).with(:delete, "https://test-api.pinpayments.com/1/customers/#{token}", instance_of(String), instance_of(Hash)).returns(failed_customer_unstore_response)

    assert response = @gateway.unstore(token)
    assert_failure response
    assert_equal 'The requested resource could not be found.', response.message
    assert response.test?
  end

  def test_successful_update
    token = 'cus_05p0n7UFPmcyCNjD8c6HdA'
    @gateway.expects(:ssl_request).with(:put, "https://test-api.pinpayments.com/1/customers/#{token}", instance_of(String), instance_of(Hash)).returns(successful_customer_store_response)
    assert response = @gateway.update('cus_05p0n7UFPmcyCNjD8c6HdA', @credit_card, @options)
    assert_success response
    assert_equal 'card__o8I8GmoXDF0d35LEDZbNQ;cus_05p0n7UFPmcyCNjD8c6HdA', response.authorization
    assert_equal JSON.parse(successful_customer_store_response), response.params
    assert response.test?
  end

  def test_successful_inquire
    post_data = {}
    headers = {}
    token = 'ch_Kw_JxmVqMeSOQU19_krRdw'
    @gateway.stubs(:headers).returns(headers)
    @gateway.expects(:ssl_request).with(:get, "https://test-api.pinpayments.com/1/charges/#{token}", nil, headers).returns(successful_inquire_response)

    assert response = @gateway.inquire(token)
    assert_success response
    assert_equal token, response.authorization
    assert response.test?
  end

  def test_successful_transaction_search
    @gateway.expects(:ssl_request).with(:get, 'https://test-api.pinpayments.com/1/charges/search', nil, instance_of(Hash)).returns(successful_transaction_search_response)

    assert response = @gateway.transaction_search
    assert_success response
    assert_equal 2, response.params['response'].length
    assert_equal 'ch_Kw_JxmVqMeSOQU19_krRdw', response.params['response'][0]['token']
    assert response.test?
  end

  def test_transaction_search_with_query
    @gateway.expects(:ssl_request).with(:get, 'https://test-api.pinpayments.com/1/charges/search?query=roland%40pinpayments.com', nil, instance_of(Hash)).returns(successful_transaction_search_response)

    assert response = @gateway.transaction_search(query: 'roland@pinpayments.com')
    assert_success response
    assert_equal 2, response.params['response'].length
    assert response.test?
  end

  def test_transaction_search_with_date_range
    start_date = '2025-01-01'
    end_date = '2025-01-31'
    @gateway.expects(:ssl_request).with(:get, "https://test-api.pinpayments.com/1/charges/search?end_date=#{end_date}&start_date=#{start_date}", nil, instance_of(Hash)).returns(successful_transaction_search_response)

    assert response = @gateway.transaction_search(start_date: start_date, end_date: end_date)
    assert_success response
    assert response.test?
  end

  def test_transaction_search_with_pagination
    @gateway.expects(:ssl_request).with(:get, 'https://test-api.pinpayments.com/1/charges/search?page=2', nil, instance_of(Hash)).returns(successful_transaction_search_response)

    assert response = @gateway.transaction_search(page: 2)
    assert_success response
    assert response.test?
  end

  def test_transaction_search_with_sort_and_direction
    @gateway.expects(:ssl_request).with(:get, 'https://test-api.pinpayments.com/1/charges/search?direction=1&sort=created_at', nil, instance_of(Hash)).returns(successful_transaction_search_response)

    assert response = @gateway.transaction_search(sort: 'created_at', direction: 1)
    assert_success response
    assert response.test?
  end

  def test_transaction_search_with_amount_sort
    @gateway.expects(:ssl_request).with(:get, 'https://test-api.pinpayments.com/1/charges/search?direction=-1&sort=amount', nil, instance_of(Hash)).returns(successful_transaction_search_response)

    assert response = @gateway.transaction_search(sort: 'amount', direction: -1)
    assert_success response
    assert response.test?
  end

  def test_transaction_search_empty_results
    @gateway.expects(:ssl_request).with(:get, 'https://test-api.pinpayments.com/1/charges/search', nil, instance_of(Hash)).returns(empty_transaction_search_response)

    assert response = @gateway.transaction_search
    assert_success response
    assert_equal 0, response.params['response'].length
    assert response.test?
  end

  def test_unsuccessful_transaction_search
    @gateway.expects(:ssl_request).returns(failed_transaction_search_response)

    assert response = @gateway.transaction_search
    assert_failure response
    assert_equal 'The requested resource could not be found.', response.message
    assert response.test?
  end

  def test_successful_refund
    token = 'ch_encBuMDf17qTabmVjDsQlg'
    @gateway.expects(:ssl_request).with(:post, "https://test-api.pinpayments.com/1/charges/#{token}/refunds", { amount: '100' }.to_json, instance_of(Hash)).returns(successful_refund_response)

    assert response = @gateway.refund(100, token)
    assert_equal 'rf_d2C7M6Mn4z2m3APqarNN6w', response.authorization
    assert_success response
    assert response.test?
  end

  def test_unsuccessful_refund
    token = 'ch_encBuMDf17qTabmVjDsQlg'
    @gateway.expects(:ssl_request).with(:post, "https://test-api.pinpayments.com/1/charges/#{token}/refunds", { amount: '100' }.to_json, instance_of(Hash)).returns(failed_refund_response)

    assert response = @gateway.refund(100, token)
    assert_failure response
    assert_equal 'The current resource was deemed invalid.', response.message
    assert response.test?
  end

  def test_successful_authorize
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/charges', post_data, headers).returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'ch_Kw_JxmVqMeSOQU19_krRdw', response.authorization
    assert_equal JSON.parse(successful_purchase_response), response.params
    assert response.test?
  end

  def test_successful_capture
    post_data = {}
    headers = {}
    token = 'ch_encBuMDf17qTabmVjDsQlg'
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:put, "https://test-api.pinpayments.com/1/charges/#{token}/capture", post_data, headers).returns(successful_capture_response)

    assert response = @gateway.capture(100, token)
    assert_success response
    assert_equal token, response.authorization
    assert response.test?
  end

  def test_succesful_purchase_with_3ds
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/charges', post_data, headers).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(three_d_secure: @three_d_secure_v1))
    assert_success response
    assert_equal 'ch_Kw_JxmVqMeSOQU19_krRdw', response.authorization
    assert_equal JSON.parse(successful_purchase_response), response.params
    assert response.test?
  end

  def test_succesful_authorize_with_3ds
    post_data = {}
    headers = {}
    @gateway.stubs(:headers).returns(headers)
    @gateway.stubs(:post_data).returns(post_data)
    @gateway.expects(:ssl_request).with(:post, 'https://test-api.pinpayments.com/1/charges', post_data, headers).returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, @credit_card, @options.merge(three_d_secure: @three_d_secure_v1))
    assert_success response
    assert_equal 'ch_Kw_JxmVqMeSOQU19_krRdw', response.authorization
    assert_equal JSON.parse(successful_purchase_response), response.params
    assert response.test?
  end

  def test_store_parameters
    @gateway.expects(:add_payment_method).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)
    @gateway.expects(:ssl_request).returns(successful_store_response)
    assert_success @gateway.store(@credit_card, @options)
  end

  def test_update_parameters
    @gateway.expects(:add_payment_method).with(instance_of(Hash), @credit_card)
    @gateway.expects(:add_address).with(instance_of(Hash), @credit_card, @options)
    @gateway.expects(:ssl_request).returns(successful_store_response)
    assert_success @gateway.update('cus_XZg1ULpWaROQCOT5PdwLkQ', @credit_card, @options)
  end

  def test_add_amount
    @gateway.expects(:amount).with(100).returns('100')
    post = {}
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal '100', post[:amount]
  end

  def test_set_default_currency
    @gateway.expects(:currency).with(100).returns('AUD')
    post = {}
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal 'AUD', post[:currency]
  end

  def test_set_currency
    @gateway.expects(:currency).never
    post = {}
    @options[:currency] = 'USD'
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal 'USD', post[:currency]
  end

  def test_set_currency_case
    @gateway.expects(:currency).never
    post = {}
    @options[:currency] = 'usd'
    @gateway.send(:add_amount, post, 100, @options)
    assert_equal 'USD', post[:currency]
  end

  def test_add_customer_data
    post = {}

    @gateway.send(:add_customer_data, post, @options)

    assert_equal 'roland@pinpayments.com', post[:email]
    assert_equal '127.0.0.1', post[:ip_address]
  end

  def test_add_address
    post = {}

    @gateway.send(:add_address, post, @credit_card, @options)

    assert_equal @options[:billing_address][:address1], post[:card][:address_line1]
    assert_equal @options[:billing_address][:city], post[:card][:address_city]
    assert_equal @options[:billing_address][:zip], post[:card][:address_postcode]
    assert_equal @options[:billing_address][:state], post[:card][:address_state]
    assert_equal @options[:billing_address][:country], post[:card][:address_country]
  end

  def test_add_address_with_card_token
    post = {}

    @gateway.send(:add_address, post, 'somecreditcardtoken', @options)

    assert_equal false, post.has_key?(:card)
  end

  def test_add_invoice
    post = {}
    @gateway.send(:add_invoice, post, @options)

    assert_equal @options[:description], post[:description]
  end

  def test_add_capture
    post = {}

    @gateway.send(:add_capture, post, @options)
    assert_equal post[:capture], true

    @gateway.send(:add_capture, post, capture: false)
    assert_equal post[:capture], false
  end

  def test_add_payment_method
    post = {}
    @gateway.send(:add_payment_method, post, @credit_card)

    assert_equal @credit_card.number, post[:card][:number]
    assert_equal @credit_card.month, post[:card][:expiry_month]
    assert_equal @credit_card.year, post[:card][:expiry_year]
    assert_equal @credit_card.verification_value, post[:card][:cvc]
    assert_equal @credit_card.name, post[:card][:name]
  end

  def test_add_payment_method_with_card_token
    post = {}
    @gateway.send(:add_payment_method, post, 'card_nytGw7koRg23EEp9NTmz9w')
    assert_equal 'card_nytGw7koRg23EEp9NTmz9w', post[:card_token]
    assert_false post.has_key?(:card)
  end

  def test_add_payment_method_with_customer_token
    post = {}
    @gateway.send(:add_payment_method, post, 'cus_XZg1ULpWaROQCOT5PdwLkQ')
    assert_equal 'cus_XZg1ULpWaROQCOT5PdwLkQ', post[:customer_token]
    assert_false post.has_key?(:card)
  end

  def test_add_3ds
    post = {}
    @gateway.send(:add_3ds, post, @options.merge(three_d_secure: @three_d_secure))
    assert_equal true, post[:three_d_secure][:enabled]
    assert_equal true, post[:three_d_secure][:fallback_ok]
    assert_equal 'https://yoursite.com/authentication_complete', post[:three_d_secure][:callback_url]
  end

  def test_add_3ds_v1
    post = {}
    @gateway.send(:add_3ds, post, @options.merge(three_d_secure: @three_d_secure_v1))
    assert_equal '1.0.2', post[:three_d_secure][:version]
    assert_equal '05', post[:three_d_secure][:eci]
    assert_equal '1234', post[:three_d_secure][:cavv]
    assert_equal '1234', post[:three_d_secure][:transaction_id]
  end

  def test_add_3ds_v2
    post = {}
    @gateway.send(:add_3ds, post, @options.merge(three_d_secure: @three_d_secure_v2))
    assert_equal '2.0.0', post[:three_d_secure][:version]
    assert_equal '06', post[:three_d_secure][:eci]
    assert_equal 'jEoEjMykRWFCBEAAAVOBSYAAAA=', post[:three_d_secure][:cavv]
    assert_equal 'f92a19e2-485f-4d21-81ea-69a7352f611e', post[:three_d_secure][:transaction_id]
  end

  def test_post_data
    post = {}
    @gateway.send(:add_payment_method, post, @credit_card)
    assert_equal post.to_json, @gateway.send(:post_data, post)
  end

  def test_headers
    expected_headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Basic #{Base64.strict_encode64('I_THISISNOTAREALAPIKEY:').strip}"
    }

    @gateway.expects(:ssl_request).with(:post, anything, anything, expected_headers).returns(successful_purchase_response)
    assert @gateway.purchase(@amount, @credit_card, {})

    expected_headers['X-Partner-Key'] = 'MyPartnerKey'
    expected_headers['X-Safe-Card'] = '1'

    @gateway.expects(:ssl_request).with(:post, anything, anything, expected_headers).returns(successful_purchase_response)
    assert @gateway.purchase(@amount, @credit_card, partner_key: 'MyPartnerKey', safe_card: '1')
  end

  def test_transcript_scrubbing
    assert_equal scrubbed_transcript, @gateway.scrub(transcript)
  end

  def test_transcript_scrubbing_with_apple_pay
    assert_equal scrubbed_transcript_with_apple_pay, @gateway.scrub(transcript_with_apple_pay)
  end

  private

  def successful_purchase_response
    '{
      "response":{
        "token":"ch_Kw_JxmVqMeSOQU19_krRdw",
        "success":true,
        "amount":400,
        "currency":"AUD",
        "description":"test charge",
        "email":"roland@pinpayments.com",
        "ip_address":"203.192.1.172",
        "created_at":"2013-01-14T03:00:41Z",
        "status_message":"Success!",
        "error_message":null,
        "card":{
          "token":"card_0oG1hjachN7g8KsOnWlOcg",
          "display_number":"XXXX-XXXX-XXXX-0000",
          "scheme":"master",
          "address_line1":"42 Sevenoaks St",
          "address_line2":null,
          "address_city":"Lathlain",
          "address_postcode":"6454",
          "address_state":"WA",
          "address_country":"AU"
        },
        "transfer":[

        ],
        "amount_refunded":0,
        "total_fees":62,
        "merchant_entitlement":338,
        "refund_pending":false
      }
    }'
  end

  def successful_purchase_response_with_apple_pay
    '{
      "response": {
        "token": "ch_KpX2EKVlZlcjjaAu1gJ_Vg",
        "success": true,
        "amount": 100,
        "currency": "AUD",
        "description": "Store Purchase 1746727811",
        "email": "roland@pinpayments.com",
        "ip_address": "203.59.39.62",
        "created_at": "2025-05-08T18:10:14Z",
        "status_message": "Success",
        "error_message": null,
        "card": {
          "token": "card_VH8Sto6E6Lc35k8DR8-f6A",
          "scheme": "visa",
          "display_number": "XXXX-XXXX-XXXX-0000",
          "issuing_country": "AU",
          "expiry_month": 12,
          "expiry_year": 2027,
          "name": null,
          "address_line1": null,
          "address_line2": null,
          "address_city": null,
          "address_postcode": null,
          "address_state": null,
          "address_country": null,
          "customer_token": null,
          "primary": null,
          "network_type": "applepay",
          "network_format": null
        },
        "transfer": [

        ],
        "amount_refunded": 0,
        "total_fees": 32,
        "merchant_entitlement": 68,
        "refund_pending": false,
        "authorisation_token": null,
        "authorisation_expired": false,
        "authorisation_voided": false,
        "captured": true,
        "captured_at": "2025-05-08T18:10:14Z",
        "settlement_currency": "AUD",
        "active_chargebacks": false,
        "metadata": {
        },
        "platform_fees": 0,
        "platform_adjustment": {
          "amount": 0,
          "currency": "AUD"
        }
      }
    }'
  end

  def successful_purchase_response_with_google_pay
    '{
      "response": {
        "token": "ch_4C1Avej4rgK9rBWFnbMMEg",
        "success": true,
        "amount": 100,
        "currency": "AUD",
        "description": "Store Purchase 1746732792",
        "email": "roland@pinpayments.com",
        "ip_address": "203.59.39.62",
        "created_at": "2025-05-08T19:33:20Z",
        "status_message": "Success",
        "error_message": null,
        "card": {
          "token": "card__xu9lnQiWzRiZZevyrc3rA",
          "scheme": "visa",
          "display_number": "XXXX-XXXX-XXXX-0000",
          "issuing_country": "AU",
          "expiry_month": 12,
          "expiry_year": 2027,
          "name": null,
          "address_line1": null,
          "address_line2": null,
          "address_city": null,
          "address_postcode": null,
          "address_state": null,
          "address_country": null,
          "customer_token": null,
          "primary": null,
          "network_type": "googlepay",
          "network_format": "cryptogram_3ds"
        },
        "transfer": [

        ],
        "amount_refunded": 0,
        "total_fees": 32,
        "merchant_entitlement": 68,
        "refund_pending": false,
        "authorisation_token": null,
        "authorisation_expired": false,
        "authorisation_voided": false,
        "captured": true,
        "captured_at": "2025-05-08T19:33:20Z",
        "settlement_currency": "AUD",
        "active_chargebacks": false,
        "metadata": {
        },
        "platform_fees": 0,
        "platform_adjustment": {
          "amount": 0,
          "currency": "AUD"
        }
      }
    }'
  end

  def failed_purchase_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":[
        {
          "param":"card.brand",
          "code":"card_brand_invalid",
          "message":"Card brand [\"is required\"]"
        },
        {
          "param":"card.number",
          "code":"card_number_invalid",
          "message":"Card number []"
        }
      ]
    }'
  end

  def successful_store_response
    '{
      "response":{
        "token":"card_sVOs8D9nANoNgDc38NvKow",
        "display_number":"XXXX-XXXX-XXXX-0000",
        "scheme":"master",
        "address_line1":"42 Sevenoaks St",
        "address_line2":null,
        "address_city":"Lathlain",
        "address_postcode":"6454",
        "address_state":"WA",
        "address_country":"Australia"
      }
    }'
  end

  def failed_store_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":[
        {
          "param":"number",
          "code":"number_invalid",
          "message":"Number [\"is not a valid credit card number\"]"
        }
      ]
    }'
  end

  def successful_customer_store_response
    '{
      "response":{
        "token":"cus_05p0n7UFPmcyCNjD8c6HdA",
        "email":"roland@pinpayments.com",
        "created_at":"2013-01-16T03:16:11Z",
        "card":{
          "token":"card__o8I8GmoXDF0d35LEDZbNQ",
          "display_number":"XXXX-XXXX-XXXX-0000",
          "scheme":"master",
          "address_line1":"42 Sevenoaks St",
          "address_line2":null,
          "address_city":"Lathlain",
          "address_postcode":"6454",
          "address_state":"WA",
          "address_country":"Australia"
        }
      }
    }'
  end

  def failed_customer_store_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":[
        {
          "param":"card.number",
          "code":"card_number_invalid",
          "message":"Card number [\"is not a valid credit card number\"]"
        }
      ]
    }'
  end

  def failed_customer_unstore_response
    '{
      "error": "not_found",
      "error_description": "The requested resource could not be found."
    }'
  end

  def successful_inquire_response
    '{
      "response": {
        "token": "ch_Kw_JxmVqMeSOQU19_krRdw",
        "success": true,
        "amount": 400,
        "currency": "AUD",
        "description": "test charge",
        "email": "roland@pinpayments.com",
        "ip_address": "203.192.1.172",
        "created_at": "2023-06-20T03:10:49Z",
        "status_message": "Success",
        "error_message": null,
        "card": {
          "token": "card_pIQJKMs93GsCc9vLSLevbw",
          "scheme": "master",
          "display_number": "XXXX-XXXX-XXXX-0000",
          "issuing_country": "AU",
          "expiry_month": 5,
          "expiry_year": 2026,
          "name": "Roland Robot",
          "address_line1": "42 Sevenoaks St",
          "address_line2": "",
          "address_city": "Lathlain",
          "address_postcode": "6454",
          "address_state": "WA",
          "address_country": "Australia",
          "network_type": null,
          "network_format": null,
          "customer_token": null,
          "primary": null
        },
        "transfer": [
          {
            "state": "paid",
            "paid_at": "2023-06-27T03:10:49Z",
            "token": "tfer_j_u-Ef7aO0Y4CuLnGh92rg"
          }
        ],
        "amount_refunded": 0,
        "total_fees": 42,
        "merchant_entitlement": 358,
        "refund_pending": false,
        "authorisation_token": null,
        "authorisation_expired": false,
        "authorisation_voided": false,
        "captured": true,
        "captured_at": "2023-06-20T03:10:49Z",
        "settlement_currency": "AUD",
        "active_chargebacks": false,
        "metadata": {
          "OrderNumber": "123456",
          "CustomerName": "Roland Robot"
        }
      }
    }'
  end

  def successful_transaction_search_response
    '{
      "response": [
        {
          "token": "ch_Kw_JxmVqMeSOQU19_krRdw",
          "success": true,
          "amount": 400,
          "currency": "AUD",
          "description": "test charge",
          "email": "roland@pinpayments.com",
          "ip_address": "203.192.1.172",
          "created_at": "2025-01-14T03:00:41Z",
          "status_message": "Success!",
          "error_message": null,
          "card": {
            "token": "card_0oG1hjachN7g8KsOnWlOcg",
            "display_number": "XXXX-XXXX-XXXX-0000",
            "scheme": "master",
            "address_line1": "42 Sevenoaks St",
            "address_line2": null,
            "address_city": "Lathlain",
            "address_postcode": "6454",
            "address_state": "WA",
            "address_country": "AU"
          },
          "transfer": [],
          "amount_refunded": 0,
          "total_fees": 62,
          "merchant_entitlement": 338,
          "refund_pending": false,
          "captured": true,
          "captured_at": "2025-01-14T03:00:41Z"
        },
        {
          "token": "ch_ABC123XYZ",
          "success": true,
          "amount": 200,
          "currency": "AUD",
          "description": "another test charge",
          "email": "roland@pinpayments.com",
          "ip_address": "203.192.1.173",
          "created_at": "2025-01-15T04:00:41Z",
          "status_message": "Success!",
          "error_message": null,
          "card": {
            "token": "card_ABC123",
            "display_number": "XXXX-XXXX-XXXX-1111",
            "scheme": "visa"
          },
          "transfer": [],
          "amount_refunded": 0,
          "total_fees": 32,
          "merchant_entitlement": 168,
          "refund_pending": false,
          "captured": true,
          "captured_at": "2025-01-15T04:00:41Z"
        }
      ],
      "pagination": {
        "current": 1,
        "previous": null,
        "next": null,
        "per_page": 25,
        "pages": 1,
        "count": 2
      }
    }'
  end

  def empty_transaction_search_response
    '{
      "response": [],
      "pagination": {
        "current": 1,
        "previous": null,
        "next": null,
        "per_page": 25,
        "pages": 0,
        "count": 0
      }
    }'
  end

  def failed_transaction_search_response
    '{
      "error": "not_found",
      "error_description": "The requested resource could not be found."
    }'
  end

  def successful_refund_response
    '{
      "response":{
        "token":"rf_d2C7M6Mn4z2m3APqarNN6w",
        "success":null,
        "amount":400,
        "currency":"AUD",
        "charge":"ch_encBuMDf17qTabmVjDsQlg",
        "created_at":"2013-01-16T05:33:34Z",
        "error_message":null,
        "status_message":"Pending"
      }
    }'
  end

  def failed_refund_response
    '{
      "error":"invalid_resource",
      "error_description":"The current resource was deemed invalid.",
      "messages":{
        "charge":[
          "You have tried to refund more than the original charge"
        ]
      }
    }'
  end

  def successful_capture_response
    '{
      "response":{
        "token":"ch_encBuMDf17qTabmVjDsQlg",
        "success":true,
        "amount":400,
        "currency":"AUD",
        "description":"test charge",
        "email":"roland@pinpayments.com",
        "ip_address":"203.192.1.172",
        "created_at":"2013-01-14T03:00:41Z",
        "status_message":"Success!",
        "error_message":null,
        "card":{
          "token":"card_0oG1hjachN7g8KsOnWlOcg",
          "display_number":"XXXX-XXXX-XXXX-0000",
          "scheme":"master",
          "address_line1":"42 Sevenoaks St",
          "address_line2":null,
          "address_city":"Lathlain",
          "address_postcode":"6454",
          "address_state":"WA",
          "address_country":"AU"
        },
        "transfer":[

        ],
        "amount_refunded":0,
        "total_fees":62,
        "merchant_entitlement":338,
        "refund_pending":false
      }
    }'
  end

  def successful_payment_token_response_with_apple_pay
    '{
      "response": {
        "token": "ps_ww1kVvBgfAVLOCy-lNBy_Q",
        "type": "network_token",
        "source": {
          "token": "card_VH8Sto6E6Lc35k8DR8-f6A",
          "scheme": "visa",
          "display_number": "XXXX-XXXX-XXXX-0000",
          "issuing_country": "AU",
          "expiry_month": 12,
          "expiry_year": 2027,
          "name": null,
          "address_line1": null,
          "address_line2": null,
          "address_city": null,
          "address_postcode": null,
          "address_state": null,
          "address_country": null,
          "customer_token": null,
          "primary": null,
          "network_type": "applepay",
          "network_format": null
        }
      },
      "ip_address": "70.63.124.4"
    }'
  end

  def successful_payment_token_response_with_google_pay
    '{
      "response": {
        "token": "ps_5R56xSAmAAI9_f_P1PKgOg",
        "type": "network_token",
        "source": {
          "token": "card__xu9lnQiWzRiZZevyrc3rA",
          "scheme": "visa",
          "display_number": "XXXX-XXXX-XXXX-0000",
          "issuing_country": "AU",
          "expiry_month": 12,
          "expiry_year": 2027,
          "name": null,
          "address_line1": null,
          "address_line2": null,
          "address_city": null,
          "address_postcode": null,
          "address_state": null,
          "address_country": null,
          "customer_token": null,
          "primary": null,
          "network_type": "googlepay",
          "network_format": "cryptogram_3ds"
        }
      },
      "ip_address": "70.63.124.4"
    }'
  end

  def transcript_with_apple_pay
    <<~PRE_SCRUBBED
      opening connection to test-api.pinpayments.com:443...
      opened
      starting SSL for test-api.pinpayments.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /1/payment_sources HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic SV9tbzlCVVVVWEl3WEYtYXZjczNMQTo=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test-api.pinpayments.com\r\nContent-Length: 169\r\n\r\n"
      <- "{\"type\":\"network_token\",\"source\":{\"number\":\"4200000000000000\",\"expiry_month\":12,\"expiry_year\":2027,\"network_type\":\"applepay\",\"cryptogram\":\"AABBCCDDEEFFGGHH\",\"eci\":\"05\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 15 May 2025 20:57:55 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 493\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "X-Requested-From: 136.47.159.68\r\n"
      -> "ETag: W/\"3ef88495866aa108ac519690cc869360\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "X-Request-Id: 4c47d1ad-4713-4e75-85fb-a1412c14d023\r\n"
      -> "X-Runtime: 0.109418\r\n"
      -> "Strict-Transport-Security: max-age=252455616; includeSubdomains; preload\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "vary: Origin\r\n"
      -> "\r\n"
      reading 493 bytes...
      -> "{\"response\":{\"token\":\"ps_nUti6Z3fA5vZvqYRC0JVwg\",\"type\":\"network_token\",\"source\":{\"token\":\"card_PfKzV2Jbnr0btgESVclTMg\",\"scheme\":\"visa\",\"display_number\":\"XXXX-XXXX-XXXX-0000\",\"issuing_country\":\"AU\",\"expiry_month\":12,\"expiry_year\":2027,\"name\":null,\"address_line1\":null,\"address_line2\":null,\"address_city\":null,\"address_postcode\":null,\"address_state\":null,\"address_country\":null,\"customer_token\":null,\"primary\":null,\"network_type\":\"applepay\",\"network_format\":null}},\"ip_address\":\"136.47.159.68\"}"
      read 493 bytes
      Conn close
      opening connection to test-api.pinpayments.com:443...
      opened
      starting SSL for test-api.pinpayments.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /1/charges HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic SV9tbzlCVVVVWEl3WEYtYXZjczNMQTo=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test-api.pinpayments.com\r\nContent-Length: 202\r\n\r\n"
      <- "{\"amount\":\"100\",\"currency\":\"AUD\",\"email\":\"roland@pinpayments.com\",\"ip_address\":\"203.59.39.62\",\"description\":\"Store Purchase 1747342674\",\"payment_source_token\":\"ps_nUti6Z3fA5vZvqYRC0JVwg\",\"capture\":true}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 15 May 2025 20:57:56 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 1048\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "ETag: W/\"5a611709ad78bb7e794589e38ce6143b\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "X-Request-Id: 5d0053bd-083a-450b-98b4-1ae10bdc4dd7\r\n"
      -> "X-Runtime: 0.317112\r\n"
      -> "Strict-Transport-Security: max-age=252455616; includeSubdomains; preload\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "\r\n"
      reading 1048 bytes...
      -> "{\"response\":{\"token\":\"ch_FPA0knR3Hg99NUKxzfUcAA\",\"success\":true,\"amount\":100,\"currency\":\"AUD\",\"description\":\"Store Purchase 1747342674\",\"email\":\"roland@pinpayments.com\",\"ip_address\":\"203.59.39.62\",\"created_at\":\"2025-05-15T20:57:56Z\",\"status_message\":\"Success\",\"error_message\":null,\"card\":{\"token\":\"card_PfKzV2Jbnr0btgESVclTMg\",\"scheme\":\"visa\",\"display_number\":\"XXXX-XXXX-XXXX-0000\",\"issuing_country\":\"AU\",\"expiry_month\":12,\"expiry_year\":2027,\"name\":null,\"address_line1\":null,\"address_line2\":null,\"address_city\":null,\"address_postcode\":null,\"address_state\":null,\"address_country\":null,\"customer_token\":null,\"primary\":null,\"network_type\":\"applepay\",\"network_format\":null},\"transfer\":[],\"amount_refunded\":0,\"total_fees\":32,\"merchant_entitlement\":68,\"refund_pending\":false,\"authorisation_token\":null,\"authorisation_expired\":false,\"authorisation_voided\":false,\"captured\":true,\"captured_at\":\"2025-05-15T20:57:56Z\",\"settlement_currency\":\"AUD\",\"active_chargebacks\":false,\"metadata\":{},\"platform_fees\":0,\"platform_adjustment\":{\"amount\":0,\"currency\":\"AUD\"}}}"
      read 1048 bytes
      Conn close
    PRE_SCRUBBED
  end

  def scrubbed_transcript_with_apple_pay
    <<~SCRUBBED
      opening connection to test-api.pinpayments.com:443...
      opened
      starting SSL for test-api.pinpayments.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /1/payment_sources HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test-api.pinpayments.com\r\nContent-Length: 169\r\n\r\n"
      <- "{\"type\":\"network_token\",\"source\":{\"number\":\"[FILTERED]\",\"expiry_month\":12,\"expiry_year\":2027,\"network_type\":\"applepay\",\"cryptogram\":\"[FILTERED]\",\"eci\":\"05\"}}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 15 May 2025 20:57:55 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 493\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "X-Requested-From: 136.47.159.68\r\n"
      -> "ETag: W/\"3ef88495866aa108ac519690cc869360\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "X-Request-Id: 4c47d1ad-4713-4e75-85fb-a1412c14d023\r\n"
      -> "X-Runtime: 0.109418\r\n"
      -> "Strict-Transport-Security: max-age=252455616; includeSubdomains; preload\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "vary: Origin\r\n"
      -> "\r\n"
      reading 493 bytes...
      -> "{\"response\":{\"token\":\"ps_nUti6Z3fA5vZvqYRC0JVwg\",\"type\":\"network_token\",\"source\":{\"token\":\"card_PfKzV2Jbnr0btgESVclTMg\",\"scheme\":\"visa\",\"display_number\":\"[FILTERED]XXXX-XXXX-XXXX-0000\",\"issuing_country\":\"AU\",\"expiry_month\":12,\"expiry_year\":2027,\"name\":null,\"address_line1\":null,\"address_line2\":null,\"address_city\":null,\"address_postcode\":null,\"address_state\":null,\"address_country\":null,\"customer_token\":null,\"primary\":null,\"network_type\":\"applepay\",\"network_format\":null}},\"ip_address\":\"136.47.159.68\"}"
      read 493 bytes
      Conn close
      opening connection to test-api.pinpayments.com:443...
      opened
      starting SSL for test-api.pinpayments.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /1/charges HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: test-api.pinpayments.com\r\nContent-Length: 202\r\n\r\n"
      <- "{\"amount\":\"100\",\"currency\":\"AUD\",\"email\":\"roland@pinpayments.com\",\"ip_address\":\"203.59.39.62\",\"description\":\"Store Purchase 1747342674\",\"payment_source_token\":\"ps_nUti6Z3fA5vZvqYRC0JVwg\",\"capture\":true}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Thu, 15 May 2025 20:57:56 GMT\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Length: 1048\r\n"
      -> "Connection: close\r\n"
      -> "Server: nginx\r\n"
      -> "ETag: W/\"5a611709ad78bb7e794589e38ce6143b\"\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "X-Request-Id: 5d0053bd-083a-450b-98b4-1ae10bdc4dd7\r\n"
      -> "X-Runtime: 0.317112\r\n"
      -> "Strict-Transport-Security: max-age=252455616; includeSubdomains; preload\r\n"
      -> "X-Content-Type-Options: nosniff\r\n"
      -> "X-Download-Options: noopen\r\n"
      -> "X-Frame-Options: DENY\r\n"
      -> "X-Permitted-Cross-Domain-Policies: none\r\n"
      -> "X-XSS-Protection: 1; mode=block\r\n"
      -> "\r\n"
      reading 1048 bytes...
      -> "{\"response\":{\"token\":\"ch_FPA0knR3Hg99NUKxzfUcAA\",\"success\":true,\"amount\":100,\"currency\":\"AUD\",\"description\":\"Store Purchase 1747342674\",\"email\":\"roland@pinpayments.com\",\"ip_address\":\"203.59.39.62\",\"created_at\":\"2025-05-15T20:57:56Z\",\"status_message\":\"Success\",\"error_message\":null,\"card\":{\"token\":\"card_PfKzV2Jbnr0btgESVclTMg\",\"scheme\":\"visa\",\"display_number\":\"[FILTERED]XXXX-XXXX-XXXX-0000\",\"issuing_country\":\"AU\",\"expiry_month\":12,\"expiry_year\":2027,\"name\":null,\"address_line1\":null,\"address_line2\":null,\"address_city\":null,\"address_postcode\":null,\"address_state\":null,\"address_country\":null,\"customer_token\":null,\"primary\":null,\"network_type\":\"applepay\",\"network_format\":null},\"transfer\":[],\"amount_refunded\":0,\"total_fees\":32,\"merchant_entitlement\":68,\"refund_pending\":false,\"authorisation_token\":null,\"authorisation_expired\":false,\"authorisation_voided\":false,\"captured\":true,\"captured_at\":\"2025-05-15T20:57:56Z\",\"settlement_currency\":\"AUD\",\"active_chargebacks\":false,\"metadata\":{},\"platform_fees\":0,\"platform_adjustment\":{\"amount\":0,\"currency\":\"AUD\"}}}"
      read 1048 bytes
      Conn close
    SCRUBBED
  end

  def transcript
    '{
      "amount":"100",
      "currency":"AUD",
      "email":"roland@pinpayments.com",
      "ip_address":"203.59.39.62",
      "description":"Store Purchase 1437598192",
      "card":{
        "number":"5520000000000000",
        "expiry_month":9,
        "expiry_year":2017,
        "cvc":"123",
        "name":"Longbob Longsen",
        "address_line1":"456 My Street",
        "address_city":"Ottawa",
        "address_postcode":"K1C2N6",
        "address_state":"ON",
        "address_country":"CA"
      }
    }'
  end

  def scrubbed_transcript
    '{
      "amount":"100",
      "currency":"AUD",
      "email":"roland@pinpayments.com",
      "ip_address":"203.59.39.62",
      "description":"Store Purchase 1437598192",
      "card":{
        "number":"[FILTERED]",
        "expiry_month":9,
        "expiry_year":2017,
        "cvc":"[FILTERED]",
        "name":"Longbob Longsen",
        "address_line1":"456 My Street",
        "address_city":"Ottawa",
        "address_postcode":"K1C2N6",
        "address_state":"ON",
        "address_country":"CA"
      }
    }'
  end
end
