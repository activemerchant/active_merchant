require 'test_helper'
require 'singleton'

class RemoteAleloTest < Test::Unit::TestCase
  def setup
    @gateway = AleloGateway.new(fixtures(:alelo))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @options = {
      order_id: '1',
      establishment_code: '000002007690360',
      sub_merchant_mcc: '5499',
      player_identification: '1',
      description: 'Store Purchase',
      external_trace_number: '123456'
    }
  end

  def test_access_token_success
    resp = @gateway.send :fetch_access_token

    assert_kind_of Response, resp
    refute_nil resp.message
  end

  def test_failure_access_token_with_invalid_keys
    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      gateway = AleloGateway.new({ client_id: 'abc123', client_secret: 'abc456' })
      gateway.send :fetch_access_token
    end

    assert_match(/401/, error.message)
  end

  def test_successful_remote_encryption_key_with_provided_access_token
    access_token = @gateway.send :fetch_access_token
    resp = @gateway.send(:remote_encryption_key, access_token.message)

    assert_kind_of Response, resp
    refute_nil resp.message
  end

  def test_ensure_credentials_with_no_provided_access_token_key_are_generated
    credentials = @gateway.send :ensure_credentials, {}

    refute_nil credentials[:key]
    refute_nil credentials[:access_token]
    assert_kind_of Response, credentials[:multiresp]
    assert_equal 2, credentials[:multiresp].responses.size
  end

  def test_sucessful_encryption_key_requested_when_access_token_provided
    access_token = @gateway.send :fetch_access_token
    @gateway.options[:access_token] = access_token.message
    credentials = @gateway.send :ensure_credentials

    refute_nil credentials[:key]
    refute_nil credentials[:access_token]
    assert_equal access_token.message, credentials[:access_token]
    assert_kind_of Response, credentials[:multiresp]
    assert_equal 1, credentials[:multiresp].responses.size
  end

  def test_successful_fallback_with_expired_access_token
    @gateway.options[:access_token] = 'abc123'
    credentials = @gateway.send :ensure_credentials

    refute_nil credentials[:key]
    refute_nil credentials[:access_token]
    refute_equal 'abc123', credentials[:access_token]
    assert_kind_of Response, credentials[:multiresp]
    assert_equal 2, credentials[:multiresp].responses.size
  end

  def test_successful_purchase
    set_credentials!
    @gateway.options[:encryption_uuid] = '53141521-afc8-4a08-af0c-f0382aef43c1'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_match %r{confirmada}i, response.message
  end

  def test_successful_purchase_with_no_predefined_credentials
    @gateway.options[:encryption_uuid] = '53141521-afc8-4a08-af0c-f0382aef43c1'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_match %r{confirmada}i, response.message
    refute_nil response.params['access_token']
    refute_nil response.params['encryption_key']
  end

  def test_unsuccessful_purchase_with_merchant_discredited
    set_credentials!
    @gateway.options[:encryption_uuid] = '7c82f46e-64f7-4745-9c60-335a689b8e90'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_match %r(contato), response.message
  end

  def test_unsuccessful_purchase_with_insuffieicent_funds
    set_credentials!
    @gateway.options[:encryption_uuid] = 'a36aa740-d505-4d47-8aa6-6c31c7526a68'
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_match %r(insuficiente), response.message
  end

  def test_unsuccessful_purchase_with_invalid_fields
    set_credentials!
    @gateway.options[:encryption_uuid] = 'd7aff4a6-1ea1-4e74-b81a-934589385958'
    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_match %r{Erro}, response.message
  end

  def test_unsuccessful_purchase_with_blocked_card
    set_credentials!
    @gateway.options[:encryption_uuid] = 'd2a0350d-e872-47bf-a543-2d36c2ad693e'
    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_match %r(Bloqueado), response.message
  end

  def test_successful_purchase_with_geolocalitation
    set_credentials!
    options = {
      geo_longitude: '10.451526',
      geo_latitude: '51.165691',
      uuid: '53141521-afc8-4a08-af0c-f0382aef43c1'
    }

    response = @gateway.purchase(@amount, @credit_card, @options.merge(options))
    assert_success response
    assert_match %r(Confirmada), response.message
  end

  def test_invalid_login
    gateway = AleloGateway.new(client_id: 'asdfghj', client_secret: '1234rtytre')

    error = assert_raises(ActiveMerchant::OAuthResponseError) do
      gateway.purchase(@amount, @credit_card, @options)
    end

    assert_match(/401/, error.message)
  end

  def test_transcript_scrubbing
    set_credentials!
    transcript = capture_transcript(@gateway) do
      @gateway.options[:encryption_uuid] = '53141521-afc8-4a08-af0c-f0382aef43c1'
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:client_id], transcript)
    assert_scrubbed(@gateway.options[:client_secret], transcript)
  end

  def test_successful_refund
    set_credentials!
    response = @gateway.refund(@amount, '990a39dd-3df2-46a5-89ac-012cca00ef0b#def456', {})

    assert_success response
    assert_match %r{Estornada}, response.message
  end

  def test_failure_refund_with_invalid_uuid
    set_credentials!
    response = @gateway.refund(@amount, '7f723387-d449-4c6c-aca3-9a583689dc34', {})

    assert_failure response
  end

  private

  def set_credentials!
    if AleloCredentials.instance.access_token.nil?
      credentials = @gateway.send :ensure_credentials, {}
      AleloCredentials.instance.access_token = credentials[:access_token]
      AleloCredentials.instance.key = credentials[:key]
      AleloCredentials.instance.uuid = credentials[:uuid]
    end

    @gateway.options[:access_token] = AleloCredentials.instance.access_token
    @gateway.options[:encryption_key] = AleloCredentials.instance.key
    @gateway.options[:encryption_uuid] = AleloCredentials.instance.uuid
  end
end

# A simple singleton so an access token and key can
# be shared among several tests
class AleloCredentials
  include Singleton

  attr_accessor :access_token, :key, :uuid
end
