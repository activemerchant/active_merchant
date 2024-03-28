require 'test_helper'

class FatZebraTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FatZebraGateway.new(
      username: 'TEST',
      token: 'TEST'
    )

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: rand(10000),
      billing_address: address,
      description: 'Store Purchase',
      extra: { card_on_file: false }
    }

    @three_ds_secure = {
      version: '2.2.0',
      cavv: '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=',
      eci: '05',
      xid: 'ODUzNTYzOTcwODU5NzY3Qw==',
      enrolled: 'true',
      authentication_response_status: 'Y'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_metadata
    @gateway.expects(:ssl_request).with { |_method, _url, body, _headers|
      body.match '"metadata":{"foo":"bar"}'
    }.returns(successful_purchase_response_with_metadata)

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(metadata: { 'foo' => 'bar' }))
    assert_success response

    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token
    @gateway.expects(:ssl_request).with { |_method, _url, body, _headers|
      body.match '"card_token":"e1q7dbj2"'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, 'e1q7dbj2', @options)
    assert_success response

    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_token_string
    @gateway.expects(:ssl_request).with { |_method, _url, body, _headers|
      body.match '"card_token":"e1q7dbj2"'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, 'e1q7dbj2', @options)
    assert_success response

    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_successful_multi_currency_purchase
    @gateway.expects(:ssl_request).with { |_method, _url, body, _headers|
      body.match '"currency":"USD"'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, 'e1q7dbj2', @options.merge(currency: 'USD'))
    assert_success response

    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_successful_purchase_with_recurring_flag
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options.merge(recurring: true))
    end.check_request do |_method, _endpoint, data, _headers|
      assert_match(%r("extra":{"ecm":"32"), data)
    end.respond_with(successful_purchase_response)
  end

  def test_successful_purchase_with_descriptor
    @gateway.expects(:ssl_request).with { |_method, _url, body, _headers|
      json = JSON.parse(body)
      json['extra']['name'] == 'Merchant' && json['extra']['location'] == 'Location'
    }.returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, 'e1q7dbj2', @options.merge(merchant: 'Merchant', merchant_location: 'Location'))
    assert_success response

    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_request).with { |_method, _url, body, _headers|
      body.match '"capture":false'
    }.returns(successful_purchase_response)

    assert response = @gateway.authorize(@amount, 'e1q7dbj2', @options)
    assert_success response

    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).with { |_method, url, _body, _headers|
      url =~ %r[purchases/e1q7dbj2/capture\z]
    }.returns(successful_purchase_response)

    response = @gateway.capture(@amount, 'e1q7dbj2', @options)
    assert_success response
    assert_equal '001-P-12345AA|purchases', response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match %r{Invalid Card Number}, response.message
  end

  def test_declined_purchase
    @gateway.expects(:ssl_request).returns(declined_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
    assert_match %r{Card Declined}, response.message
  end

  def test_parse_error
    @gateway.expects(:ssl_request).returns('{') # Some invalid JSON
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Invalid JSON response}, response.message
  end

  def test_request_error
    @gateway.expects(:ssl_request).returns(missing_data_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Card Number is required}, response.message
  end

  def test_successful_tokenization
    @gateway.expects(:ssl_request).returns(successful_tokenize_response)

    assert response = @gateway.store(@credit_card)
    assert_success response
    assert_equal 'e1q7dbj2|credit_cards', response.authorization
  end

  def test_unsuccessful_tokenization
    @gateway.expects(:ssl_request).returns(failed_tokenize_response)

    assert response = @gateway.store(@credit_card)
    assert_failure response
  end

  def test_successful_tokenization_without_cvv
    credit_card = @credit_card
    credit_card.verification_value = nil
    @gateway.expects(:ssl_request).returns(successful_no_cvv_tokenize_response)

    assert response = @gateway.store(credit_card, recurring: true)
    assert_success response
    assert_equal 'ep3c05nzsqvft15wsf1z|credit_cards', response.authorization
  end

  def test_unsuccessful_tokenization_without_cvv
    credit_card = @credit_card
    credit_card.verification_value = nil
    @gateway.expects(:ssl_request).returns(failed_no_cvv_tokenize_response)

    assert response = @gateway.store(credit_card)
    assert_failure response
    assert_equal 'CVV is required', response.message
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    assert response = @gateway.refund(100, 'TEST')
    assert_success response
    assert_equal '003-R-7MNIUMY6|refunds', response.authorization
    assert response.test?
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(unsuccessful_refund_response)

    assert response = @gateway.refund(100, 'TEST')
    assert_failure response
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_three_ds_v2_object_construction
    post = {}
    @options[:three_d_secure] = @three_ds_secure

    @gateway.send(:add_three_ds, post, @options)

    assert post[:extra]
    ds_data = post[:extra]
    ds_options = @options[:three_d_secure]

    assert_equal ds_options[:version], ds_data[:threeds_version]
    assert_equal ds_options[:cavv], ds_data[:cavv]
    assert_equal ds_options[:eci], ds_data[:sli]
    assert_equal ds_options[:xid], ds_data[:xid]
    assert_equal ds_options[:ds_transaction_id], ds_data[:ds_transaction_id]
    assert_equal 'Y', ds_data[:ver]
    assert_equal ds_options[:authentication_response_status], ds_data[:par]
  end

  def test_purchase_with_three_ds
    @options[:three_d_secure] = @three_ds_secure
    stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request(skip_response: true) do |_method, _endpoint, data, _headers|
      three_ds_params = JSON.parse(data)['extra']
      assert_equal '2.2.0', three_ds_params['threeds_version']
      assert_equal '3q2+78r+ur7erb7vyv66vv\/\/\/\/8=', three_ds_params['cavv']
      assert_equal '05', three_ds_params['sli']
      assert_equal 'ODUzNTYzOTcwODU5NzY3Qw==', three_ds_params['xid']
      assert_equal 'Y', three_ds_params['ver']
      assert_equal 'Y', three_ds_params['par']
    end
  end

  def test_formatted_enrollment
    assert_equal 'Y', @gateway.send('formatted_enrollment', 'Y')
    assert_equal 'Y', @gateway.send('formatted_enrollment', 'true')
    assert_equal 'Y', @gateway.send('formatted_enrollment', true)

    assert_equal 'N', @gateway.send('formatted_enrollment', 'N')
    assert_equal 'N', @gateway.send('formatted_enrollment', 'false')
    assert_equal 'N', @gateway.send('formatted_enrollment', false)

    assert_equal 'U', @gateway.send('formatted_enrollment', 'U')
  end

  private

  def pre_scrubbed
    <<~'PRE_SCRUBBED'
      opening connection to gateway.sandbox.fatzebra.com.au:443...
      opened
      starting SSL for gateway.sandbox.fatzebra.com.au:443...
      SSL established
      <- "POST /v1.0/credit_cards HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic VEVTVDpURVNU\r\nUser-Agent: Fat Zebra v1.0/ActiveMerchant 1.56.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.sandbox.fatzebra.com.au\r\nContent-Length: 93\r\n\r\n"
      <- "{\"card_number\":\"5123456789012346\",\"card_expiry\":\"5/2017\",\"cvv\":\"111\",\"card_holder\":\"Foo Bar\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Connection: close\r\n"
      -> "Status: 200 OK\r\n"
      -> "Cache-control: no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Request-Id: 3BA78272_F214_AC10001D_01BB_566A58EC_222F1D_49F4\r\n"
      -> "X-Runtime: 0.142463\r\n"
      -> "Date: Fri, 11 Dec 2015 05:02:36 GMT\r\n"
      -> "X-Rack-Cache: invalidate, pass\r\n"
      -> "X-Sandbox: true\r\n"
      -> "X-Backend-Server: app-3\r\n"
      -> "\r\n"
      reading all...
      -> "{\"successful\":true,\"response\":{\"token\":\"nkk9rhwu\",\"card_holder\":\"Foo Bar\",\"card_number\":\"512345XXXXXX2346\",\"card_expiry\":\"2017-05-31T23:59:59+10:00\",\"authorized\":true,\"transaction_count\":0},\"errors\":[],\"test\":true}"
      read 214 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~'POST_SCRUBBED'
      opening connection to gateway.sandbox.fatzebra.com.au:443...
      opened
      starting SSL for gateway.sandbox.fatzebra.com.au:443...
      SSL established
      <- "POST /v1.0/credit_cards HTTP/1.1\r\nContent-Type: application/x-www-form-urlencoded\r\nAuthorization: Basic [FILTERED]\r\nUser-Agent: Fat Zebra v1.0/ActiveMerchant 1.56.0\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nConnection: close\r\nHost: gateway.sandbox.fatzebra.com.au\r\nContent-Length: 93\r\n\r\n"
      <- "{\"card_number\":\"[FILTERED]\",\"card_expiry\":\"5/2017\",\"cvv\":\"[FILTERED]\",\"card_holder\":\"Foo Bar\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Connection: close\r\n"
      -> "Status: 200 OK\r\n"
      -> "Cache-control: no-store\r\n"
      -> "Pragma: no-cache\r\n"
      -> "X-Request-Id: 3BA78272_F214_AC10001D_01BB_566A58EC_222F1D_49F4\r\n"
      -> "X-Runtime: 0.142463\r\n"
      -> "Date: Fri, 11 Dec 2015 05:02:36 GMT\r\n"
      -> "X-Rack-Cache: invalidate, pass\r\n"
      -> "X-Sandbox: true\r\n"
      -> "X-Backend-Server: app-3\r\n"
      -> "\r\n"
      reading all...
      -> "{\"successful\":true,\"response\":{\"token\":\"nkk9rhwu\",\"card_holder\":\"Foo Bar\",\"card_number\":\"[FILTERED]\",\"card_expiry\":\"2017-05-31T23:59:59+10:00\",\"authorized\":true,\"transaction_count\":0},\"errors\":[],\"test\":true}"
      read 214 bytes
      Conn close
    POST_SCRUBBED
  end

  # Place raw successful response from gateway here
  def successful_purchase_response
    {
      successful: true,
      response: {
        authorization: 55355,
        id: '001-P-12345AA',
        card_number: 'XXXXXXXXXXXX1111',
        card_holder: 'John Smith',
        card_expiry: '10/2011',
        card_token: 'a1bhj98j',
        amount: 349,
        decimal_amount: 3.49,
        successful: true,
        message: 'Approved',
        reference: 'ABC123',
        currency: 'AUD',
        transaction_id: '001-P-12345AA',
        settlement_date: '2011-07-01',
        transaction_date: '2011-07-01T12:00:00+11:00',
        response_code: '08',
        captured: true,
        captured_amount: 349,
        rrn: '000000000000',
        cvv_match: 'U',
        metadata: {
        }
      },
      test: true,
      errors: []
    }.to_json
  end

  def successful_purchase_response_with_metadata
    {
      successful: true,
      response: {
        authorization: 55355,
        id: '001-P-12345AA',
        card_number: 'XXXXXXXXXXXX1111',
        card_holder: 'John Smith',
        card_expiry: '2011-10-31',
        card_token: 'a1bhj98j',
        amount: 349,
        decimal_amount: 3.49,
        successful: true,
        message: 'Approved',
        reference: 'ABC123',
        currency: 'AUD',
        transaction_id: '001-P-12345AA',
        settlement_date: '2011-07-01',
        transaction_date: '2011-07-01T12:00:00+11:00',
        response_code: '08',
        captured: true,
        captured_amount: 349,
        rrn: '000000000000',
        cvv_match: 'U',
        metadata: {
          'foo' => 'bar'
        }
      },
      test: true,
      errors: []
    }.to_json
  end

  def declined_purchase_response
    {
      successful: true,
      response: {
        authorization: 0,
        id: '001-P-12345AB',
        card_number: 'XXXXXXXXXXXX1111',
        card_holder: 'John Smith',
        card_expiry: '10/2011',
        amount: 100,
        authorized: false,
        reference: 'ABC123',
        decimal_amount: 1.0,
        successful: false,
        message: 'Card Declined - check with issuer',
        currency: 'AUD',
        transaction_id: '001-P-12345AB',
        settlement_date: nil,
        transaction_date: '2011-07-01T12:00:00+11:00',
        response_code: '01',
        captured: false,
        captured_amount: 0,
        rrn: '000000000001',
        cvv_match: 'U',
        metadata: {
        }
      },
      test: true,
      errors: []
    }.to_json
  end

  def successful_refund_response
    {
      successful: true,
      response: {
        authorization: 1339973263,
        id: '003-R-7MNIUMY6',
        amount: 10,
        refunded: 'Approved',
        message: 'Approved',
        card_holder: 'Harry Smith',
        card_number: 'XXXXXXXXXXXX4444',
        card_expiry: '2013-05-31',
        card_type: 'MasterCard',
        transaction_id: '003-R-7MNIUMY6',
        reference: '18280',
        currency: 'USD',
        successful: true,
        transaction_date: '2013-07-01T12:00:00+11:00',
        response_code: '08',
        settlement_date: '2013-07-01',
        metadata: {
        },
        standalone: false,
        rrn: '000000000002'
      },
      errors: [],
      test: true
    }.to_json
  end

  def unsuccessful_refund_response
    {
      successful: false,
      response: {
        authorization: nil,
        id: nil,
        amount: nil,
        refunded: nil,
        message: nil,
        card_holder: 'Matthew Savage',
        card_number: 'XXXXXXXXXXXX4444',
        card_expiry: '2013-05-31',
        card_type: 'MasterCard',
        transaction_id: nil,
        successful: false
      },
      errors: [
        "Reference can't be blank"
      ],
      test: true
    }.to_json
  end

  def successful_tokenize_response
    {
      successful: true,
      response: {
        token: 'e1q7dbj2',
        card_holder: 'Bob Smith',
        card_number: 'XXXXXXXXXXXX2346',
        card_expiry: '2013-05-31T23:59:59+10:00',
        authorized: true,
        transaction_count: 0
      },
      errors: [],
      test: true
    }.to_json
  end

  def failed_tokenize_response
    {
      successful: false,
      response: {
        token: nil,
        card_holder: 'Bob ',
        card_number: '512345XXXXXX2346',
        card_expiry: nil,
        authorized: false,
        transaction_count: 10
      },
      errors: [
        "Expiry date can't be blank"
      ],
      test: false
    }.to_json
  end

  def successful_no_cvv_tokenize_response
    {
      successful: true,
      response: {
        token: 'ep3c05nzsqvft15wsf1z',
        card_holder: 'Bob ',
        card_number: '512345XXXXXX2346',
        card_expiry: nil,
        authorized: true,
        transaction_count: 0
      },
      errors: [],
      test: false
    }.to_json
  end

  def failed_no_cvv_tokenize_response
    {
      successful: false,
      response: {
        token: nil,
        card_holder: 'Bob ',
        card_number: '512345XXXXXX2346',
        card_expiry: nil,
        authorized: false,
        transaction_count: 0
      },
      errors: [
        'CVV is required'
      ],
      test: false
    }.to_json
  end

  # Place raw failed response from gateway here
  def failed_purchase_response
    {
      successful: false,
      response: {},
      test: true,
      errors: ['Invalid Card Number']
    }.to_json
  end

  def missing_data_response
    {
      successful: false,
      response: {},
      test: true,
      errors: ['Card Number is required']
    }.to_json
  end
end
