ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'json'
require_relative '../lib/tokenex_gateway'

# IXOONE-3: lightweight fake gateway used only by wallet tests. Echoes the
# constructed payment object's class/source/cryptogram/eci back via the
# AM Response params so tests can assert what the wrapper actually built.
# Lives in the standard ActiveMerchant::Billing namespace so the wrapper's
# `"ActiveMerchant::Billing::#{name}".constantize` lookup resolves it.
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class WalletCaptureGateway < Gateway
      def authorize(_money, paysource, _options = {})
        Response.new(true, 'OK', _capture_payment_metadata(paysource))
      end

      def purchase(_money, paysource, _options = {})
        Response.new(true, 'OK', _capture_payment_metadata(paysource))
      end

      private

      def _capture_payment_metadata(paysource)
        {
          payment_class: paysource.class.name,
          source:        (paysource.source.to_s if paysource.respond_to?(:source)),
          cryptogram:    (paysource.payment_cryptogram if paysource.respond_to?(:payment_cryptogram)),
          eci:           (paysource.eci if paysource.respond_to?(:eci))
        }
      end
    end
  end
end

class TokenExGatewayTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_health_check
    get '/'
    assert last_response.ok?
    assert_equal 'I am Alive', last_response.body
  end

  def test_about_endpoint
    get '/about'
    assert last_response.ok?
    info = JSON.parse(last_response.body)
    assert_equal 'test', info['mode']
    assert info['version']
    assert info['active_merchant_version']
  end

  def test_error_codes_endpoint
    get '/error_codes'
    assert last_response.ok?
    codes = JSON.parse(last_response.body)
    assert codes.key?('invalid_json')
    assert codes.key?('unknown')
  end

  def test_process_rejects_invalid_json
    post '/process', 'not valid json', { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert_equal 5003, result['error_number']
  end

  def test_process_requires_gateway
    payload = { 'transaction' => { 'action' => 'authorize' } }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert_equal 5004, result['error_number']
  end

  def test_process_requires_transaction
    payload = { 'gateway' => { 'name' => 'BogusGateway', 'test' => 'true' } }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert_equal 5004, result['error_number']
  end

  def test_process_rejects_unsupported_gateway
    payload = {
      'gateway' => { 'name' => 'NonExistentGateway' },
      'transaction' => { 'action' => 'authorize' }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert_equal 5005, result['error_number']
    assert_match(/Unsupported gateway/, result['additional_details'])
  end

  def test_process_rejects_unsupported_action
    payload = {
      'gateway' => { 'name' => 'BogusGateway' },
      'transaction' => { 'action' => 'invalid_action' }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert_equal 5005, result['error_number']
  end

  def test_process_authorize_requires_payment_source
    payload = {
      'gateway' => { 'name' => 'BogusGateway' },
      'transaction' => { 'action' => 'authorize', 'amount' => 100 }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert_equal 5004, result['error_number']
    assert_match(/No payment source/, result['additional_details'])
  end

  def test_process_authorize_with_bogus_gateway
    payload = {
      'tokenex_id' => '1234567890',
      'ref' => 'test_ref_123',
      'gateway' => { 'name' => 'BogusGateway' },
      'transaction' => { 'action' => 'authorize', 'amount' => 100 },
      'credit_card' => {
        'first_name' => 'Test',
        'last_name' => 'User',
        'number' => '1',
        'month' => '9',
        'year' => (Time.now.year + 1).to_s,
        'verification_value' => '123'
      }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert result['success'], "Expected success, got: #{result.inspect}"
    assert result['authorization']
  end

  def test_process_purchase_with_bogus_gateway
    payload = {
      'gateway' => { 'name' => 'BogusGateway' },
      'transaction' => { 'action' => 'purchase', 'amount' => 100 },
      'credit_card' => {
        'first_name' => 'Test',
        'last_name' => 'User',
        'number' => '1',
        'month' => '9',
        'year' => (Time.now.year + 1).to_s,
        'verification_value' => '123'
      }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert result['success']
  end

  def test_capture_passes_credit_card_directly
    # This test verifies the IXOPAY change: credit_card is passed via options[:credit_card]
    # instead of Marshal.dump(am_payment) via options[:payment_obj]
    payload = {
      'gateway' => { 'name' => 'BogusGateway' },
      'transaction' => { 'action' => 'capture', 'amount' => 100, 'authorization' => '12345' },
      'credit_card' => {
        'first_name' => 'Test',
        'last_name' => 'User',
        'number' => '1',
        'month' => '9',
        'year' => (Time.now.year + 1).to_s,
        'verification_value' => '123'
      }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    # BogusGateway capture should work
    assert result['success']
  end

  def test_void_passes_credit_card_directly
    payload = {
      'gateway' => { 'name' => 'BogusGateway' },
      'transaction' => { 'action' => 'void', 'authorization' => '12345' },
      'credit_card' => {
        'first_name' => 'Test',
        'last_name' => 'User',
        'number' => '1',
        'month' => '9',
        'year' => (Time.now.year + 1).to_s,
        'verification_value' => '123'
      }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert result['success']
  end

  def test_blocked_gateway
    # Temporarily add a gateway to the block list
    original = TokenExGateway::BLOCK_GATEWAYS.dup
    TokenExGateway::BLOCK_GATEWAYS.push('BogusGateway')

    payload = {
      'gateway' => { 'name' => 'BogusGateway' },
      'transaction' => { 'action' => 'authorize', 'amount' => 100 },
      'credit_card' => { 'number' => '1', 'month' => '9', 'year' => (Time.now.year + 1).to_s }
    }
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)
    assert_equal 5053, result['error_number']
  ensure
    TokenExGateway::BLOCK_GATEWAYS.replace(original)
  end

  def test_stripe_metadata_conversion
    payload = {
      'gateway' => { 'name' => 'StripeGateway', 'login' => 'sk_test_fake' },
      'transaction' => { 'action' => 'authorize', 'amount' => 100, 'metadata' => 'key1=val1|key2=val2' },
      'credit_card' => {
        'first_name' => 'Test',
        'last_name' => 'User',
        'number' => '4242424242424242',
        'month' => '9',
        'year' => (Time.now.year + 1).to_s,
        'verification_value' => '123'
      }
    }
    # This will fail at the gateway level (no real Stripe key), but the metadata
    # conversion should happen before the gateway call
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    # We just verify it didn't crash on metadata conversion
  end

  def test_no_marshal_dump_in_wrapper
    # Verify that the wrapper source code does not use Marshal.dump
    source = File.read(File.expand_path('../lib/tokenex_gateway.rb', __dir__))
    refute_match(/Marshal\.dump/, source, 'Wrapper should not use Marshal.dump - use options[:credit_card] instead')
  end

  def test_no_marshal_load_reference
    # Verify that the wrapper source code does not reference Marshal.load
    source = File.read(File.expand_path('../lib/tokenex_gateway.rb', __dir__))
    refute_match(/Marshal\.load/, source, 'Wrapper should not use Marshal.load')
  end

  def test_credit_card_in_options_for_capture
    # Verify the source code passes :credit_card in options for capture/refund
    source = File.read(File.expand_path('../lib/tokenex_gateway.rb', __dir__))
    assert_match(/additional_options\[:credit_card\] = am_payment/, source,
                 'Capture/refund should pass am_payment via options[:credit_card]')
  end

  # ---------- IXOONE-3 wallet support tests ------------------------------
  # These use WalletCaptureGateway (defined at the top of this file) which
  # echoes the constructed payment object's class/source/cryptogram/eci into
  # response params so we can assert the wallet branch did what it should.

  def _wallet_payload(action:, source:, with_cvv: true, cryptogram: 'X', eci: '05', transaction_id: nil)
    cc = {
      'first_name' => 'Test', 'last_name' => 'User',
      'number'     => '1', 'month' => '9', 'year' => (Time.now.year + 1).to_s
    }
    cc['verification_value'] = '123' if with_cvv
    cc['source']             = source             unless source.nil?
    cc['payment_cryptogram'] = cryptogram         unless cryptogram.nil?
    cc['eci']                = eci                unless eci.nil?
    cc['transaction_id']     = transaction_id     unless transaction_id.nil?

    {
      'gateway'     => { 'name' => 'WalletCaptureGateway' },
      'transaction' => { 'action' => action, 'amount' => 100 },
      'credit_card' => cc
    }
  end

  def test_wallet_apple_pay_builds_network_tokenization_credit_card
    # AC: source=apple_pay → NetworkTokenizationCreditCard
    payload = _wallet_payload(action: 'authorize', source: 'apple_pay',
                              cryptogram: 'AP_CRYPTO_1', eci: '05', transaction_id: 'AP_TXID_1')
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)

    assert result['success'], "expected success; got: #{result.inspect}"
    assert_equal 'ActiveMerchant::Billing::NetworkTokenizationCreditCard', result['params']['payment_class']
    assert_equal 'apple_pay',   result['params']['source']
    assert_equal 'AP_CRYPTO_1', result['params']['cryptogram']
    assert_equal '05',          result['params']['eci']
  end

  def test_wallet_google_pay_maps_to_android_pay
    # AC: source=google_pay → NetworkTokenizationCreditCard, with the wrapper
    # translating the public product name to the gem's internal :android_pay symbol.
    payload = _wallet_payload(action: 'purchase', source: 'google_pay',
                              cryptogram: 'GP_CRYPTO_1', eci: '07')
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)

    assert result['success']
    assert_equal 'ActiveMerchant::Billing::NetworkTokenizationCreditCard', result['params']['payment_class']
    assert_equal 'android_pay', result['params']['source']  # the wallet_source_map translation worked
  end

  def test_wallet_invalid_source_rejected
    # Plan addition: invalid source rejected loudly rather than silently falling
    # back to :apple_pay (which is what the gem's source getter would do).
    payload = _wallet_payload(action: 'authorize', source: 'paypal',
                              cryptogram: 'X', eci: '05')
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)

    refute result['success'], "expected failure for unknown wallet source; got: #{result.inspect}"
    assert_match(/Unsupported wallet source/, result['additional_details'].to_s)
  end

  def test_no_source_builds_standard_credit_card
    # AC: source absent → standard CreditCard (regression guard for the
    # non-wallet path).
    payload = _wallet_payload(action: 'authorize', source: nil,
                              cryptogram: nil, eci: nil)
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)

    assert result['success']
    assert_equal 'ActiveMerchant::Billing::CreditCard', result['params']['payment_class']
  end

  def test_wallet_purchase_without_verification_value
    # AC: missing verification_value with wallet source → no error.
    # Network-tokenized payments authenticate via cryptogram + ECI, not CVV.
    payload = _wallet_payload(action: 'purchase', source: 'apple_pay',
                              with_cvv: false,
                              cryptogram: 'AP_CRYPTO_NO_CVV', eci: '05')
    post '/process', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    result = JSON.parse(last_response.body)

    assert result['success'], "expected success without CVV; got: #{result.inspect}"
    assert_equal 'ActiveMerchant::Billing::NetworkTokenizationCreditCard', result['params']['payment_class']
    assert_equal 'apple_pay', result['params']['source']
  end
end
