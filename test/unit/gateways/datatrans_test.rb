require 'test_helper'

class DatatransTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = DatatransGateway.new(fixtures(:datatrans))
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: SecureRandom.random_number(1000000000),
      email: 'john.smith@test.com'
    }

    @billing_address = address
  end

  def test_authorize_with_credit_card
    @gateway.expects(:ssl_request).
      with(
        :post,
        'https://api.sandbox.datatrans.com/v1/transactions/authorize',
        all_of(
          regexp_matches(%r{"number\":\"(\d+{12})\"}),
          regexp_matches(%r{"refno\":\"(\d+)\"}),
          includes('"currency":"CHF"'),
          includes('"amount":"100"')
        ),
        anything
      ).
      returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)

    assert_success response
  end

  def test_authorize_with_credit_card_and_billing_address
    @gateway.expects(:ssl_request).
      with(
        :post,
        'https://api.sandbox.datatrans.com/v1/transactions/authorize',
        all_of(
          regexp_matches(%r{"number\":\"(\d+{12})\"}),
          regexp_matches(%r{"refno\":\"(\d+)\"}),
          includes('"currency":"CHF"'),
          includes('"amount":"100"'),
          includes('"name":"Jim Smith"'),
          includes('"street":"456 My Street"'),
          includes('"street2":"Apt 1"'),
          includes('"city":"Ottawa"'),
          includes('"country":"CAN"'),
          includes('"phoneNumber":"(555)555-5555"'),
          includes('"zipCode":"K1C2N6"'),
          includes('"email":"john.smith@test.com"')
        ),
        anything
      ).
      returns(successful_authorize_response)

    @gateway.authorize(@amount, @credit_card, @options.merge({ billing_address: @billing_address }))
  end

  def test_purchase_with_credit_card
    @gateway.expects(:ssl_request).
      with(
        :post,
        'https://api.sandbox.datatrans.com/v1/transactions/authorize',
        all_of(
          # same than authorize + autoSettle value
          includes('"autoSettle":true')
        ),
        anything
      ).
      returns(successful_authorize_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_capture
    @gateway.expects(:ssl_request).with(:post, 'https://api.sandbox.datatrans.com/v1/transactions/authorize', anything, anything).returns(successful_authorize_response)

    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    transaction_reference, _card_token, _brand = authorize_response.authorization.split('|')
    @gateway.expects(:ssl_request).
      with(
        :post,
        regexp_matches(%r{https://api.sandbox.datatrans.com/v1/transactions/(\d+)/settle}),
        all_of(
          regexp_matches(%r{"refno\":\"(\d+)\"}),
          includes('"currency":"CHF"'),
          includes('"amount":"100"')
        ),
        anything
      ).
      returns(successful_capture_response)
    @gateway.capture(@amount, transaction_reference, @options)
  end

  def test_refund
    @gateway.expects(:ssl_request).with(:post, 'https://api.sandbox.datatrans.com/v1/transactions/authorize', anything, anything).returns(successful_purchase_response)

    purchase_response = @gateway.purchase(@amount, @credit_card, @options)
    transaction_reference, _card_token, _brand = purchase_response.authorization.split('|')
    @gateway.expects(:ssl_request).
      with(
        :post,
        regexp_matches(%r{https://api.sandbox.datatrans.com/v1/transactions/(\d+)/credit}),
        all_of(
          regexp_matches(%r{"refno\":\"(\d+)\"}),
          includes('"currency":"CHF"'),
          includes('"amount":"100"')
        ),
        anything
      ).
      returns(successful_refund_response)
    @gateway.refund(@amount, transaction_reference, @options)
  end

  def test_void
    @gateway.expects(:ssl_request).with(:post, 'https://api.sandbox.datatrans.com/v1/transactions/authorize', anything, anything).returns(successful_purchase_response)

    authorize_response = @gateway.authorize(@amount, @credit_card, @options)
    transaction_reference, _card_token, _brand = authorize_response.authorization.split('|')
    @gateway.expects(:ssl_request).
      with(
        :post,
        regexp_matches(%r{https://api.sandbox.datatrans.com/v1/transactions/(\d+)/cancel}),
        '{}',
        anything
      ).
      returns(successful_void_response)
    @gateway.void(transaction_reference, @options)
  end

  def test_required_merchant_id_and_password
    error = assert_raises ArgumentError do
      DatatransGateway.new
    end

    assert_equal 'Missing required parameter: merchant_id', error.message
  end

  def test_supported_card_types
    assert_equal DatatransGateway.supported_cardtypes, %i[master visa american_express unionpay diners_club discover jcb maestro dankort]
  end

  def test_supported_countries
    assert_equal DatatransGateway.supported_countries, %w[CH GR US]
  end

  def test_support_scrubbing_flag_enabled
    assert @gateway.supports_scrubbing?
  end

  def test_detecting_successfull_response_from_capture
    assert @gateway.send :success_from, 'settle', { 'response_code' => 204 }
  end

  def test_detecting_successfull_response_from_purchase
    assert @gateway.send :success_from, 'authorize', { 'transactionId' => '2124504', 'acquirerAuthorizationCode' => '12345t' }
  end

  def test_detecting_successfull_response_from_authorize
    assert @gateway.send :success_from, 'authorize', { 'transactionId' => '2124504', 'acquirerAuthorizationCode' => '12345t' }
  end

  def test_detecting_successfull_response_from_refund
    assert @gateway.send :success_from, 'credit', { 'transactionId' => '2124504', 'acquirerAuthorizationCode' => '12345t' }
  end

  def test_detecting_successfull_response_from_void
    assert @gateway.send :success_from, 'cancel', { 'response_code' => 204 }
  end

  def test_get_response_message_from_messages_key
    message = @gateway.send :message_from, false, { 'error' => { 'message' => 'hello' } }
    assert_equal 'hello', message

    message = @gateway.send :message_from, true, {}
    assert_equal nil, message
  end

  def test_get_response_message_from_message_user
    message = @gateway.send :message_from, 'order', { other_key: 'something_else' }
    assert_nil message
  end

  def test_url_generation_from_action
    action = 'test'
    assert_equal "#{@gateway.test_url}#{action}", @gateway.send(:url, action)
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal post_scrubbed, @gateway.scrub(pre_scrubbed)
  end

  private

  def successful_authorize_response
    '{
      "transactionId":"240214093712238757",
      "acquirerAuthorizationCode":"093712"
    }'
  end

  def successful_purchase_response
    successful_authorize_response
  end

  def successful_capture_response
    '{"response_code": 204}'
  end

  def successful_refund_response
    successful_authorize_response
  end

  def successful_void_response
    successful_capture_response
  end
 

  def pre_scrubbed
    <<~PRE_SCRUBBED
      "opening connection to api.sandbox.datatrans.com:443...\n
      opened\n
      starting SSL for api.sandbox.datatrans.com:443...\n
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n
      <- \"POST /v1/transactions/authorize HTTP/1.1\\r\\n
      Content-Type: application/json; charset=UTF-8\\r\\n
      Authorization: Basic [FILTERED]\\r\\n
      Connection: close\\r\\n
      Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\n
      Accept: */*\\r\\n
      User-Agent: Ruby\\r\\n
      Host: api.sandbox.datatrans.com\\r\\n
      Content-Length: 157\\r\\n\\r\\n\"\n
      <- \"{\\\"card\\\":{\\\"number\\\":\\\"4242424242424242\\\",\\\"cvv\\\":\\\"123\\\",\\\"expiryMonth\\\":\\\"06\\\",\\\"expiryYear\\\":\\\"25\\\"},\\\"refno\\\":\\\"683040814\\\",\\\"currency\\\":\\\"CHF\\\",\\\"amount\\\":\\\"756\\\",\\\"autoSettle\\\":true}\"\n
      -> \"HTTP/1.1 200 \\r\\n\"\n
      -> \"Server: nginx\\r\\n\"\n
      -> \"Date: Thu, 18 Apr 2024 15:02:34 GMT\\r\\n\"\n
      -> \"Content-Type: application/json\\r\\n\"\n
      -> \"Content-Length: 86\\r\\n\"\n
      -> \"Connection: close\\r\\n\"\n
      -> \"Strict-Transport-Security: max-age=31536000; includeSubdomains\\r\\n\"\n
      -> \"P3P: CP=\\\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\\\"\\r\\n\"\n
      -> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n
      -> \"Correlation-Id: abda35b0-44ac-4a42-8811-941488acc21b\\r\\n\"\n
      -> \"\\r\\n\"\nreading 86 bytes...\n
      -> \"{\\n
        \\\"transactionId\\\" : \\\"240418170233899207\\\",\\n#{'  '}
        \\\"acquirerAuthorizationCode\\\" : \\\"170233\\\"\\n
      }\"\n
      read 86 bytes\n
      Conn close\n"
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~POST_SCRUBBED
      "opening connection to api.sandbox.datatrans.com:443...\n
      opened\n
      starting SSL for api.sandbox.datatrans.com:443...\n
      SSL established, protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384\n
      <- \"POST /v1/transactions/authorize HTTP/1.1\\r\\n
      Content-Type: application/json; charset=UTF-8\\r\\n
      Authorization: Basic [FILTERED]\\r\\n
      Connection: close\\r\\n
      Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\n
      Accept: */*\\r\\n
      User-Agent: Ruby\\r\\n
      Host: api.sandbox.datatrans.com\\r\\n
      Content-Length: 157\\r\\n\\r\\n\"\n
      <- \"{\\\"card\\\":{\\\"number\\\":\\\"[FILTERED]\\\",\\\"cvv\\\":\\\"[FILTERED]\\\",\\\"expiryMonth\\\":\\\"06\\\",\\\"expiryYear\\\":\\\"25\\\"},\\\"refno\\\":\\\"683040814\\\",\\\"currency\\\":\\\"CHF\\\",\\\"amount\\\":\\\"756\\\",\\\"autoSettle\\\":true}\"\n
      -> \"HTTP/1.1 200 \\r\\n\"\n
      -> \"Server: nginx\\r\\n\"\n
      -> \"Date: Thu, 18 Apr 2024 15:02:34 GMT\\r\\n\"\n
      -> \"Content-Type: application/json\\r\\n\"\n
      -> \"Content-Length: 86\\r\\n\"\n
      -> \"Connection: close\\r\\n\"\n
      -> \"Strict-Transport-Security: max-age=31536000; includeSubdomains\\r\\n\"\n
      -> \"P3P: CP=\\\"IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT\\\"\\r\\n\"\n
      -> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n
      -> \"Correlation-Id: abda35b0-44ac-4a42-8811-941488acc21b\\r\\n\"\n
      -> \"\\r\\n\"\nreading 86 bytes...\n
      -> \"{\\n
        \\\"transactionId\\\" : \\\"240418170233899207\\\",\\n#{'  '}
        \\\"acquirerAuthorizationCode\\\" : \\\"170233\\\"\\n
      }\"\n
      read 86 bytes\n
      Conn close\n"
    POST_SCRUBBED
  end
end
