require 'test_helper'

class EbanxTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EbanxGateway.new(integration_key: 'key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }

    @network_token = network_tokenization_credit_card(
      '4111111111111111',
      brand: 'visa',
      payment_cryptogram: 'network_token_example_cryptogram',
      month: 12,
      year: 2030
    )
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response

    assert_equal '592db57ad6933455efbb62a48d1dfa091dd7cd092109db99', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_optional_processing_type_header
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(processing_type: 'local'))
    end.check_request do |_method, _endpoint, _data, headers|
      assert_equal 'local', headers['x-ebanx-api-processing-type']
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_soft_descriptor
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(soft_descriptor: 'ActiveMerchant'))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"soft_descriptor\":\"ActiveMerchant\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_without_merchant_payment_code
    # hexdigest of 1 is c4ca4238a0b923820dcc509a6f75849b
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"merchant_payment_code\":\"1\"}, data
      assert_match %r{"merchant_payment_code\":\"c4ca4238a0b923820dcc509a6f75849b\"}, data
      assert_match %r{"order_number\":\"1\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_merchant_payment_code
    # hexdigest of 2 is c81e728d9d4c2f636f067f89cc14862c
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(merchant_payment_code: '2'))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"merchant_payment_code\":\"2\"}, data
      assert_match %r{"merchant_payment_code\":\"c81e728d9d4c2f636f067f89cc14862c\"}, data
      assert_match %r{"order_number\":\"1\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_notification_url
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(notification_url: 'https://notify.example.com/'))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"notification_url\":\"https://notify.example.com/\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_default_payment_type_code
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"payment_type_code\":\"creditcard\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_payment_type_code_override
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge({ payment_type_code: 'visa' }))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"payment_type_code\":\"visa\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_cardholder_recurring
    options = @options.merge!({
      stored_credential: {
        initial_transaction: true,
        initiator: 'cardholder',
        reason_type: 'recurring',
        network_transaction_id: nil
      }
    })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"cof_type\":\"initial\"}, data
      assert_match %r{"initiator\":\"CIT\"}, data
      assert_match %r{"trans_type\":\"SCHEDULED_RECURRING\"}, data
      assert_not_match %r{"mandate_id\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_cardholder_unscheduled
    options = @options.merge!({
      stored_credential: {
        initial_transaction: true,
        initiator: 'cardholder',
        reason_type: 'unscheduled',
        network_transaction_id: nil
      }
    })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"cof_type\":\"initial\"}, data
      assert_match %r{"initiator\":\"CIT\"}, data
      assert_match %r{"trans_type\":\"CUSTOMER_COF\"}, data
      assert_not_match %r{"mandate_id\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_cardholder_installment
    options = @options.merge!({
      stored_credential: {
        initial_transaction: true,
        initiator: 'cardholder',
        reason_type: 'installment',
        network_transaction_id: nil
      }
    })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"cof_type\":\"initial\"}, data
      assert_match %r{"initiator\":\"CIT\"}, data
      assert_match %r{"trans_type\":\"INSTALLMENT\"}, data
      assert_not_match %r{"mandate_id\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_merchant_installment
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'installment',
        network_transaction_id: '1234'
      }
    })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"cof_type\":\"stored\"}, data
      assert_match %r{"initiator\":\"MIT\"}, data
      assert_match %r{"trans_type\":\"INSTALLMENT\"}, data
      assert_match %r{"mandate_id\":\"1234\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_merchant_unscheduled
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'unscheduled',
        network_transaction_id: '1234'
      }
    })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"cof_type\":\"stored\"}, data
      assert_match %r{"initiator\":\"MIT\"}, data
      assert_match %r{"trans_type\":\"MERCHANT_COF\"}, data
      assert_match %r{"mandate_id\":\"1234\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_merchant_recurring
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'merchant',
        reason_type: 'recurring',
        network_transaction_id: '1234'
      }
    })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"cof_type\":\"stored\"}, data
      assert_match %r{"initiator\":\"MIT\"}, data
      assert_match %r{"trans_type\":\"SCHEDULED_RECURRING\"}, data
      assert_match %r{"mandate_id\":\"1234\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_successful_purchase_with_stored_credentials_cardholder_not_initial
    options = @options.merge!({
      stored_credential: {
        initial_transaction: false,
        initiator: 'cardholder',
        reason_type: 'unscheduled',
        network_transaction_id: '1234'
      }
    })
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match %r{"cof_type\":\"stored\"}, data
      assert_match %r{"initiator\":\"CIT\"}, data
      assert_match %r{"trans_type\":\"CUSTOMER_COF\"}, data
      assert_match %r{"mandate_id\":\"1234\"}, data
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'NOK', response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '592dc02dbe421478a132bf5c2ecfe52c86ac01b454ae799b', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'NOK', response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'authorization', @options)
    assert_success response
    assert_equal '5dee94502bd59660b801c441ad5a703f2c4123f5fc892ccb', response.authorization
    assert_equal 'Accepted', response.message
    assert response.test?
  end

  def test_failed_partial_capture
    @gateway.expects(:ssl_request).returns(failed_partial_capture_response)

    response = @gateway.capture(@amount, 'authorization', @options.merge(include_capture_amount: true))
    assert_failure response
    assert_equal 'BP-CAP-11', response.error_code
    assert_equal 'Partial capture not available', response.message
  end

  def test_failed_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(@amount, '', @options)
    assert_failure response
    assert_equal 'BP-CAP-1', response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'authorization', @options)
    assert_success response

    assert_equal '59306246f2a0c5f327a15dd6492687e197aca7eda179da08', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    response = @gateway.refund(@amount, '', @options)
    assert_failure response
    assert_equal 'BP-REF-CAN-2', response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('authorization', @options)
    assert_success response

    assert_equal '5930629dde0899dc53b3557ea9887aa8f3d264a91d115d40', response.authorization
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    response = @gateway.void('', @options)
    assert_failure response
    assert_equal 'BP-CAN-1', response.error_code
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal nil, response.error_code
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal 'Not accepted', response.message
  end

  def test_successful_store_and_purchase
    @gateway.expects(:ssl_request).returns(successful_store_response)

    store = @gateway.store(@credit_card, @options)
    assert_success store
    assert_equal 'a61a7c98535718801395991b5112f888d359c2d632e2c3bb8afe75aa23f3334d7fd8dc57d7721f8162503773063de59ee85901b5714a92338c6d9c0352aee78c|visa', store.authorization

    @gateway.expects(:ssl_request).returns(successful_purchase_with_stored_card_response)

    response = @gateway.purchase(@amount, store.authorization, @options)
    assert_success response
  end

  def test_successful_purchase_and_inquire
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    response = @gateway.inquire(purchase.authorization)

    assert_success response
  end

  def test_error_response_with_invalid_creds
    @gateway.expects(:ssl_request).returns(invalid_cred_response)

    response = @gateway.store(@credit_card, @options)
    assert_failure response
    assert_equal 'Invalid integration key', response.message
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_successful_purchase_with_network_tokenization
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @network_token, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(/"network_token_pan\":\"#{@network_token.number}\"/, data)
      assert_match(/"network_token_cryptogram\":\"#{@network_token.payment_cryptogram}\"/, data)
      assert_match(/"network_token_expire_date\":\"#{@network_token.month}\/#{@network_token.year}\"/, data)
    end.respond_with(successful_purchase_with_network_token)

    assert_success response
    assert_equal '66e45f37b6700ed7119469c774a824a006a1da0293ffd204', response.authorization
  end

  def test_scrub_network_token
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_network_token), post_scrubbed_network_token
  end

  def test_supported_countries
    assert_equal %w[BR MX CO CL AR PE BO EC CR DO GT PA PY UY], EbanxGateway.supported_countries
  end

  private

  def pre_scrubbed
    %q(
      request_body={\"integration_key\":\"Ac1EwnH0ud2UIndICS37l0\",\"operation\":\"request\",\"payment\":{\"amount_total\":\"1.00\",\"currency_code\":\"USD\",\"merchant_payment_code\":\"2bed75b060e936834e354d944aeaa892\",\"name\":\"Longbob Longsen\",\"email\":\"unspecified@example.com\",\"document\":\"853.513.468-93\",\"payment_type_code\":\"visa\",\"creditcard\":{\"card_number\":\"4111111111111111\",\"card_name\":\"Longbob Longsen\",\"card_due_date\":\"9/2018\",\"card_cvv\":\"123\"},\"address\":\"Rua E\",\"street_number\":\"1040\",\"city\":\"Maracana\u{fa}\",\"state\":\"CE\",\"zipcode\":\"61919-230\",\"country\":\"BR\",\"phone_number\":\"(555)555-5555\"}}
    )
  end

  def post_scrubbed
    %q(
      request_body={\"integration_key\":\"[FILTERED]\",\"operation\":\"request\",\"payment\":{\"amount_total\":\"1.00\",\"currency_code\":\"USD\",\"merchant_payment_code\":\"2bed75b060e936834e354d944aeaa892\",\"name\":\"Longbob Longsen\",\"email\":\"unspecified@example.com\",\"document\":\"853.513.468-93\",\"payment_type_code\":\"visa\",\"creditcard\":{\"card_number\":\"[FILTERED]\",\"card_name\":\"Longbob Longsen\",\"card_due_date\":\"9/2018\",\"card_cvv\":\"[FILTERED]\"},\"address\":\"Rua E\",\"street_number\":\"1040\",\"city\":\"Maracana\u{fa}\",\"state\":\"CE\",\"zipcode\":\"61919-230\",\"country\":\"BR\",\"phone_number\":\"(555)555-5555\"}}
    )
  end

  def pre_scrubbed_network_token
    %q(
      request_body={\"payment\":{\"amount_total\":\"1.00\",\"currency_code\":\"USD\",\"merchant_payment_code\":\"dc2df1269619de89d72ca6c8fc1ee52a\",\"instalments\":1,\"order_number\":\"d17a85de6bb15444b82320a7ab0ce846\",\"name\":\"Longbob Longsen\",\"email\":\"neymar@test.com\",\"document\":\"853.513.468-93\",\"payment_type_code\":\"creditcard\",\"creditcard\":{\"network_token_pan\":\"4111111111111111\",\"network_token_expire_date\":\"12/2030\",\"network_token_cryptogram\":\"example+/_cryptogram==\",\"soft_descriptor\":\"ActiveMerchant\"},\"address\":\"Rua E\",\"street_number\":\"1040\",\"city\":\"Maracana\u00FA\",\"state\":\"CE\",\"zipcode\":\"61919-230\",\"country\":\"br\",\"phone_number\":\"(555)555-5555\",\"tags\":[\"Spreedly\"]},\"integration_key\":\"test_ik_Gc1EwnH0ud2UIndICS37lA\",\"operation\":\"request\",\"device_id\":\"34c376b2767\",\"metadata\":{\"metadata_1\":\"test\",\"metadata_2\":\"test2\",\"merchant_payment_code\":\"d17a85de6bb15444b82320a7ab0ce846\"}}
    )
  end

  def post_scrubbed_network_token
    %q(
      request_body={\"payment\":{\"amount_total\":\"1.00\",\"currency_code\":\"USD\",\"merchant_payment_code\":\"dc2df1269619de89d72ca6c8fc1ee52a\",\"instalments\":1,\"order_number\":\"d17a85de6bb15444b82320a7ab0ce846\",\"name\":\"Longbob Longsen\",\"email\":\"neymar@test.com\",\"document\":\"853.513.468-93\",\"payment_type_code\":\"creditcard\",\"creditcard\":{\"network_token_pan\":\"[FILTERED]\",\"network_token_expire_date\":\"12/2030\",\"network_token_cryptogram\":\"[FILTERED]\",\"soft_descriptor\":\"ActiveMerchant\"},\"address\":\"Rua E\",\"street_number\":\"1040\",\"city\":\"Maracana\u00FA\",\"state\":\"CE\",\"zipcode\":\"61919-230\",\"country\":\"br\",\"phone_number\":\"(555)555-5555\",\"tags\":[\"Spreedly\"]},\"integration_key\":\"[FILTERED]\",\"operation\":\"request\",\"device_id\":\"34c376b2767\",\"metadata\":{\"metadata_1\":\"test\",\"metadata_2\":\"test2\",\"merchant_payment_code\":\"d17a85de6bb15444b82320a7ab0ce846\"}}
    )
  end

  def successful_purchase_response
    %(
      {"payment":{"hash":"592db57ad6933455efbb62a48d1dfa091dd7cd092109db99","pin":"081043552","merchant_payment_code":"ca2251ed6ac582162b17d77dfd7fb98a","order_number":null,"status":"CO","status_date":"2017-05-30 15:10:01","open_date":"2017-05-30 15:10:01","confirm_date":"2017-05-30 15:10:01","transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"OK","description":"Sandbox - Test credit card, transaction captured"},"pre_approved":true,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def failed_purchase_response
    %(
      {"payment":{"hash":"592dd2f17965cd3d7a17e71a3fe943b8363c72d60caffacc","pin":"655998606","merchant_payment_code":"e71e467805aef9064599bc5a76e98e23","order_number":null,"status":"CA","status_date":"2017-05-30 17:15:45","open_date":"2017-05-30 17:15:45","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"NOK","description":"Sandbox - Test credit card, transaction declined reason insufficientFunds"},"pre_approved":false,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def successful_authorize_response
    %(
      {"payment":{"hash":"592dc02dbe421478a132bf5c2ecfe52c86ac01b454ae799b","pin":"296389224","merchant_payment_code":"8e5c943c3c93adbed8d8a7347ca333fe","order_number":null,"status":"PE","status_date":null,"open_date":"2017-05-30 15:55:40","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"OK","description":"Sandbox - Test credit card, transaction will be approved"},"pre_approved":true,"capture_available":true,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def failed_authorize_response
    %(
      {"payment":{"hash":"592dd2146d5b8a27924daaa0f0248d8c582cb2ce6b67495e","pin":"467618452","merchant_payment_code":"7883bdbbdfa961ce753247fbeb4ff99d","order_number":null,"status":"CA","status_date":"2017-05-30 17:12:03","open_date":"2017-05-30 17:12:03","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-02","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"NOK","description":"Sandbox - Test credit card, transaction declined reason insufficientFunds"},"pre_approved":false,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def successful_verify_response
    %(
      {"status":"SUCCESS","payment_type_code":"creditcard","card_verification":{"transaction_status":{"code":"OK","description":"Accepted"},"transaction_type":"ZERO DOLLAR"}}
    )
  end

  def failed_verify_response
    %(
      {"status":"SUCCESS","payment_type_code":"discover","card_verification":{"transaction_status":{"code":"NOK", "description":"Not accepted"}, "transaction_type":"GHOST AUTHORIZATION"}}
    )
  end

  def successful_capture_response
    %(
      {"payment":{"hash":"5dee94502bd59660b801c441ad5a703f2c4123f5fc892ccb","pin":"675968133","country":"br","merchant_payment_code":"b98b2892b80771b9dadf2ebc482cb65d","order_number":null,"status":"CO","status_date":"2019-12-09 18:37:05","open_date":"2019-12-09 18:37:04","confirm_date":"2019-12-09 18:37:05","transfer_date":null,"amount_br":"4.19","amount_ext":"1.00","amount_iof":"0.02","currency_rate":"4.1700","currency_ext":"USD","due_date":"2019-12-12","instalments":"1","payment_type_code":"visa","details":{"billing_descriptor":"DEMONSTRATION"},"transaction_status":{"acquirer":"EBANX","code":"OK","description":"Accepted"},"pre_approved":true,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def failed_partial_capture_response
    %(
      {"status":"ERROR", "status_code":"BP-CAP-11", "status_message":"Partial capture not available"}
    )
  end

  def failed_capture_response
    %(
      {"status":"ERROR","status_code":"BP-CAP-1","status_message":"Parameters hash or merchant_payment_code not informed"}
    )
  end

  def successful_refund_response
    %(
      {"payment":{"hash":"59306246f2a0c5f327a15dd6492687e197aca7eda179da08","pin":"446189033","merchant_payment_code":"b5e1f7298f8fa645e8a903fbdc5ce44a","order_number":null,"status":"CO","status_date":"2017-06-01 15:51:49","open_date":"2017-06-01 15:51:49","confirm_date":"2017-06-01 15:51:49","transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-04","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"OK","description":"Sandbox - Test credit card, transaction captured"},"pre_approved":true,"capture_available":false,"refunds":[{"id":"20739","merchant_refund_code":null,"status":"RE","request_date":"2017-06-01 15:51:50","pending_date":null,"confirm_date":null,"cancel_date":null,"amount_ext":"1.00","description":"full refund"}],"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"refund":{"id":"20739","merchant_refund_code":null,"status":"RE","request_date":"2017-06-01 15:51:50","pending_date":null,"confirm_date":null,"cancel_date":null,"amount_ext":"1.00","description":"full refund"},"operation":"refund","status":"SUCCESS"}
    )
  end

  def failed_refund_response
    %(
      {"status":"ERROR","status_code":"BP-REF-CAN-2","status_message":"Payment not found with this hash: "}
    )
  end

  def successful_void_response
    %(
      {"payment":{"hash":"5930629dde0899dc53b3557ea9887aa8f3d264a91d115d40","pin":"465556618","merchant_payment_code":"8b97c49aecffbb309dadd08c87ccbdd0","order_number":null,"status":"CA","status_date":"2017-06-01 15:53:18","open_date":"2017-06-01 15:53:17","confirm_date":null,"transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-06-04","instalments":"1","payment_type_code":"visa","transaction_status":{"acquirer":"EBANX","code":"NOK","description":"Sandbox - Test credit card, transaction cancelled"},"pre_approved":false,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"LONGBOB LONGSEN","birth_date":null}},"operation":"cancel","status":"SUCCESS"}
    )
  end

  def failed_void_response
    %(
      {"status":"ERROR","status_code":"BP-CAN-1","status_message":"Parameter hash not informed"}
    )
  end

  def successful_store_response
    %(
      {"status":"SUCCESS","payment_type_code":"visa","token":"a61a7c98535718801395991b5112f888d359c2d632e2c3bb8afe75aa23f3334d7fd8dc57d7721f8162503773063de59ee85901b5714a92338c6d9c0352aee78c","masked_card_number":"411111xxxxxx1111"}
    )
  end

  def successful_purchase_with_stored_card_response
    %(
      {"payment":{"hash":"59d3e2955021c5e2b180e1ea9670e2d9675c15453a2ab346","pin":"252076123","merchant_payment_code":"a942f8a68836e888fa8e8af1e8ca4bf2","order_number":null,"status":"CO","status_date":"2017-10-03 19:18:45","open_date":"2017-10-03 19:18:44","confirm_date":"2017-10-03 19:18:45","transfer_date":null,"amount_br":"3.31","amount_ext":"1.00","amount_iof":"0.01","currency_rate":"3.3000","currency_ext":"USD","due_date":"2017-10-06","instalments":"1","payment_type_code":"visa","details":{"billing_descriptor":""},"transaction_status":{"acquirer":"EBANX","code":"OK","description":"Accepted"},"pre_approved":true,"capture_available":false,"customer":{"document":"85351346893","email":"unspecified@example.com","name":"NOT PROVIDED","birth_date":null}},"status":"SUCCESS"}
    )
  end

  def invalid_cred_response
    %(
      {"status":"ERROR","status_code":"DA-1","status_message":"Invalid integration key"}
    )
  end

  def successful_purchase_with_network_token
    %(
      {"payment":{"hash":"66e45f37b6700ed7119469c774a824a006a1da0293ffd204","country":"br","merchant_payment_code":"dc2df1269619de89d72ca6c8fc1ee52a","order_number":"d17a85de6bb15444b82320a7ab0ce846","status":"CO","status_date":"2024-09-13 15:50:15","open_date":"2024-09-13 15:50:15","confirm_date":"2024-09-13 15:50:15","transfer_date":null,"amount_br":"5.85","amount_ext":"1.00","amount_iof":"0.02","currency_rate":"5.8300","currency_ext":"USD","due_date":"2024-09-16","instalments":"1","payment_type_code":"visa","details":{"billing_descriptor":"SPREEDLY"},"transaction_status":{"acquirer":"EBANX","code":"OK","description":"Accepted","authcode":"87017"},"pre_approved":true,"capture_available":false},"status":"SUCCESS"}
    )
  end
end
