require 'test_helper'
require File.expand_path(File.dirname(__FILE__) + '/../../../../lib/active_merchant/billing/gateways/punto_pagos/status_request')

class PuntoPagosStatusRequestTest < Test::Unit::TestCase
  def setup
    Time.stubs(:now).returns(Time.new(1984, 6, 4))
    @request_class = ActiveMerchant::Billing::PuntoPagos::StatusRequest
    @request = @request_class.new(
      key: 'k',
      secret: 's',
      url: 'some-url',
      token: 'xxx'
    )
  end

  def test_headers
    headers = @request.headers
    assert_equal('application/json', headers['Accept'])
    assert_equal('utf-8', headers['Accept-Charset'])
    assert_equal('application/json; charset=utf-8', headers['Content-Type'])
    assert_equal('PP k:bFpoEFFCtzgHrFwyxoHcSgpeR6o=', headers['Autorizacion'])
    assert_equal('Mon, 04 Jun 1984 00:00:00 GMT', headers['Fecha'])
  end

  def test_endpoint
    assert_equal('some-url/transaccion/xxx', @request.endpoint)
  end
end
