require 'test_helper'

class FortisTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FortisGateway.new(user_id: 'abc', user_api_key: 'def', developer_id: 'ghi', location_id: 'jkl')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_raises_error_without_required_options
    assert_raises(ArgumentError) { FortisGateway.new }
    assert_raises(ArgumentError) { FortisGateway.new(user_id: 'abc') }
    assert_raises(ArgumentError) { FortisGateway.new(user_id: 'abc', user_api_key: 'def') }
    assert_nothing_raised { FortisGateway.new(user_id: 'abc', user_api_key: 'def', developer_id: 'ghi') }
  end

  def test_parse_valid_json
    body = '{"key": "value"}'
    expected_result = { 'key' => 'value' }.with_indifferent_access
    result = @gateway.send(:parse, body)
    assert_equal expected_result, result
  end

  def test_parse_invalid_json
    body = 'invalid json'
    result = @gateway.send(:parse, body)
    assert_equal 'Unable to parse JSON response', result[:status]
    assert_equal body, result[:errors]
    assert result[:message].include?('unexpected token')
  end

  def test_parse_empty_json
    body = ''
    result = @gateway.send(:parse, body)
    assert_equal 'Unable to parse JSON response', result[:status]
    assert_equal body, result[:errors]
    assert result[:message].include?('unexpected token')
  end

  def test_request_headers
    expected = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'user-id' => 'abc',
      'user-api-key' => 'def',
      'developer-id' => 'ghi'
    }
    assert_equal expected, @gateway.send(:request_headers)
  end

  def test_url_for_test_environment
    @gateway.stubs(:test?).returns(true)
    assert_equal 'https://api.sandbox.fortis.tech/v1/some_action', @gateway.send(:url, '/some_action')
  end

  def test_url_for_live_environment
    @gateway.stubs(:test?).returns(false)
    assert_equal 'https://api.fortis.tech/v1/some_action', @gateway.send(:url, '/some_action')
  end

  def test_success_from
    assert @gateway.send(:success_from, 200, { data: { status_code: 101 } })
    refute @gateway.send(:success_from, 200, { data: { status_code: 301 } })
    refute @gateway.send(:success_from, 200, { data: { status_code: 999 } })
  end

  def test_message_from
    assert_equal 'Transaction Approved', @gateway.send(:message_from, { data: { verbiaje: 'Transaction Approved' } })
    assert_equal 'CC - Approved / ACH - Accepted', @gateway.send(:message_from, { data: { reason_code_id: 1000 } })
    assert_equal 'Sale cc Approved', @gateway.send(:message_from, { data: { status_code: 101 } })
    assert_equal 'Reserved for Future Fraud Reason Codes', @gateway.send(:message_from, { data: { reason_code_id: 1302 } })
    assert_equal 999, @gateway.send(:message_from, { data: { status_code: 999 } })
  end

  def test_get_reason_description_from
    assert_equal 'CC - Approved / ACH - Accepted', @gateway.send(:get_reason_description_from, { data: { reason_code_id: 1000 } })
    assert_equal 'Reserved for Future Fraud Reason Codes', @gateway.send(:get_reason_description_from, { data: { reason_code_id: 1302 } })
    assert_nil @gateway.send(:get_reason_description_from, { data: { reason_code_id: 9999 } })
  end

  def test_authorization_from
    assert_equal '31efa3732483237895c9a23d', @gateway.send(:authorization_from, { data: { id: '31efa3732483237895c9a23d' } })
    assert_nil @gateway.send(:authorization_from, { data: { id: nil } })
    assert_nil @gateway.send(:authorization_from, { data: {} })
    assert_nil @gateway.send(:authorization_from, {})
  end

  def test_successfully_build_an_authorize_request
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(699, @credit_card, @options)
    end.check_request do |_method, _endpoint, data, _headers|
      request = JSON.parse(data)
      assert_equal '699', request['transaction_amount']
      assert_equal @options[:order_id], request['order_number']
      assert_equal @options[:order_id], request['transaction_api_id']
      assert_equal @credit_card.number, request['account_number']
      assert_equal @credit_card.month.to_s.rjust(2, '0') + @credit_card.year.to_s[-2..-1], request['exp_date']
      assert_equal @credit_card.verification_value, request['cvv']
      assert_equal @credit_card.name, request['account_holder_name']
      assert_equal @options[:billing_address][:address1], request['billing_address']['street']
      assert_equal @options[:billing_address][:city], request['billing_address']['city']
      assert_equal @options[:billing_address][:state], request['billing_address']['state']
      assert_equal @options[:billing_address][:zip], request['billing_address']['postal_code']
      assert_equal 'CAN', request['billing_address']['country']
    end.respond_with(successful_authorize_response)
  end

  def test_on_purchase_point_to_the_sale_endpoint
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(699, @credit_card, @options)
    end.check_request do |_method, endpoint, _data, _headers|
      assert_match %r{sale}, endpoint
    end.respond_with(successful_authorize_response)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_error_code_from_with_status_code_301
    response = { data: { status_code: 301, reason_code_id: 1622 } }
    assert_equal '301 - 1622', @gateway.send(:error_code_from, 400, response)
  end

  def test_error_code_from_with_status_code_101
    response = { data: { status_code: 101 } }
    assert_nil @gateway.send(:error_code_from, 200, response)
  end

  def test_error_code_from_with_status_code_500
    response = { data: { status_code: 500 } }
    assert_equal '500', @gateway.send(:error_code_from, 500, response)
  end

  def test_error_code_from_with_nil_status_code
    response = { data: { status_code: nil } }
    assert_nil @gateway.send(:error_code_from, 204, response)
  end

  private

  def pre_scrubbed
    <<~PRE
      <- "POST /v1/transactions/cc/auth-only/keyed HTTP/1.1\r\ncontent-type: application/json\r\naccept: application/json\r\nuser-id: 11ef69fdc8fd8db2b07213de\r\nuser-api-key: 11ef9c5897f42ac2a072e521\r\ndeveloper-id: bEgKPZos\r\nconnection: close\r\naccept-encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nuser-agent: Ruby\r\nhost: api.sandbox.fortis.tech\r\ncontent-length: 154\r\n\r\n"
      <- "{\"transaction_amount\":\"100\",\"order_number\":null,\"account_number\":\"5454545454545454\",\"exp_date\":\"0925\",\"cvv\":\"123\",\"account_holder_name\":\"Longbob Longsen\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Fri, 15 Nov 2024 17:00:42 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 2031\r\n"
      -> "Connection: close\r\n"
      -> "x-amzn-RequestId: dfd852a8-5c39-4558-9f05-8eaa14affac9\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: BTCoUG6SIAMEsdw=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-67377e34-170c289b473cbb2e56aeab61;Parent=7e76c3e737bb48c3;Sampled=0;Lineage=1:ae593ade:0\r\n"
      -> "Access-Control-Max-Age: 86400\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "\r\n"
      reading 2031 bytes...
      -> "{\"type\":\"Transaction\",\"data\":{\"id\":\"31efa3732483237895c9a23d\",\"payment_method\":\"cc\",\"account_vault_id\":null,\"recurring_id\":null,\"first_six\":\"545454\",\"last_four\":\"5454\",\"account_holder_name\":\"Longbob Longsen\",\"transaction_amount\":100,\"description\":null,\"transaction_code\":null,\"avs\":null,\"batch\":null,\"verbiage\":\"Test 7957\",\"transaction_settlement_status\":null,\"effective_date\":null,\"return_date\":null,\"created_ts\":1731690040,\"modified_ts\":1731690040,\"transaction_api_id\":null,\"terms_agree\":null,\"notification_email_address\":null,\"notification_email_sent\":true,\"notification_phone\":null,\"response_message\":null,\"auth_amount\":100,\"auth_code\":\"a37325\",\"type_id\":20,\"location_id\":\"11ef69fdc684ae30b436c55b\",\"reason_code_id\":1000,\"contact_id\":null,\"product_transaction_id\":\"11ef69fdc6debc2cb1af505c\",\"tax\":0,\"customer_ip\":\"34.234.17.123\",\"customer_id\":null,\"po_number\":null,\"avs_enhanced\":\"V\",\"cvv_response\":\"N\",\"cavv_result\":null,\"clerk_number\":null,\"tip_amount\":0,\"created_user_id\":\"11ef69fdc8fd8db2b07213de\",\"modified_user_id\":\"11ef69fdc8fd8db2b07213de\",\"ach_identifier\":null,\"check_number\":null,\"recurring_flag\":\"no\",\"installment_counter\":null,\"installment_total\":null,\"settle_date\":null,\"charge_back_date\":null,\"void_date\":null,\"account_type\":\"mc\",\"is_recurring\":false,\"is_accountvault\":false,\"transaction_c1\":null,\"transaction_c2\":null,\"transaction_c3\":null,\"additional_amounts\":[],\"terminal_serial_number\":null,\"entry_mode_id\":\"K\",\"terminal_id\":null,\"quick_invoice_id\":null,\"ach_sec_code\":null,\"custom_data\":null,\"ebt_type\":null,\"voucher_number\":null,\"hosted_payment_page_id\":null,\"transaction_batch_id\":null,\"currency_code\":840,\"par\":\"ZZZZZZZZZZZZZZZZZZZZ545454545\",\"stan\":null,\"currency\":\"USD\",\"secondary_amount\":0,\"card_bin\":\"545454\",\"paylink_id\":null,\"emv_receipt_data\":null,\"status_code\":102,\"token_id\":null,\"wallet_type\":null,\"order_number\":\"963274518498\",\"routing_number\":null,\"trx_source_code\":12,\"billing_address\":{\"city\":null,\"state\":null,\"postal_code\":null,\"phone\":null,\"country\":null,\"street\":null},\"is_token\":false}}"
    PRE
  end

  def post_scrubbed
    <<~PRE
      <- "POST /v1/transactions/cc/auth-only/keyed HTTP/1.1\r\ncontent-type: application/json\r\naccept: application/json\r\nuser-id: [FILTERED]\r\nuser-api-key: [FILTERED]\r\ndeveloper-id: [FILTERED]\r\nconnection: close\r\naccept-encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nuser-agent: Ruby\r\nhost: api.sandbox.fortis.tech\r\ncontent-length: 154\r\n\r\n"
      <- "{\"transaction_amount\":\"100\",\"order_number\":null,\"account_number\":\"[FILTERED]\",\"exp_date\":\"0925\",\"cvv\":\"[FILTERED]\",\"account_holder_name\":\"Longbob Longsen\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Fri, 15 Nov 2024 17:00:42 GMT\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Content-Length: 2031\r\n"
      -> "Connection: close\r\n"
      -> "x-amzn-RequestId: dfd852a8-5c39-4558-9f05-8eaa14affac9\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "x-amz-apigw-id: BTCoUG6SIAMEsdw=\r\n"
      -> "X-Amzn-Trace-Id: Root=1-67377e34-170c289b473cbb2e56aeab61;Parent=7e76c3e737bb48c3;Sampled=0;Lineage=1:ae593ade:0\r\n"
      -> "Access-Control-Max-Age: 86400\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "\r\n"
      reading 2031 bytes...
      -> "{\"type\":\"Transaction\",\"data\":{\"id\":\"31efa3732483237895c9a23d\",\"payment_method\":\"cc\",\"account_vault_id\":null,\"recurring_id\":null,\"first_six\":\"545454\",\"last_four\":\"5454\",\"account_holder_name\":\"Longbob Longsen\",\"transaction_amount\":100,\"description\":null,\"transaction_code\":null,\"avs\":null,\"batch\":null,\"verbiage\":\"Test 7957\",\"transaction_settlement_status\":null,\"effective_date\":null,\"return_date\":null,\"created_ts\":1731690040,\"modified_ts\":1731690040,\"transaction_api_id\":null,\"terms_agree\":null,\"notification_email_address\":null,\"notification_email_sent\":true,\"notification_phone\":null,\"response_message\":null,\"auth_amount\":100,\"auth_code\":\"a37325\",\"type_id\":20,\"location_id\":\"11ef69fdc684ae30b436c55b\",\"reason_code_id\":1000,\"contact_id\":null,\"product_transaction_id\":\"11ef69fdc6debc2cb1af505c\",\"tax\":0,\"customer_ip\":\"34.234.17.123\",\"customer_id\":null,\"po_number\":null,\"avs_enhanced\":\"V\",\"cvv_response\":\"N\",\"cavv_result\":null,\"clerk_number\":null,\"tip_amount\":0,\"created_user_id\":\"11ef69fdc8fd8db2b07213de\",\"modified_user_id\":\"11ef69fdc8fd8db2b07213de\",\"ach_identifier\":null,\"check_number\":null,\"recurring_flag\":\"no\",\"installment_counter\":null,\"installment_total\":null,\"settle_date\":null,\"charge_back_date\":null,\"void_date\":null,\"account_type\":\"mc\",\"is_recurring\":false,\"is_accountvault\":false,\"transaction_c1\":null,\"transaction_c2\":null,\"transaction_c3\":null,\"additional_amounts\":[],\"terminal_serial_number\":null,\"entry_mode_id\":\"K\",\"terminal_id\":null,\"quick_invoice_id\":null,\"ach_sec_code\":null,\"custom_data\":null,\"ebt_type\":null,\"voucher_number\":null,\"hosted_payment_page_id\":null,\"transaction_batch_id\":null,\"currency_code\":840,\"par\":\"ZZZZZZZZZZZZZZZZZZZZ545454545\",\"stan\":null,\"currency\":\"USD\",\"secondary_amount\":0,\"card_bin\":\"545454\",\"paylink_id\":null,\"emv_receipt_data\":null,\"status_code\":102,\"token_id\":null,\"wallet_type\":null,\"order_number\":\"963274518498\",\"routing_number\":null,\"trx_source_code\":12,\"billing_address\":{\"city\":null,\"state\":null,\"postal_code\":null,\"phone\":null,\"country\":null,\"street\":null},\"is_token\":false}}"
    PRE
  end

  def successful_authorize_response
    <<-JSON
      {
        "type": "Transaction",
        "data": {
          "id": "31efa361a11da7588f260af5",
          "payment_method": "cc",
          "account_vault_id": null,
          "recurring_id": null,
          "first_six": "545454",
          "last_four": "5454",
          "account_holder_name": "smith",
          "transaction_amount": 699,
          "description": null,
          "transaction_code": null,
          "avs": null,
          "batch": null,
          "verbiage": "Test 4669",
          "transaction_settlement_status": null,
          "effective_date": null,
          "return_date": null,
          "created_ts": 1731682518,
          "modified_ts": 1731682518,
          "transaction_api_id": null,
          "terms_agree": null,
          "notification_email_address": null,
          "notification_email_sent": true,
          "notification_phone": null,
          "response_message": null,
          "auth_amount": 699,
          "auth_code": "a361a2",
          "type_id": 20,
          "location_id": "11ef69fdc684ae30b436c55b",
          "reason_code_id": 1000,
          "contact_id": null,
          "product_transaction_id": "11ef69fdc6debc2cb1af505c",
          "tax": 0,
          "customer_ip": "34.234.17.123",
          "customer_id": null,
          "po_number": null,
          "avs_enhanced": "V",
          "cvv_response": "N",
          "cavv_result": null,
          "clerk_number": null,
          "tip_amount": 0,
          "created_user_id": "11ef69fdc8fd8db2b07213de",
          "modified_user_id": "11ef69fdc8fd8db2b07213de",
          "ach_identifier": null,
          "check_number": null,
          "recurring_flag": "no",
          "installment_counter": null,
          "installment_total": null,
          "settle_date": null,
          "charge_back_date": null,
          "void_date": null,
          "account_type": "mc",
          "is_recurring": false,
          "is_accountvault": false,
          "transaction_c1": null,
          "transaction_c2": null,
          "transaction_c3": null,
          "additional_amounts": [],
          "terminal_serial_number": null,
          "entry_mode_id": "K",
          "terminal_id": null,
          "quick_invoice_id": null,
          "ach_sec_code": null,
          "custom_data": null,
          "ebt_type": null,
          "voucher_number": null,
          "hosted_payment_page_id": null,
          "transaction_batch_id": null,
          "currency_code": 840,
          "par": "ZZZZZZZZZZZZZZZZZZZZ545454545",
          "stan": null,
          "currency": "USD",
          "secondary_amount": 0,
          "card_bin": "545454",
          "paylink_id": null,
          "emv_receipt_data": null,
          "status_code": 102,
          "token_id": null,
          "wallet_type": null,
          "order_number": "865934726945",
          "routing_number": null,
          "trx_source_code": 12,
          "billing_address": {
            "city": null,
            "state": null,
            "postal_code": null,
            "phone": null,
            "country": null,
            "street": null
          },
          "is_token": false
        }
      }
    JSON
  end
end
