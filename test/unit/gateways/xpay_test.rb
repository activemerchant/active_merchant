require 'test_helper'

class XpayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = XpayGateway.new(
      api_key: 'some api key'
    )
    @credit_card = credit_card
    @amount = 100
  end

  def test_supported_countries
    assert_equal %w(AT BE CY EE FI FR DE GR IE IT LV LT LU MT PT SK SI ES BG HR DK NO PL RO RO SE CH HU), XpayGateway.supported_countries
  end

  def test_supported_cardtypes
    assert_equal %i[visa master maestro american_express jcb], @gateway.supported_cardtypes
  end
end
