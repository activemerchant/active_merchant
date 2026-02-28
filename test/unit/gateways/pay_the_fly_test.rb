require 'test_helper'

class PayTheFlyTest < Test::Unit::TestCase
  def setup
    @gateway = PayTheFlyGateway.new(
      project_id: 'test-project-001',
      project_key: 'test-project-key-secret',
      private_key: '0x4c0883a69102937d6231471b5dbb6204fe512961708279f23efb3c1382ac4fa7',
      chain: 'BSC',
      token_address: '0x55d398326f99059fF775485246999027B3197955',
      contract_address: '0x1234567890abcdef1234567890abcdef12345678'
    )

    @amount = 100 # 100 cents = 1.00 USDT

    @options = {
      order_id: 'ORDER-001',
      chain: 'BSC',
      token_address: '0x55d398326f99059fF775485246999027B3197955',
      deadline: 1700000000
    }
  end

  def test_successful_purchase_bsc
    response = @gateway.purchase(@amount, nil, @options)

    assert_success response
    assert_equal 'Payment URL generated successfully', response.message
    assert_equal 'ORDER-001', response.authorization
    assert response.params['payment_url'].start_with?('https://pro.paythefly.com/pay?')
    assert_equal 'BSC', response.params['chain']
    assert_equal 56, response.params['chain_id']
    assert_equal '0x55d398326f99059fF775485246999027B3197955', response.params['token']
    assert_equal 'ORDER-001', response.params['serial_no']
    assert response.params['signature'].start_with?('0x')
    assert_equal 132, response.params['signature'].length # 0x + 64 + 64 + 2
    assert response.test?
  end

  def test_successful_purchase_tron
    tron_options = @options.merge(chain: 'TRON')
    response = @gateway.purchase(@amount, nil, tron_options)

    assert_success response
    assert_equal 'TRON', response.params['chain']
    assert_equal 728126428, response.params['chain_id']
    assert response.params['payment_url'].include?('chainId=728126428')
  end

  def test_purchase_with_different_amounts
    # 100 cents = 1.00 USDT on BSC (18 decimals)
    response = @gateway.purchase(100, nil, @options)
    assert_success response
    assert_equal '1000000000000000000', response.params['raw_amount'] # 1 * 10^18

    # 50 cents = 0.50 USDT
    response = @gateway.purchase(50, nil, @options)
    assert_success response
    assert_equal '500000000000000000', response.params['raw_amount'] # 0.5 * 10^18
  end

  def test_purchase_tron_decimals
    # TRON uses 6 decimals
    tron_options = @options.merge(chain: 'TRON')
    response = @gateway.purchase(100, nil, tron_options)
    assert_success response
    assert_equal '1000000', response.params['raw_amount'] # 1 * 10^6
  end

  def test_purchase_unsupported_chain
    bad_options = @options.merge(chain: 'ETH')
    response = @gateway.purchase(@amount, nil, bad_options)

    assert_failure response
    assert_match %r{Unsupported chain: ETH}, response.message
  end

  def test_purchase_generates_serial_no_when_not_provided
    options_without_order = @options.dup
    options_without_order.delete(:order_id)
    response = @gateway.purchase(@amount, nil, options_without_order)

    assert_success response
    assert response.params['serial_no'].start_with?('PTF-')
    assert_equal response.params['serial_no'], response.authorization
  end

  def test_purchase_url_contains_required_params
    response = @gateway.purchase(@amount, nil, @options)

    assert_success response
    url = response.params['payment_url']
    assert url.include?('chainId=56')
    assert url.include?('projectId=test-project-001')
    assert url.include?('serialNo=ORDER-001')
    assert url.include?('deadline=1700000000')
    assert url.include?('signature=0x')
    assert url.include?('token=0x')
  end

  def test_successful_withdrawal
    user_address = '0xAbCdEf0123456789AbCdEf0123456789AbCdEf01'
    response = @gateway.withdraw(@amount, user_address, @options)

    assert_success response
    assert_equal 'Withdrawal URL generated successfully', response.message
    assert response.params['withdrawal_url'].start_with?('https://pro.paythefly.com/withdraw?')
    assert_equal user_address, response.params['user']
    assert response.params['withdrawal_url'].include?("user=#{CGI.escape(user_address)}")
    assert response.params['signature'].start_with?('0x')
  end

  def test_withdrawal_unsupported_chain
    user_address = '0xAbCdEf0123456789AbCdEf0123456789AbCdEf01'
    bad_options = @options.merge(chain: 'SOL')
    response = @gateway.withdraw(@amount, user_address, bad_options)

    assert_failure response
    assert_match %r{Unsupported chain: SOL}, response.message
  end

  def test_verify_webhook_valid
    data = '{"project_id":"test-project-001","serial_no":"ORDER-001","tx_hash":"0xabc123","tx_type":1,"confirmed":true}'
    timestamp = '1700000000'
    sign = OpenSSL::HMAC.hexdigest('SHA256', 'test-project-key-secret', "#{data}.#{timestamp}")

    body = { 'data' => data, 'sign' => sign, 'timestamp' => timestamp }
    result = @gateway.verify_webhook(body)

    assert_not_nil result
    assert_equal 'test-project-001', result['project_id']
    assert_equal 'ORDER-001', result['serial_no']
    assert_equal 1, result['tx_type']
    assert_equal true, result['confirmed']
  end

  def test_verify_webhook_invalid_signature
    data = '{"project_id":"test-project-001","serial_no":"ORDER-001"}'
    timestamp = '1700000000'

    body = { 'data' => data, 'sign' => 'invalid_signature_hex', 'timestamp' => timestamp }
    result = @gateway.verify_webhook(body)

    assert_nil result
  end

  def test_verify_webhook_tampered_data
    data = '{"project_id":"test-project-001","serial_no":"ORDER-001"}'
    timestamp = '1700000000'
    sign = OpenSSL::HMAC.hexdigest('SHA256', 'test-project-key-secret', "#{data}.#{timestamp}")

    tampered_data = '{"project_id":"hacker-project","serial_no":"ORDER-001"}'
    body = { 'data' => tampered_data, 'sign' => sign, 'timestamp' => timestamp }
    result = @gateway.verify_webhook(body)

    assert_nil result
  end

  def test_verify_webhook_missing_fields
    body = { 'data' => '{}' }
    result = @gateway.verify_webhook(body)

    assert_nil result
  end

  def test_verify_webhook_class_method
    data = '{"project_id":"test","tx_type":1}'
    timestamp = '1700000000'
    key = 'my-secret-key'
    sign = OpenSSL::HMAC.hexdigest('SHA256', key, "#{data}.#{timestamp}")

    body = { 'data' => data, 'sign' => sign, 'timestamp' => timestamp }
    result = PayTheFlyGateway.verify_webhook(key, body)

    assert_not_nil result
    assert_equal 'test', result['project_id']
  end

  def test_verify_webhook_with_symbol_keys
    data = '{"project_id":"test","tx_type":2}'
    timestamp = '1700000000'
    sign = OpenSSL::HMAC.hexdigest('SHA256', 'test-project-key-secret', "#{data}.#{timestamp}")

    body = { data: data, sign: sign, timestamp: timestamp }
    result = @gateway.verify_webhook(body)

    assert_not_nil result
    assert_equal 2, result['tx_type']
  end

  def test_supported_chains
    assert_equal %w[BSC TRON], PayTheFlyGateway::CHAINS.keys
    assert_equal 56, PayTheFlyGateway::CHAINS['BSC'][:chain_id]
    assert_equal 18, PayTheFlyGateway::CHAINS['BSC'][:decimals]
    assert_equal 728126428, PayTheFlyGateway::CHAINS['TRON'][:chain_id]
    assert_equal 6, PayTheFlyGateway::CHAINS['TRON'][:decimals]
  end

  def test_gateway_display_name
    assert_equal 'PayTheFly', PayTheFlyGateway.display_name
  end

  def test_scrub
    transcript = 'project_key=secret123&private_key=0xabc&signature=0xdef456'
    scrubbed = @gateway.scrub(transcript)

    assert_match %r{project_key=\[FILTERED\]}, scrubbed
    assert_match %r{private_key=\[FILTERED\]}, scrubbed
    assert_match %r{signature=\[FILTERED\]}, scrubbed
  end

  def test_supports_scrubbing
    assert @gateway.supports_scrubbing?
  end

  def test_initialization_requires_project_id
    assert_raises(ArgumentError) do
      PayTheFlyGateway.new(project_key: 'key', private_key: '0xabc')
    end
  end

  def test_initialization_requires_project_key
    assert_raises(ArgumentError) do
      PayTheFlyGateway.new(project_id: 'id', private_key: '0xabc')
    end
  end

  def test_initialization_requires_private_key
    assert_raises(ArgumentError) do
      PayTheFlyGateway.new(project_id: 'id', project_key: 'key')
    end
  end

  def test_default_chain_is_bsc
    gateway = PayTheFlyGateway.new(
      project_id: 'test',
      project_key: 'key',
      private_key: '0x4c0883a69102937d6231471b5dbb6204fe512961708279f23efb3c1382ac4fa7',
      token_address: '0x55d398326f99059fF775485246999027B3197955',
      contract_address: '0x1234567890abcdef1234567890abcdef12345678'
    )

    options = {
      order_id: 'TEST-001',
      deadline: 1700000000
    }

    response = gateway.purchase(100, nil, options)
    assert_success response
    assert_equal 'BSC', response.params['chain']
    assert_equal 56, response.params['chain_id']
  end

  def test_payment_and_withdrawal_tx_type_constants
    assert_equal 1, PayTheFlyGateway::PAYMENT_TX_TYPE
    assert_equal 2, PayTheFlyGateway::WITHDRAWAL_TX_TYPE
  end

  def test_eip712_domain_name_and_version
    assert_equal 'PayTheFlyPro', PayTheFlyGateway::EIP712_DOMAIN_NAME
    assert_equal '1', PayTheFlyGateway::EIP712_DOMAIN_VERSION
  end

  def test_keccak256_not_sha3_256
    # Keccak-256 and SHA3-256 differ in padding (Keccak uses 0x01, SHA3 uses 0x06).
    # The empty-string digest for Keccak-256 is the well-known constant below.
    # If this test fails, the gateway is using SHA3-256 instead of Keccak-256,
    # which would produce invalid EIP-712 signatures.
    expected_empty_hash = 'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'
    actual = Digest::Keccak.new(256).hexdigest('')
    assert_equal expected_empty_hash, actual, 'keccak256 of empty string must match Ethereum Keccak-256, not NIST SHA3-256'
  end

  def test_payment_signature_deterministic
    # With fixed inputs, the EIP-712 signature should be deterministic
    # (same private key + same message → same signature every time).
    response1 = @gateway.purchase(@amount, nil, @options)
    response2 = @gateway.purchase(@amount, nil, @options)

    assert_success response1
    assert_success response2
    assert_equal response1.params['signature'], response2.params['signature'],
      'EIP-712 signature must be deterministic for identical inputs'
  end

  def test_withdrawal_signature_differs_from_payment
    user_address = '0xAbCdEf0123456789AbCdEf0123456789AbCdEf01'
    payment_response = @gateway.purchase(@amount, nil, @options)
    withdrawal_response = @gateway.withdraw(@amount, user_address, @options)

    assert_success payment_response
    assert_success withdrawal_response
    assert_not_equal payment_response.params['signature'], withdrawal_response.params['signature'],
      'Payment and withdrawal signatures must differ (different EIP-712 type hashes)'
  end

  def test_human_readable_amount_bsc
    # BSC has 18 decimals
    response = @gateway.purchase(1, nil, @options) # 1 cent = 0.01 USDT
    assert_success response
    assert_equal '0.01', response.params['amount']

    response = @gateway.purchase(100, nil, @options) # 100 cents = 1.00 USDT
    assert_success response
    assert_match %r{\A1\.0}, response.params['amount']
  end

  def test_human_readable_amount_tron
    tron_options = @options.merge(chain: 'TRON')
    response = @gateway.purchase(1, nil, tron_options) # 1 cent = 0.01 USDT
    assert_success response
    assert_equal '0.01', response.params['amount']
  end
end
