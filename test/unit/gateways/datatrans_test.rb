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

    @transaction_reference = '240214093712238757|093712'

    @billing_address = address

    @nt_credit_card = network_tokenization_credit_card(
      '4111111111111111',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=',
      eci: '07',
      source: :network_token,
      verification_value: '737',
      brand: 'visa'
    )

    @apple_pay_card = network_tokenization_credit_card(
      '4900000000000094',
      payment_cryptogram: 'YwAAAAAABaYcCMX/OhNRQAAAAAA=',
      month: '06',
      year: '2025',
      source: 'apple_pay',
      verification_value: 569
    )
  end

  def test_authorize_with_credit_card
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options)
    end.check_request do |_action, endpoint, data, _headers|
      parsed_data = JSON.parse(data)
      common_assertions_authorize_purchase(endpoint, parsed_data)
      assert_equal(@credit_card.number, parsed_data['card']['number'])
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_authorize_with_credit_card_and_billing_address
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.authorize(@amount, @credit_card, @options.merge({ billing_address: @billing_address }))
    end.check_request do |_action, endpoint, data, _headers|
      parsed_data = JSON.parse(data)
      common_assertions_authorize_purchase(endpoint, parsed_data)
      assert_equal(@credit_card.number, parsed_data['card']['number'])

      billing = parsed_data['billing']
      assert_equal('Jim Smith', billing['name'])
      assert_equal(@billing_address[:address1], billing['street'])
      assert_match(@billing_address[:address2], billing['street2'])
      assert_match(@billing_address[:city], billing['city'])
      assert_match(@billing_address[:country], billing['country'])
      assert_match(@billing_address[:phone], billing['phoneNumber'])
      assert_match(@billing_address[:zip], billing['zipCode'])
      assert_match(@options[:email], billing['email'])
    end.respond_with(successful_authorize_response)

    assert_success response
  end

  def test_purchase_with_credit_card
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_action, endpoint, data, _headers|
      parsed_data = JSON.parse(data)
      common_assertions_authorize_purchase(endpoint, parsed_data)
      assert_equal(@credit_card.number, parsed_data['card']['number'])

      assert_equal(true, parsed_data['autoSettle'])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_purchase_with_network_token
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @nt_credit_card, @options)
    end.check_request do |_action, endpoint, data, _headers|
      parsed_data = JSON.parse(data)
      common_assertions_authorize_purchase(endpoint, parsed_data)
      assert_match('"autoSettle":true', data)

      assert_equal(@nt_credit_card.number, parsed_data['card']['token'])
      assert_equal('NETWORK_TOKEN', parsed_data['card']['type'])
      assert_equal('VISA', parsed_data['card']['tokenType'])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_authorize_with_apple_pay
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.purchase(@amount, @apple_pay_card, @options)
    end.check_request do |_action, endpoint, data, _headers|
      parsed_data = JSON.parse(data)
      common_assertions_authorize_purchase(endpoint, parsed_data)
      assert_match('"autoSettle":true', data)

      assert_equal(@apple_pay_card.number, parsed_data['card']['token'])
      assert_equal('DEVICE_TOKEN', parsed_data['card']['type'])
      assert_equal('APPLE_PAY', parsed_data['card']['tokenType'])
    end.respond_with(successful_purchase_response)

    assert_success response
  end

  def test_capture
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.capture(@amount, @transaction_reference, @options)
    end.check_request do |_action, endpoint, data, _headers|
      parsed_data = JSON.parse(data)
      assert_match('240214093712238757/settle', endpoint)
      assert_equal(@options[:order_id], parsed_data['refno'])
      assert_equal('CHF', parsed_data['currency'])
      assert_equal('100', parsed_data['amount'])
    end.respond_with(successful_capture_response)

    assert_success response
  end

  def test_refund
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.refund(@amount, @transaction_reference, @options)
    end.check_request do |_action, endpoint, data, _headers|
      parsed_data = JSON.parse(data)
      assert_match('240214093712238757/credit', endpoint)
      assert_equal(@options[:order_id], parsed_data['refno'])
      assert_equal('CHF', parsed_data['currency'])
      assert_equal('100', parsed_data['amount'])
    end.respond_with(successful_refund_response)

    assert_success response
  end

  def test_voids
    response = stub_comms(@gateway, :ssl_request) do
      @gateway.void(@transaction_reference, @options)
    end.check_request do |_action, endpoint, data, _headers|
      assert_match('240214093712238757/cancel', endpoint)
      assert_equal data, '{}'
    end.respond_with(successful_void_response)

    assert_success response
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

  def test_authorization_from
    assert_equal '1234|9248', @gateway.send(:authorization_from, { 'transactionId' => '1234', 'acquirerAuthorizationCode' => '9248' })
    assert_equal '1234|', @gateway.send(:authorization_from, { 'transactionId' => '1234' })
    assert_equal '|9248', @gateway.send(:authorization_from, { 'acquirerAuthorizationCode' => '9248' })
    assert_equal nil, @gateway.send(:authorization_from, {})
  end

  def test_parse
    assert_equal @gateway.send(:parse, '{"response_code":204}'), { 'response_code' => 204 }
    assert_equal @gateway.send(:parse, '{"transactionId":"240418170233899207","acquirerAuthorizationCode":"170233"}'), { 'transactionId' => '240418170233899207', 'acquirerAuthorizationCode' => '170233' }

    assert_equal @gateway.send(:parse,
                               '{"transactionId":"240418170233899207",acquirerAuthorizationCode":"170233"}'),
                 { 'successful' => false,
                   'response' => {},
                   'errors' =>
                    ['Invalid JSON response received from Datatrans. Please contact them for support if you continue to receive this message.  (The raw response returned by the API was "{\\"transactionId\\":\\"240418170233899207\\",acquirerAuthorizationCode\\":\\"170233\\"}")'] }
  end

  private

  def successful_authorize_response
    '{
      "transactionId":"240214093712238757",
      "acquirerAuthorizationCode":"093712"
    }'
  end

  def successful_capture_response
    '{"response_code": 204}'
  end

  def common_assertions_authorize_purchase(endpoint, parsed_data)
    assert_match('authorize', endpoint)
    assert_equal(@options[:order_id], parsed_data['refno'])
    assert_equal('CHF', parsed_data['currency'])
    assert_equal('100', parsed_data['amount'])
  end

  alias successful_purchase_response successful_authorize_response
  alias successful_refund_response successful_authorize_response
  alias successful_void_response successful_capture_response

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
        \\\"transactionId\\\" : \\\"240418170233899207\\\",\\n
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
        \\\"transactionId\\\" : \\\"240418170233899207\\\",\\n
        \\\"acquirerAuthorizationCode\\\" : \\\"170233\\\"\\n
      }\"\n
      read 86 bytes\n
      Conn close\n"
    POST_SCRUBBED
  end
end
