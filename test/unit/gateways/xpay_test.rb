require 'test_helper'

class XpayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = XpayGateway.new(
      api_key: 'some api key'
    )
    @credit_card = credit_card
    @amount = 100
    @base_url = @gateway.test_url
    @options = {}
  end

  def test_supported_countries
    assert_equal %w(AT BE CY EE FI FR DE GR IE IT LV LT LU MT PT SK SI ES BG HR DK NO PL RO RO SE CH HU), XpayGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master maestro american_express jcb], @gateway.supported_cardtypes
  end

  def test_build_request_url_for_purchase
    action = :purchase
    assert_equal @gateway.send(:build_request_url, action), "#{@base_url}orders/2steps/payment"
  end

  def test_build_request_url_with_id_param
    action = :refund
    id = 123
    assert_equal @gateway.send(:build_request_url, action, id), "#{@base_url}operations/{123}/refunds"
  end

  def test_invalid_instance
    assert_raise ArgumentError do
      XpayGateway.new()
    end
  end

  def test_check_request_headers
    stub_comms do
      @gateway.send(:commit, 'purchase', {}, {})
    end.check_request(skip_response: true) do |_endpoint, _data, headers|
      assert_equal headers['Content-Type'], 'application/json'
      assert_equal headers['X-Api-Key'], 'some api key'
    end
  end

  def test_check_authorize_endpoint
    stub_comms do
      @gateway.send(:authorize, @amount, @credit_card, @options)
    end.check_request(skip_response: true) do |endpoint, _data, _headers|
      assert_match(/orders\/2steps\/init/, endpoint)
    end
  end
end
