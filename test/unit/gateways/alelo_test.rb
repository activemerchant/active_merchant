require 'test_helper'

class AleloTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = AleloGateway.new(fixtures(:alelo))
    @gateway_no_valid = AleloGateway.new(client_id: 'client_id', client_secret: 'client_secret')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      establishment_code: '000002007690360',
      sub_merchant_mcc: '5499',
      player_identification: '1',
      description: 'Store Purchase',
      external_trace_number: '123456'
    }
  end

  def test_required_client_id_and_client_secret
    error = assert_raises ArgumentError do
      AleloGateway.new
    end

    assert_equal 'Missing required parameter: client_id', error.message
  end

  def test_supported_card_types
    assert_equal AleloGateway.supported_cardtypes, %i[visa master american_express discover]
  end

  def test_supported_countries
    assert_equal AleloGateway.supported_countries, ['BR']
  end

  def test_support_scrubbing_flag_enabled
    assert @gateway.supports_scrubbing?
  end

  def test_extra_data_present; end

  def test_sucessful_fetch_access_token_with_proper_client_id_client_secret
    @gateway = AleloGateway.new(client_id: 'abc123', client_secret: 'def456')
    access_token_expectation! @gateway

    resp = @gateway.send(:fetch_access_token)
    assert_kind_of Response, resp
    assert_equal 'abc123', resp.message
  end

  def test_successful_remote_encryption_key
    @gateway = AleloGateway.new(client_id: 'abc123', client_secret: 'def456')
    encryption_key_expectation! @gateway

    resp = @gateway.send(:remote_encryption_key, 'abc123')

    assert_kind_of Response, resp
    assert_equal 'def456', resp.message
  end

  def test_success_purchase_with_provided_credentials
    key, secret_key = test_key true

    @options[:encryption_key] = key
    @options[:access_token] = 'abc123'

    response = stub_comms do
      @gateway.purchase(@amount, @credit_card, @options)
    end.check_request do |_endpoint, data, _headers|
      decrypted = JOSE::JWE.block_decrypt(secret_key, JSON.parse(data)['token']).first
      request = JSON.parse(decrypted, symbolize_names: true)

      assert_equal @options[:order_id], request[:request_id]
      assert_equal '1.00', request[:amount]
      assert_equal @credit_card.number, request[:cardNumber]
      assert_equal @credit_card.name, request[:cardholderName]
      assert_equal @credit_card.month, request[:expirationMonth]
      assert_equal '23', request[:expirationYear]
      assert_equal '3', request[:captureType]
      assert_equal @credit_card.verification_value, request[:securityCode]
      assert_equal @options[:establishment_code], request[:establishmentCode]
      assert_equal @options[:player_identification], request[:playerIdentification]
      assert_equal @options[:sub_merchant_mcc], request[:subMerchantCode]
      assert_equal @options[:external_trace_number], request[:externalTraceNumber]
    end.respond_with(successful_capture_response)

    assert_success response
  end

  def test_success_purchase_with_no_provided_credentials
    key = test_key
    @gateway.expects(:ssl_post).times(2).returns({ access_token: 'abc123' }.to_json).returns(successful_capture_response)
    @gateway.expects(:ssl_get).returns({ publicKey: key }.to_json)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_kind_of MultiResponse, response
    assert_equal 3, response.responses.size
    assert_equal 'abc123', response.responses.first.message
    assert_equal key, response.responses[1].message
  end

  def test_sucessful_retry_with_expired_credentials
    key = test_key
    @options[:encryption_key] = key
    @options[:access_token] = 'abc123'

    # Expectations
    # ssl_post => raises a 401
    # ssl_post => access_token
    # ssl_get => key
    # ssl_post => Final purchase success
    @gateway.expects(:ssl_post).
      times(3).
      raises(ActiveMerchant::ResponseError.new(stub('401 Response', code: '401'))).
      then.returns({ access_token: 'abc123' }.to_json, successful_capture_response)
    @gateway.expects(:ssl_get).returns({ publicKey: key }.to_json)

    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_kind_of MultiResponse, response
    assert_equal 3, response.responses.size
    assert_equal 'abc123', response.responses.first.message
    assert_equal key, response.responses[1].message
  end

  def test_detecting_successfull_response_from_body
    assert @gateway.send :success_from, { status: 'CONFIRMADA' }
  end

  def test_get_response_message_from_messages_key
    message = @gateway.send :message_from, { messages: 'hello', messageUser: 'world' }
    assert_equal 'hello', message
  end

  def test_get_response_message_from_message_user
    message = @gateway.send :message_from, { messages: nil, messageUser: 'world' }
    assert_equal 'world', message
  end

  def test_url_generation_from_action
    action = 'test'
    assert_equal @gateway.test_url + action, @gateway.send(:url, action)
  end

  def test_request_headers_building
    gateway = AleloGateway.new(client_id: 'abc123', client_secret: 'def456')
    headers = gateway.send :request_headers, 'access_123'

    assert_equal 'application/json', headers['Accept']
    assert_equal 'abc123', headers['X-IBM-Client-Id']
    assert_equal 'def456', headers['X-IBM-Client-Secret']
    assert_equal 'Bearer access_123', headers['Authorization']
  end

  def test_scrub
    assert @gateway.supports_scrubbing?

    pre_scrubbed = File.read('test/unit/transcripts/alelo_purchase')
    post_scrubbed = File.read('test/unit/transcripts/alelo_purchase_scrubbed')

    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_success_payload_encryption
    options = {
      access_token: 'abc123',
      encryption_key: test_key
    }

    jwe, _credentials = @gateway.send(:encrypt_payload, { hello: 'world' }, options)

    refute_nil JSON.parse(jwe)['token']
    refute_nil JSON.parse(jwe)['uuid']
  end

  def test_ensure_encryption_format
    key, secret_key = test_key true
    body = { hello: 'world' }
    options = { access_token: 'abc123', encryption_key: key }

    jwe, _cred = @gateway.send(:encrypt_payload, body, options)
    parsed_jwe = JSON.parse(jwe, symbolize_names: true)
    refute_nil parsed_jwe[:token]

    decrypted = JOSE::JWE.block_decrypt(secret_key, parsed_jwe[:token]).first
    assert_equal body.to_json, decrypted
  end

  def test_ensure_credentials_use_provided_access_token_and_key
    options = { access_token: 'abc123', encryption_key: 'def456' }

    credentials = @gateway.send :ensure_credentials, options

    assert_equal options[:access_token], credentials[:access_token]
    assert_equal options[:encryption_key], credentials[:key]
    assert_nil options[:multiresp]
  end

  def test_ensure_credentials_with_access_token_and_not_key
    encryption_key_expectation! @gateway
    options = { access_token: 'abc123' }

    credentials = @gateway.send :ensure_credentials, options

    assert_equal options[:access_token], credentials[:access_token]
    assert_equal 'def456', credentials[:key]
    refute_nil credentials[:multiresp]
    assert_equal 1, credentials[:multiresp].responses.size
  end

  def test_ensure_credentials_with_key_but_not_access_token
    @gateway = AleloGateway.new(client_id: 'abc123', client_secret: 'def456')
    access_token_expectation! @gateway
    encryption_key_expectation! @gateway

    options = { encryption_key: 'xx_no_key_xx' }

    credentials = @gateway.send :ensure_credentials, options

    assert_equal 'abc123', credentials[:access_token]
    assert_equal 'def456', credentials[:key]
    refute_nil credentials[:multiresp]
    assert_equal 2, credentials[:multiresp].responses.size
  end

  private

  def test_key(with_sk = false)
    jwk_rsa_sk = JOSE::JWK.generate_key([:rsa, 4096])
    jwk_rsa_pk = JOSE::JWK.to_public(jwk_rsa_sk)

    pem = jwk_rsa_pk.to_pem.split("\n")
    pem.pop
    pem.shift

    return pem.join unless with_sk

    return pem.join, jwk_rsa_sk
  end

  def access_token_expectation!(gateway, access_token = 'abc123')
    url = 'https://sandbox-api.alelo.com.br/alelo/sandbox/captura-oauth-provider/oauth/token'
    params = [
      'grant_type=client_credentials',
      'client_id=abc123',
      'client_secret=def456',
      'scope=%2Fcapture'
    ].join('&')

    headers = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/x-www-form-urlencoded'
    }

    gateway.expects(:ssl_post).with(url, params, headers).returns({ access_token: access_token }.to_json)
  end

  def encryption_key_expectation!(gateway, public_key = 'def456')
    url = 'https://sandbox-api.alelo.com.br/alelo/sandbox/capture/key?format=json'
    headers = {
      'Accept' => 'application/json',
      'X-IBM-Client-Id' => gateway.options[:client_id],
      'X-IBM-Client-Secret' => gateway.options[:client_secret],
      'Authorization' => 'Bearer abc123'
    }

    @gateway.expects(:ssl_get).with(url, headers).returns({ publicKey: public_key }.to_json)
  end

  def failed_purchase_response; end

  def successful_capture_response
    {
      requestId: '5dce2c96-58f6-411e-bc8e-47b52ecbaa4e',
      dateTime: '211105181958',
      returnCode: '00',
      nsu: '00123',
      amount: '0.10',
      maskedCard: '506758******7013',
      authorizationCode: '735977',
      messages: 'Transação Confirmada com sucesso.',
      status: 'CONFIRMADA',
      playerIdentification: '4',
      captureType: '3'
    }.to_json
  end
end
