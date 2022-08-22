require 'test_helper'

class AleloTest < Test::Unit::TestCase
  def setup
    @gateway = AleloGateway.new(client_id: 'xxxx', client_secret: 'xxxx')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase; end

  def test_failed_purchase; end

  def test_successful_authorize; end

  def test_failed_authorize; end

  def test_successful_capture; end

  def test_failed_capture; end

  def test_successful_refund; end

  def test_failed_refund; end

  def test_successful_void; end

  def test_failed_void; end

  def test_successful_verify; end

  def test_successful_verify_with_failed_void; end

  def test_failed_verify; end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  def test_access_token_from_options
    options = { access_token: 'abc123' }

    assert_equal options[:access_token], @gateway.send(:access_token, options)
  end

  def test_encryption_key_from_options
    options = { encryption_key: 'abc123' }

    assert_equal options[:encryption_key], @gateway.send(:remote_encryption_key, options)
  end

  def test_success_payload_encryption
    jwe = @gateway.send(:encrypt_payload, { hello: 'world' }, test_key)

    refute_nil jwe
  end

  private

  def pre_scrubbed
    %(same text)
  end

  def post_scrubbed
    %(same text)
  end

  def test_key
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlqfFfUoVCZnSM66vq0UimOZzsd6k5nuHOMr5s/pGw45n24Qs2cdJlgtX34N7W7vftuxYBAMhD4FucFZ0b12HO3iqGheqcgPolYTAlM/XFkzEohSI3B5Xhj1m6PTJZfmwFWaGHWapy0oAHJQvc4gnjn5UjytN1UGCKNStiN255XhpdsDJBwY4zPz55doZGywKscpN4QuPGJQK/XocbWApYIh0+Yj9PxSgFoEWH1KIxDVg+voOruVrOJwPNaNITBX3O0U6G9xT4av+4hcomGNhrFZDuhlvbUqBllw0VUp+87bzDJVImnz97WvZLRnOMgrPfwTz5z467/yqbmaevCI+VwIDAQAB'
  end

  def successful_purchase_response
    %(
      Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
      to "true" when running remote tests:

      $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
        test/remote/gateways/remote_alelo_test.rb \
        -n test_successful_purchase
    )
  end

  def failed_purchase_response; end

  def successful_authorize_response; end

  def failed_authorize_response; end

  def successful_capture_response; end

  def failed_capture_response; end

  def successful_refund_response; end

  def failed_refund_response; end

  def successful_void_response; end

  def failed_void_response; end
end
