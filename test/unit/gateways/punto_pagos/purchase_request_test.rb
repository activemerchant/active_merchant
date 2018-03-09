require 'test_helper'
require File.expand_path(File.dirname(__FILE__) + '/../../../../lib/active_merchant/billing/gateways/punto_pagos/purchase_request')

class PuntoPagosPurchaseRequestTest < Test::Unit::TestCase
  def setup
    Time.stubs(:now).returns(Time.new(1984, 6, 4))
    @request_class = ActiveMerchant::Billing::PuntoPagos::PurchaseRequest
    @request = @request_class.new(
      key: 'k',
      secret: 's',
      url: 'some-url',
      trx_id: 123,
      amount: 1000,
      payment_method: 1
    )
  end

  def test_headers
    headers = @request.headers
    assert_equal('application/json', headers['Accept'])
    assert_equal('utf-8', headers['Accept-Charset'])
    assert_equal('application/json; charset=utf-8', headers['Content-Type'])
    assert_equal('PP k:wbDLfr22QQNDrYNv2ayJUhebljs=', headers['Autorizacion'])
    assert_equal('Mon, 04 Jun 1984 00:00:00 GMT', headers['Fecha'])
  end

  def test_data
    data = JSON.parse(@request.data)
    assert_equal('123', data['trx_id'])
    assert_equal('1000.00', data['monto'])
    assert_equal(1, data['medio_pago'])
  end

  def test_endpoint
    assert_equal('some-url/transaccion/crear', @request.endpoint)
  end
end
