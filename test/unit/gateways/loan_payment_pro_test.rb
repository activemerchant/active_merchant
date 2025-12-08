require 'test_helper'

class LoanPaymentProTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = LoanPaymentProGateway.new(transaction_key: 'login')
    @credit_card = credit_card('4000100011112224', month: 9, year: 2025, verification_value: '123')
    @amount = 500

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_raises_error_without_required_options
    assert_raises(ArgumentError) { LoanPaymentProGateway.new }
    assert_nothing_raised { LoanPaymentProGateway.new(transaction_key: 'abc') }
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
      TransactionKey: 'login'
    }
    assert_equal expected, @gateway.send(:request_headers)
  end

  def test_success_from
    assert @gateway.send(:success_from, @gateway.send(:parse, successful_purchase_response))
    refute @gateway.send(:success_from, @gateway.send(:parse, failed_purchase_response))
  end

  def test_message_from
    assert_equal 'Transaction Approved.', @gateway.send(:message_from, @gateway.send(:parse, successful_purchase_response))
    assert_equal 'Invalid Test Payment Instrument', @gateway.send(:message_from, @gateway.send(:parse, failed_purchase_response))
  end

  def test_authorization_from
    assert_equal '4c3cde2a-fe29-4c40-b445-1f071798225f', @gateway.send(:authorization_from, @gateway.send(:parse, successful_purchase_response))
    assert_equal 'a718b5cc-08ab-419d-9c76-4049de5a4030', @gateway.send(:authorization_from, @gateway.send(:parse, failed_purchase_response))
  end

  def test_successfully_build_an_authorize_request
    stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |method, endpoint, data, headers|
      assert_equal :post, method
      assert_match(/v2-3\/paymentcards\/authorize/, endpoint)
      assert_match(/login/, headers[:TransactionKey])

      request = URI.decode_www_form(data).to_h

      assert_equal '5.00', request['Amount']
      assert_equal '1', request['InvoiceId']
      assert_equal '4000100011112224', request['CardNumber']
      assert_equal '123', request['CardCode']
      assert_equal '09', request['ExpMonth']
      assert_equal '25', request['ExpYear']
      assert_equal 'Jim', request['BillingFirstName']
      assert_equal 'Smith', request['BillingLastName']
      assert_equal '456 My Street', request['BillingAddress1']
      assert_equal 'Apt 1', request['BillingAddress2']
      assert_equal 'Ottawa', request['BillingCity']
      assert_equal 'ON', request['BillingState']
      assert_equal 'K1C2N6', request['BillingZip']
    end.respond_with(successful_purchase_response)
  end

  def test_auth_purchase_path_with_credit_card
    assert_equal 'v2-3/paymentcards/run', @gateway.send(:auth_purchase_path, @credit_card, @options)
    assert_equal 'v2-3/paymentcards/authorize', @gateway.send(:auth_purchase_path, @credit_card, @options.merge(action: :authorize))
  end

  def test_auth_purchase_path_with_token
    assert_equal 'v2-3/payments/paymentcards/abc123/run', @gateway.send(:auth_purchase_path, 'abc123', @options)
    assert_equal 'v2-3/payments/paymentcards/abc123/authorize', @gateway.send(:auth_purchase_path, 'abc123', @options.merge(action: :authorize))
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~PRE
      <- "POST //v2-3/paymentcards/run HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nTransactionkey: 74b0ff6d-279d-4b0a-96c8-b73bb39249a8\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: gateway.loanpaymentpro.com\r\nContent-Length: 270\r\n\r\n"
      <- "InvoiceId=e90cba9c-0442-4bcf-aa74-786e0a4ec5f8&Amount=5.00&CardNumber=4000100011112224&CardCode=123&ExpMonth=09&ExpYear=25&BillingFirstName=Jim&BillingLastName=Smith&BillingAddress1=456+My+Street&BillingAddress2=Apt+1&BillingCity=Ottawa&BillingState=ON&BillingZip=K1C2N6"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Expires: -1\r\n"
      -> "Content-Length: 320\r\n"
      -> "Date: Mon, 05 May 2025 19:52:49 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 320 bytes...
      -> "{\"BatchID\":\"22154071-6ad3-45fb-a1f1-ee62f10e8c0c\",\"Status\":\"Success\",\"ResponseCode\":\"29\",\"Message\":\"Transaction Approved.\",\"AuthCode\":\"2ad6fe13-277c-4a4a-9752-e248d6f425b2\",\"TransactionId\":\"05e8b0c0-f267-4d22-b531-b31911cf137f\",\"AVSResultCode\":\"\",\"AVSResultMessage\":\"\",\"CardCodeResultCode\":\"\",\"CardCodeResultMessage\":\"\"}"
    PRE
  end

  def post_scrubbed
    <<~PRE
      <- "POST //v2-3/paymentcards/run HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nTransactionkey: [FILTERED]\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: gateway.loanpaymentpro.com\r\nContent-Length: 270\r\n\r\n"
      <- "InvoiceId=e90cba9c-0442-4bcf-aa74-786e0a4ec5f8&Amount=5.00&CardNumber=[FILTERED]&CardCode=[FILTERED]&ExpMonth=09&ExpYear=25&BillingFirstName=Jim&BillingLastName=Smith&BillingAddress1=456+My+Street&BillingAddress2=Apt+1&BillingCity=Ottawa&BillingState=ON&BillingZip=K1C2N6"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Expires: -1\r\n"
      -> "Content-Length: 320\r\n"
      -> "Date: Mon, 05 May 2025 19:52:49 GMT\r\n"
      -> "Connection: close\r\n"
      -> "\r\n"
      reading 320 bytes...
      -> "{\"BatchID\":\"22154071-6ad3-45fb-a1f1-ee62f10e8c0c\",\"Status\":\"Success\",\"ResponseCode\":\"29\",\"Message\":\"Transaction Approved.\",\"AuthCode\":\"2ad6fe13-277c-4a4a-9752-e248d6f425b2\",\"TransactionId\":\"05e8b0c0-f267-4d22-b531-b31911cf137f\",\"AVSResultCode\":\"\",\"AVSResultMessage\":\"\",\"CardCodeResultCode\":\"\",\"CardCodeResultMessage\":\"\"}"
    PRE
  end

  def successful_purchase_response
    {
      Status: 'Success',
      ResponseCode: '29',
      Message: 'Transaction Approved.',
      AuthCode: '72ea73df-5bc6-4d91-8b2b-a3eaf3784dc1',
      TransactionId: '4c3cde2a-fe29-4c40-b445-1f071798225f'
    }.to_json
  end

  def failed_purchase_response
    {
      BatchID: '',
      Status: 'Failure',
      ResponseCode: '259',
      Message: 'Invalid Test Payment Instrument',
      AuthCode: '',
      TransactionId: 'a718b5cc-08ab-419d-9c76-4049de5a4030',
      AVSResultCode: '',
      AVSResultMessage: '',
      CardCodeResultCode: '',
      CardCodeResultMessage: ''
    }.to_json
  end
end
